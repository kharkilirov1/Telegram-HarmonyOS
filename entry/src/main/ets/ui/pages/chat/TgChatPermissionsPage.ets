// TgChatPermissionsPage — edit the chat's default participant permissions (S12j).
// iOS counterpart: ChatPermissionsController. Every toggle rewrites the whole chatPermissions object,
// so fields the screen does not show are preserved.

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { ChatPermissionKey, ChatPermissionsDto } from '../../../core/model/dto/ChatPermissionsDto';
import {
  ChatPermissionsUseCase,
  createChatPermissionsUseCase
} from '../../../domain/usecases/chatPermissions';
import { ChatPermissionsRouteParams } from './chatPermissionsRoute';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x0045;
const TAG = 'TgChatPermissionsPage';

@Builder
export function TgChatPermissionsPageBuilder() {
  TgChatPermissionsPage();
}

@ComponentV2
export struct TgChatPermissionsPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private chatId: number = 0;
  @Local private permissions: ChatPermissionsDto = new ChatPermissionsDto();
  @Local private isLoading: boolean = true;
  @Local private isSaving: boolean = false;
  @Local private errorText: string = '';
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  private useCase?: ChatPermissionsUseCase;
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
      this.useCase = createChatPermissionsUseCase(getTdGatewayAdapter());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Use case init failed: %{public}s', String(error));
      this.useCase = undefined;
    }
    const params = this.pageStack.getParamByName('TgChatPermissionsPage') as Object[];
    if (params.length > 0) {
      const routeParams = params[0] as ChatPermissionsRouteParams;
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
      this.errorText = localized($r('app.string.permissions_failed').id, 'Could not load permissions');
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isLoading = true;
    this.errorText = '';
    useCase.load(this.chatId)
      .then((permissions: ChatPermissionsDto) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isLoading = false;
        this.permissions = permissions;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isLoading = false;
        this.errorText = error.message.length > 0
          ? error.message : localized($r('app.string.permissions_failed').id,
            'Could not load permissions');
      });
  }

  private permissionValue(key: ChatPermissionKey): boolean {
    const permissions = this.permissions;
    if (key === 'canSendBasicMessages') {
      return permissions.canSendBasicMessages;
    }
    if (key === 'canSendAudios') {
      return permissions.canSendAudios;
    }
    if (key === 'canSendDocuments') {
      return permissions.canSendDocuments;
    }
    if (key === 'canSendPhotos') {
      return permissions.canSendPhotos;
    }
    if (key === 'canSendVideos') {
      return permissions.canSendVideos;
    }
    if (key === 'canSendVideoNotes') {
      return permissions.canSendVideoNotes;
    }
    if (key === 'canSendVoiceNotes') {
      return permissions.canSendVoiceNotes;
    }
    if (key === 'canSendPolls') {
      return permissions.canSendPolls;
    }
    if (key === 'canSendOtherMessages') {
      return permissions.canSendOtherMessages;
    }
    if (key === 'canAddLinkPreviews') {
      return permissions.canAddLinkPreviews;
    }
    if (key === 'canChangeInfo') {
      return permissions.canChangeInfo;
    }
    if (key === 'canInviteUsers') {
      return permissions.canInviteUsers;
    }
    if (key === 'canPinMessages') {
      return permissions.canPinMessages;
    }
    return permissions.canCreateTopics;
  }

  private toggle(key: ChatPermissionKey): void {
    if (this.isSaving) {
      return;
    }
    const next = this.permissions.clone();
    const value = !this.permissionValue(key);
    if (key === 'canSendBasicMessages') {
      next.canSendBasicMessages = value;
    } else if (key === 'canSendAudios') {
      next.canSendAudios = value;
    } else if (key === 'canSendDocuments') {
      next.canSendDocuments = value;
    } else if (key === 'canSendPhotos') {
      next.canSendPhotos = value;
    } else if (key === 'canSendVideos') {
      next.canSendVideos = value;
    } else if (key === 'canSendVideoNotes') {
      next.canSendVideoNotes = value;
    } else if (key === 'canSendVoiceNotes') {
      next.canSendVoiceNotes = value;
    } else if (key === 'canSendPolls') {
      next.canSendPolls = value;
    } else if (key === 'canSendOtherMessages') {
      next.canSendOtherMessages = value;
    } else if (key === 'canAddLinkPreviews') {
      next.canAddLinkPreviews = value;
    } else if (key === 'canChangeInfo') {
      next.canChangeInfo = value;
    } else if (key === 'canInviteUsers') {
      next.canInviteUsers = value;
    } else if (key === 'canPinMessages') {
      next.canPinMessages = value;
    } else {
      next.canCreateTopics = value;
    }
    const previous = this.permissions;
    this.permissions = next;
    this.save(next, previous);
  }

  private save(next: ChatPermissionsDto, previous: ChatPermissionsDto): void {
    const useCase = this.useCase;
    if (useCase === undefined) {
      this.permissions = previous;
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isSaving = true;
    this.errorText = '';
    useCase.save(this.chatId, next)
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
        // A rejected write must not leave the toggle showing a value TDLib never accepted.
        this.permissions = previous;
        this.errorText = error.message.length > 0
          ? error.message : localized($r('app.string.permissions_save_failed').id,
            'Could not save permissions');
      });
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        List() {
          ListItem() {
            PermissionToggleRow({
              title: localized($r('app.string.permissions_send_messages').id, 'Send Messages'),
              value: this.permissionValue('canSendBasicMessages'),
              isEnabled: !this.isSaving && !this.isLoading,
              onToggle: (): void => {
                this.toggle('canSendBasicMessages');
              }
            })
          }
          ListItem() {
            PermissionToggleRow({
              title: localized($r('app.string.permissions_send_audios').id, 'Send Audio Files'),
              value: this.permissionValue('canSendAudios'),
              isEnabled: !this.isSaving && !this.isLoading,
              onToggle: (): void => {
                this.toggle('canSendAudios');
              }
            })
          }
          ListItem() {
            PermissionToggleRow({
              title: localized($r('app.string.permissions_send_documents').id, 'Send Documents'),
              value: this.permissionValue('canSendDocuments'),
              isEnabled: !this.isSaving && !this.isLoading,
              onToggle: (): void => {
                this.toggle('canSendDocuments');
              }
            })
          }
          ListItem() {
            PermissionToggleRow({
              title: localized($r('app.string.permissions_send_photos').id, 'Send Photos'),
              value: this.permissionValue('canSendPhotos'),
              isEnabled: !this.isSaving && !this.isLoading,
              onToggle: (): void => {
                this.toggle('canSendPhotos');
              }
            })
          }
          ListItem() {
            PermissionToggleRow({
              title: localized($r('app.string.permissions_send_videos').id, 'Send Videos'),
              value: this.permissionValue('canSendVideos'),
              isEnabled: !this.isSaving && !this.isLoading,
              onToggle: (): void => {
                this.toggle('canSendVideos');
              }
            })
          }
          ListItem() {
            PermissionToggleRow({
              title: localized($r('app.string.permissions_send_video_notes').id, 'Send Video Messages'),
              value: this.permissionValue('canSendVideoNotes'),
              isEnabled: !this.isSaving && !this.isLoading,
              onToggle: (): void => {
                this.toggle('canSendVideoNotes');
              }
            })
          }
          ListItem() {
            PermissionToggleRow({
              title: localized($r('app.string.permissions_send_voice_notes').id, 'Send Voice Messages'),
              value: this.permissionValue('canSendVoiceNotes'),
              isEnabled: !this.isSaving && !this.isLoading,
              onToggle: (): void => {
                this.toggle('canSendVoiceNotes');
              }
            })
          }
          ListItem() {
            PermissionToggleRow({
              title: localized($r('app.string.permissions_send_polls').id, 'Send Polls'),
              value: this.permissionValue('canSendPolls'),
              isEnabled: !this.isSaving && !this.isLoading,
              onToggle: (): void => {
                this.toggle('canSendPolls');
              }
            })
          }
          ListItem() {
            PermissionToggleRow({
              title: localized($r('app.string.permissions_send_other').id, 'Send Stickers and GIFs'),
              value: this.permissionValue('canSendOtherMessages'),
              isEnabled: !this.isSaving && !this.isLoading,
              onToggle: (): void => {
                this.toggle('canSendOtherMessages');
              }
            })
          }
          ListItem() {
            PermissionToggleRow({
              title: localized($r('app.string.permissions_link_previews').id, 'Embed Link Previews'),
              value: this.permissionValue('canAddLinkPreviews'),
              isEnabled: !this.isSaving && !this.isLoading,
              onToggle: (): void => {
                this.toggle('canAddLinkPreviews');
              }
            })
          }
          ListItem() {
            PermissionToggleRow({
              title: localized($r('app.string.permissions_change_info').id, 'Change Chat Info'),
              value: this.permissionValue('canChangeInfo'),
              isEnabled: !this.isSaving && !this.isLoading,
              onToggle: (): void => {
                this.toggle('canChangeInfo');
              }
            })
          }
          ListItem() {
            PermissionToggleRow({
              title: localized($r('app.string.permissions_invite_users').id, 'Invite Users'),
              value: this.permissionValue('canInviteUsers'),
              isEnabled: !this.isSaving && !this.isLoading,
              onToggle: (): void => {
                this.toggle('canInviteUsers');
              }
            })
          }
          ListItem() {
            PermissionToggleRow({
              title: localized($r('app.string.permissions_pin_messages').id, 'Pin Messages'),
              value: this.permissionValue('canPinMessages'),
              isEnabled: !this.isSaving && !this.isLoading,
              onToggle: (): void => {
                this.toggle('canPinMessages');
              }
            })
          }
          ListItem() {
            PermissionToggleRow({
              title: localized($r('app.string.permissions_create_topics').id, 'Create Topics'),
              value: this.permissionValue('canCreateTopics'),
              isEnabled: !this.isSaving && !this.isLoading,
              onToggle: (): void => {
                this.toggle('canCreateTopics');
              }
            })
          }

          if (this.isLoading) {
            ListItem() {
              Text(localized($r('app.string.permissions_loading').id, 'Loading permissions…'))
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
          title: localized($r('app.string.permissions_title').id, 'Permissions'),
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

@ComponentV2
struct PermissionToggleRow {
  @Param title: string = '';
  @Param value: boolean = false;
  @Param isEnabled: boolean = true;
  @Event onToggle: () => void = (): void => {};

  build() {
    Row() {
      Text(this.title)
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.value })
        .enabled(this.isEnabled)
        .onChange((_isOn: boolean) => {
          this.onToggle();
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
  }
}
