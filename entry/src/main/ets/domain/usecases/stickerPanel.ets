// StickerPanel use cases — recent stickers for the composer panel and sticker send.
//
// getRecentStickers is a request-response call (no update flows through the store),
// so the panel talks to the gateway directly: load list → download missing files
// synchronously per item → send via inputMessageSticker with inputFileRemote.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { ChatId } from '../../core/model/EntityId';
import {
  createGetRecentStickersCommand,
  createGetFavoriteStickersCommand,
  createGetPremiumStickersCommand,
  createGetInstalledCustomEmojiSetsCommand,
  createGetTrendingCustomEmojiSetsCommand,
  createSearchEmojisCommand,
  createSearchCustomEmojiStickersCommand,
  createSearchRegularStickersCommand,
  createGetOptionCommand,
  createSearchPublicChatCommand,
  createGetInlineQueryResultsCommand,
  createSendInlineQueryResultCommand,
  createGetStickerSetCommand,
  createSendStickerCommand,
  createSendAnimationCommand,
  createDownloadFileCommand,
  GetInstalledStickerSetsCommand,
  GetSavedAnimationsCommand
} from '../../core/model/AppCommand';
import { TdObject } from '../../models/td/common/index';

const TAG = 'StickerPanel';
const DOMAIN = 0x0016;

// Plain data holder for one panel sticker (UI wraps it into its own VO)
export class StickerPanelEntry {
  stickerId: string = '0';
  remoteFileId: string = '';   // sticker.file.remote.id — send handle
  fileId: number = 0;          // sticker.file.id — download handle
  localPath: string = '';      // set when file is already on disk
  thumbFileId: number = 0;
  thumbPath: string = '';
  emoji: string = '';
  isAnimated: boolean = false; // tgs
  isVideo: boolean = false;    // webm
  width: number = 0;
  height: number = 0;
  customEmojiId: string = '0'; // stickerFullTypeCustomEmoji.custom_emoji_id
}

export class SendStickerParams {
  chatId: ChatId = 0;
  remoteFileId: string = '';
  width: number = 0;
  height: number = 0;
  emoji: string = '';
}

// One installed sticker set for the panel's pack tabs
export class StickerSetInfoEntry {
  setId: string = '0';
  title: string = '';
  thumbFileId: number = 0;
  thumbPath: string = '';
  coverEmoji: string = ''; // first cover's emoji — fallback tab icon
}

// One saved GIF for the panel's GIF tab
export class GifPanelEntry {
  remoteFileId: string = ''; // animation.file.remote.id — send handle
  fileId: number = 0;
  thumbFileId: number = 0;
  thumbPath: string = '';
  minithumbnailData: string = '';
  duration: number = 0;
  width: number = 0;
  height: number = 0;
  inlineQueryId: string = '0';
  inlineResultId: string = '';
}

export class GifSearchPage {
  queryId: string = '0';
  nextOffset: string = '';
  items: GifPanelEntry[] = [];
}

export class SendAnimationParams {
  chatId: ChatId = 0;
  remoteFileId: string = '';
  duration: number = 0;
  width: number = 0;
  height: number = 0;
  inlineQueryId: string = '0';
  inlineResultId: string = '';
}

export class EmojiKeyboardSearchResult {
  unicodeEmoji: string[] = [];
  customEmoji: StickerPanelEntry[] = [];
}

function parseStickerEntry(sticker: TdObject): StickerPanelEntry {
  const entry = new StickerPanelEntry();
  entry.stickerId = sticker.getInt64String('id');
  entry.emoji = sticker.getString('emoji');
  entry.width = sticker.getNumber('width');
  entry.height = sticker.getNumber('height');
  const fullType = sticker.getObject('full_type');
  if (fullType.getType() === 'stickerFullTypeCustomEmoji') {
    entry.customEmojiId = fullType.getTopLevelInt64String('custom_emoji_id');
  }

  const format = sticker.getObject('format').getType();
  entry.isAnimated = format === 'stickerFormatTgs';
  entry.isVideo = format === 'stickerFormatWebm';

  const file = sticker.getObject('sticker');
  entry.fileId = file.getTopLevelNumber('id');
  entry.remoteFileId = file.getObject('remote').getString('id');
  const local = file.getObject('local');
  if (local.getBool('is_downloading_completed')) {
    entry.localPath = local.getString('path');
  }

  const thumbFile = sticker.getObject('thumbnail').getObject('file');
  entry.thumbFileId = thumbFile.getTopLevelNumber('id');
  const thumbLocal = thumbFile.getObject('local');
  if (thumbLocal.getBool('is_downloading_completed')) {
    entry.thumbPath = thumbLocal.getString('path');
  }

  return entry;
}

