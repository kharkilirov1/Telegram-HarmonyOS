// PendingMediaOpenIntent — user-initiated download continuation.
// Keeps runtime behavior Telegram-like: tap unloaded media -> download -> open/play
// when the reducer exposes a local file path.

import { ChatTimelineEntryVO, ChatMessageRowVO } from './ChatTimelineVO';

export type PendingMediaOpenKind = 'document' | 'audio' | 'voice';

export class PendingMediaOpenResolution {
  kind: PendingMediaOpenKind = 'document';
  fileId: number = 0;
  messageId: string = '0';
  path: string = '';
  mimeType: string = '';
}

export class PendingMediaOpenIntent {
  kind: PendingMediaOpenKind = 'document';
  fileId: number = 0;
  messageId: string = '0';
  mimeType: string = '';
  chatId: number = 0;
  lifecycleToken: number = 0;

  set(kind: PendingMediaOpenKind, fileId: number, messageId: string, mimeType: string,
    chatId: number, lifecycleToken: number): void {
    if (fileId <= 0) {
      this.reset();
      return;
    }
    this.kind = kind;
    this.fileId = fileId;
    this.messageId = messageId.length > 0 ? messageId : '0';
    this.mimeType = mimeType;
    this.chatId = chatId;
    this.lifecycleToken = lifecycleToken;
  }

  reset(): void {
    this.kind = 'document';
    this.fileId = 0;
    this.messageId = '0';
    this.mimeType = '';
    this.chatId = 0;
    this.lifecycleToken = 0;
  }

  isActiveFor(chatId: number, lifecycleToken: number): boolean {
    return this.fileId > 0 &&
      this.chatId === chatId &&
      this.lifecycleToken === lifecycleToken;
  }

  matchesFile(fileId: number): boolean {
    return fileId > 0 && this.fileId === fileId;
  }
}

function matchesMessage(intent: PendingMediaOpenIntent, message: ChatMessageRowVO): boolean {
  return intent.messageId === '0' || intent.messageId === message.messageId;
}

function makeResolution(intent: PendingMediaOpenIntent, message: ChatMessageRowVO, path: string): PendingMediaOpenResolution {
  const resolution = new PendingMediaOpenResolution();
  resolution.kind = intent.kind;
  resolution.fileId = intent.fileId;
  resolution.messageId = message.messageId;
  resolution.path = path;
  resolution.mimeType = intent.mimeType.length > 0 ? intent.mimeType : message.mimeType;
  return resolution;
}

export function resolvePendingMediaOpenIntent(intent: PendingMediaOpenIntent, entries: ChatTimelineEntryVO[],
  chatId: number, lifecycleToken: number): PendingMediaOpenResolution | undefined {
  if (!intent.isActiveFor(chatId, lifecycleToken)) {
    return undefined;
  }
  for (const entry of entries) {
    if (entry.kind !== 'message') {
      continue;
    }
    const message = entry.message;
    if (!matchesMessage(intent, message)) {
      continue;
    }
    if (intent.kind === 'document' &&
      message.documentFileId === intent.fileId &&
      message.documentPath.trim().length > 0) {
      return makeResolution(intent, message, message.documentPath);
    }
    if (intent.kind === 'audio' &&
      message.audioFileId === intent.fileId &&
      message.audioPath.trim().length > 0) {
      return makeResolution(intent, message, message.audioPath);
    }
    if (intent.kind === 'voice' &&
      message.voiceFileId === intent.fileId &&
      message.voicePath.trim().length > 0) {
      return makeResolution(intent, message, message.voicePath);
    }
  }
  return undefined;
}
