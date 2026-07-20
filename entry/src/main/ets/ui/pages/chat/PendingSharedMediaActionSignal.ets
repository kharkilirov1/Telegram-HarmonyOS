// PendingSharedMediaActionSignal — one-shot intent from Profile Shared Media.
// TgChatScreenPage consumes it after the profile stack unwinds and reuses the
// same gallery/download/playback paths as an ordinary message-bubble tap.

export type SharedMediaActionKind = 'media' | 'file' | 'link' | 'voice';

export class PendingSharedMediaAction {
  readonly chatId: number;
  readonly messageId: string;
  readonly kind: SharedMediaActionKind;
  readonly linkUrl: string;

  constructor(chatId: number, messageId: string, kind: SharedMediaActionKind, linkUrl: string = '') {
    this.chatId = chatId;
    this.messageId = messageId;
    this.kind = kind;
    this.linkUrl = linkUrl;
  }
}

export class PendingSharedMediaActionSignal {
  private static chatId: number = 0;
  private static messageId: string = '0';
  private static kind: SharedMediaActionKind = 'media';
  private static linkUrl: string = '';

  static set(chatId: number, messageId: string, kind: SharedMediaActionKind, linkUrl: string = ''): void {
    PendingSharedMediaActionSignal.chatId = chatId;
    PendingSharedMediaActionSignal.messageId = messageId;
    PendingSharedMediaActionSignal.kind = kind;
    PendingSharedMediaActionSignal.linkUrl = linkUrl;
  }

  static consume(chatId: number): PendingSharedMediaAction | undefined {
    if (PendingSharedMediaActionSignal.chatId !== chatId ||
      PendingSharedMediaActionSignal.messageId === '0') {
      return undefined;
    }
    const action = new PendingSharedMediaAction(
      PendingSharedMediaActionSignal.chatId,
      PendingSharedMediaActionSignal.messageId,
      PendingSharedMediaActionSignal.kind,
      PendingSharedMediaActionSignal.linkUrl
    );
    PendingSharedMediaActionSignal.clear();
    return action;
  }

  static clear(): void {
    PendingSharedMediaActionSignal.chatId = 0;
    PendingSharedMediaActionSignal.messageId = '0';
    PendingSharedMediaActionSignal.kind = 'media';
    PendingSharedMediaActionSignal.linkUrl = '';
  }
}
