// TgChatRestrictRightsPage — restrict a member with a chosen permission set and duration (G6).
// iOS counterpart: the restriction sheet of AdminUserActionsSheet. Toggles mean "still allowed"; every
// disabled toggle is denied in the chatPermissions object sent with chatMemberStatusRestricted.

import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { ChatPermissionsDto, chatPermissionsToJson } from '../../../core/model/dto/ChatPermissionsDto';
import {
  ChatMemberAdminUseCase,
  MODERATION_DURATION_SECONDS,
  createChatMemberAdminUseCase,
  moderationUntilDate
} from '../../../domain/usecases/chatMemberAdmin';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { ChatRestrictRightsRouteParams } from './chatRestrictRightsRoute';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x0048;
const TAG = 'TgChatRestrictRightsPage';

class RestrictPermissionRow {
  readonly key: string;
  readonly titleRes: Resource;
  readonly fallback: string;

  constructor(key: string, titleRes: Resource, fallback: string) {
    this.key = key;
    this.titleRes = titleRes;
    this.fallback = fallback;
  }
}

// Send permissions first (the common restriction), then the administrative ones.
const RESTRICT_PERMISSION_ROWS: RestrictPermissionRow[] = [
  new RestrictPermissionRow('canSendBasicMessages', $r('app.string.restrict_perm_text'), 'Text messages'),
  new RestrictPermissionRow('canSendPhotos', $r('app.string.restrict_perm_photos'), 'Photos'),
  new RestrictPermissionRow('canSendVideos', $r('app.string.restrict_perm_videos'), 'Videos'),
  new RestrictPermissionRow('canSendAudios', $r('app.string.restrict_perm_audios'), 'Audio files'),
  new RestrictPermissionRow('canSendVoiceNotes', $r('app.string.restrict_perm_voice'), 'Voice messages'),
  new RestrictPermissionRow('canSendVideoNotes', $r('app.string.restrict_perm_video_notes'),
    'Video messages'),
  new RestrictPermissionRow('canSendDocuments', $r('app.string.restrict_perm_documents'), 'Documents'),
  new RestrictPermissionRow('canSendPolls', $r('app.string.restrict_perm_polls'), 'Polls'),
  new RestrictPermissionRow('canSendOtherMessages', $r('app.string.restrict_perm_other'),
    'GIFs and stickers'),
  new RestrictPermissionRow('canAddLinkPreviews', $r('app.string.restrict_perm_links'),
    'Link previews'),
  new RestrictPermissionRow('canInviteUsers', $r('app.string.restrict_perm_invite'), 'Invite users'),
  new RestrictPermissionRow('canPinMessages', $r('app.string.restrict_perm_pin'), 'Pin messages'),
  new RestrictPermissionRow('canChangeInfo', $r('app.string.restrict_perm_info'), 'Change chat info'),
  new RestrictPermissionRow('canCreateTopics', $r('app.string.restrict_perm_topics'), 'Create topics')
];

