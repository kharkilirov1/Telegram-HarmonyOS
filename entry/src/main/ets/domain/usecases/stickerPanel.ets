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
  duration: number = 0;
  width: number = 0;
  height: number = 0;
}

export class SendAnimationParams {
  chatId: ChatId = 0;
  remoteFileId: string = '';
  duration: number = 0;
  width: number = 0;
  height: number = 0;
}

function parseStickerEntry(sticker: TdObject): StickerPanelEntry {
  const entry = new StickerPanelEntry();
  entry.stickerId = sticker.getInt64String('id');
  entry.emoji = sticker.getString('emoji');
  entry.width = sticker.getNumber('width');
  entry.height = sticker.getNumber('height');

  const format = sticker.getObject('format').getType();
  entry.isAnimated = format === 'stickerFormatTgs';
  entry.isVideo = format === 'stickerFormatWebm';

  const file = sticker.getObject('sticker');
  entry.fileId = file.getNumber('id');
  entry.remoteFileId = file.getObject('remote').getString('id');
  const local = file.getObject('local');
  if (local.getBool('is_downloading_completed')) {
    entry.localPath = local.getString('path');
  }

  const thumbFile = sticker.getObject('thumbnail').getObject('file');
  entry.thumbFileId = thumbFile.getNumber('id');
  const thumbLocal = thumbFile.getObject('local');
  if (thumbLocal.getBool('is_downloading_completed')) {
    entry.thumbPath = thumbLocal.getString('path');
  }

  return entry;
}

export class StickerPanelUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
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
      entry.thumbFileId = thumbFile.getNumber('id');
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
      const anim = animations[i];
      const entry = new GifPanelEntry();
      entry.duration = anim.getNumber('duration');
      entry.width = anim.getNumber('width');
      entry.height = anim.getNumber('height');
      const file = anim.getObject('animation');
      entry.fileId = file.getNumber('id');
      entry.remoteFileId = file.getObject('remote').getString('id');
      const thumbFile = anim.getObject('thumbnail').getObject('file');
      entry.thumbFileId = thumbFile.getNumber('id');
      const thumbLocal = thumbFile.getObject('local');
      if (thumbLocal.getBool('is_downloading_completed')) {
        entry.thumbPath = thumbLocal.getString('path');
      }
      if (entry.remoteFileId.length > 0) {
        entries.push(entry);
      }
    }
    hilog.info(DOMAIN, TAG, 'Saved animations loaded: %{public}d', entries.length);
    return entries;
  }

  async sendAnimation(params: SendAnimationParams): Promise<void> {
    if (params.chatId === 0 || params.remoteFileId.length === 0) {
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
