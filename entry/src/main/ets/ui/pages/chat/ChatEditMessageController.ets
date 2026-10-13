import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { EditMessageParams, EditMessageUseCase, EditMessageOutcomeError } from '../../../domain/usecases/editMessage';

export interface ChatEditMessageHost {
  getActiveChatId(): number;
  getLifecycleToken(): number;
  hasActiveChatState(): boolean;
  getEditUseCase(): EditMessageUseCase | undefined;
  getEditingMessageId(): string;
  getEditingOriginalText(): string;
  rebaseEditingMessage(messageId: string, text: string): void;
  getDraftText(): string;
  clearEditMode(clearDraft: boolean): void;
  isSendingMessage(): boolean;
  setSendingMessage(value: boolean): void;
  getSendOperationToken(): number;
  getChatUIContext(): UIContext;
}

// Retain the editable text until the actual server result is confirmed. The
// page-wide send owner prevents double submission; edit intent guards prevent
// stale completion from clearing a replacement edit or a newer draft.
export class ChatEditMessageController {
  private generation: number = 0;
  private releaseOwner?: () => void;

  cancel(): void {
    this.generation++;
    this.releaseOwner?.();
    this.releaseOwner = undefined;
  }

  submit(newText: string, host: ChatEditMessageHost): void {
    const useCase = host.getEditUseCase();
    const chatId = host.getActiveChatId();
    const lifecycle = host.getLifecycleToken();
    const messageId = host.getEditingMessageId();
    if (!useCase || !host.hasActiveChatState() || host.isSendingMessage() || chatId === 0 || messageId === '0') return;
    const original = host.getEditingOriginalText();
    const submittedDraft = host.getDraftText();
    if (newText === original) {
      this.cancel();
      host.clearEditMode(true);
      return;
    }
    const generation = ++this.generation;
    const params = new EditMessageParams();
    params.chatId = chatId;
    params.messageId = messageId;
    params.text = newText;
    params.expectedOriginalText = original;
    host.setSendingMessage(true);
    const operation = host.getSendOperationToken();
    const ownsOperation = (): boolean => operation === host.getSendOperationToken() &&
      lifecycle === host.getLifecycleToken() && chatId === host.getActiveChatId();
    const ownsSend = (): boolean => ownsOperation() && host.hasActiveChatState() && host.getEditUseCase() === useCase;
    const ownsEdit = (): boolean => generation === this.generation && ownsSend() &&
      host.getEditingMessageId() === messageId && host.getEditingOriginalText() === original;
    // Permission loss cannot strand our own busy bit; only a newer operation
    // or a new page context owns the right to keep that bit after completion.
    this.releaseOwner = (): void => { if (ownsOperation()) host.setSendingMessage(false); };
    useCase.execute(params, ownsEdit)
      .then((result) => {
        if (!ownsEdit()) return;
        if (host.getDraftText() === submittedDraft) {
          host.clearEditMode(true);
        } else {
          // New typing is not discarded. Rebase only its original server text,
          // without resetting the draft, selection or custom-emoji entities.
          host.rebaseEditingMessage(result.messageId, result.text);
        }
      })
      .catch((error: Object) => {
        if (!ownsEdit()) return;
        const text = error instanceof EditMessageOutcomeError
          ? localized($r('app.string.edit_message_not_confirmed').id, 'Edit was not confirmed. Your text is preserved. Check the message before retrying.')
          : localized($r('app.string.edit_message_unavailable').id, 'This message cannot be edited now. Your text is preserved.');
        try { host.getChatUIContext().getPromptAction().showToast({ message: text, duration: 3000 }); }
        catch (_error) { hilog.warn(0x0021, 'ChatEditMessage', 'Edit feedback unavailable'); }
      })
      .finally(() => {
        if (generation !== this.generation) return;
        this.releaseOwner?.();
        this.releaseOwner = undefined;
      });
  }
}