function parseGifEntry(animation: TdObject, inlineQueryId: string = '0',
  inlineResultId: string = ''): GifPanelEntry {
  const entry = new GifPanelEntry();
  entry.duration = animation.getNumber('duration');
  entry.width = animation.getNumber('width');
  entry.height = animation.getNumber('height');
  const file = animation.getObject('animation');
  entry.fileId = file.getTopLevelNumber('id');
  entry.remoteFileId = file.getObject('remote').getString('id');
  const thumbFile = animation.getObject('thumbnail').getObject('file');
  entry.thumbFileId = thumbFile.getTopLevelNumber('id');
  const thumbLocal = thumbFile.getObject('local');
  if (thumbLocal.getBool('is_downloading_completed')) {
    entry.thumbPath = thumbLocal.getString('path');
  }
  entry.minithumbnailData = animation.getObject('minithumbnail').getString('data');
  entry.inlineQueryId = inlineQueryId;
  entry.inlineResultId = inlineResultId;
  return entry;
}

export class StickerPanelUseCase {
  private gateway: TdGatewayPort;
  private gifBotUserId: number = 0;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async searchEmojiKeyboard(
    query: string,
    inputLanguageCodes: string[]
  ): Promise<EmojiKeyboardSearchResult> {
    const result = new EmojiKeyboardSearchResult();
    const normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) {
      return result;
    }

    try {
      const emojiResponse = await this.gateway.send(
        createSearchEmojisCommand(normalizedQuery, inputLanguageCodes)) as TdObject;
      if (emojiResponse.getType() === 'emojiKeywords') {
        const keywords = emojiResponse.getArray('emoji_keywords');
        const seen: Set<string> = new Set<string>();
        for (let i = 0; i < keywords.length; i++) {
          const emoji = keywords[i].getString('emoji');
          if (emoji.length > 0 && !seen.has(emoji)) {
            seen.add(emoji);
            result.unicodeEmoji.push(emoji);
          }
        }
      } else {
        hilog.warn(DOMAIN, TAG, 'Unexpected emoji keyword response: %{public}s', emojiResponse.getType());
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Unicode emoji search failed: %{public}s', (error as Error).message);
    }

    try {
      const emojiQuery = result.unicodeEmoji.join(' ');
      const stickerResponse = await this.gateway.send(createSearchCustomEmojiStickersCommand(
        normalizedQuery, inputLanguageCodes, emojiQuery, 0, 64)) as TdObject;
      if (stickerResponse.getType() === 'stickers') {
        const stickers = stickerResponse.getArray('stickers');
        const seenCustomIds: Set<string> = new Set<string>();
        for (let i = 0; i < stickers.length; i++) {
          const entry = parseStickerEntry(stickers[i]);
          if (entry.customEmojiId !== '0' && entry.remoteFileId.length > 0 && entry.emoji.length > 0 &&
            !seenCustomIds.has(entry.customEmojiId)) {
            seenCustomIds.add(entry.customEmojiId);
            result.customEmoji.push(entry);
          }
        }
      } else {
        hilog.warn(DOMAIN, TAG, 'Unexpected custom emoji search response: %{public}s',
          stickerResponse.getType());
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Custom emoji search failed: %{public}s', (error as Error).message);
    }

    return result;
  }

  async loadRecentStickers(): Promise<StickerPanelEntry[]> {
    const response = await this.gateway.send(createGetRecentStickersCommand(false)) as TdObject;
    if (response.getType() !== 'stickers') {
      hilog.warn(DOMAIN, TAG, 'Unexpected recent stickers response: %{public}s', response.getType());
      return [];
    }
    const stickers = response.getArray('stickers');
    const entries: StickerPanelEntry[] = [];
    for (let i = 0; i < stickers.length; i++) {
      const entry = parseStickerEntry(stickers[i]);
      if (entry.remoteFileId.length > 0) {
        entries.push(entry);
      }
    }
    hilog.info(DOMAIN, TAG, 'Recent stickers loaded: %{public}d', entries.length);
    return entries;
  }

  async searchRegularStickers(
    query: string,
    inputLanguageCodes: string[]
  ): Promise<StickerPanelEntry[]> {
    const normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) {
      return [];
    }
    const response = await this.gateway.send(createSearchRegularStickersCommand(
      normalizedQuery, inputLanguageCodes, '', 0, 64)) as TdObject;
    if (response.getType() !== 'stickers') {
      hilog.warn(DOMAIN, TAG, 'Unexpected regular sticker search response: %{public}s', response.getType());
      return [];
    }
    const stickers = response.getArray('stickers');
    const entries: StickerPanelEntry[] = [];
    const seenStickerIds: Set<string> = new Set<string>();
    for (let i = 0; i < stickers.length; i++) {
      const entry = parseStickerEntry(stickers[i]);
      if (entry.stickerId !== '0' && entry.remoteFileId.length > 0 &&
        !seenStickerIds.has(entry.stickerId)) {
        seenStickerIds.add(entry.stickerId);
        entries.push(entry);
      }
    }
    hilog.info(DOMAIN, TAG, 'Regular sticker search loaded: %{public}d', entries.length);
    return entries;
  }

