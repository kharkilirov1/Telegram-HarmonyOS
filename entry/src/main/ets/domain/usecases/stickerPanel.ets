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
  createSendStickerCommand,
  createDownloadFileCommand
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
