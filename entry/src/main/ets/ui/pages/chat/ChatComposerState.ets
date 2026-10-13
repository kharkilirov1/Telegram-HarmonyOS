import { TgVoiceRecordingState } from '../../tg_ui/utils/TgVoiceRecordingPolicy';

// Page-owned presentation state. Keep this instance stable for its route lifetime.
@ObservedV2
export class ChatComposerState {
  @Trace composerDraftText: string = '';
  @Trace composerSelectionStart: number = 0;
  @Trace composerSelectionEnd: number = 0;
  @Trace composerCaretRequestRevision: number = 0;
  @Trace pendingAttachmentKind: string = '';
  @Trace pendingAttachmentTitle: string = '';
  @Trace pendingAttachmentPreview: string = '';
  @Trace pendingAttachmentUris: string[] = [];
  @Trace isSending: boolean = false;
  @Trace voiceRecordingState: TgVoiceRecordingState = 'idle';
  @Trace voiceRecordingDurationMs: number = 0;
  @Trace showBotMenu: boolean = false;
  @Trace botMenuOpen: boolean = false;
  @Trace botMenuTitle: string = '';
  @Trace replyToMessageId: string = '0';
  @Trace replyToAuthor: string = '';
  @Trace replyToPreview: string = '';
  @Trace replyToIsQuote: boolean = false;
  @Trace isForwardingMessages: boolean = false;
  @Trace forwardingMessageIds: string[] = [];
  @Trace forwardSourceChatId: number = 0;
  @Trace forwardTitle: string = '';
  @Trace forwardPreview: string = '';
  @Trace isEditingMessage: boolean = false;
  @Trace editingMessageId: string = '0';
  @Trace editingOriginalText: string = '';
  @Trace editingAllowsEmpty: boolean = false;
}
