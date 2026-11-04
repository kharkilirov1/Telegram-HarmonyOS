// Chat actions menu coordinator — keeps TgChatScreenPage within the bounded-owner size limit while the
// menu grows (Info / Mute / Clear History / Delete / Leave or Share Contact / Report).
// The page owns routing and UI context; this coordinator owns the menu flow and TDLib calls.

import { promptAction, UIContext } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { AppState, Chat } from '../../../core/model/AppState';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { createSetChatMuteUseCase, MUTE_FOREVER } from '../../../domain/usecases/setChatMute';
import { createDeleteChatHistoryUseCase } from '../../../domain/usecases/deleteChatHistory';
import { createLeaveChatUseCase, createShareMyContactUseCase } from '../../../domain/usecases/chatMembership';
import { createReportChatUseCase } from '../../../domain/usecases/reportChat';
import { ReportChatOptionDto, ReportChatStepDto } from '../../../core/model/dto/ReportChatDto';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';

const DOMAIN = 0x003b;
const TAG = 'ChatActions';

// A class (not an interface literal) keeps ArkTS' object-literal restrictions out of the page.
export class ChatActionsHost {
  private uiContextProvider: () => UIContext;
  private titleProvider: () => string;
  private tokenProvider: () => number;
  private profileAction: () => void;
  private backAction: () => void;

  constructor(
    uiContextProvider: () => UIContext,
    titleProvider: () => string,
    tokenProvider: () => number,
    profileAction: () => void,
    backAction: () => void,
    reportCommentAction: (chatId: number, optionId: string) => void,
    reportMessagesAction: (chatId: number, optionId: string) => void
  ) {
    this.uiContextProvider = uiContextProvider;
    this.titleProvider = titleProvider;
    this.tokenProvider = tokenProvider;
    this.profileAction = profileAction;
    this.backAction = backAction;
    this.reportCommentHandler = reportCommentAction;
    this.reportMessagesHandler = reportMessagesAction;
  }

  uiContext(): UIContext {
    return this.uiContextProvider();
  }

  title(): string {
    return this.titleProvider();
  }

  lifecycleToken(): number {
    return this.tokenProvider();
  }

  openProfile(): void {
    this.profileAction();
  }

  handleBackPress(): void {
    this.backAction();
  }

  private reportCommentHandler: (chatId: number, optionId: string) => void;
  private reportMessagesHandler: (chatId: number, optionId: string) => void;

  requestReportComment(chatId: number, optionId: string): void {
    this.reportCommentHandler(chatId, optionId);
  }

  requestReportMessages(chatId: number, optionId: string): void {
    this.reportMessagesHandler(chatId, optionId);
  }

}

export class ChatActionsCoordinator {
  private host: ChatActionsHost;

  constructor(host: ChatActionsHost) {
    this.host = host;
  }

  activeChat(): Chat | undefined {
    try {
      const state: AppState = getAppCoreRuntime().getStore().getState();
      const chatId = state.chats.orderedChatIds.length >= 0 ? this.activeChatId() : 0;
      return chatId > 0 ? state.chats.chats.get(chatId) : undefined;
    } catch (_error) {
      return undefined;
    }
  }

  private activeChatId(): number {
    try {
      const state: AppState = getAppCoreRuntime().getStore().getState();
      // The page passes the live id through the title host only; the store lookup is by id.
      return state.chats.orderedChatIds.length >= 0 ? this.currentChatId : 0;
    } catch (_error) {
      return 0;
    }
  }

  // Set by the page before opening the menu; avoids duplicating the chrome state here.
  currentChatId: number = 0;

  private isMuted(): boolean {
    const chat = this.activeChat();
    return chat !== undefined && chat.muteForSeconds > 0;
  }

