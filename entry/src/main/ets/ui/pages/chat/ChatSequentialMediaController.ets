// Existing composer-owned document/video sequence. Each accepted item retires
// only its current selection slot; an uncertain item requires explicit resend.
import { AppError, isSilentTdlibError } from '../../../core/model/AppError';
import { localized } from '../../../core/utils/AppResource';
import { SendMediaMessageParams, SendMediaMessageUseCase } from '../../../domain/usecases/sendMediaMessage';
import { ChatPhotoAlbumHost } from './ChatPhotoAlbumController';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';

const MAX_CONSUMED_MEDIA_URIS = 128;

export interface ChatSequentialMediaHost extends ChatPhotoAlbumHost {
  getDraftSelectionStart(): number;
  getDraftSelectionEnd(): number;
}

class SequentialMediaAttempt {
  chatId: number = 0;
  lifecycle: number = 0;
  operation: number = 0;
  inputRevision: number = 0;
  kind: string = '';
  uris: string[] = [];
  draftText: string = '';
  caption: string = '';
  replyToMessageId: string = '0';
  selectionStart: number = 0;
  selectionEnd: number = 0;
  useCase?: SendMediaMessageUseCase;
  wasNearBottom: boolean = false;
}

class MediaConsumptionMark {
  uri: string = '';
  overflow: boolean = false;
}

export class ChatSequentialMediaController {
  private consumedChatId: number = 0;
  private consumedLifecycle: number = 0;
  private consumedUseCase?: SendMediaMessageUseCase;
  private readonly consumedUriCounts: Map<string, number> = new Map();
  private consumedOverflow: number = 0;

  handleSend(caption: string, host: ChatSequentialMediaHost,
    prepareLocalPath: (kind: string, uri: string) => Promise<string>,
    discardPreparedPath: (path: string) => void, replacePendingSelection: (uris: string[]) => void): void {
    const kind = host.getPendingAttachmentKind();
    const useCase = host.getSendMediaUseCase(kind);
    if ((kind !== 'document' && kind !== 'video') || useCase === undefined || host.isSendingMessage() ||
      !host.hasActiveChatState() || host.isEditModeActive() || host.isForwardModeActive() ||
      !host.canSendNewMessages(kind)) return;
    const attempt = new SequentialMediaAttempt();
    attempt.chatId = host.getActiveChatId();
    attempt.lifecycle = host.getLifecycleToken();
    attempt.inputRevision = host.getComposerInputRevision();
    attempt.kind = kind;
    attempt.uris = host.getPendingAttachmentUris().slice();
    attempt.draftText = host.getDraftText();
    attempt.caption = caption;
    attempt.replyToMessageId = host.getReplyToMessageId();
    attempt.selectionStart = host.getDraftSelectionStart();
    attempt.selectionEnd = host.getDraftSelectionEnd();
    attempt.useCase = useCase;
    attempt.wasNearBottom = host.isNearBottom();
    if (!this.isValidInput(attempt)) {
      this.showFeedback(host, localized($r('app.string.composer_media_send_failed').id, 'Could not send media'));
      return;
    }
    host.setEmojiPanelVisible(false);
    host.setSendingMessage(true);
    attempt.operation = host.getSendOperationToken();
    this.runSend(attempt, host, prepareLocalPath, discardPreparedPath, replacePendingSelection);
  }

