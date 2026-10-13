import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { DeleteMessagesAvailability, DeleteMessagesEligibilityError, DeleteMessagesParams, DeleteMessagesUseCase } from '../../../domain/usecases/deleteMessages';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';

export interface ChatDeleteMessageHost {
  getActiveChatId(): number;
  getLifecycleToken(): number;
  hasActiveChatState(): boolean;
  getDeleteUseCase(): DeleteMessagesUseCase | undefined;
  getChatUIContext(): UIContext;
}

export interface DeleteMessageConfirmation {
  confirm(availability: DeleteMessagesAvailability, host: ChatDeleteMessageHost,
    isCurrent: () => boolean): Promise<boolean | undefined>;
}

// Native confirmation is deliberately separate from the source action popup.
// The semantic mode map is captured before await; a missing/cancelled/invalid
// response never becomes permission to delete, and index 1 is not always self.
export class NativeDeleteMessageConfirmation implements DeleteMessageConfirmation {
  async confirm(availability: DeleteMessagesAvailability, host: ChatDeleteMessageHost,
    isCurrent: () => boolean): Promise<boolean | undefined> {
    if (!isCurrent() || (!availability.forSelf && !availability.forEveryone)) return undefined;
    const buttons: promptAction.Button[] = [{
      text: localized($r('app.string.cancel').id, 'Cancel'), color: TgUiTokens.COLOR_TEXT_TITLE
    }];
    const modes: (boolean | undefined)[] = [undefined];
    if (availability.forSelf) {
      buttons.push({ text: localized($r('app.string.delete_message_for_me').id, 'Delete for me'),
        color: TgUiTokens.COLOR_TEXT_ERROR });
      modes.push(false);
    }
    if (availability.forEveryone) {
      buttons.push({ text: localized($r('app.string.delete_message_for_everyone').id, 'Delete for everyone'),
        color: TgUiTokens.COLOR_TEXT_ERROR });
      modes.push(true);
    }
    try {
      const result = await host.getChatUIContext().getPromptAction().showDialog({
        title: localized($r('app.string.delete_message_title').id, 'Delete message?'),
        message: localized($r('app.string.delete_message_warning').id, 'This action cannot be undone.'),
        buttons: buttons
      });
      if (!isCurrent()) return undefined;
      const index = result?.index;
      if (typeof index !== 'number' || !Number.isInteger(index) || index < 0 || index >= modes.length) return undefined;
      return modes[index];
    } catch (_error) {
      // Cancel/back/dismiss or unavailable UI: no destructive fallback.
      return undefined;
    }
  }
}

// One local confirmation flow; account/lifecycle/use-case identity fences every
// async boundary. No optimistic store deletion and no automatic mode fallback.
export class ChatDeleteMessageController {
  private confirmation: DeleteMessageConfirmation;
  private generation: number = 0;
  private phase: string = 'idle';
  private chatId: number = 0;
  private lifecycle: number = 0;
  private messageId: string = '';
  private useCase?: DeleteMessagesUseCase;

  constructor(confirmation: DeleteMessageConfirmation = new NativeDeleteMessageConfirmation()) {
    this.confirmation = confirmation;
  }

  cancel(): void {
    this.generation++;
    this.phase = 'idle';
    this.useCase = undefined;
  }

  request(messageId: string, host: ChatDeleteMessageHost): void {
    const useCase = host.getDeleteUseCase();
    const chatId = host.getActiveChatId();
    const lifecycle = host.getLifecycleToken();
    if (!useCase || !host.hasActiveChatState() || chatId === 0) return;
    const sameContext = this.useCase === useCase && this.chatId === chatId && this.lifecycle === lifecycle;
    if (sameContext && this.phase !== 'idle' && (this.phase !== 'loading' || this.messageId === messageId)) return;
    const generation = ++this.generation;
    this.useCase = useCase;
    this.chatId = chatId;
    this.lifecycle = lifecycle;
    this.messageId = messageId;
    this.phase = 'loading';
    const current = (): boolean => generation === this.generation && host.hasActiveChatState() &&
      host.getActiveChatId() === chatId && host.getLifecycleToken() === lifecycle && host.getDeleteUseCase() === useCase;
    useCase.getAvailability(chatId, [messageId], current)
      .then(async (availability: DeleteMessagesAvailability) => {
        if (!current()) return;
        if (!availability.forSelf && !availability.forEveryone) throw new DeleteMessagesEligibilityError();
        this.phase = 'confirming';
        const revoke = await this.confirmation.confirm(availability, host, current);
        if (!current() || revoke === undefined) return;
        this.phase = 'deleting';
        const params = new DeleteMessagesParams();
        params.chatId = chatId;
        params.messageIds = [messageId];
        params.revoke = revoke;
        // Permissions can expire/change while the native dialog is visible.
        await useCase.execute(params, current);
      })
      .catch((error: Object) => {
        if (!current()) return;
        const text = error instanceof DeleteMessagesEligibilityError || this.phase !== 'deleting'
          ? localized($r('app.string.delete_message_unavailable').id, 'This message cannot be deleted now.')
          : localized($r('app.string.delete_message_not_confirmed').id, 'Deletion was not confirmed. Check the chat before retrying.');
        try {
          host.getChatUIContext().getPromptAction().showToast({ message: text, duration: 2500 });
        } catch (_error) {
          hilog.warn(0x0021, 'ChatDeleteMessage', 'Delete feedback unavailable');
        }
      })
      .finally(() => {
        if (generation !== this.generation) return;
        this.phase = 'idle';
        this.useCase = undefined;
      });
  }
}
