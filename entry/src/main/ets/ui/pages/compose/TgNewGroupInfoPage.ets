import { fileUri } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState, UserStatusType } from '../../../core/model/AppState';
import { localized } from '../../../core/utils/AppResource';
import {
  CreateBasicGroupChatResult,
  CreateBasicGroupChatUseCase,
  createBasicGroupChatUseCase
} from '../../../domain/usecases/createBasicGroupChat';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { TgContactRow } from '../../tg_ui/atoms/TgContactRow';
import { TgForwardPickerNavigationBar } from '../../tg_ui/atoms/TgForwardPickerNavigationBar';
import { TgIcon } from '../../tg_ui/atoms/TgIcon';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { ComposeContactVO, buildComposeContacts } from './ComposeContactModel';
import { isValidComposeChatTitle } from './ComposeCreationModel';
import { ComposeCreationResult, NewGroupInfoRouteParams } from './ComposeCreationRouteTypes';

const DOMAIN = 0x0044;
const TAG = 'TgNewGroupInfoPage';

@ComponentV2
export struct TgNewGroupInfoPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private userIds: number[] = [];
  @Local private selectedContacts: ComposeContactVO[] = [];
  @Local private title: string = '';
  @Local private errorText: string = '';
  @Local private isCreating: boolean = false;

  private createGroupUseCase?: CreateBasicGroupChatUseCase;
  private pendingCreationResult?: ComposeCreationResult;
  private pageLifecycleToken: number = 0;
  private isClosing: boolean = false;

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    this.isClosing = false;
    this.isCreating = false;
    this.errorText = '';
    try {
      this.createGroupUseCase = createBasicGroupChatUseCase(getTdGatewayAdapter());
    } catch (error) {
      this.createGroupUseCase = undefined;
      this.errorText = localized($r('app.string.action_failed').id, 'Action failed');
      hilog.error(DOMAIN, TAG, 'Group use case init failed: %{public}s', String(error));
    }
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.isCreating = false;
  }

  private rebuildSelectedContacts(): void {
    try {
      const state: AppState = getAppCoreRuntime().getStore().getState();
      const selected: Set<number> = new Set<number>(this.userIds);
      this.selectedContacts = buildComposeContacts(state).filter(
        (contact: ComposeContactVO): boolean => selected.has(contact.userId)
      );
    } catch (_error) {
      this.selectedContacts = [];
    }
  }

  private canCreate(): boolean {
    if (this.pendingCreationResult !== undefined) {
      return !this.isClosing;
    }
    return this.createGroupUseCase !== undefined && !this.isCreating && !this.isClosing &&
      isValidComposeChatTitle(this.title);
  }

  private handoffPendingCreation(): void {
    const result: ComposeCreationResult | undefined = this.pendingCreationResult;
    if (result === undefined || this.isClosing) {
      return;
    }
    this.isClosing = true;
    try {
      this.pageStack.pop(result);
      this.pendingCreationResult = undefined;
    } catch (error) {
      this.isClosing = false;
      this.errorText = localized($r('app.string.action_failed').id, 'Action failed');
      hilog.error(DOMAIN, TAG, 'Group result pop failed: %{public}s', String(error));
    }
  }

  private handleBackPress(): void {
    if (this.pendingCreationResult !== undefined) {
      this.handoffPendingCreation();
      return;
    }
    if (this.isClosing || this.isCreating) {
      return;
    }
    this.isClosing = true;
    try {
      this.pageStack.pop(new ComposeCreationResult());
    } catch (error) {
      this.isClosing = false;
      hilog.error(DOMAIN, TAG, 'Group info cancel failed: %{public}s', String(error));
    }
  }

  private handleCreatePress(): void {
    if (this.pendingCreationResult !== undefined) {
      this.handoffPendingCreation();
      return;
    }
    if (!this.canCreate() || this.createGroupUseCase === undefined) {
      return;
    }
    const lifecycleToken: number = this.pageLifecycleToken;
    const title: string = this.title.trim();
    this.isCreating = true;
    this.errorText = '';
    this.createGroupUseCase.execute(this.userIds, title)
      .then((result: CreateBasicGroupChatResult): void => {
        if (lifecycleToken !== this.pageLifecycleToken || this.isClosing) {
          return;
        }
        this.isCreating = false;
        if (result.failedMembers.length > 0) {
          hilog.warn(DOMAIN, TAG, 'Group created with %{public}d partial member failures',
            result.failedMembers.length);
        }
        if (!result.isHydrated) {
          hilog.warn(DOMAIN, TAG, 'Group was created but returned through committed identity fallback');
        }
        this.isClosing = false;
        this.pendingCreationResult = new ComposeCreationResult(
          result.chat.id,
          result.chat.title || title,
          result.failedMembers.length
        );
        this.handoffPendingCreation();
      })
      .catch((error: Error): void => {
        if (lifecycleToken !== this.pageLifecycleToken || this.isClosing) {
          return;
        }
        this.isCreating = false;
        this.errorText = localized($r('app.string.action_failed').id, 'Action failed');
        hilog.error(DOMAIN, TAG, 'Group creation failed: %{public}s', error.message);
      });
  }

  private formatUserStatus(status: UserStatusType): string {
    return status === 'online'
      ? localized($r('app.string.online').id, 'online')
      : localized($r('app.string.offline').id, 'offline');
  }

  private avatarUri(path: string): string {
    if (path.length === 0) {
      return '';
    }
    try {
      return fileUri.getUriFromPath(path);
    } catch (_error) {
      return '';
    }
  }

  private selectedCountText(): string {
    return localized($r('app.string.selected_count').id, '%d selected')
      .replace('%d', this.userIds.length.toString());
  }

  @Builder
  private buildGroupIdentity() {
    Row() {
      Row() {
        TgIcon({
          src: TgUiTokens.ICON_RES_GROUP,
          iconSize: TgUiTokens.COMPOSE_CREATION_AVATAR_ICON_SIZE,
          tintColor: TgUiTokens.COLOR_UNREAD_TEXT
        })
      }
      .width(TgUiTokens.COMPOSE_CREATION_AVATAR_SIZE)
      .height(TgUiTokens.COMPOSE_CREATION_AVATAR_SIZE)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(TgUiTokens.COLOR_ICON_PRIMARY)
      .borderRadius(TgUiTokens.COMPOSE_CREATION_AVATAR_SIZE / 2)

      Column() {
        TextInput({
          text: this.title,
          placeholder: localized($r('app.string.group_name').id, 'Group Name')
        })
          .width('100%')
          .height(TgUiTokens.COMPOSE_CREATION_FIELD_HEIGHT)
          .fontSize(TgUiTokens.COMPOSE_CREATION_FIELD_TEXT_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .placeholderColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
          .borderRadius(TgUiTokens.COMPOSE_CREATION_FIELD_RADIUS)
          .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12 })
          .maxLength(128)
          .onChange((value: string): void => {
            this.title = value;
            this.errorText = '';
          })
          .onSubmit((): void => this.handleCreatePress())

        Text(this.selectedCountText())
          .fontSize(TgUiTokens.COMPOSE_CREATION_HELP_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .margin({ top: TgUiTokens.SPACE_4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: TgUiTokens.COMPOSE_CREATION_AVATAR_GAP })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildSelectedMembers() {
    if (this.selectedContacts.length > 0) {
      Column() {
        Text(localized($r('app.string.members_label').id, 'Members'))
          .width('100%')
          .fontSize(TgUiTokens.COMPOSE_CREATION_HELP_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .margin({ bottom: TgUiTokens.SPACE_4 })

        ForEach(this.selectedContacts, (contact: ComposeContactVO, index?: number) => {
          TgContactRow({
            name: contact.name,
            initials: contact.initials,
            statusText: this.formatUserStatus(contact.status),
            avatarPath: this.avatarUri(contact.avatarPath),
            isOnline: contact.isOnline,
            showSeparator: (index ?? 0) < this.selectedContacts.length - 1,
            rowHeight: TgUiTokens.COMPOSE_CONTACT_ROW_HEIGHT,
            contentGap: TgUiTokens.COMPOSE_CONTACT_ROW_GAP,
            statusFontSize: TgUiTokens.COMPOSE_CONTACT_STATUS_SIZE,
            separatorInset: TgUiTokens.COMPOSE_CONTACT_SEPARATOR_INSET
          })
        }, (contact: ComposeContactVO): string => 'new-group-info-' + contact.userId.toString())
      }
      .width('100%')
      .margin({ top: TgUiTokens.COMPOSE_CREATION_SECTION_GAP })
    }
  }

  build() {
    NavDestination() {
      Column() {
        TgForwardPickerNavigationBar({
          title: localized($r('app.string.new_group').id, 'New Group'),
          backAccessibilityText: localized($r('app.string.accessibility_back').id, 'Back'),
          trailingTitle: localized($r('app.string.create').id, 'Create'),
          trailingAccessibilityText: localized($r('app.string.create').id, 'Create'),
          trailingEnabled: this.canCreate(),
          onBackPress: (): void => this.handleBackPress(),
          onTrailingPress: (): void => this.handleCreatePress()
        })

        Scroll() {
          Column() {
            this.buildGroupIdentity()
            this.buildSelectedMembers()

            if (this.errorText.length > 0) {
              Text(this.errorText)
                .width('100%')
                .fontSize(TgUiTokens.COMPOSE_CREATION_HELP_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_ERROR)
                .margin({ top: TgUiTokens.COMPOSE_CREATION_SECTION_GAP })
            }

            if (this.isCreating) {
              LoadingProgress()
                .width(TgUiTokens.COMPOSE_CREATION_PROGRESS_SIZE)
                .height(TgUiTokens.COMPOSE_CREATION_PROGRESS_SIZE)
                .color(TgUiTokens.COLOR_ICON_PRIMARY)
                .margin({ top: TgUiTokens.COMPOSE_CREATION_SECTION_GAP })
            }
          }
          .width('100%')
          .padding({
            left: TgUiTokens.COMPOSE_CREATION_SIDE_INSET,
            right: TgUiTokens.COMPOSE_CREATION_SIDE_INSET,
            top: TgUiTokens.COMPOSE_CREATION_TOP_GAP,
            bottom: TgUiTokens.SPACE_24
          })
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.TopStart)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .hideToolBar(true)
    .onReady((context: NavDestinationContext): void => {
      this.pageStack = context.pathStack;
      const params = context.pathInfo.param as NewGroupInfoRouteParams;
      this.userIds = params?.userIds?.slice() ?? [];
      this.rebuildSelectedContacts();
    })
    .onBackPressed((): boolean => {
      this.handleBackPress();
      return true;
    })
  }
}

@Builder
export function TgNewGroupInfoPageBuilder() {
  TgNewGroupInfoPage()
}
