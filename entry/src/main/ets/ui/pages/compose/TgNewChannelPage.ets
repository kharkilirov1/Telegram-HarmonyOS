import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatDto } from '../../../core/model/dto/ChatDto';
import { localized } from '../../../core/utils/AppResource';
import {
  CreateChannelChatUseCase,
  createChannelChatUseCase
} from '../../../domain/usecases/createChannelChat';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { TgForwardPickerNavigationBar } from '../../tg_ui/atoms/TgForwardPickerNavigationBar';
import { TgIcon } from '../../tg_ui/atoms/TgIcon';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import {
  isValidComposeChannelDescription,
  isValidComposeChatTitle
} from './ComposeCreationModel';
import { ComposeCreationResult } from './ComposeCreationRouteTypes';

const DOMAIN = 0x0044;
const TAG = 'TgNewChannelPage';

function channelStepTransition(): TransitionEffect {
  const enter: TransitionEffect = TransitionEffect.OPACITY
    .animation({ duration: TgUiTokens.COMPOSE_CREATION_TRANSITION_MS, curve: Curve.EaseOut })
    .combine(TransitionEffect.translate({ x: TgUiTokens.COMPOSE_CREATION_TRANSITION_OFFSET })
      .animation({ duration: TgUiTokens.COMPOSE_CREATION_TRANSITION_MS, curve: Curve.Smooth }));
  const exit: TransitionEffect = TransitionEffect.OPACITY
    .animation({ duration: TgUiTokens.COMPOSE_CREATION_TRANSITION_MS, curve: Curve.EaseIn })
    .combine(TransitionEffect.translate({ x: -TgUiTokens.COMPOSE_CREATION_TRANSITION_OFFSET })
      .animation({ duration: TgUiTokens.COMPOSE_CREATION_TRANSITION_MS, curve: Curve.Smooth }));
  return TransitionEffect.asymmetric(enter, exit);
}

