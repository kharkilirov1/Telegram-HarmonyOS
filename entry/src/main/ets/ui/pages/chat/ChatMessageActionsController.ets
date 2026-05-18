// ChatMessageActionsController — message action sheet and action-mode orchestration.
// Keeps promptAction/pasteboard/use-case logic out of TgChatScreenPage.

import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { navigationUIState } from '../../../core/model/UIStateModels';
import { localized } from '../../../core/utils/AppResource';
import { DeleteMessagesParams, DeleteMessagesUseCase } from '../../../domain/usecases/deleteMessages';
import { EditMessageParams, EditMessageUseCase } from '../../../domain/usecases/editMessage';
import { ForwardMessagesParams, ForwardMessagesUseCase } from '../../../domain/usecases/forwardMessages';
import { PinChatMessageUseCase } from '../../../domain/usecases/pinChatMessage';
import { SendMessageParams, SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { ForwardTargetPickerResult, ForwardTargetPickerRouteParams } from '../forward/TgForwardTargetPickerPage';
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { pendingForwardTransfer } from './PendingForwardTransfer';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
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

export interface ChatMessageActionsHost {
  getActiveChatId(): number;
  getLifecycleToken(): number;
  getChatUIContext(): UIContext;
  bindNavigationStack(): NavPathStack | undefined;
  requestOpenChatData(chatId: number): void;
  getSendUseCase(): SendMessageUseCase | undefined;
  getEditUseCase(): EditMessageUseCase | undefined;
  getDeleteUseCase(): DeleteMessagesUseCase | undefined;
  getForwardUseCase(): ForwardMessagesUseCase | undefined;
  getPinUseCase(): PinChatMessageUseCase | undefined;
  isSendingMessage(): boolean;
  setSendingMessage(value: boolean): void;
  getDraftText(): string;
  setDraftText(value: string): void;
  isNearBottom(): boolean;
  scrollToBottomSoon(): void;
  setReplyMode(messageId: string, author: string, preview: string, isQuote: boolean): void;
  clearReplyMode(): void;
  setEditMode(messageId: string, originalText: string): void;
  getEditingMessageId(): string;
  getEditingOriginalText(): string;
  clearEditMode(clearDraft: boolean): void;
  setForwardMode(messageIds: string[], sourceChatId: number, title: string, preview: string): void;
  getForwardModeState(): ChatForwardModeState;
  clearForwardMode(): void;
}

export class ChatMessageActionsController {
  startReply(
    messageId: string,
    author: string,
    preview: string,
    isQuote: boolean,
    host: ChatMessageActionsHost
  ): void {
    host.clearEditMode(false);
    host.clearForwardMode();
    const safeAuthor = author.length > 0 ? author : 'Message';
    const trimmed = preview.trim();
    host.setReplyMode(messageId, safeAuthor, trimmed.length > 0 ? trimmed : 'Message', isQuote);
  }

  clearReplyMode(host: ChatMessageActionsHost): void {
    host.clearReplyMode();
  }

  cancelReply(host: ChatMessageActionsHost): void {
    host.clearReplyMode();
  }

  clearEditMode(clearDraft: boolean, host: ChatMessageActionsHost): void {
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
    if (messageIds.length === 0 || fromChatId === 0) {
      return;
    }
    host.clearReplyMode();
    host.clearEditMode(false);
    host.setForwardMode(messageIds, fromChatId, this.buildForwardTitle(messageIds.length),
      this.buildForwardPreview(author, preview));
  }

  cancelForwardMessages(host: ChatMessageActionsHost): void {
    host.clearForwardMode();
  }

  applyPendingForwardTransferIfNeeded(host: ChatMessageActionsHost): void {
    const payload = pendingForwardTransfer.consumeFor(host.getActiveChatId());
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
    if (messageIds.length === 0 || host.getActiveChatId() === 0) {
      return;
    }
    const navStack: NavPathStack | undefined = host.bindNavigationStack();
    if (navStack === undefined) {
      hilog.error(DOMAIN, TAG, 'Navigation stack unavailable for forward picker');
      return;
    }

    const sourceChatId = host.getActiveChatId();
    const lifecycleToken: number = host.getLifecycleToken();
    try {
      navStack.pushPathByName(
        'TgForwardTargetPickerPage',
        new ForwardTargetPickerRouteParams(sourceChatId),
        (popInfo) => {
          if (lifecycleToken !== host.getLifecycleToken() || host.getActiveChatId() !== sourceChatId) {
            return;
          }
          const result = popInfo.result as ForwardTargetPickerResult | undefined;
          if (!result || result.chatId === 0) {
            return;
          }
          if (result.chatId === sourceChatId) {
            this.startForwardMessages(messageIds, author, preview, sourceChatId, host);
            return;
          }

          const prevChatId: number = navigationUIState.activeChatId;
          const prevTitle: string = navigationUIState.activeChatTitle;
          const prevChatScreenVisible: boolean = navigationUIState.chatScreenVisible;
          pendingForwardTransfer.arm(result.chatId, sourceChatId, messageIds, author, preview);
          navigationUIState.activeChatId = result.chatId;
          navigationUIState.activeChatTitle = result.chatTitle;
          navigationUIState.chatScreenVisible = true;
          AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, true);

          try {
            navStack.pushPathByName('TgChatScreenPage', new ChatScreenRouteParams(result.chatId, result.chatTitle));
            host.requestOpenChatData(result.chatId);
          } catch (error) {
            pendingForwardTransfer.clear();
            navigationUIState.activeChatId = prevChatId;
            navigationUIState.activeChatTitle = prevTitle;
            navigationUIState.chatScreenVisible = prevChatScreenVisible;
            AppStorage.set<boolean>(StorageKeys.CHAT_SCREEN_VISIBLE, prevChatScreenVisible);
            hilog.error(DOMAIN, TAG, 'Failed to push forwarded target chat: %{public}s', String(error));
          }
        }
      );
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to push forward target picker: %{public}s', String(error));
    }
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

  showMessageActions(entry: ChatTimelineEntryVO, host: ChatMessageActionsHost): void {
    const messageText = entry.message.text.length > 0 ? entry.message.text :
      (entry.message.caption.length > 0 ? entry.message.caption : '');
    const hasText = messageText.trim().length > 0;
    const author = entry.message.isOutgoing ? 'You' :
      (entry.message.senderName.length > 0 ? entry.message.senderName : 'Message');
    const preview = this.resolveReplyPreviewForEntry(entry);
    const messageId = entry.message.messageId;

    const replyBtn: promptAction.Button = {
      text: localized($r('app.string.action_reply').id, 'Reply'),
      color: TgUiTokens.COLOR_ICON_PRIMARY
    };
    const copyBtn: promptAction.Button = {
      text: localized($r('app.string.action_copy').id, 'Copy'),
      color: TgUiTokens.COLOR_TEXT_TITLE
    };
    const deleteBtn: promptAction.Button = {
      text: localized($r('app.string.action_delete').id, 'Delete'),
      color: TgUiTokens.COLOR_TEXT_ERROR
    };
    const forwardBtn: promptAction.Button = {
      text: localized($r('app.string.action_forward').id, 'Forward'),
      color: TgUiTokens.COLOR_TEXT_TITLE
    };

    const nonEditableTypes: string[] = ['sticker', 'videoNote', 'contact', 'poll', 'location', 'game'];
    const canEdit = entry.message.isOutgoing && hasText &&
      !nonEditableTypes.includes(entry.message.contentType);

    const buttons: promptAction.Button[] = [];
    const actions: (() => void)[] = [];

    buttons.push(replyBtn);
    actions.push(() => {
      this.startReply(messageId, author, preview, entry.message.replyIsQuote, host);
    });

    if (canEdit) {
      buttons.push({
        text: localized($r('app.string.action_edit').id, 'Edit'),
        color: TgUiTokens.COLOR_ICON_PRIMARY
      });
      actions.push(() => {
        this.startEditMessage(messageId, messageText, host);
      });
    }

    if (hasText) {
      buttons.push(copyBtn);
      actions.push(() => {
        this.copyMessageText(messageText, host);
      });
    }

    buttons.push(forwardBtn);
    actions.push(() => {
      this.openForwardTargetPicker([messageId], author, preview, host);
    });

    buttons.push({
      text: localized($r('app.string.action_pin').id, 'Pin'),
      color: TgUiTokens.COLOR_TEXT_TITLE
    });
    actions.push(() => {
      this.handlePinMessage(messageId, host);
    });

    buttons.push(deleteBtn);
    actions.push(() => {
      this.handleDeleteMessage(messageId, host);
    });

    const lifecycleToken: number = host.getLifecycleToken();
    const chatId: number = host.getActiveChatId();
    host.getChatUIContext().getPromptAction().showActionMenu({
      title: '',
      buttons: buttons as [promptAction.Button, promptAction.Button?, promptAction.Button?,
        promptAction.Button?, promptAction.Button?, promptAction.Button?]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (lifecycleToken !== host.getLifecycleToken() || host.getActiveChatId() !== chatId) {
        return;
      }
      if (result.index >= 0 && result.index < actions.length) {
        actions[result.index]();
      }
    }).catch((_: Error) => {
      // User dismissed — no action needed.
    });
  }

  startEditMessage(messageId: string, originalText: string, host: ChatMessageActionsHost): void {
    host.clearReplyMode();
    host.clearForwardMode();
    host.setEditMode(messageId, originalText);
    host.setDraftText(originalText);
    hilog.info(DOMAIN, TAG, 'Edit mode started for message %{public}s', messageId);
  }

  cancelEditMessage(host: ChatMessageActionsHost): void {
    host.clearEditMode(true);
  }

  handleEditMessage(newText: string, host: ChatMessageActionsHost): void {
    const useCase = host.getEditUseCase();
    const chatId = host.getActiveChatId();
    const messageId = host.getEditingMessageId();
    if (!useCase || chatId === 0 || messageId === '0') {
      return;
    }
    if (newText.trim().length === 0) {
      this.cancelEditMessage(host);
      return;
    }
    if (newText === host.getEditingOriginalText()) {
      this.cancelEditMessage(host);
      return;
    }

    const params = new EditMessageParams();
    params.chatId = chatId;
    params.messageId = messageId;
    params.text = newText;
    const editId = messageId;

    host.clearEditMode(true);

    const lifecycleToken: number = host.getLifecycleToken();
    useCase.execute(params)
      .then(() => {
        if (!this.isEditContextActive(host, lifecycleToken, useCase, chatId)) {
          return;
        }
        hilog.info(DOMAIN, TAG, 'Message %{public}s edited', editId);
      })
      .catch((err: Error) => {
        if (!this.isEditContextActive(host, lifecycleToken, useCase, chatId)) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Edit failed: %{public}s', err.message);
      });
  }

  handleForwardMessages(commentText: string, host: ChatMessageActionsHost): void {
    const forwardUseCase = host.getForwardUseCase();
    const sendUseCase = host.getSendUseCase();
    const forwardState = host.getForwardModeState();
    if (host.isSendingMessage() || host.getActiveChatId() === 0 || !forwardUseCase) {
      return;
    }
    if (forwardState.sourceChatId === 0 || forwardState.messageIds.length === 0) {
      return;
    }

    const targetChatId = host.getActiveChatId();
    const sourceChatId = forwardState.sourceChatId;
    const messageIds = [...forwardState.messageIds];
    const previewTitle = forwardState.title;
    const previewText = forwardState.preview;
    const trimmedComment = commentText.trim();
    const wasNearBottom = host.isNearBottom();
    let commentSent = false;

    host.setSendingMessage(true);
    host.setDraftText('');
    host.clearReplyMode();
    host.clearEditMode(false);
    host.clearForwardMode();

    const lifecycleToken: number = host.getLifecycleToken();
    Promise.resolve()
      .then(async () => {
        if (trimmedComment.length > 0 && sendUseCase) {
          const sendParams = new SendMessageParams();
          sendParams.chatId = targetChatId;
          sendParams.text = trimmedComment;
          await sendUseCase.execute(sendParams);
          commentSent = true;
        }

        const params = new ForwardMessagesParams();
        params.chatId = targetChatId;
        params.fromChatId = sourceChatId;
        params.messageIds = messageIds;
        await forwardUseCase.execute(params);

        if (!this.isForwardContextActive(host, lifecycleToken, forwardUseCase, sendUseCase, targetChatId)) {
          return;
        }
        if (wasNearBottom) {
          host.scrollToBottomSoon();
        }
      })
      .then(() => {
        if (!this.isForwardContextActive(host, lifecycleToken, forwardUseCase, sendUseCase, targetChatId)) {
          return;
        }
        hilog.info(DOMAIN, TAG, 'Forwarded %{public}d messages into chat %{public}d',
          messageIds.length, targetChatId);
      })
      .catch((err: Error) => {
        if (!this.isForwardContextActive(host, lifecycleToken, forwardUseCase, sendUseCase, targetChatId)) {
          return;
        }
        host.setForwardMode(messageIds, sourceChatId, previewTitle, previewText);
        if (!commentSent && trimmedComment.length > 0) {
          host.setDraftText(trimmedComment);
        }
        hilog.error(DOMAIN, TAG, 'Forward failed: %{public}s', err.message);
      })
      .finally(() => {
        if (!this.isForwardContextActive(host, lifecycleToken, forwardUseCase, sendUseCase, targetChatId)) {
          return;
        }
        host.setSendingMessage(false);
      });
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
      })
      .catch((err: Error) => {
        if (!this.isPinContextActive(host, lifecycleToken, useCase, chatId)) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Pin failed: %{public}s', err.message);
      });
  }

  handleDeleteMessage(messageId: string, host: ChatMessageActionsHost): void {
    const useCase = host.getDeleteUseCase();
    const chatId = host.getActiveChatId();
    if (!useCase || chatId === 0) {
      return;
    }

    const params = new DeleteMessagesParams();
    params.chatId = chatId;
    params.messageIds = [messageId];
    params.revoke = true;

    const lifecycleToken: number = host.getLifecycleToken();
    useCase.execute(params)
      .then(() => {
        if (!this.isDeleteContextActive(host, lifecycleToken, useCase, chatId)) {
          return;
        }
        hilog.info(DOMAIN, TAG, 'Message %{public}s deleted', messageId);
      })
      .catch((err: Error) => {
        if (!this.isDeleteContextActive(host, lifecycleToken, useCase, chatId)) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Delete failed: %{public}s', err.message);
      });
  }

  private buildForwardTitle(messageCount: number): string {
    if (messageCount <= 1) {
      return localized($r('app.string.forwarded_message').id, 'Forwarded message');
    }
    return `${localized($r('app.string.action_forward').id, 'Forward')} ${messageCount}`;
  }

  private buildForwardPreview(author: string, preview: string): string {
    const safeAuthor = author.trim().length > 0 ? author.trim() : 'Message';
    const safePreview = preview.trim().length > 0 ? preview.trim() : 'Message';
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

  private isForwardContextActive(
    host: ChatMessageActionsHost,
    lifecycleToken: number,
    forwardUseCase: ForwardMessagesUseCase,
    sendUseCase: SendMessageUseCase | undefined,
    targetChatId: number
  ): boolean {
    return lifecycleToken === host.getLifecycleToken() &&
      host.getForwardUseCase() === forwardUseCase &&
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
