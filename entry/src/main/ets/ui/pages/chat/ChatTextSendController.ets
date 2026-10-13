// Existing composer-owned text send, acceptance cleanup and explicit unknown-result resend.
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { SendMessageParams, SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import { CustomEmojiTextEntity } from '../../../core/model/AppCommand';
import { AppError, isSilentTdlibError, isWriteOutcomeUnknown } from '../../../core/model/AppError';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { normalizeCustomEmojiEntitiesForSubstring } from '../../tg_ui/utils/TgCustomEmojiDraftPolicy';
import { ChatPhotoAlbumHost } from './ChatPhotoAlbumController';

const DOMAIN = 0x0021;
const TAG = 'ChatTextSend';
const MAX_TEXT_CONSUMPTION_MARKS = 128;

class TextConsumptionMark {
  key: string = '';
  overflow: boolean = false;
}

export interface ChatTextSendHost extends ChatPhotoAlbumHost {
  getSendUseCase(): SendMessageUseCase | undefined;
  getDraftSelectionStart(): number;
  getDraftSelectionEnd(): number;
  getCustomEmojiEntities(): CustomEmojiTextEntity[];
}

export class ChatTextSendController {
  private textConsumptionChatId: number = 0;
  private textConsumptionLifecycle: number = 0;
  private textConsumptionUseCase?: SendMessageUseCase;
  private readonly textConsumptionCounts: Map<string, number> = new Map();
  private textConsumptionOverflow: number = 0;
  handleSend(text: string, host: ChatTextSendHost): void {
    const useCase = host.getSendUseCase();
    const chatId = host.getActiveChatId();
    if (host.isSendingMessage() || chatId === 0 || !useCase || !host.canSendNewMessages('text')) {
      return;
    }

    host.setEmojiPanelVisible(false);
    host.setSendingMessage(true);
    const operation = host.getSendOperationToken();

    const params = new SendMessageParams();
    params.chatId = chatId;
    params.text = text;
    const originalDraft = host.getDraftText();
    const originalEntities = host.getCustomEmojiEntities().map((entity: CustomEmojiTextEntity): CustomEmojiTextEntity =>
      new CustomEmojiTextEntity(entity.offset, entity.length, entity.customEmojiId));
    const originalSelectionStart = host.getDraftSelectionStart();
    const originalSelectionEnd = host.getDraftSelectionEnd();
    const sentEntities = normalizeCustomEmojiEntitiesForSubstring(
      originalDraft, text, originalEntities);
    params.customEmojiEntities = sentEntities;
    const replyToMessageId = host.getReplyToMessageId();
    if (replyToMessageId !== '0') {
      params.replyToMessageId = replyToMessageId;
    }

    const sentText = text;
    const inputRevision = host.getComposerInputRevision();
    let clearedRevision = -1;
    let submitted = false;
    let consumption: TextConsumptionMark | undefined = undefined;
    const wasNearBottom = host.isNearBottom();
    const lifecycleToken: number = host.getLifecycleToken();
    const key = replyToMessageId + '\u0000' + sentText;
    Promise.resolve().then(async (): Promise<void> => {
      if (!this.ownsSendOperation(host, lifecycleToken, chatId, operation) ||
        !this.isSendContextActive(host, lifecycleToken, useCase, chatId) || !host.hasActiveChatState() ||
        !host.canSendNewMessages('text')) return;
      if (this.hasTextConsumption(chatId, lifecycleToken, useCase, key)) {
        const confirmed = await this.confirmTextResend(host);
        if (!confirmed) return;
      }
      if (!this.ownsSendOperation(host, lifecycleToken, chatId, operation) ||
        !this.isSendContextActive(host, lifecycleToken, useCase, chatId) ||
        !host.hasActiveChatState() || host.isEditModeActive() || host.isForwardModeActive() ||
        host.getPendingAttachmentUris().length > 0 || host.getComposerInputRevision() !== inputRevision ||
        !host.canSendNewMessages('text')) return;
      consumption = this.recordTextConsumption(chatId, lifecycleToken, useCase, key);
      submitted = true;
      host.setCustomEmojiEntities([]);
      host.setDraftText('');
      host.setDraftSelection(0, 0);
      // Retain full reply metadata until acceptance. No failed request can lose
      // it, and a new reply/input revision must not be cleared by old success.
      clearedRevision = host.getComposerInputRevision();
      await useCase.execute(params);
    })
      .then(() => {
        if (!submitted) return;
        if (consumption !== undefined) this.rollbackTextConsumption(chatId, lifecycleToken, useCase, consumption);
        if (!this.ownsSendOperation(host, lifecycleToken, chatId, operation) ||
          !this.isSendContextActive(host, lifecycleToken, useCase, chatId)) {
          return;
        }
        if (host.getComposerInputRevision() === clearedRevision &&
          host.getReplyToMessageId() === replyToMessageId) host.clearReplyMode();
        if (wasNearBottom) {
          host.scrollToBottomSoon();
        }
      })
      .catch((err: Error) => {
        const unknown = submitted && isWriteOutcomeUnknown(err);
        if (!unknown && consumption !== undefined) {
          this.rollbackTextConsumption(chatId, lifecycleToken, useCase, consumption);
        }
        if (!this.ownsSendOperation(host, lifecycleToken, chatId, operation)) {
          return;
        }
        const currentUseCase = host.getSendUseCase();
        if (submitted && host.getComposerInputRevision() === clearedRevision &&
          (currentUseCase === useCase || currentUseCase === undefined) &&
          host.hasActiveChatState() && !host.isEditModeActive() && !host.isForwardModeActive() &&
          host.getPendingAttachmentUris().length === 0 && host.getDraftText().trim().length === 0) {
          host.setCustomEmojiEntities(originalEntities);
          host.setDraftText(originalDraft);
          host.setDraftSelection(originalSelectionStart, originalSelectionEnd);
        }
        if (host.hasActiveChatState() && (currentUseCase === useCase || currentUseCase === undefined) &&
          !isSilentTdlibError(err)) {
          hilog.error(DOMAIN, TAG, 'Send failed: %{public}s', err.message);
          this.showPendingToast(host, unknown
            ? localized($r('app.string.composer_send_result_unknown').id, 'Check the chat before sending again.')
            : err instanceof AppError ? err.userMessage
            : localized($r('app.string.composer_media_send_failed').id, 'Could not send message'));
        }
      })
      .finally(() => {
        if (!this.ownsSendOperation(host, lifecycleToken, chatId, operation)) {
          return;
        }
        host.setSendingMessage(false);
      });
  }

  private matchesTextConsumptionOwner(chatId: number, lifecycle: number, useCase: SendMessageUseCase): boolean {
    return this.textConsumptionChatId === chatId && this.textConsumptionLifecycle === lifecycle &&
      this.textConsumptionUseCase === useCase;
  }

  private hasTextConsumption(chatId: number, lifecycle: number, useCase: SendMessageUseCase, key: string): boolean {
    return this.matchesTextConsumptionOwner(chatId, lifecycle, useCase) &&
      (this.textConsumptionOverflow > 0 || this.textConsumptionCounts.has(key));
  }

  private recordTextConsumption(chatId: number, lifecycle: number, useCase: SendMessageUseCase,
    key: string): TextConsumptionMark {
    if (!this.matchesTextConsumptionOwner(chatId, lifecycle, useCase)) {
      this.textConsumptionChatId = chatId;
      this.textConsumptionLifecycle = lifecycle;
      this.textConsumptionUseCase = useCase;
      this.textConsumptionCounts.clear();
      this.textConsumptionOverflow = 0;
    }
    const mark = new TextConsumptionMark();
    mark.key = key;
    const count = this.textConsumptionCounts.get(key);
    if (count !== undefined || this.textConsumptionCounts.size < MAX_TEXT_CONSUMPTION_MARKS) {
      this.textConsumptionCounts.set(key, (count ?? 0) + 1);
    } else {
      mark.overflow = true;
      this.textConsumptionOverflow++;
    }
    return mark;
  }

  private rollbackTextConsumption(chatId: number, lifecycle: number, useCase: SendMessageUseCase,
    mark: TextConsumptionMark): void {
    if (!this.matchesTextConsumptionOwner(chatId, lifecycle, useCase)) return;
    if (mark.overflow) {
      this.textConsumptionOverflow = Math.max(0, this.textConsumptionOverflow - 1);
    } else {
      const count = this.textConsumptionCounts.get(mark.key) ?? 0;
      if (count <= 1) this.textConsumptionCounts.delete(mark.key);
      else this.textConsumptionCounts.set(mark.key, count - 1);
    }
  }

  private async confirmTextResend(host: ChatTextSendHost): Promise<boolean> {
    try {
      const context = host.getChatUIContext().getHostContext();
      if (context === undefined) return false;
      const argb = context.resourceManager.getColorByNameSync(TgUiTokens.COLOR_ICON_PRIMARY_RESOURCE_NAME) >>> 0;
      const color = '#' + argb.toString(16).padStart(8, '0');
      const result = await host.getChatUIContext().getPromptAction().showDialog({
        title: localized($r('app.string.composer_send_resend_title').id, 'Send this message again?'),
        message: localized($r('app.string.composer_send_resend_message').id,
          'This message may already have been sent. Sending again can create duplicates.'),
        buttons: [
          { text: localized($r('app.string.cancel').id, 'Cancel'), color: color },
          { text: localized($r('app.string.composer_album_resend_action').id, 'Send again'), color: color }
        ]
      });
      return result.index === 1;
    } catch (_error) {
      return false;
    }
  }

  private ownsSendOperation(host: ChatTextSendHost, lifecycleToken: number,
    chatId: number, operation: number): boolean {
    return operation === host.getSendOperationToken() && lifecycleToken === host.getLifecycleToken() &&
      host.getActiveChatId() === chatId;
  }

  private isSendContextActive(
    host: ChatTextSendHost,
    lifecycleToken: number,
    useCase: SendMessageUseCase,
    chatId: number
  ): boolean {
    return lifecycleToken === host.getLifecycleToken() &&
      host.getSendUseCase() === useCase &&
      host.getActiveChatId() === chatId;
  }

  private showPendingToast(host: ChatTextSendHost, message: string): void {
    try { host.getChatUIContext().getPromptAction().showToast({ message: message, duration: 1500 }); }
    catch (_error) {}
  }
}