  private toast(message: string): void {
    this.host.uiContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  open(): void {
    const chatId = this.currentChatId;
    const chat = this.activeChat();
    if (chatId <= 0 || chat === undefined) {
      return;
    }
    const muteTitle: string = this.isMuted()
      ? localized($r('app.string.profile_unmute').id, 'Unmute')
      : localized($r('app.string.profile_mute').id, 'Mute');
    const membershipTitle: string = this.canLeaveChat(chat)
      ? localized($r('app.string.chat_actions_leave').id, 'Leave Chat')
      : localized($r('app.string.chat_actions_share_contact').id, 'Share My Contact');
    const destructive: ResourceColor = TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE;
    const normal: ResourceColor = TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND;
    const menu: promptAction.ActionMenuOptions = chat.canBeReported
      ? {
        title: this.host.title(),
        buttons: [
          { text: localized($r('app.string.chat_actions_info').id, 'Chat Info'), color: normal },
          { text: muteTitle, color: normal },
          { text: localized($r('app.string.profile_clear_history').id, 'Clear History'), color: normal },
          { text: localized($r('app.string.profile_delete_chat').id, 'Delete Chat'), color: destructive },
          { text: membershipTitle, color: destructive },
          { text: localized($r('app.string.chat_actions_report').id, 'Report'), color: destructive }
        ]
      }
      : {
        title: this.host.title(),
        buttons: [
          { text: localized($r('app.string.chat_actions_info').id, 'Chat Info'), color: normal },
          { text: muteTitle, color: normal },
          { text: localized($r('app.string.profile_clear_history').id, 'Clear History'), color: normal },
          { text: localized($r('app.string.profile_delete_chat').id, 'Delete Chat'), color: destructive },
          { text: membershipTitle, color: destructive }
        ]
      };
    this.host.uiContext().getPromptAction().showActionMenu(menu)
      .then((result: promptAction.ActionMenuSuccessResponse) => {
        this.handleChoice(result.index, chatId, chat);
      })
      .catch((error: Error) => {
        hilog.warn(DOMAIN, TAG, 'Chat actions failed: %{public}s', error.message);
      });
  }

  private handleChoice(index: number, chatId: number, chat: Chat): void {
    if (index === 0) {
      this.host.openProfile();
    } else if (index === 1) {
      this.toggleMute(chatId);
    } else if (index === 2) {
      this.confirmDeletion(chatId, false);
    } else if (index === 3) {
      this.confirmDeletion(chatId, true);
    } else if (index === 4) {
      if (this.canLeaveChat(chat)) {
        this.confirmLeave(chatId);
      } else {
        this.shareContact(chatId);
      }
    } else if (index === 5) {
      this.startReport(chatId);
    }
  }

  private canLeaveChat(chat: Chat): boolean {
    return chat.type === 'group' || chat.type === 'supergroup' || chat.type === 'channel';
  }

  private toggleMute(chatId: number): void {
    const token: number = this.host.lifecycleToken();
    const nextMuted: boolean = !this.isMuted();
    try {
      const useCase = createSetChatMuteUseCase(getTdGatewayAdapter());
      const work = nextMuted ? useCase.mute(chatId, MUTE_FOREVER) : useCase.unmute(chatId);
      work.then(() => {
        if (token !== this.host.lifecycleToken()) {
          return;
        }
        this.toast(nextMuted
          ? localized($r('app.string.profile_mute').id, 'Mute')
          : localized($r('app.string.profile_unmute').id, 'Unmute'));
      }).catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Mute failed: %{public}s', error.message);
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Mute use case init failed: %{public}s', String(error));
    }
  }

  private confirmDeletion(chatId: number, removeChat: boolean): void {
    const title: string = removeChat
      ? localized($r('app.string.profile_delete_chat').id, 'Delete Chat')
      : localized($r('app.string.profile_clear_history').id, 'Clear History');
    const message: string = removeChat
      ? localized($r('app.string.profile_delete_chat_confirm').id, 'Delete this chat and all its messages?')
      : localized($r('app.string.profile_clear_history_confirm').id,
        'Delete all messages in this chat? The chat itself stays in the list.');
    this.host.uiContext().getPromptAction().showDialog({
      title: title,
      message: message,
      buttons: [
        { text: localized($r('app.string.cancel').id, 'Cancel'), color: TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND },
        { text: title, color: TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.executeDeletion(chatId, removeChat);
      }
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'Delete dialog failed: %{public}s', error.message);
    });
  }

  private executeDeletion(chatId: number, removeChat: boolean): void {
    const token: number = this.host.lifecycleToken();
    try {
      const useCase = createDeleteChatHistoryUseCase(getTdGatewayAdapter());
      useCase.execute(chatId, removeChat, removeChat).then(() => {
        if (token !== this.host.lifecycleToken()) {
          return;
        }
        this.toast(removeChat
          ? localized($r('app.string.profile_chat_deleted_toast').id, 'Chat deleted')
          : localized($r('app.string.profile_history_cleared_toast').id, 'History cleared'));
        if (removeChat) {
          this.host.handleBackPress();
        }
      }).catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Delete failed: %{public}s', error.message);
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Delete use case init failed: %{public}s', String(error));
    }
  }

  private confirmLeave(chatId: number): void {
    const title: string = localized($r('app.string.chat_actions_leave').id, 'Leave Chat');
    this.host.uiContext().getPromptAction().showDialog({
      title: title,
      message: localized($r('app.string.chat_actions_leave_confirm').id,
        'Leave this chat? You will stop receiving its messages.'),
      buttons: [
        { text: localized($r('app.string.cancel').id, 'Cancel'), color: TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND },
        { text: title, color: TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index !== 1) {
        return;
      }
      const token: number = this.host.lifecycleToken();
      try {
        const useCase = createLeaveChatUseCase(getTdGatewayAdapter());
        useCase.leave(chatId).then(() => {
          if (token !== this.host.lifecycleToken()) {
            return;
          }
          this.toast(localized($r('app.string.chat_actions_left_toast').id, 'You left the chat'));
          this.host.handleBackPress();
        }).catch((error: Error) => {
          hilog.error(DOMAIN, TAG, 'Leave failed: %{public}s', error.message);
        });
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Leave use case init failed: %{public}s', String(error));
      }
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'Leave dialog failed: %{public}s', error.message);
    });
  }

  private shareContact(chatId: number): void {
    let phoneNumber: string = '';
    let firstName: string = '';
    let lastName: string = '';
    let userId: number = 0;
    try {
      const state: AppState = getAppCoreRuntime().getStore().getState();
      userId = state.auth.userId;
      const self = state.users.users.get(userId);
      if (self === undefined) {
        this.toast(localized($r('app.string.chat_actions_share_failed').id, 'Could not share your contact'));
        return;
      }
      phoneNumber = self.phoneNumber;
      firstName = self.firstName;
      lastName = self.lastName;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Self lookup failed: %{public}s', String(error));
      return;
    }
    const token: number = this.host.lifecycleToken();
    try {
      const useCase = createShareMyContactUseCase(getTdGatewayAdapter());
      useCase.share(chatId, phoneNumber, firstName, lastName, userId).then(() => {
        if (token !== this.host.lifecycleToken()) {
          return;
        }
        this.toast(localized($r('app.string.chat_actions_contact_shared').id, 'Contact shared'));
      }).catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Share contact failed: %{public}s', error.message);
        this.toast(localized($r('app.string.chat_actions_share_failed').id, 'Could not share your contact'));
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Share use case init failed: %{public}s', String(error));
    }
  }

  private startReport(chatId: number): void {
    const token: number = this.host.lifecycleToken();
    try {
      const useCase = createReportChatUseCase(getTdGatewayAdapter());
      useCase.start(chatId).then((step: ReportChatStepDto) => {
        if (token !== this.host.lifecycleToken()) {
          return;
        }
        this.handleReportStep(chatId, step);
      }).catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Report start failed: %{public}s', error.message);
        this.toast(localized($r('app.string.chat_actions_report_failed').id, 'Could not report the chat'));
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Report use case init failed: %{public}s', String(error));
    }
  }

  private handleReportStep(chatId: number, step: ReportChatStepDto): void {
    if (step.kind === 'ok') {
      this.toast(localized($r('app.string.chat_actions_report_sent').id, 'Report sent'));
      return;
    }
    if (step.kind === 'options') {
      this.showReasonMenu(chatId, step);
      return;
    }
    if (step.kind === 'text') {
      // The page owns the comment panel; the reason id travels back with the text.
      this.host.requestReportComment(chatId, step.optionId);
      return;
    }
    if (step.kind === 'messages') {
      // The page enters selection mode and reports the chosen message ids.
      this.host.requestReportMessages(chatId, step.optionId);
      return;
    }
    this.toast(localized($r('app.string.chat_actions_report_failed').id, 'Could not report the chat'));
  }

  private showReasonMenu(chatId: number, step: ReportChatStepDto): void {
    // showActionMenu takes a fixed six-slot tuple; extra reasons stay out of this sheet.
    const shown: ReportChatOptionDto[] = step.options.slice(0, 6);
    if (shown.length === 0) {
      this.toast(localized($r('app.string.chat_actions_report_failed').id, 'Could not report the chat'));
      return;
    }
    const destructive: ResourceColor = TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE;
    const b0: promptAction.Button | undefined = { text: shown[0].text, color: destructive };
    const b1: promptAction.Button | undefined = shown.length > 1 ? { text: shown[1].text, color: destructive } : undefined;
    const b2: promptAction.Button | undefined = shown.length > 2 ? { text: shown[2].text, color: destructive } : undefined;
    const b3: promptAction.Button | undefined = shown.length > 3 ? { text: shown[3].text, color: destructive } : undefined;
    const b4: promptAction.Button | undefined = shown.length > 4 ? { text: shown[4].text, color: destructive } : undefined;
    const b5: promptAction.Button | undefined = shown.length > 5 ? { text: shown[5].text, color: destructive } : undefined;
    const label: string = step.title.length > 0
      ? step.title : localized($r('app.string.chat_actions_report').id, 'Report');
    this.host.uiContext().getPromptAction().showActionMenu({
      title: label,
      buttons: [b0, b1, b2, b3, b4, b5]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      const option = shown[result.index];
      if (option === undefined) {
        return;
      }
      this.submitReportOption(chatId, option.id);
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'Report options failed: %{public}s', error.message);
    });
  }

