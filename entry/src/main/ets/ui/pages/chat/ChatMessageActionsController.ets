// ChatMessageActionsController — message action model and action-mode orchestration.
// The page owns the glass popup presentation; this controller owns available actions and behavior.

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { navigationUIState } from '../../../core/model/UIStateModels';
import { localized } from '../../../core/utils/AppResource';
import { DeleteMessagesUseCase } from '../../../domain/usecases/deleteMessages';
import { ChatDeleteMessageController, ChatDeleteMessageHost } from './ChatDeleteMessageController';
import { EditMessageUseCase } from '../../../domain/usecases/editMessage';
import { ChatEditMessageController, ChatEditMessageHost } from './ChatEditMessageController';
import { ForwardMessagesParams, ForwardMessagesUseCase, ForwardMessagesResultError, ForwardSourceAvailability } from '../../../domain/usecases/forwardMessages';
import { PinChatMessageUseCase } from '../../../domain/usecases/pinChatMessage';
import { SendMessageParams, SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import { AppError, isSilentTdlibError, isWriteOutcomeUnknown } from '../../../core/model/AppError';
import { ForwardTargetPickerResult, ForwardTargetPickerRouteParams } from '../forward/TgForwardTargetPickerPage';
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { pendingForwardTransfer } from './PendingForwardTransfer';
import { pasteboard } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'ChatMessageActions';

export class ChatForwardModeState {
  isForwardingMessages: boolean = false;
  messageIds: string[] = [];
  sourceChatId: number = 0;
  title: string = '';
  preview: string = '';
}

export class ChatMessageActionItem {
  id: string;
  title: string;
  destructive: boolean;
  enabled: boolean;
  sourceMessageId: string = '';
  contextToken: number = 0;

  constructor(id: string, title: string, destructive: boolean = false, enabled: boolean = true) {
    this.id = id;
    this.title = title;
    this.destructive = destructive;
    this.enabled = enabled;
  }
}

export interface ChatMessageActionsHost extends ChatDeleteMessageHost, ChatEditMessageHost {
  canSendNewMessages(sendKind?: string): boolean;
  getActiveChatId(): number;
  getChatRouteToken(): number;
  getLifecycleToken(): number;
  getChatUIContext(): UIContext;
  bindNavigationStack(): NavPathStack | undefined;
  createChatRouteParams(chatId: number, title: string): ChatScreenRouteParams | undefined;
  getSendUseCase(): SendMessageUseCase | undefined;
  getEditUseCase(): EditMessageUseCase | undefined;
  getDeleteUseCase(): DeleteMessagesUseCase | undefined;
  getForwardUseCase(sourceChatId?: number, messageIds?: string[]): ForwardMessagesUseCase | undefined;
  getSourceForwardUseCase(): ForwardMessagesUseCase | undefined;
  getPinUseCase(): PinChatMessageUseCase | undefined;
  onPinnedMessageChanged(): void;
  isSendingMessage(): boolean;
  setSendingMessage(value: boolean): void;
  getSendOperationToken(): number;
  hasActiveChatState(): boolean;
  getPendingAttachmentUris(): string[];
  getDraftText(): string;
  getComposerInputRevision(): number;
  setDraftText(value: string): void;
  isNearBottom(): boolean;
  scrollToBottomSoon(): void;
  setReplyMode(messageId: string, author: string, preview: string, isQuote: boolean): void;
  clearReplyMode(): void;
  setEditMode(messageId: string, originalText: string, allowEmptyEdit?: boolean): void;
  getEditingMessageId(): string;
  getEditingOriginalText(): string;
  clearEditMode(clearDraft: boolean): void;
  setForwardMode(messageIds: string[], sourceChatId: number, title: string, preview: string): void;
  getForwardModeState(): ChatForwardModeState;
  clearForwardMode(): void;
}

export class ChatMessageActionsController {
  private editController?: ChatEditMessageController;
  private forwardPickerGeneration: number = 0;
  private forwardPickerOpen: boolean = false;
  private forwardPickerSourceChatId: number = 0;
  private forwardPickerLifecycle: number = 0;
  private forwardPickerUseCase?: ForwardMessagesUseCase;
  private deleteController?: ChatDeleteMessageController;

  cancelPendingMessageActions(): void {
    this.cancelPendingForwardPicker();
    this.deleteController?.cancel();
    this.editController?.cancel();
  }

  cancelPendingForwardPicker(): void {
    this.forwardPickerGeneration++;
    this.forwardPickerOpen = false;
  }
  startReply(
    messageId: string,
    author: string,
    preview: string,
    isQuote: boolean,
    host: ChatMessageActionsHost
  ): void {
    this.cancelPendingMessageActions();
    host.clearEditMode(false);
    host.clearForwardMode();
    const generic = localized($r('app.string.message_action').id, 'Message');
    const safeAuthor = author.length > 0 ? author : generic;
    const trimmed = preview.trim();
    host.setReplyMode(messageId, safeAuthor, trimmed.length > 0 ? trimmed : generic, isQuote);
  }

  clearReplyMode(host: ChatMessageActionsHost): void {
    host.clearReplyMode();
  }

  cancelReply(host: ChatMessageActionsHost): void {
    host.clearReplyMode();
  }

  clearEditMode(clearDraft: boolean, host: ChatMessageActionsHost): void {
    this.editController?.cancel();
    host.clearEditMode(clearDraft);
  }

  clearForwardMode(host: ChatMessageActionsHost): void {
    host.clearForwardMode();
  }

  startForwardMessages(
    messageIds: string[],
    author: string,
    preview: string,
    fromChatId: number,
    host: ChatMessageActionsHost
  ): void {
    this.cancelPendingMessageActions();
    if (messageIds.length === 0 || fromChatId === 0) {
      return;
    }
    host.clearReplyMode();
    host.clearEditMode(false);
    host.setForwardMode(messageIds, fromChatId, this.buildForwardTitle(messageIds.length),
      this.buildForwardPreview(author, preview));
  }

  cancelForwardMessages(host: ChatMessageActionsHost): void {
    this.cancelPendingMessageActions();
    host.clearForwardMode();
  }

  applyPendingForwardTransferIfNeeded(host: ChatMessageActionsHost): void {
    const payload = pendingForwardTransfer.consumeFor(host.getActiveChatId(), host.getChatRouteToken());
    if (payload === undefined) {
      return;
    }
    this.startForwardMessages(payload.messageIds, payload.author, payload.preview, payload.sourceChatId, host);
  }

  openForwardTargetPicker(
    messageIds: string[],
    author: string,
    preview: string,
    host: ChatMessageActionsHost
  ): void {
    // Channel-share reaches this entry without opening the source popup. Its
    // new intent must invalidate an older delete before any async lookup.
    this.deleteController?.cancel();
    this.editController?.cancel();
    if (this.forwardPickerOpen && this.forwardPickerSourceChatId === host.getActiveChatId() &&
      this.forwardPickerLifecycle === host.getLifecycleToken() &&
      this.forwardPickerUseCase === host.getSourceForwardUseCase()) return;
    this.forwardPickerOpen = false;
    const generation = ++this.forwardPickerGeneration;
    const useCase = host.getSourceForwardUseCase();
    const sourceChatId = host.getActiveChatId();
    const lifecycleToken = host.getLifecycleToken();
    if (!useCase || !host.hasActiveChatState()) return;
    let ids: string[];
    try {
      const input = new ForwardMessagesParams();
      input.chatId = sourceChatId;
      input.fromChatId = sourceChatId;
      input.messageIds = messageIds;
      ids = useCase.prepare(input).messageIds;
    } catch (_error) {
      this.showForwardFeedback(host, localized($r('app.string.forward_invalid_selection').id,
        'Select up to 100 valid messages to forward.'));
      return;
    }
    const current = (): boolean => generation === this.forwardPickerGeneration &&
      lifecycleToken === host.getLifecycleToken() && sourceChatId === host.getActiveChatId() &&
      host.hasActiveChatState() && host.getSourceForwardUseCase() === useCase;
    useCase.getSourceAvailability(sourceChatId, ids, current)
      .then((availability: ForwardSourceAvailability) => {
        if (!current()) return;
        if (!availability.ordinaryTargets && !availability.secretTargets) {
          this.showForwardFeedback(host, localized($r('app.string.forward_unavailable').id, 'Unable to forward this message'));
          return;
        }
        this.pushForwardTargetPicker(ids, author, preview, availability, current, host);
      })
      .catch((_error: Object) => {
        if (!current()) return;
        this.showForwardFeedback(host, localized($r('app.string.forward_unavailable').id, 'Unable to forward this message'));
      });
  }

  private pushForwardTargetPicker(messageIds: string[], author: string, preview: string,
    availability: ForwardSourceAvailability, current: () => boolean, host: ChatMessageActionsHost): void {
    if (messageIds.length === 0 || host.getActiveChatId() === 0) {
      return;
    }
    const sourceOwnerToken = host.getChatRouteToken();
    if (!current() || navigationUIState.activeChatOwnerToken !== sourceOwnerToken) return;
    const navStack: NavPathStack | undefined = host.bindNavigationStack();
    if (navStack === undefined) {
      hilog.error(DOMAIN, TAG, 'Navigation stack unavailable for forward picker');
      return;
    }

    const sourceChatId = host.getActiveChatId();
    const lifecycleToken: number = host.getLifecycleToken();
    try {
      if (!current() || navigationUIState.activeChatOwnerToken !== sourceOwnerToken) return;
      this.forwardPickerOpen = true;
      this.forwardPickerSourceChatId = sourceChatId;
      this.forwardPickerLifecycle = lifecycleToken;
      this.forwardPickerUseCase = host.getSourceForwardUseCase();
      navStack.pushPathByName(
        'TgForwardTargetPickerPage',
        this.forwardPickerParams(sourceChatId, availability),
        (popInfo) => {
          if (!this.forwardPickerOpen || !current() || navigationUIState.activeChatOwnerToken !== sourceOwnerToken ||
            lifecycleToken !== host.getLifecycleToken() || host.getActiveChatId() !== sourceChatId) {
            return;
          }
          this.forwardPickerOpen = false;
          const result = popInfo.result as ForwardTargetPickerResult | undefined;
          if (!result || result.chatId === 0) {
            return;
          }
          if (result.chatId === sourceChatId) {
            this.startForwardMessages(messageIds, author, preview, sourceChatId, host);
            return;
          }

          const params = host.createChatRouteParams(result.chatId, result.chatTitle);
          if (params === undefined || !current() || navigationUIState.activeChatOwnerToken !== sourceOwnerToken ||
            !params.isCurrentAccount(params.accountStore)) return;
          const prevOwnerToken = navigationUIState.activeChatOwnerToken;
          const prevChatId: number = navigationUIState.activeChatId;
          const prevTitle: string = navigationUIState.activeChatTitle;
          const prevChatScreenVisible: boolean = navigationUIState.chatScreenVisible;
          pendingForwardTransfer.arm(result.chatId, sourceChatId, messageIds, author, preview, params.navigationToken);
          navigationUIState.activeChatOwnerToken = params.navigationToken;
          navigationUIState.activeChatId = result.chatId;
          navigationUIState.activeChatTitle = result.chatTitle;
          navigationUIState.chatScreenVisible = true;
          AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, true);

          try {
            navStack.pushPathByName('TgChatScreenPage', params);
          } catch (error) {
            pendingForwardTransfer.clear(params.navigationToken);
            if (navigationUIState.activeChatOwnerToken === params.navigationToken &&
              current() && params.isCurrentAccount(params.accountStore)) {
              navigationUIState.activeChatOwnerToken = prevOwnerToken;
              navigationUIState.activeChatId = prevChatId;
              navigationUIState.activeChatTitle = prevTitle;
              navigationUIState.chatScreenVisible = prevChatScreenVisible;
              AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, prevChatScreenVisible);
            }
            hilog.error(DOMAIN, TAG, 'Failed to push forwarded target chat: %{public}s', String(error));
          }
        }
      );
    } catch (error) {
      this.forwardPickerOpen = false;
      hilog.error(DOMAIN, TAG, 'Failed to push forward target picker: %{public}s', String(error));
    }
  }

  private forwardPickerParams(sourceChatId: number, availability: ForwardSourceAvailability): ForwardTargetPickerRouteParams {
    const params = new ForwardTargetPickerRouteParams(sourceChatId);
    params.allowOrdinaryTargets = availability.ordinaryTargets;
    params.allowSecretTargets = availability.secretTargets;
    return params;
  }

  openForwardTargetPickerForEntry(entry: ChatTimelineEntryVO, host: ChatMessageActionsHost): void {
    const author = entry.message.isOutgoing ? localized($r('app.string.chat_you_prefix').id, 'You') :
      (entry.message.senderName.length > 0 ? entry.message.senderName
        : localized($r('app.string.message_action').id, 'Message'));
    const preview = this.resolveReplyPreviewForEntry(entry);
    this.openForwardTargetPicker([entry.message.messageId], author, preview, host);
  }

  copyMessageText(text: string, host: ChatMessageActionsHost): void {
    if (text.trim().length === 0) {
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setDataSync(data);
      host.getChatUIContext().getPromptAction().showToast({
        message: localized($r('app.string.copied').id, 'Copied'),
        duration: 1500
      });
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Copy failed: %{public}s', String(e));
    }
  }

  buildMessageActionItems(entry: ChatTimelineEntryVO, forwardState: string = 'loading'): ChatMessageActionItem[] {
    const messageText = entry.message.text.length > 0 ? entry.message.text :
      (entry.message.caption.length > 0 ? entry.message.caption : '');
    const hasText = messageText.trim().length > 0;
    const nonEditableTypes: string[] = ['sticker', 'videoNote', 'contact', 'poll', 'location', 'game'];
    const canEdit = entry.message.isOutgoing && hasText &&
      !nonEditableTypes.includes(entry.message.contentType);

    const items: ChatMessageActionItem[] = [
      new ChatMessageActionItem('reply', localized($r('app.string.action_reply').id, 'Reply'))
    ];

    if (canEdit) {
      items.push(new ChatMessageActionItem('edit', localized($r('app.string.action_edit').id, 'Edit')));
    }

    if (hasText) {
      items.push(new ChatMessageActionItem('copy', localized($r('app.string.action_copy').id, 'Copy')));
    }

    const forwardTitle = forwardState === 'allowed' ? localized($r('app.string.action_forward').id, 'Forward')
      : forwardState === 'unavailable' ? localized($r('app.string.forward_source_retry').id, 'Retry forwarding check')
      : forwardState === 'denied' ? localized($r('app.string.forward_source_denied').id, 'Forwarding unavailable')
      : localized($r('app.string.forward_source_checking').id, 'Checking forwarding…');
    items.push(new ChatMessageActionItem(forwardState === 'unavailable' ? 'forwardRetry' : 'forward', forwardTitle,
      false, forwardState === 'allowed' || forwardState === 'unavailable'));
    items.push(new ChatMessageActionItem('pin', localized($r('app.string.action_pin').id, 'Pin')));
    items.push(new ChatMessageActionItem('delete', localized($r('app.string.action_delete').id, 'Delete'), true));
    for (const item of items) item.sourceMessageId = entry.message.messageId;
    return items;
  }

  handleMessageActionPress(actionId: string, entry: ChatTimelineEntryVO, host: ChatMessageActionsHost): void {
    const items = this.buildMessageActionItems(entry, 'allowed');
    if (!items.some((item: ChatMessageActionItem): boolean => item.id === actionId)) {
      return;
    }

    const messageText = entry.message.text.length > 0 ? entry.message.text :
      (entry.message.caption.length > 0 ? entry.message.caption : '');
    const author = entry.message.isOutgoing ? localized($r('app.string.chat_you_prefix').id, 'You') :
      (entry.message.senderName.length > 0 ? entry.message.senderName
        : localized($r('app.string.message_action').id, 'Message'));
    const preview = this.resolveReplyPreviewForEntry(entry);
    const messageId = entry.message.messageId;

    switch (actionId) {
      case 'reply':
        // A plain reply is never a quote — the target's own quote-reply state
        // must not leak into the new draft banner (quote selection UI is a
        // separate future slice).
        this.startReply(messageId, author, preview, false, host);
        break;
      case 'edit':
        this.startEditMessage(messageId, messageText, host,
          ['photo', 'video', 'animation', 'audio', 'document', 'voice', 'paidMedia'].includes(entry.message.contentType));
        break;
      case 'copy':
        this.copyMessageText(messageText, host);
        break;
      case 'forward':
        this.openForwardTargetPicker([messageId], author, preview, host);
        break;
      case 'pin':
        this.handlePinMessage(messageId, host);
        break;
      case 'delete':
        this.handleDeleteMessage(messageId, host);
        break;
      default:
        break;
    }
  }

  startEditMessage(messageId: string, originalText: string, host: ChatMessageActionsHost, allowEmptyEdit: boolean = false): void {
    this.cancelPendingMessageActions();
    host.clearReplyMode();
    host.clearForwardMode();
    host.setEditMode(messageId, originalText, allowEmptyEdit);
    host.setDraftText(originalText);
    hilog.info(DOMAIN, TAG, 'Edit mode started for message %{public}s', messageId);
  }

  cancelEditMessage(host: ChatMessageActionsHost): void {
    this.editController?.cancel();
    host.clearEditMode(true);
  }

  handleEditMessage(newText: string, host: ChatMessageActionsHost): void {
    if (this.editController === undefined) this.editController = new ChatEditMessageController();
    this.editController.submit(newText, host);
  }

  handleForwardMessages(commentText: string, host: ChatMessageActionsHost): void {
    const forwardState = host.getForwardModeState();
    const forwardUseCase = host.getForwardUseCase(forwardState.sourceChatId, forwardState.messageIds);
    const sendUseCase = host.getSendUseCase();
    if (host.isSendingMessage() || host.getActiveChatId() === 0 || !forwardUseCase || !host.canSendNewMessages()) {
      return;
    }
    if (forwardState.sourceChatId === 0 || forwardState.messageIds.length === 0) {
      return;
    }

    const targetChatId = host.getActiveChatId();
    const sourceChatId = forwardState.sourceChatId;
    let prepared: ForwardMessagesParams;
    try {
      const input = new ForwardMessagesParams();
      input.chatId = targetChatId;
      input.fromChatId = sourceChatId;
      input.messageIds = forwardState.messageIds;
      prepared = forwardUseCase.prepare(input);
    } catch (_error) {
      this.showForwardFeedback(host, localized($r('app.string.forward_invalid_selection').id,
        'Select up to 100 valid messages to forward.'));
      return;
    }
    const messageIds = prepared.messageIds;
    const previewTitle = forwardState.title;
    const previewText = forwardState.preview;
    const trimmedComment = commentText.trim();
    // A user-supplied comment is part of the intent, not an optional best-effort
    // side effect. Do not silently forward without it when text is unavailable.
    if (trimmedComment.length > 0 && sendUseCase === undefined) return;
    const wasNearBottom = host.isNearBottom();
    let commentSent = false;

    const lifecycleToken: number = host.getLifecycleToken();
    host.setSendingMessage(true);
    const operation = host.getSendOperationToken();
    host.setDraftText('');
    host.clearReplyMode();
    host.clearEditMode(false);
    host.clearForwardMode();

    const clearedRevision = host.getComposerInputRevision();
    Promise.resolve()
      .then(async () => {
        // Reject protected/missing/ineligible sources before the comment side effect.
        // The callback also prevents async preflight from outliving its UI/account.
        await forwardUseCase.validateEligibility(prepared, (): boolean =>
          host.canSendNewMessages() &&
          this.ownsForwardOperation(host, lifecycleToken, targetChatId, operation) &&
          this.isForwardContextActive(host, lifecycleToken, forwardUseCase,
            trimmedComment.length > 0 ? sendUseCase : undefined, targetChatId, sourceChatId, messageIds));
        if (!host.canSendNewMessages() || !this.ownsForwardOperation(host, lifecycleToken, targetChatId, operation) ||
          !this.isForwardContextActive(host, lifecycleToken, forwardUseCase,
            trimmedComment.length > 0 ? sendUseCase : undefined, targetChatId, sourceChatId, messageIds)) {
          throw new Error('Forward context changed before dispatch');
        }
        if (trimmedComment.length > 0 && sendUseCase) {
          const sendParams = new SendMessageParams();
          sendParams.chatId = targetChatId;
          sendParams.text = trimmedComment;
          await sendUseCase.execute(sendParams);
          commentSent = true;
        }

        // Comment and forwarding are two requests. Revalidate after the await;
        // capturing a use case before it does not keep the old permission alive.
        if (!host.canSendNewMessages() || !this.ownsForwardOperation(host, lifecycleToken, targetChatId, operation) ||
          !this.isForwardContextActive(host, lifecycleToken, forwardUseCase, undefined, targetChatId, sourceChatId, messageIds)) {
          throw new Error('Forward context changed after comment');
        }
        await forwardUseCase.execute(prepared, (): boolean =>
          host.canSendNewMessages() &&
          this.ownsForwardOperation(host, lifecycleToken, targetChatId, operation) &&
          this.isForwardContextActive(host, lifecycleToken, forwardUseCase, undefined, targetChatId, sourceChatId, messageIds));

        if (!this.ownsForwardOperation(host, lifecycleToken, targetChatId, operation) ||
          !this.isForwardContextActive(host, lifecycleToken, forwardUseCase, undefined, targetChatId, sourceChatId, messageIds)) {
          return;
        }
        if (wasNearBottom) {
          host.scrollToBottomSoon();
        }
      })
      .then(() => {
        if (!this.ownsForwardOperation(host, lifecycleToken, targetChatId, operation) ||
          !this.isForwardContextActive(host, lifecycleToken, forwardUseCase, undefined, targetChatId, sourceChatId, messageIds)) {
          return;
        }
        hilog.info(DOMAIN, TAG, 'Forwarded %{public}d messages into chat %{public}d',
          messageIds.length, targetChatId);
      })
      .catch((err: Error) => {
        if (!this.ownsForwardOperation(host, lifecycleToken, targetChatId, operation)) {
          return;
        }
        // Recover only into the untouched, current account's compose buffer.
        // Never overwrite a new edit/forward/attachment/draft after failure.
        const unknown = isWriteOutcomeUnknown(err) ||
          (err instanceof ForwardMessagesResultError && !err.outcomeKnown);
        const retryIds = err instanceof ForwardMessagesResultError ? err.retryMessageIds : unknown ? [] : messageIds;
        const currentForwardUseCase = host.getForwardUseCase(sourceChatId, messageIds);
        if (retryIds.length > 0 && host.getComposerInputRevision() === clearedRevision &&
          (currentForwardUseCase === forwardUseCase || currentForwardUseCase === undefined) &&
          host.hasActiveChatState() && host.getEditingMessageId() === '0' &&
          !host.getForwardModeState().isForwardingMessages && host.getPendingAttachmentUris().length === 0 &&
          host.getDraftText().trim().length === 0) {
          host.setForwardMode(retryIds, sourceChatId, previewTitle, previewText);
          if (!commentSent && trimmedComment.length > 0) host.setDraftText(trimmedComment);
        }
        if (isSilentTdlibError(err)) return;
        if (unknown && host.hasActiveChatState()) {
          this.showForwardFeedback(host, localized($r('app.string.forward_result_unknown').id,
            'Check the destination chat before forwarding again.'));
        } else if (err instanceof ForwardMessagesResultError && host.hasActiveChatState()) {
          this.showForwardFeedback(host, err.outcomeKnown
            ? localized($r('app.string.forward_partial_failed').id, 'Some messages could not be forwarded.')
            : localized($r('app.string.forward_result_unknown').id, 'Check the destination chat before forwarding again.'));
        } else if (host.hasActiveChatState()) {
          this.showForwardFeedback(host, err instanceof AppError ? err.userMessage
            : localized($r('app.string.forward_unavailable').id, 'Unable to forward this message'));
        }
        hilog.error(DOMAIN, TAG, 'Forward failed: %{public}s', err.message);
      })
      .finally(() => {
        if (!this.ownsForwardOperation(host, lifecycleToken, targetChatId, operation)) {
          return;
        }
        host.setSendingMessage(false);
      });
  }

  private showForwardFeedback(host: ChatMessageActionsHost, message: string): void {
    try {
      host.getChatUIContext().getPromptAction().showToast({ message: message, duration: 2500 });
    } catch (_error) {
      // Presentation failure must not skip operation cleanup or reject a send.
      hilog.warn(DOMAIN, TAG, 'Forward feedback unavailable');
    }
  }

  handlePinMessage(messageId: string, host: ChatMessageActionsHost): void {
    const useCase = host.getPinUseCase();
    const chatId = host.getActiveChatId();
    if (!useCase || chatId === 0) {
      return;
    }

    const lifecycleToken: number = host.getLifecycleToken();
    useCase.pin(chatId, messageId, false, false)
      .then(() => {
        if (!this.isPinContextActive(host, lifecycleToken, useCase, chatId)) {
          return;
        }
        hilog.info(DOMAIN, TAG, 'Message %{public}s pinned', messageId);
        host.onPinnedMessageChanged();
      })
      .catch((err: Error) => {
        if (!this.isPinContextActive(host, lifecycleToken, useCase, chatId)) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Pin failed: %{public}s', err.message);
      });
  }

  handleDeleteMessage(messageId: string, host: ChatMessageActionsHost): void {
    this.editController?.cancel();
    this.cancelPendingForwardPicker();
    if (this.deleteController === undefined) this.deleteController = new ChatDeleteMessageController();
    this.deleteController.request(messageId, host);
  }

  private buildForwardTitle(messageCount: number): string {
    if (messageCount <= 1) {
      return localized($r('app.string.forwarded_message').id, 'Forwarded message');
    }
    return `${localized($r('app.string.action_forward').id, 'Forward')} ${messageCount}`;
  }

  private buildForwardPreview(author: string, preview: string): string {
    const genericLabel = localized($r('app.string.message_action').id, 'Message');
    const safeAuthor = author.trim().length > 0 ? author.trim() : genericLabel;
    const safePreview = preview.trim().length > 0 ? preview.trim() : genericLabel;
    return `${safeAuthor}: ${safePreview}`;
  }

  private resolveReplyPreviewForEntry(entry: ChatTimelineEntryVO): string {
    if (entry.message.text.length > 0) {
      return entry.message.text;
    }
    if (entry.message.caption.length > 0) {
      return entry.message.caption;
    }
    switch (entry.message.contentType) {
      case 'photo':
        return localized($r('app.string.photo').id, 'Photo');
      case 'video':
        return localized($r('app.string.video').id, 'Video');
      case 'animation':
        return localized($r('app.string.gif').id, 'GIF');
      case 'voice':
        return localized($r('app.string.voice_message').id, 'Voice message');
      case 'videoNote':
        return localized($r('app.string.video_note').id, 'Video message');
      case 'sticker':
        return localized($r('app.string.sticker').id, 'Sticker');
      case 'audio':
        return entry.message.audioTitle.length > 0 ? entry.message.audioTitle : 'Audio';
      case 'document':
        return entry.message.fileName.length > 0
          ? entry.message.fileName
          : localized($r('app.string.file_label').id, 'File');
      default:
        return localized($r('app.string.message_action').id, 'Message');
    }
  }

  private isEditContextActive(
    host: ChatMessageActionsHost,
    lifecycleToken: number,
    useCase: EditMessageUseCase,
    chatId: number
  ): boolean {
    return lifecycleToken === host.getLifecycleToken() &&
      host.getEditUseCase() === useCase &&
      host.getActiveChatId() === chatId;
  }

  private ownsForwardOperation(host: ChatMessageActionsHost, lifecycleToken: number,
    targetChatId: number, operation: number): boolean {
    return operation === host.getSendOperationToken() && lifecycleToken === host.getLifecycleToken() &&
      targetChatId === host.getActiveChatId();
  }

  private isForwardContextActive(
    host: ChatMessageActionsHost,
    lifecycleToken: number,
    forwardUseCase: ForwardMessagesUseCase,
    sendUseCase: SendMessageUseCase | undefined,
    targetChatId: number,
    sourceChatId: number,
    messageIds: string[]
  ): boolean {
    return lifecycleToken === host.getLifecycleToken() &&
      host.getForwardUseCase(sourceChatId, messageIds) === forwardUseCase &&
      host.getActiveChatId() === targetChatId &&
      (sendUseCase === undefined || host.getSendUseCase() === sendUseCase);
  }

  private isPinContextActive(
    host: ChatMessageActionsHost,
    lifecycleToken: number,
    useCase: PinChatMessageUseCase,
    chatId: number
  ): boolean {
    return lifecycleToken === host.getLifecycleToken() &&
      host.getPinUseCase() === useCase &&
      host.getActiveChatId() === chatId;
  }

  private isDeleteContextActive(
    host: ChatMessageActionsHost,
    lifecycleToken: number,
    useCase: DeleteMessagesUseCase,
    chatId: number
  ): boolean {
    return lifecycleToken === host.getLifecycleToken() &&
      host.getDeleteUseCase() === useCase &&
      host.getActiveChatId() === chatId;
  }
}