@ComponentV2
export struct TgNewChannelPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private showIntro: boolean = true;
  @Local private title: string = '';
  @Local private description: string = '';
  @Local private errorText: string = '';
  @Local private isCreating: boolean = false;

  private createChannel?: CreateChannelChatUseCase;
  private pendingCreationResult?: ComposeCreationResult;
  private pageLifecycleToken: number = 0;
  private isClosing: boolean = false;

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    this.showIntro = true;
    this.isCreating = false;
    this.isClosing = false;
    this.errorText = '';
    try {
      this.createChannel = createChannelChatUseCase(getTdGatewayAdapter());
    } catch (error) {
      this.createChannel = undefined;
      this.errorText = localized($r('app.string.action_failed').id, 'Action failed');
      hilog.error(DOMAIN, TAG, 'Channel use case init failed: %{public}s', String(error));
    }
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.isCreating = false;
  }

  private canCreate(): boolean {
    if (this.pendingCreationResult !== undefined) {
      return !this.isClosing;
    }
    return this.createChannel !== undefined && !this.showIntro && !this.isCreating && !this.isClosing &&
      isValidComposeChatTitle(this.title) && isValidComposeChannelDescription(this.description);
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
      hilog.error(DOMAIN, TAG, 'Channel result pop failed: %{public}s', String(error));
    }
  }

  private setIntroVisible(visible: boolean): void {
    this.getUIContext().animateTo({
      duration: TgUiTokens.COMPOSE_CREATION_TRANSITION_MS,
      curve: Curve.Friction
    }, (): void => {
      this.showIntro = visible;
    });
  }

  private handleBackPress(): void {
    if (this.pendingCreationResult !== undefined) {
      this.handoffPendingCreation();
      return;
    }
    if (this.isCreating || this.isClosing) {
      return;
    }
    this.isClosing = true;
    try {
      this.pageStack.pop(new ComposeCreationResult());
    } catch (error) {
      this.isClosing = false;
      hilog.error(DOMAIN, TAG, 'New channel cancel failed: %{public}s', String(error));
    }
  }

  private handleCreatePress(): void {
    if (this.pendingCreationResult !== undefined) {
      this.handoffPendingCreation();
      return;
    }
    if (!this.canCreate() || this.createChannel === undefined) {
      return;
    }
    const lifecycleToken: number = this.pageLifecycleToken;
    const title: string = this.title.trim();
    this.isCreating = true;
    this.errorText = '';
    this.createChannel.execute(title, this.description)
      .then((chat: ChatDto): void => {
        if (lifecycleToken !== this.pageLifecycleToken || this.isClosing) {
          return;
        }
        this.isCreating = false;
        this.pendingCreationResult = new ComposeCreationResult(chat.id, chat.title || title);
        this.handoffPendingCreation();
      })
      .catch((error: Error): void => {
        if (lifecycleToken !== this.pageLifecycleToken || this.isClosing) {
          return;
        }
        this.isCreating = false;
        this.errorText = localized($r('app.string.action_failed').id, 'Action failed');
        hilog.error(DOMAIN, TAG, 'Channel creation failed: %{public}s', error.message);
      });
  }

  @Builder
  private buildIntro() {
    Column() {
      Row() {
        TgIcon({
          src: TgUiTokens.ICON_RES_CHANNEL,
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

      Text(localized($r('app.string.channel_intro_title').id, 'What is a Channel?'))
        .fontSize(TgUiTokens.COMPOSE_CREATION_INTRO_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .textAlign(TextAlign.Center)
        .margin({ top: TgUiTokens.COMPOSE_CREATION_SECTION_GAP })

      Text(localized(
        $r('app.string.channel_intro_text').id,
        'Channels let you broadcast messages to a large audience.'
      ))
        .fontSize(TgUiTokens.COMPOSE_CREATION_INTRO_TEXT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .textAlign(TextAlign.Center)
        .margin({ top: TgUiTokens.SPACE_8 })

      Button(localized($r('app.string.channel_intro_create').id, 'Create Channel'))
        .width('100%')
        .height(TgUiTokens.COMPOSE_CREATION_PRIMARY_HEIGHT)
        .fontSize(TgUiTokens.COMPOSE_CREATION_PRIMARY_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.COLOR_UNREAD_TEXT)
        .backgroundColor(TgUiTokens.COLOR_ICON_PRIMARY)
        .borderRadius(TgUiTokens.COMPOSE_CREATION_PRIMARY_RADIUS)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
        .margin({ top: TgUiTokens.SPACE_24 })
        .onClick((): void => this.setIntroVisible(false))
    }
    .width('100%')
    .padding({
      left: TgUiTokens.COMPOSE_CREATION_SIDE_INSET,
      right: TgUiTokens.COMPOSE_CREATION_SIDE_INSET
    })
    .transition(channelStepTransition())
  }

  @Builder
  private buildChannelForm() {
    Scroll() {
      Column() {
        Row() {
          Row() {
            TgIcon({
              src: TgUiTokens.ICON_RES_CHANNEL,
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

          TextInput({
            text: this.title,
            placeholder: localized($r('app.string.channel_name').id, 'Channel Name')
          })
            .layoutWeight(1)
            .height(TgUiTokens.COMPOSE_CREATION_FIELD_HEIGHT)
            .fontSize(TgUiTokens.COMPOSE_CREATION_FIELD_TEXT_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .placeholderColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
            .borderRadius(TgUiTokens.COMPOSE_CREATION_FIELD_RADIUS)
            .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12 })
            .maxLength(128)
            .margin({ left: TgUiTokens.COMPOSE_CREATION_AVATAR_GAP })
            .onChange((value: string): void => {
              this.title = value;
              this.errorText = '';
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        TextArea({
          text: this.description,
          placeholder: localized($r('app.string.channel_description_optional').id, 'Description (optional)')
        })
          .width('100%')
          .height(TgUiTokens.COMPOSE_CREATION_TEXT_AREA_HEIGHT)
          .fontSize(TgUiTokens.COMPOSE_CREATION_FIELD_TEXT_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .placeholderColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
          .borderRadius(TgUiTokens.COMPOSE_CREATION_FIELD_RADIUS)
          .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12,
            top: TgUiTokens.SPACE_8, bottom: TgUiTokens.SPACE_8 })
          .maxLength(255)
          .margin({ top: TgUiTokens.COMPOSE_CREATION_SECTION_GAP })
          .onChange((value: string): void => {
            this.description = value;
            this.errorText = '';
          })

        Row() {
          TgIcon({
            src: TgUiTokens.ICON_RES_LOCK,
            iconSize: TgUiTokens.ICON_SIZE_SM,
            tintColor: TgUiTokens.COLOR_ICON_SECONDARY
          })
          Text(localized($r('app.string.private_channel').id, 'Private Channel'))
            .fontSize(TgUiTokens.COMPOSE_CREATION_HELP_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .margin({ left: TgUiTokens.SPACE_8 })
        }
        .width('100%')
        .margin({ top: TgUiTokens.SPACE_8 })
        .alignItems(VerticalAlign.Center)

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .width('100%')
            .fontSize(TgUiTokens.COMPOSE_CREATION_HELP_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_ERROR)
            .margin({ top: TgUiTokens.SPACE_8 })
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
    .height('100%')
    .align(Alignment.TopStart)
    .edgeEffect(EdgeEffect.Spring)
    .transition(channelStepTransition())
  }

  build() {
    NavDestination() {
      Column() {
        TgForwardPickerNavigationBar({
          title: localized($r('app.string.new_channel').id, 'New Channel'),
          backAccessibilityText: localized($r('app.string.accessibility_back').id, 'Back'),
          trailingTitle: this.showIntro ? '' : localized($r('app.string.create').id, 'Create'),
          trailingAccessibilityText: localized($r('app.string.create').id, 'Create'),
          trailingEnabled: this.canCreate(),
          onBackPress: (): void => this.handleBackPress(),
          onTrailingPress: (): void => this.handleCreatePress()
        })

        Stack({ alignContent: Alignment.Center }) {
          if (this.showIntro) {
            this.buildIntro()
          } else {
            this.buildChannelForm()
          }
        }
        .width('100%')
        .layoutWeight(1)
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
    })
    .onBackPressed((): boolean => {
      this.handleBackPress();
      return true;
    })
  }
}

@Builder
export function TgNewChannelPageBuilder() {
  TgNewChannelPage()
}