  submitReportComment(chatId: number, optionId: string, text: string): Promise<void> {
    const token: number = this.host.lifecycleToken();
    return new Promise<void>((resolve: () => void, reject: (error: Error) => void): void => {
      try {
        const useCase = createReportChatUseCase(getTdGatewayAdapter());
        useCase.submitComment(chatId, optionId, text).then((step: ReportChatStepDto) => {
          if (token === this.host.lifecycleToken()) {
            this.handleReportStep(chatId, step);
          }
          resolve();
        }).catch((error: Error) => {
          hilog.error(DOMAIN, TAG, 'Report comment failed: %{public}s', error.message);
          this.toast(localized($r('app.string.chat_actions_report_failed').id, 'Could not report the chat'));
          reject(error);
        });
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Report use case init failed: %{public}s', String(error));
        reject(error as Error);
      }
    });
  }

  submitReportMessages(chatId: number, optionId: string, messageIds: number[]): Promise<void> {
    const token: number = this.host.lifecycleToken();
    return new Promise<void>((resolve: () => void, reject: (error: Error) => void): void => {
      try {
        const useCase = createReportChatUseCase(getTdGatewayAdapter());
        useCase.submitMessages(chatId, optionId, messageIds).then((step: ReportChatStepDto) => {
          if (token === this.host.lifecycleToken()) {
            this.handleReportStep(chatId, step);
          }
          resolve();
        }).catch((error: Error) => {
          hilog.error(DOMAIN, TAG, 'Report messages failed: %{public}s', error.message);
          this.toast(localized($r('app.string.chat_actions_report_failed').id, 'Could not report the chat'));
          reject(error);
        });
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Report use case init failed: %{public}s', String(error));
        reject(error as Error);
      }
    });
  }

  private submitReportOption(chatId: number, optionId: string): void {
    const token: number = this.host.lifecycleToken();
    try {
      const useCase = createReportChatUseCase(getTdGatewayAdapter());
      useCase.chooseOption(chatId, optionId).then((step: ReportChatStepDto) => {
        if (token !== this.host.lifecycleToken()) {
          return;
        }
        this.handleReportStep(chatId, step);
      }).catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Report submit failed: %{public}s', error.message);
        this.toast(localized($r('app.string.chat_actions_report_failed').id, 'Could not report the chat'));
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Report use case init failed: %{public}s', String(error));
    }
  }
}