  async loadFavoriteStickers(): Promise<StickerPanelEntry[]> {
    const response = await this.gateway.send(createGetFavoriteStickersCommand()) as TdObject;
    if (response.getType() !== 'stickers') {
      hilog.warn(DOMAIN, TAG, 'Unexpected favorite stickers response: %{public}s', response.getType());
      return [];
    }
    const stickers = response.getArray('stickers');
    const entries: StickerPanelEntry[] = [];
    for (let i = 0; i < stickers.length; i++) {
      const entry = parseStickerEntry(stickers[i]);
      if (entry.remoteFileId.length > 0) {
        entries.push(entry);
      }
    }
    hilog.info(DOMAIN, TAG, 'Favorite stickers loaded: %{public}d', entries.length);
    return entries;
  }

  async loadPremiumStickers(limit: number = 16): Promise<StickerPanelEntry[]> {
    const response = await this.gateway.send(createGetPremiumStickersCommand(limit)) as TdObject;
    if (response.getType() !== 'stickers') {
      hilog.warn(DOMAIN, TAG, 'Unexpected premium stickers response: %{public}s', response.getType());
      return [];
    }
    const stickers = response.getArray('stickers');
    const entries: StickerPanelEntry[] = [];
    for (let i = 0; i < stickers.length; i++) {
      const entry = parseStickerEntry(stickers[i]);
      if (entry.remoteFileId.length > 0) {
        entries.push(entry);
      }
    }
    hilog.info(DOMAIN, TAG, 'Premium stickers loaded: %{public}d', entries.length);
    return entries;
  }

  async loadInstalledStickerSets(): Promise<StickerSetInfoEntry[]> {
    const response = await this.gateway.send(new GetInstalledStickerSetsCommand()) as TdObject;
    if (response.getType() !== 'stickerSets') {
      hilog.warn(DOMAIN, TAG, 'Unexpected sticker sets response: %{public}s', response.getType());
      return [];
    }
    const sets = response.getArray('sets');
    const entries: StickerSetInfoEntry[] = [];
    for (let i = 0; i < sets.length; i++) {
      const set = sets[i];
      const entry = new StickerSetInfoEntry();
      entry.setId = set.getTopLevelInt64String('id');
      entry.title = set.getString('title');
      const thumbFile = set.getObject('thumbnail').getObject('file');
      entry.thumbFileId = thumbFile.getTopLevelNumber('id');
      const thumbLocal = thumbFile.getObject('local');
      if (thumbLocal.getBool('is_downloading_completed')) {
        entry.thumbPath = thumbLocal.getString('path');
      }
      const covers = set.getArray('covers');
      if (covers.length > 0) {
        entry.coverEmoji = covers[0].getString('emoji');
      }
      if (entry.setId !== '0') {
        entries.push(entry);
      }
    }
    hilog.info(DOMAIN, TAG, 'Installed sticker sets loaded: %{public}d', entries.length);
    return entries;
  }

