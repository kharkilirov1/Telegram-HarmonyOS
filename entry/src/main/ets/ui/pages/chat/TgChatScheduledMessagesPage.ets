// TgChatScheduledMessagesPage — list, send now, reschedule and cancel a chat's scheduled messages (D21).
// iOS counterpart: ChatScheduledMessagesController. Row actions mirror the iOS context menu.

import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { ScheduledMessageDto } from '../../../core/model/dto/ScheduledMessageDto';
import {
  ScheduledMessagesUseCase,
  createScheduledMessagesUseCase
} from '../../../domain/usecases/scheduledMessages';
import { ChatScheduledMessagesRouteParams } from './chatScheduledMessagesRoute';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x0047;
const TAG = 'TgChatScheduledMessagesPage';

type ScheduledRowAction = 'sendNow' | 'rescheduleHour' | 'cancel';

@Builder
export function TgChatScheduledMessagesPageBuilder() {
  TgChatScheduledMessagesPage();
}

@ComponentV2
export struct TgChatScheduledMessagesPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private chatId: number = 0;
  @Local private messages: ScheduledMessageDto[] = [];
  @Local private isLoading: boolean = true;
  @Local private errorText: string = '';
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  private useCase?: ScheduledMessagesUseCase;
  private pageLifecycleToken: number = 0;

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topBarTotalHeight = computeTopBarHeight(context);
      this.topBarInset = this.topBarTotalHeight - TgUiTokens.TOP_BAR_HEIGHT;
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
      this.topBarInset = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
    }
    try {
      this.useCase = createScheduledMessagesUseCase(getTdGatewayAdapter());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Use case init failed: %{public}s', String(error));
      this.useCase = undefined;
    }
    const params = this.pageStack.getParamByName('TgChatScheduledMessagesPage') as Object[];
    if (params.length > 0) {
      const routeParams = params[0] as ChatScheduledMessagesRouteParams;
      this.chatId = routeParams.chatId;
    }
    this.reload();
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.useCase = undefined;
  }

  private reload(): void {
    const useCase = this.useCase;
    if (useCase === undefined || this.chatId <= 0) {
      this.isLoading = false;
      this.errorText = localized($r('app.string.scheduled_failed').id,
        'Could not load scheduled messages');
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isLoading = true;
    this.errorText = '';
    useCase.load(this.chatId)
      .then((page) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isLoading = false;
        this.messages = page.messages;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isLoading = false;
        this.errorText = error.message.length > 0
          ? error.message : localized($r('app.string.scheduled_failed').id,
            'Could not load scheduled messages');
      });
  }

  private rowSubtitle(message: ScheduledMessageDto): string {
    const date = new Date(message.sendDate * 1000);
    const pad = (value: number): string => value < 10 ? '0' + value.toString() : value.toString();
    return pad(date.getDate()) + '.' + pad(date.getMonth() + 1) + ' ' +
      pad(date.getHours()) + ':' + pad(date.getMinutes());
  }

  private rowTitle(message: ScheduledMessageDto): string {
    return message.text.length > 0
      ? message.text
      : localized($r('app.string.scheduled_media').id, 'Media message');
  }

  private showActions(message: ScheduledMessageDto): void {
    const labels: string[] = [
      localized($r('app.string.scheduled_send_now').id, 'Send Now'),
      localized($r('app.string.scheduled_reschedule_hour').id, 'In 1 hour'),
      localized($r('app.string.scheduled_cancel').id, 'Delete')
    ];
    const actions: ScheduledRowAction[] = ['sendNow', 'rescheduleHour', 'cancel'];
    const normal: Resource = TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND;
    const destructive: Resource = TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE;
    const b0: promptAction.Button = { text: labels[0], color: normal };
    const b1: promptAction.Button = { text: labels[1], color: normal };
    const b2: promptAction.Button = { text: labels[2], color: destructive };
    this.getUIContext().getPromptAction().showActionMenu({
      title: this.rowTitle(message),
      buttons: [b0, b1, b2]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      this.applyAction(actions[result.index], message);
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'Scheduled row menu failed: %{public}s', error.message);
    });
  }

  private applyAction(action: ScheduledRowAction | undefined, message: ScheduledMessageDto): void {
    const useCase = this.useCase;
    if (useCase === undefined || action === undefined) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.errorText = '';
    if (action === 'sendNow') {
      useCase.sendNow(this.chatId, message.messageId)
        .then(() => {
          if (token === this.pageLifecycleToken) {
            this.reload();
          }
        })
        .catch((error: Error) => {
          if (token !== this.pageLifecycleToken) {
            return;
          }
          this.errorText = error.message;
        });
      return;
    }
    if (action === 'rescheduleHour') {
      const nowSeconds: number = Math.floor(Date.now() / 1000);
      useCase.reschedule(this.chatId, message.messageId, nowSeconds + 3600, nowSeconds)
        .then(() => {
          if (token === this.pageLifecycleToken) {
            this.reload();
          }
        })
        .catch((error: Error) => {
          if (token !== this.pageLifecycleToken) {
            return;
          }
          this.errorText = error.message;
        });
      return;
    }
    useCase.cancel(this.chatId, message.messageId)
      .then(() => {
        if (token === this.pageLifecycleToken) {
          this.reload();
        }
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.errorText = error.message;
      });
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        List() {
          ForEach(this.messages, (message: ScheduledMessageDto) => {
            ListItem() {
              Column() {
                Text(this.rowTitle(message))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                Text(this.rowSubtitle(message))
                  .fontSize(TgUiTokens.FONT_META_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_META)
                  .margin({ top: TgUiTokens.SPACE_4 })
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8,
                bottom: TgUiTokens.SPACE_8 })
              .onClick(() => {
                this.showActions(message);
              })
            }
          }, (message: ScheduledMessageDto) => message.messageId)

          if (this.isLoading) {
            ListItem() {
              Text(localized($r('app.string.scheduled_loading').id, 'Loading scheduled messages…'))
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_META)
                .width('100%')
                .padding({ left: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_12 })
            }
          }

          if (!this.isLoading && this.messages.length === 0 && this.errorText.length === 0) {
            ListItem() {
              Text(localized($r('app.string.scheduled_empty').id, 'No scheduled messages'))
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_META)
                .width('100%')
                .padding({ left: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_12 })
            }
          }
        }
        .width('100%')
        .height('100%')
        .contentStartOffset(this.topBarTotalHeight)
        .divider({ strokeWidth: 1, color: TgUiTokens.COLOR_SEPARATOR, startMargin: TgUiTokens.SPACE_16 })

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE)
            .width('100%')
            .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_12 })
            .position({ x: 0, y: this.topBarTotalHeight })
        }

        TgChatTopBar({
          topInset: this.topBarInset,
          title: localized($r('app.string.scheduled_title').id, 'Scheduled Messages'),
          subtitle: this.messages.length > 0 ? this.messages.length.toString() : '',
          onBackPress: (): void => {
            this.pageStack.pop();
          }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }
    .hideTitleBar(true)
  }
}