@ComponentV2
struct RestrictPermissionToggleRow {
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
export function TgChatRestrictRightsPageBuilder() {
  TgChatRestrictRightsPage();
}

@ComponentV2
export struct TgChatRestrictRightsPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private chatId: number = 0;
  @Local private userId: number = 0;
  @Local private allowed: boolean[] = [];
  @Local private durationSeconds: number = 86400;
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
    const params = this.pageStack.getParamByName('TgChatRestrictRightsPage') as Object[];
    if (params.length > 0) {
      const routeParams = params[0] as ChatRestrictRightsRouteParams;
      this.chatId = routeParams.chatId;
      this.userId = routeParams.userId;
    }
    const initial: boolean[] = [];
    for (let i = 0; i < RESTRICT_PERMISSION_ROWS.length; i += 1) {
      initial.push(false);
    }
    this.allowed = initial;
    this.prefill();
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.useCase = undefined;
  }

  // An already restricted member opens with the permissions they still have.
  private prefill(): void {
    const useCase = this.useCase;
    if (useCase === undefined || this.chatId <= 0 || this.userId <= 0) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    useCase.loadState(this.chatId, this.userId)
      .then((state) => {
        if (token !== this.pageLifecycleToken || state.statusKind !== 'restricted') {
          return;
        }
        const values: boolean[] = [];
        for (let i = 0; i < RESTRICT_PERMISSION_ROWS.length; i += 1) {
          values.push(this.permissionValue(state.permissions, RESTRICT_PERMISSION_ROWS[i].key));
        }
        this.allowed = values;
        if (state.untilDate > 0) {
          const remaining: number = Math.max(0, state.untilDate - Math.floor(Date.now() / 1000));
          if (remaining <= 3600) {
            this.durationSeconds = 3600;
          } else if (remaining <= 86400) {
            this.durationSeconds = 86400;
          } else if (remaining <= 7 * 86400) {
            this.durationSeconds = 7 * 86400;
          } else {
            this.durationSeconds = MODERATION_DURATION_SECONDS[2];
          }
        }
      })
      .catch((error: Error) => {
        hilog.warn(DOMAIN, TAG, 'Restriction prefill failed: %{public}s', error.message);
      });
  }

  private permissionValue(permissions: ChatPermissionsDto, key: string): boolean {
    switch (key) {
      case 'canSendBasicMessages':
        return permissions.canSendBasicMessages;
      case 'canSendPhotos':
        return permissions.canSendPhotos;
      case 'canSendVideos':
        return permissions.canSendVideos;
      case 'canSendAudios':
        return permissions.canSendAudios;
      case 'canSendVoiceNotes':
        return permissions.canSendVoiceNotes;
      case 'canSendVideoNotes':
        return permissions.canSendVideoNotes;
      case 'canSendDocuments':
        return permissions.canSendDocuments;
      case 'canSendPolls':
        return permissions.canSendPolls;
      case 'canSendOtherMessages':
        return permissions.canSendOtherMessages;
      case 'canAddLinkPreviews':
        return permissions.canAddLinkPreviews;
      case 'canInviteUsers':
        return permissions.canInviteUsers;
      case 'canPinMessages':
        return permissions.canPinMessages;
      case 'canChangeInfo':
        return permissions.canChangeInfo;
      case 'canCreateTopics':
        return permissions.canCreateTopics;
      default:
        return false;
    }
  }

  private toggle(index: number): void {
    const next: boolean[] = [];
    for (let i = 0; i < this.allowed.length; i += 1) {
      next.push(i === index ? !this.allowed[i] : this.allowed[i]);
    }
    this.allowed = next;
  }

  private buildPermissions(): ChatPermissionsDto {
    const permissions = new ChatPermissionsDto();
    for (let i = 0; i < RESTRICT_PERMISSION_ROWS.length && i < this.allowed.length; i += 1) {
      const value: boolean = this.allowed[i];
      switch (RESTRICT_PERMISSION_ROWS[i].key) {
        case 'canSendBasicMessages':
          permissions.canSendBasicMessages = value;
          break;
        case 'canSendPhotos':
          permissions.canSendPhotos = value;
          break;
        case 'canSendVideos':
          permissions.canSendVideos = value;
          break;
        case 'canSendAudios':
          permissions.canSendAudios = value;
          break;
        case 'canSendVoiceNotes':
          permissions.canSendVoiceNotes = value;
          break;
        case 'canSendVideoNotes':
          permissions.canSendVideoNotes = value;
          break;
        case 'canSendDocuments':
          permissions.canSendDocuments = value;
          break;
        case 'canSendPolls':
          permissions.canSendPolls = value;
          break;
        case 'canSendOtherMessages':
          permissions.canSendOtherMessages = value;
          break;
        case 'canAddLinkPreviews':
          permissions.canAddLinkPreviews = value;
          break;
        case 'canInviteUsers':
          permissions.canInviteUsers = value;
          break;
        case 'canPinMessages':
          permissions.canPinMessages = value;
          break;
        case 'canChangeInfo':
          permissions.canChangeInfo = value;
          break;
        case 'canCreateTopics':
          permissions.canCreateTopics = value;
          break;
        default:
          break;
      }
    }
    return permissions;
  }

  private durationLabel(): string {
    if (this.durationSeconds === 3600) {
      return localized($r('app.string.moderation_duration_1h').id, '1 hour');
    }
    if (this.durationSeconds === 86400) {
      return localized($r('app.string.moderation_duration_1d').id, '1 day');
    }
    if (this.durationSeconds === 7 * 86400) {
      return localized($r('app.string.moderation_duration_1w').id, '1 week');
    }
    return localized($r('app.string.moderation_duration_forever').id, 'Forever');
  }

  private chooseDuration(): void {
    const normal: Resource = TgUiTokens.CHAT_TOP_BAR_ACTION_FOREGROUND;
    const destructive: Resource = TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE;
    const d0: promptAction.Button = { text: localized($r('app.string.moderation_duration_1h').id,
      '1 hour'), color: normal };
    const d1: promptAction.Button = { text: localized($r('app.string.moderation_duration_1d').id,
      '1 day'), color: normal };
    const d2: promptAction.Button = { text: localized($r('app.string.moderation_duration_1w').id,
      '1 week'), color: normal };
    const d3: promptAction.Button = { text: localized($r('app.string.moderation_duration_forever').id,
      'Forever'), color: destructive };
    this.getUIContext().getPromptAction().showActionMenu({
      title: localized($r('app.string.moderation_duration_title').id, 'Duration'),
      buttons: [d0, d1, d2, d3]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (result.index >= 0 && result.index < MODERATION_DURATION_SECONDS.length) {
        this.durationSeconds = MODERATION_DURATION_SECONDS[result.index];
      }
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'Duration menu failed: %{public}s', error.message);
    });
  }

  private save(): void {
    const useCase = this.useCase;
    if (useCase === undefined || this.isSaving || this.chatId <= 0 || this.userId <= 0) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isSaving = true;
    this.errorText = '';
    const untilDate: number = moderationUntilDate(Math.floor(Date.now() / 1000),
      this.durationSeconds);
    useCase.apply(this.chatId, this.userId, 'restrict', untilDate,
      undefined, chatPermissionsToJson(this.buildPermissions()))
      .then(() => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isSaving = false;
        this.getUIContext().getPromptAction().showToast({
          message: localized($r('app.string.restrict_rights_saved').id, 'Member restricted'),
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
          ? error.message : localized($r('app.string.restrict_rights_failed').id,
            'Could not restrict the member');
      });
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        List() {
          ListItem() {
            Row() {
              Text(localized($r('app.string.restrict_rights_duration').id, 'Duration'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                .layoutWeight(1)
              Text(this.durationLabel())
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_META)
            }
            .width('100%')
            .height(48)
            .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
            .onClick(() => {
              this.chooseDuration();
            })
          }

          ForEach(RESTRICT_PERMISSION_ROWS, (row: RestrictPermissionRow, index: number) => {
            ListItem() {
              RestrictPermissionToggleRow({
                title: localized(row.titleRes.id, row.fallback),
                value: index < this.allowed.length ? this.allowed[index] : false,
                onToggle: (): void => {
                  this.toggle(index);
                }
              })
            }
          }, (row: RestrictPermissionRow) => row.key)

          ListItem() {
            Column() {
              Button(localized($r('app.string.restrict_rights_save').id, 'Restrict'))
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
          title: localized($r('app.string.restrict_rights_title').id, 'Restrict Member'),
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
