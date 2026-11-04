// TgChatAdminRightsPage — choose administrator rights before promoting a member (G6).
// iOS counterpart: AdminUserActionsSheet / ChatAdminRightsController. Every right maps 1:1 onto a
// chatAdministratorRights flag; rights the chat type does not support stay off (TDLib ignores them).

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { ChatAdminRightsPayload } from '../../../core/model/AppCommand';
import {
  ChatMemberAdminUseCase,
  createChatMemberAdminUseCase
} from '../../../domain/usecases/chatMemberAdmin';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { ChatAdminRightsRouteParams } from './chatAdminRightsRoute';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x0048;
const TAG = 'TgChatAdminRightsPage';

class AdminRightRow {
  readonly key: string;
  readonly titleRes: Resource;
  readonly fallback: string;

  constructor(key: string, titleRes: Resource, fallback: string) {
    this.key = key;
    this.titleRes = titleRes;
    this.fallback = fallback;
  }
}

// Ten rights that are meaningful for groups and channels; the remaining flags stay false.
const ADMIN_RIGHT_ROWS: AdminRightRow[] = [
  new AdminRightRow('canManageChat', $r('app.string.admin_rights_manage_chat'), 'Manage Chat'),
  new AdminRightRow('canChangeInfo', $r('app.string.admin_rights_change_info'), 'Change Info'),
  new AdminRightRow('canDeleteMessages', $r('app.string.admin_rights_delete_messages'), 'Delete Messages'),
  new AdminRightRow('canInviteUsers', $r('app.string.admin_rights_invite_users'), 'Invite Users'),
  new AdminRightRow('canRestrictMembers', $r('app.string.admin_rights_restrict_members'), 'Restrict Members'),
  new AdminRightRow('canPinMessages', $r('app.string.admin_rights_pin_messages'), 'Pin Messages'),
  new AdminRightRow('canManageTopics', $r('app.string.admin_rights_manage_topics'), 'Manage Topics'),
  new AdminRightRow('canManageVideoChats', $r('app.string.admin_rights_manage_video_chats'),
    'Manage Video Chats'),
  new AdminRightRow('canPromoteMembers', $r('app.string.admin_rights_promote_members'), 'Promote Members'),
  new AdminRightRow('isAnonymous', $r('app.string.admin_rights_anonymous'), 'Remain Anonymous')
];

@ComponentV2
struct AdminRightToggleRow {
  @Param title: string = '';
  @Param value: boolean = false;
  @Event onToggle: () => void = (): void => {};

  build() {
    Row() {
      Text(this.title)
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.value })
        .onChange((_isOn: boolean) => {
          this.onToggle();
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
  }
}

@Builder
export function TgChatAdminRightsPageBuilder() {
  TgChatAdminRightsPage();
}

@ComponentV2
export struct TgChatAdminRightsPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private chatId: number = 0;
  @Local private userId: number = 0;
  @Local private selected: boolean[] = [];
  @Local private isSaving: boolean = false;
  @Local private errorText: string = '';
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  private useCase?: ChatMemberAdminUseCase;
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
      this.useCase = createChatMemberAdminUseCase(getTdGatewayAdapter());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Use case init failed: %{public}s', String(error));
      this.useCase = undefined;
    }
    const params = this.pageStack.getParamByName('TgChatAdminRightsPage') as Object[];
    if (params.length > 0) {
      const routeParams = params[0] as ChatAdminRightsRouteParams;
      this.chatId = routeParams.chatId;
      this.userId = routeParams.userId;
    }
    const initial: boolean[] = [];
    for (let i = 0; i < ADMIN_RIGHT_ROWS.length; i += 1) {
      initial.push(false);
    }
    this.selected = initial;
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.useCase = undefined;
  }

  private toggle(index: number): void {
    const next: boolean[] = [];
    for (let i = 0; i < this.selected.length; i += 1) {
      next.push(i === index ? !this.selected[i] : this.selected[i]);
    }
    this.selected = next;
  }

  private buildRights(): ChatAdminRightsPayload {
    const rights = new ChatAdminRightsPayload();
    for (let i = 0; i < ADMIN_RIGHT_ROWS.length && i < this.selected.length; i += 1) {
      const value: boolean = this.selected[i];
      switch (ADMIN_RIGHT_ROWS[i].key) {
        case 'canManageChat':
          rights.canManageChat = value;
          break;
        case 'canChangeInfo':
          rights.canChangeInfo = value;
          break;
        case 'canDeleteMessages':
          rights.canDeleteMessages = value;
          break;
        case 'canInviteUsers':
          rights.canInviteUsers = value;
          break;
        case 'canRestrictMembers':
          rights.canRestrictMembers = value;
          break;
        case 'canPinMessages':
          rights.canPinMessages = value;
          break;
        case 'canManageTopics':
          rights.canManageTopics = value;
          break;
        case 'canManageVideoChats':
          rights.canManageVideoChats = value;
          break;
        case 'canPromoteMembers':
          rights.canPromoteMembers = value;
          break;
        case 'isAnonymous':
          rights.isAnonymous = value;
          break;
        default:
          break;
      }
    }
    return rights;
  }

  private save(): void {
    const useCase = this.useCase;
    if (useCase === undefined || this.isSaving || this.chatId <= 0 || this.userId <= 0) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isSaving = true;
    this.errorText = '';
    useCase.apply(this.chatId, this.userId, 'promote', 0, this.buildRights())
      .then(() => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isSaving = false;
        this.getUIContext().getPromptAction().showToast({
          message: localized($r('app.string.admin_rights_saved').id, 'Administrator added'),
          duration: 1500
        });
        this.pageStack.pop();
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isSaving = false;
        this.errorText = error.message.length > 0
          ? error.message : localized($r('app.string.admin_rights_failed').id,
            'Could not add the administrator');
      });
  }

  @Builder
  private buildSaveButton() {
    Button(localized($r('app.string.admin_rights_save').id, 'Add Administrator'))
      .width('100%')
      .height(TgUiTokens.COMPOSER_BUTTON_SIZE)
      .type(ButtonType.Capsule)
      .backgroundColor(TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND)
      .fontColor(TgUiTokens.COLOR_BG_PRIMARY)
      .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
      .fontWeight(FontWeight.Medium)
      .enabled(!this.isSaving)
      .opacity(this.isSaving ? 0.6 : 1)
      .onClick(() => {
        this.save();
      })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        List() {
          ForEach(ADMIN_RIGHT_ROWS, (row: AdminRightRow, index: number) => {
            ListItem() {
              AdminRightToggleRow({
                title: localized(row.titleRes.id, row.fallback),
                value: index < this.selected.length ? this.selected[index] : false,
                onToggle: (): void => {
                  this.toggle(index);
                }
              })
            }
          }, (row: AdminRightRow) => row.key)

          ListItem() {
            Column() {
              this.buildSaveButton()
              if (this.errorText.length > 0) {
                Text(this.errorText)
                  .fontSize(TgUiTokens.FONT_META_SIZE)
                  .fontColor(TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE)
                  .width('100%')
                  .margin({ top: TgUiTokens.SPACE_8 })
              }
            }
            .width('100%')
            .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_16 })
          }
        }
        .width('100%')
        .height('100%')
        .contentStartOffset(this.topBarTotalHeight)
        .divider({ strokeWidth: 1, color: TgUiTokens.COLOR_SEPARATOR, startMargin: TgUiTokens.SPACE_16 })

        TgChatTopBar({
          topInset: this.topBarInset,
          title: localized($r('app.string.admin_rights_title').id, 'Administrator Rights'),
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