  private async runSend(attempt: SequentialMediaAttempt, host: ChatSequentialMediaHost,
    prepareLocalPath: (kind: string, uri: string) => Promise<string>,
    discardPreparedPath: (path: string) => void, replacePendingSelection: (uris: string[]) => void): Promise<void> {
    let outcomeUnknown = false;
    const originalUris = attempt.uris.slice();
    try {
      if (!this.canSubmit(host, attempt) || !host.canSendNewMessages(attempt.kind)) return;
      if (this.hasConsumedSelection(attempt)) {
        if (!await this.confirmResend(host) || !this.canSubmit(host, attempt) ||
          !host.canSendNewMessages(attempt.kind)) return;
      }
      for (let index = 0; index < originalUris.length; index++) {
        if (!this.canSubmit(host, attempt) || attempt.useCase === undefined ||
          !host.canSendNewMessages(attempt.kind)) return;
        let path = '';
        let submitted = false;
        let mark: MediaConsumptionMark | undefined = undefined;
        try {
          path = await prepareLocalPath(attempt.kind, originalUris[index]);
          if (!this.canSubmit(host, attempt) || !host.canSendNewMessages(attempt.kind)) return;
          if (typeof path !== 'string' || path.trim().length === 0) throw new Error('Prepared media path is empty');
          const params = new SendMediaMessageParams();
          params.chatId = attempt.chatId;
          params.mediaKind = attempt.kind;
          params.localPath = path;
          params.caption = index === 0 ? attempt.caption : '';
          params.replyToMessageId = index === 0 ? attempt.replyToMessageId : '0';
          // Record before invoking the mutation. A busy reset or input edit
          // cannot make this submitted URI safe to repeat while still pending.
          mark = this.recordConsumption(attempt, originalUris[index]);
          submitted = true;
          await attempt.useCase.execute(params);
        } catch (error) {
          const rejected = error instanceof AppError && error.requestRejected;
          outcomeUnknown = submitted && !rejected;
          if (rejected) {
            submitted = false;
            if (mark !== undefined) this.rollbackConsumption(attempt, mark);
          }
          throw error as Error;
        } finally {
          // Acceptance/uncertainty can leave TDLib uploading from this path.
          // Only an unsubmitted or explicitly rejected file is ours to delete.
          if (!submitted && typeof path === 'string' && path.length > 0) {
            try { discardPreparedPath(path); } catch (_error) {}
          }
        }
        if (!this.canSubmit(host, attempt)) return;
        const remaining = attempt.uris.slice(1);
        if (index === 0) {
          host.setCustomEmojiEntities([]);
          host.setDraftText('');
          host.setDraftSelection(0, 0);
          host.clearReplyMode();
          attempt.draftText = '';
          attempt.replyToMessageId = '0';
          attempt.selectionStart = 0;
          attempt.selectionEnd = 0;
        }
        replacePendingSelection(remaining);
        attempt.uris = remaining;
        // These synchronous owned mutations establish the next expected input,
        // while the single busy owner spans the entire sequence.
        attempt.inputRevision = host.getComposerInputRevision();
        if (!this.canSubmit(host, attempt)) return;
      }
      if (attempt.wasNearBottom && this.canSubmit(host, attempt)) host.scrollToBottomSoon();
    } catch (error) {
      if (!this.isCurrentOwner(host, attempt) || isSilentTdlibError(error)) return;
      this.showFeedback(host, outcomeUnknown
        ? localized($r('app.string.composer_media_result_unknown').id,
          'Check the chat before sending these files again. They may already have been sent.')
        : error instanceof AppError ? error.userMessage
        : localized($r('app.string.composer_media_send_failed').id, 'Could not send media'));
    } finally {
      if (this.ownsOperation(host, attempt)) host.setSendingMessage(false);
    }
  }

  private isValidInput(attempt: SequentialMediaAttempt): boolean {
    return Number.isSafeInteger(attempt.chatId) && attempt.chatId !== 0 &&
      typeof attempt.caption === 'string' && attempt.caption.length <= 4096 &&
      attempt.uris.length >= 1 && attempt.uris.length <= 10 &&
      attempt.uris.every((uri: string, index: number) => typeof uri === 'string' && uri.trim().length > 0 &&
        attempt.uris.indexOf(uri) === index) && typeof attempt.replyToMessageId === 'string' &&
      (attempt.replyToMessageId === '0' || (/^[1-9][0-9]*$/.test(attempt.replyToMessageId) &&
        Number.isSafeInteger(Number(attempt.replyToMessageId))));
  }

  private ownsOperation(host: ChatSequentialMediaHost, attempt: SequentialMediaAttempt): boolean {
    return host.getSendOperationToken() === attempt.operation && host.getLifecycleToken() === attempt.lifecycle &&
      host.getActiveChatId() === attempt.chatId;
  }

  private isCurrentOwner(host: ChatSequentialMediaHost, attempt: SequentialMediaAttempt): boolean {
    return this.ownsOperation(host, attempt) && host.hasActiveChatState() &&
      host.getSendMediaUseCase(attempt.kind) === attempt.useCase;
  }