  async loadInstalledCustomEmojiSets(): Promise<StickerSetInfoEntry[]> {
    const response = await this.gateway.send(createGetInstalledCustomEmojiSetsCommand()) as TdObject;
    if (response.getType() !== 'stickerSets') {
      hilog.warn(DOMAIN, TAG, 'Unexpected custom emoji sets response: %{public}s', response.getType());
      return [];
    }
    const sets = response.getArray('sets');
    const entries: StickerSetInfoEntry[] = [];
    for (let i = 0; i < sets.length; i++) {
      const set = sets[i];
      const entry = new StickerSetInfoEntry();
      entry.setId = set.getTopLevelInt64String('id');
      entry.title = set.getString('title');
      const thumbFile = set.getObject('thumbnail').getObject('file');
      entry.thumbFileId = thumbFile.getTopLevelNumber('id');
      const thumbLocal = thumbFile.getObject('local');
      if (thumbLocal.getBool('is_downloading_completed')) {
        entry.thumbPath = thumbLocal.getString('path');
      }
      const covers = set.getArray('covers');
      if (covers.length > 0) {
        entry.coverEmoji = covers[0].getString('emoji');
      }
      if (entry.setId !== '0') {
        entries.push(entry);
      }
    }
    hilog.info(DOMAIN, TAG, 'Installed custom emoji sets loaded: %{public}d', entries.length);
    return entries;
  }

  async loadTrendingCustomEmojiSets(offset: number = 0, limit: number = 12): Promise<StickerSetInfoEntry[]> {
    const response = await this.gateway.send(createGetTrendingCustomEmojiSetsCommand(offset, limit)) as TdObject;
    if (response.getType() !== 'trendingStickerSets') {
      hilog.warn(DOMAIN, TAG, 'Unexpected trending custom emoji response: %{public}s', response.getType());
      return [];
    }
    const sets = response.getArray('sets');
    const entries: StickerSetInfoEntry[] = [];
    for (let i = 0; i < sets.length; i++) {
      const set = sets[i];
      const entry = new StickerSetInfoEntry();
      entry.setId = set.getTopLevelInt64String('id');
      entry.title = set.getString('title');
      const thumbFile = set.getObject('thumbnail').getObject('file');
      entry.thumbFileId = thumbFile.getTopLevelNumber('id');
      const thumbLocal = thumbFile.getObject('local');
      if (thumbLocal.getBool('is_downloading_completed')) {
        entry.thumbPath = thumbLocal.getString('path');
      }
      const covers = set.getArray('covers');
      if (covers.length > 0) {
        entry.coverEmoji = covers[0].getString('emoji');
      }
      if (entry.setId !== '0') {
        entries.push(entry);
      }
    }
    hilog.info(DOMAIN, TAG, 'Trending custom emoji sets loaded: %{public}d', entries.length);
    return entries;
  }

  async loadStickerSet(setId: string): Promise<StickerPanelEntry[]> {
    const response = await this.gateway.send(createGetStickerSetCommand(setId)) as TdObject;
    if (response.getType() !== 'stickerSet') {
      hilog.warn(DOMAIN, TAG, 'Unexpected sticker set response: %{public}s', response.getType());
      return [];
    }
    const stickers = response.getArray('stickers');
    const entries: StickerPanelEntry[] = [];
    for (let i = 0; i < stickers.length; i++) {
      const entry = parseStickerEntry(stickers[i]);
      if (entry.remoteFileId.length > 0) {
        entries.push(entry);
      }
    }
    hilog.info(DOMAIN, TAG, 'Sticker set %{public}s loaded: %{public}d stickers', setId, entries.length);
    return entries;
  }

  async loadSavedAnimations(): Promise<GifPanelEntry[]> {
    const response = await this.gateway.send(new GetSavedAnimationsCommand()) as TdObject;
    if (response.getType() !== 'animations') {
      hilog.warn(DOMAIN, TAG, 'Unexpected saved animations response: %{public}s', response.getType());
      return [];
    }
    const animations = response.getArray('animations');
    const entries: GifPanelEntry[] = [];
    for (let i = 0; i < animations.length; i++) {
      const entry = parseGifEntry(animations[i]);
      if (entry.remoteFileId.length > 0) {
        entries.push(entry);
      }
    }
    hilog.info(DOMAIN, TAG, 'Saved animations loaded: %{public}d', entries.length);
    return entries;
  }

  private async resolveGifBotUserId(): Promise<number> {
    if (this.gifBotUserId > 0) {
      return this.gifBotUserId;
    }
    let username = 'gif';
    try {
      const option = await this.gateway.send(
        createGetOptionCommand('animation_search_bot_username')) as TdObject;
      if (option.getType() === 'optionValueString') {
        const value = option.getString('value').trim();
        if (value.length > 0) {
          username = value.startsWith('@') ? value.substring(1) : value;
        }
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'GIF bot option failed, using fallback: %{public}s', String(error));
    }
    try {
      const chat = await this.gateway.send(createSearchPublicChatCommand(username)) as TdObject;
      const type = chat.getObject('type');
      if (chat.getType() === 'chat' && type.getType() === 'chatTypePrivate') {
        this.gifBotUserId = type.getNumber('user_id');
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'GIF bot resolve failed: %{public}s', String(error));
    }
    return this.gifBotUserId;
  }

