// TgChatAdministratorsPage — admin screen listing the chat's administrators (S12i).
// iOS counterpart: ChatAdministratorsController. Names resolve from the users store; TDLib returns
// only user_id, custom_title and is_owner, so unknown users fall back to a neutral placeholder.

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { ChatAdministratorDto } from '../../../core/model/dto/ChatAdministratorDto';
import { User } from '../../../core/model/AppState';
import {
  ChatAdministratorsUseCase,
  createChatAdministratorsUseCase
} from '../../../domain/usecases/chatAdministrators';
import { ChatAdministratorsRouteParams } from './chatAdministratorsRoute';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x0044;
const TAG = 'TgChatAdministratorsPage';

@Builder
export function TgChatAdministratorsPageBuilder() {
  TgChatAdministratorsPage();
}

@ComponentV2
export struct TgChatAdministratorsPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private chatId: number = 0;
  @Local private administrators: ChatAdministratorDto[] = [];
  @Local private isLoading: boolean = true;
  @Local private errorText: string = '';
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  private useCase?: ChatAdministratorsUseCase;
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
      this.useCase = createChatAdministratorsUseCase(getTdGatewayAdapter());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Use case init failed: %{public}s', String(error));
      this.useCase = undefined;
    }
    const params = this.pageStack.getParamByName('TgChatAdministratorsPage') as Object[];
    if (params.length > 0) {
      const routeParams = params[0] as ChatAdministratorsRouteParams;
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
      this.errorText = localized($r('app.string.administrators_failed').id,
        'Could not load administrators');
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
        this.administrators = page.administrators;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isLoading = false;
        this.errorText = error.message.length > 0
          ? error.message : localized($r('app.string.administrators_failed').id,
            'Could not load administrators');
      });
  }

  private displayName(admin: ChatAdministratorDto): string {
    try {
      const user: User | undefined = getAppCoreRuntime().getStore().getState().users.users
        .get(admin.userId);
      if (user !== undefined) {
        const fullName: string = (user.firstName + ' ' + user.lastName).trim();
        if (fullName.length > 0) {
          return fullName;
        }
        if (user.username.length > 0) {
          return '@' + user.username;
        }
      }
    } catch (_error) {
      // Fall through to the placeholder below.
    }
    return localized($r('app.string.administrators_unknown_user').id, 'User') + ' ' +
      admin.userId.toString();
  }

  private subtitle(admin: ChatAdministratorDto): string {
    const parts: string[] = [];
    if (admin.isOwner) {
      parts.push(localized($r('app.string.administrators_owner').id, 'Owner'));
    }
    if (admin.customTitle.length > 0) {
      parts.push(admin.customTitle);
    }
    return parts.join(' · ');
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        List() {
          ForEach(this.administrators, (admin: ChatAdministratorDto) => {
            ListItem() {
              Column() {
                Text(this.displayName(admin))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                if (this.subtitle(admin).length > 0) {
                  Text(this.subtitle(admin))
                    .fontSize(TgUiTokens.FONT_META_SIZE)
                    .fontColor(TgUiTokens.COLOR_TEXT_META)
                    .margin({ top: TgUiTokens.SPACE_4 })
                    .width('100%')
                }
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8,
                bottom: TgUiTokens.SPACE_8 })
            }
          }, (admin: ChatAdministratorDto) => admin.userId.toString() + (admin.isOwner ? ':o' : ''))

          if (this.isLoading) {
            ListItem() {
              Text(localized($r('app.string.administrators_loading').id, 'Loading administrators…'))
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_META)
                .width('100%')
                .padding({ left: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_12 })
            }
          }

          if (!this.isLoading && this.administrators.length === 0 && this.errorText.length === 0) {
            ListItem() {
              Text(localized($r('app.string.administrators_empty').id, 'No administrators'))
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
          title: localized($r('app.string.administrators_title').id, 'Administrators'),
          subtitle: this.administrators.length > 0 ? this.administrators.length.toString() : '',
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
