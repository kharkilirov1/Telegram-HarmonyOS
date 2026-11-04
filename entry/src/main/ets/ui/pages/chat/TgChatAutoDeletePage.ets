// TgChatAutoDeletePage — pick the auto-delete timer for a chat (D20).
// iOS counterpart: ChatAutoDeleteTimeController. Presets mirror iOS; the current value is read from
// getChat and every tap writes the whole timer back through setChatMessageAutoDeleteTime.

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import {
  AUTO_DELETE_PRESETS,
  ChatAutoDeleteUseCase,
  createChatAutoDeleteUseCase
} from '../../../domain/usecases/chatAutoDelete';
import { ChatAutoDeleteRouteParams } from './chatAutoDeleteRoute';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x0046;
const TAG = 'TgChatAutoDeletePage';

@Builder
export function TgChatAutoDeletePageBuilder() {
  TgChatAutoDeletePage();
}

@ComponentV2
export struct TgChatAutoDeletePage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private chatId: number = 0;
  @Local private currentSeconds: number = 0;
  @Local private isLoading: boolean = true;
  @Local private isSaving: boolean = false;
  @Local private errorText: string = '';
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  private useCase?: ChatAutoDeleteUseCase;
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
      this.useCase = createChatAutoDeleteUseCase(getTdGatewayAdapter());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Use case init failed: %{public}s', String(error));
      this.useCase = undefined;
    }
    const params = this.pageStack.getParamByName('TgChatAutoDeletePage') as Object[];
    if (params.length > 0) {
      const routeParams = params[0] as ChatAutoDeleteRouteParams;
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
      this.errorText = localized($r('app.string.auto_delete_failed').id,
        'Could not load the auto-delete timer');
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isLoading = true;
    this.errorText = '';
    useCase.load(this.chatId)
      .then((seconds: number) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isLoading = false;
        this.currentSeconds = seconds;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isLoading = false;
        this.errorText = error.message.length > 0
          ? error.message : localized($r('app.string.auto_delete_failed').id,
            'Could not load the auto-delete timer');
      });
  }

  private presetLabel(seconds: number): string {
    if (seconds === 0) {
      return localized($r('app.string.auto_delete_off').id, 'Off');
    }
    if (seconds === 3600) {
      return localized($r('app.string.auto_delete_1h').id, '1 hour');
    }
    if (seconds === 86400) {
      return localized($r('app.string.auto_delete_1d').id, '1 day');
    }
    if (seconds === 7 * 86400) {
      return localized($r('app.string.auto_delete_1w').id, '1 week');
    }
    return localized($r('app.string.auto_delete_1m').id, '1 month');
  }

  private currentLabel(): string {
    if (this.currentSeconds === 3600) {
      return localized($r('app.string.auto_delete_1h').id, '1 hour');
    }
    if (this.currentSeconds === 86400) {
      return localized($r('app.string.auto_delete_1d').id, '1 day');
    }
    if (this.currentSeconds === 7 * 86400) {
      return localized($r('app.string.auto_delete_1w').id, '1 week');
    }
    if (this.currentSeconds === 30 * 86400) {
      return localized($r('app.string.auto_delete_1m').id, '1 month');
    }
    return localized($r('app.string.auto_delete_off').id, 'Off');
  }

  private apply(seconds: number): void {
    const useCase = this.useCase;
    if (useCase === undefined || this.isSaving || seconds === this.currentSeconds) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    const previous: number = this.currentSeconds;
    this.isSaving = true;
    this.errorText = '';
    this.currentSeconds = seconds;
    useCase.set(this.chatId, seconds)
      .then(() => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isSaving = false;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isSaving = false;
        // A rejected write must not leave a value TDLib never accepted on screen.
        this.currentSeconds = previous;
        this.errorText = error.message.length > 0
          ? error.message : localized($r('app.string.auto_delete_save_failed').id,
            'Could not save the auto-delete timer');
      });
  }

  @Builder
  private buildPresetRow(seconds: number) {
    Row() {
      Text(this.presetLabel(seconds))
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .layoutWeight(1)
      if (this.currentSeconds === seconds) {
        Text('✓')
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .fontColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
    .onClick(() => {
      this.apply(seconds);
    })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        List() {
          ListItem() {
            Text(localized($r('app.string.auto_delete_current').id, 'Current') + ': ' + this.currentLabel())
              .fontSize(TgUiTokens.FONT_META_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_META)
              .width('100%')
              .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_12,
                bottom: TgUiTokens.SPACE_8 })
          }
          ForEach(AUTO_DELETE_PRESETS, (seconds: number) => {
            ListItem() {
              this.buildPresetRow(seconds)
            }
          }, (seconds: number) => 'auto-delete:' + seconds.toString())

          if (this.isLoading) {
            ListItem() {
              Text(localized($r('app.string.auto_delete_loading').id, 'Loading…'))
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
          title: localized($r('app.string.auto_delete_title').id, 'Auto-Delete'),
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