  async searchGifs(query: string, chatId: ChatId, offset: string = ''): Promise<GifSearchPage> {
    const page = new GifSearchPage();
    const normalizedQuery = query.trim();
    if (normalizedQuery.length === 0 || chatId === 0) {
      return page;
    }
    const botUserId = await this.resolveGifBotUserId();
    if (botUserId <= 0) {
      return page;
    }
    const response = await this.gateway.send(createGetInlineQueryResultsCommand(
      botUserId, chatId, normalizedQuery, offset)) as TdObject;
    if (response.getType() !== 'inlineQueryResults') {
      hilog.warn(DOMAIN, TAG, 'Unexpected GIF inline response: %{public}s', response.getType());
      return page;
    }
    page.queryId = response.getTopLevelInt64String('inline_query_id');
    page.nextOffset = response.getString('next_offset');
    const results = response.getArray('results');
    const seenResultIds: Set<string> = new Set<string>();
    for (let i = 0; i < results.length; i++) {
      const result = results[i];
      if (result.getType() !== 'inlineQueryResultAnimation') {
        continue;
      }
      const resultId = result.getString('id');
      const entry = parseGifEntry(result.getObject('animation'), page.queryId, resultId);
      if (resultId.length > 0 && entry.remoteFileId.length > 0 && !seenResultIds.has(resultId)) {
        seenResultIds.add(resultId);
        page.items.push(entry);
      }
    }
    hilog.info(DOMAIN, TAG, 'GIF inline page loaded: %{public}d', page.items.length);
    return page;
  }

  async sendAnimation(params: SendAnimationParams): Promise<void> {
    if (params.chatId === 0) {
      hilog.warn(DOMAIN, TAG, 'sendAnimation rejected: empty chat');
      return;
    }
    if (params.inlineQueryId !== '0' && params.inlineResultId.length > 0) {
      await this.gateway.send(createSendInlineQueryResultCommand(
        params.chatId, params.inlineQueryId, params.inlineResultId, true));
      hilog.info(DOMAIN, TAG, 'Inline GIF sent to chat %{public}d', params.chatId);
      return;
    }
    if (params.remoteFileId.length === 0) {
      hilog.warn(DOMAIN, TAG, 'sendAnimation rejected: empty chat or file');
      return;
    }
    await this.gateway.send(createSendAnimationCommand(
      params.chatId, params.remoteFileId, params.duration, params.width, params.height));
    hilog.info(DOMAIN, TAG, 'Animation sent to chat %{public}d', params.chatId);
  }

  // Downloads one sticker file and returns its sandbox path ('' on failure).
  // synchronous=true so the response already carries local.path.
  async downloadStickerFile(fileId: number): Promise<string> {
    if (fileId <= 0) {
      return '';
    }
    try {
      const response = await this.gateway.send(createDownloadFileCommand(fileId, 1, true)) as TdObject;
      const local = response.getObject('local');
      if (local.getBool('is_downloading_completed')) {
        return local.getString('path');
      }
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'sticker download failed id=%{public}d: %{public}s',
        fileId, String(error));
    }
    return '';
  }

  // Visible grouped-home previews use TDLib's updateFile flow instead of
  // blocking the panel on a chain of synchronous downloads.
  async requestStickerFileDownload(fileId: number, priority: number = 16): Promise<string> {
    if (fileId <= 0) {
      return '';
    }
    try {
      const response = await this.gateway.send(createDownloadFileCommand(fileId, priority, false)) as TdObject;
      const local = response.getObject('local');
      if (local.getBool('is_downloading_completed')) {
        return local.getString('path');
      }
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'sticker preview request failed id=%{public}d: %{public}s',
        fileId, String(error));
    }
    return '';
  }

  async sendSticker(params: SendStickerParams): Promise<void> {
    if (params.chatId === 0 || params.remoteFileId.length === 0) {
      hilog.warn(DOMAIN, TAG, 'sendSticker rejected: empty chat or file');
      return;
    }
    await this.gateway.send(createSendStickerCommand(
      params.chatId, params.remoteFileId, params.width, params.height, params.emoji));
    hilog.info(DOMAIN, TAG, 'Sticker sent to chat %{public}d', params.chatId);
  }
}

export function createStickerPanelUseCase(gateway: TdGatewayPort): StickerPanelUseCase {
  return new StickerPanelUseCase(gateway);
}