  private canSubmit(host: ChatSequentialMediaHost, attempt: SequentialMediaAttempt): boolean {
    const uris = host.getPendingAttachmentUris();
    return this.isCurrentOwner(host, attempt) && !host.isEditModeActive() && !host.isForwardModeActive() &&
      host.getComposerInputRevision() === attempt.inputRevision && host.getDraftText() === attempt.draftText &&
      host.getReplyToMessageId() === attempt.replyToMessageId &&
      host.getDraftSelectionStart() === attempt.selectionStart && host.getDraftSelectionEnd() === attempt.selectionEnd &&
      host.getPendingAttachmentKind() === (attempt.uris.length > 0 ? attempt.kind : '') &&
      uris.length === attempt.uris.length && uris.every((uri: string, index: number) => uri === attempt.uris[index]);
  }

  private matchesConsumedOwner(attempt: SequentialMediaAttempt): boolean {
    return this.consumedChatId === attempt.chatId && this.consumedLifecycle === attempt.lifecycle &&
      this.consumedUseCase === attempt.useCase;
  }

  private hasConsumedSelection(attempt: SequentialMediaAttempt): boolean {
    return this.matchesConsumedOwner(attempt) && (this.consumedOverflow > 0 ||
      attempt.uris.some((uri: string) => this.consumedUriCounts.has(uri)));
  }

  private recordConsumption(attempt: SequentialMediaAttempt, uri: string): MediaConsumptionMark {
    if (!this.matchesConsumedOwner(attempt)) {
      this.consumedChatId = attempt.chatId;
      this.consumedLifecycle = attempt.lifecycle;
      this.consumedUseCase = attempt.useCase;
      this.consumedUriCounts.clear();
      this.consumedOverflow = 0;
    }
    const mark = new MediaConsumptionMark();
    mark.uri = uri;
    const count = this.consumedUriCounts.get(uri);
    if (count !== undefined || this.consumedUriCounts.size < MAX_CONSUMED_MEDIA_URIS) {
      this.consumedUriCounts.set(uri, (count ?? 0) + 1);
    } else {
      mark.overflow = true;
      this.consumedOverflow++;
    }
    return mark;
  }

  private rollbackConsumption(attempt: SequentialMediaAttempt, mark: MediaConsumptionMark): void {
    if (!this.matchesConsumedOwner(attempt)) return;
    if (mark.overflow) {
      this.consumedOverflow = Math.max(0, this.consumedOverflow - 1);
    } else {
      const count = this.consumedUriCounts.get(mark.uri) ?? 0;
      if (count <= 1) this.consumedUriCounts.delete(mark.uri);
      else this.consumedUriCounts.set(mark.uri, count - 1);
    }
  }

  private async confirmResend(host: ChatSequentialMediaHost): Promise<boolean> {
    try {
      const result = await host.getChatUIContext().getPromptAction().showDialog({
        title: localized($r('app.string.composer_media_resend_title').id, 'Send these files again?'),
        message: localized($r('app.string.composer_media_resend_message').id,
          'Some of these files may already have been sent. Sending again can create duplicates.'),
        buttons: [
          { text: localized($r('app.string.cancel').id, 'Cancel'),
            color: this.dialogButtonColor(host, TgUiTokens.COLOR_TEXT_TITLE_RESOURCE_NAME) },
          { text: localized($r('app.string.composer_album_resend_action').id, 'Send again'),
            color: this.dialogButtonColor(host, TgUiTokens.COLOR_ICON_PRIMARY_RESOURCE_NAME) }
        ]
      });
      return result.index === 1;
    } catch (_error) {
      return false;
    }
  }

  private dialogButtonColor(host: ChatSequentialMediaHost, resourceName: string): string {
    const context = host.getChatUIContext().getHostContext();
    if (context === undefined) throw new Error('Native dialog context is unavailable');
    const argb = context.resourceManager.getColorByNameSync(resourceName) >>> 0;
    return '#' + argb.toString(16).padStart(8, '0');
  }

  private showFeedback(host: ChatSequentialMediaHost, message: string): void {
    try { host.getChatUIContext().getPromptAction().showToast({ message: message, duration: 1500 }); }
    catch (_error) {}
  }
}
