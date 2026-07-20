import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { CreatePrivateChatUseCase, createPrivateChatUseCase } from '../../../domain/usecases/createPrivateChat';
import { ImportContactResult, ImportContactUseCase, importContactUseCase } from '../../../domain/usecases/importContact';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { TgForwardPickerNavigationBar } from '../../tg_ui/atoms/TgForwardPickerNavigationBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import {
  isValidComposeContact,
  normalizeComposePhoneNumber
} from './ComposeCreationModel';
import { ComposeCreationResult } from './ComposeCreationRouteTypes';

const DOMAIN = 0x0044;
const TAG = 'TgNewContactPage';

@ComponentV2
export struct TgNewContactPage {
  private static readonly FIRST_NAME_INPUT_ID: string = 'compose_new_contact_first_name';

  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private firstName: string = '';
  @Local private lastName: string = '';
  @Local private phoneNumber: string = '';
  @Local private errorText: string = '';
  @Local private isCreating: boolean = false;

  private importContact?: ImportContactUseCase;
  private openPrivateChat?: CreatePrivateChatUseCase;
  private pendingCreationResult?: ComposeCreationResult;
  private importedRegisteredUserId: number = 0;
  private pageLifecycleToken: number = 0;
  private isClosing: boolean = false;

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    this.isClosing = false;
    this.isCreating = false;
    this.errorText = '';
    try {
      const gateway = getTdGatewayAdapter();
      this.importContact = importContactUseCase(gateway);
      this.openPrivateChat = createPrivateChatUseCase(gateway);
    } catch (error) {
      this.importContact = undefined;
      this.openPrivateChat = undefined;
      this.errorText = localized($r('app.string.action_failed').id, 'Action failed');
      hilog.error(DOMAIN, TAG, 'Contact use case init failed: %{public}s', String(error));
    }
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.isCreating = false;
  }

  private canSubmit(): boolean {
    if (this.pendingCreationResult !== undefined) {
      return !this.isClosing;
    }
    return this.importContact !== undefined && this.openPrivateChat !== undefined &&
      !this.isCreating && !this.isClosing &&
      isValidComposeContact(this.firstName, this.lastName, this.phoneNumber);
  }

  private handleInputChange(): void {
    this.errorText = '';
    this.importedRegisteredUserId = 0;
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
      hilog.error(DOMAIN, TAG, 'New contact result pop failed: %{public}s', String(error));
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
      hilog.error(DOMAIN, TAG, 'New contact cancel failed: %{public}s', String(error));
    }
  }

  private handleDonePress(): void {
    if (this.pendingCreationResult !== undefined) {
      this.handoffPendingCreation();
      return;
    }
    if (!this.canSubmit() || this.importContact === undefined || this.openPrivateChat === undefined) {
      return;
    }
    const lifecycleToken: number = this.pageLifecycleToken;
    const firstName: string = this.firstName.trim();
    const lastName: string = this.lastName.trim();
    const phoneNumber: string = normalizeComposePhoneNumber(this.phoneNumber);
    const chatTitle: string = (firstName + ' ' + lastName).trim();
    const openPrivateChat: CreatePrivateChatUseCase = this.openPrivateChat;
    this.isCreating = true;
    this.errorText = '';
    const importOrReuse: Promise<ImportContactResult> = this.importedRegisteredUserId > 0
      ? Promise.resolve(new ImportContactResult(this.importedRegisteredUserId, 0))
      : this.importContact.execute(phoneNumber, firstName, lastName);
    importOrReuse
      .then((result: ImportContactResult): Promise<number> => {
        if (lifecycleToken !== this.pageLifecycleToken || this.isClosing) {
          return Promise.resolve(0);
        }
        if (!result.isRegistered()) {
          return Promise.resolve(0);
        }
        this.importedRegisteredUserId = result.userId;
        return openPrivateChat.execute(result.userId).then((chat): number => chat.id);
      })
      .then((chatId: number): void => {
        if (lifecycleToken !== this.pageLifecycleToken || this.isClosing) {
          return;
        }
        this.isCreating = false;
        if (chatId <= 0) {
          this.pendingCreationResult = new ComposeCreationResult(0, chatTitle, 0, true);
          this.handoffPendingCreation();
          return;
        }
        this.pendingCreationResult = new ComposeCreationResult(chatId, chatTitle);
        this.handoffPendingCreation();
      })
      .catch((error: Error): void => {
        if (lifecycleToken !== this.pageLifecycleToken || this.isClosing) {
          return;
        }
        this.isCreating = false;
        this.errorText = localized($r('app.string.action_failed').id, 'Action failed');
        hilog.error(DOMAIN, TAG, 'Contact import failed: %{public}s', error.message);
      });
  }

  private focusFirstName(): void {
    try {
      this.getUIContext().getFocusController().requestFocus(TgNewContactPage.FIRST_NAME_INPUT_ID);
    } catch (_error) {
    }
  }

  @Builder
  private buildNameFields() {
    Column() {
      TextInput({
        text: this.firstName,
        placeholder: localized($r('app.string.profile_first_name').id, 'First Name')
      })
        .id(TgNewContactPage.FIRST_NAME_INPUT_ID)
        .width('100%')
        .height(TgUiTokens.COMPOSE_CREATION_FIELD_HEIGHT)
        .fontSize(TgUiTokens.COMPOSE_CREATION_FIELD_TEXT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .placeholderColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .backgroundColor(Color.Transparent)
        .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12 })
        .maxLength(64)
        .onChange((value: string): void => {
          this.firstName = value;
          this.handleInputChange();
        })

      Divider()
        .strokeWidth(TgUiTokens.CONTACT_ROW_SEPARATOR_STROKE)
        .color(TgUiTokens.COLOR_SEPARATOR)
        .margin({ left: TgUiTokens.SPACE_12 })

      TextInput({
        text: this.lastName,
        placeholder: localized($r('app.string.profile_last_name').id, 'Last Name')
      })
        .width('100%')
        .height(TgUiTokens.COMPOSE_CREATION_FIELD_HEIGHT)
        .fontSize(TgUiTokens.COMPOSE_CREATION_FIELD_TEXT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .placeholderColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .backgroundColor(Color.Transparent)
        .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12 })
        .maxLength(64)
        .onChange((value: string): void => {
          this.lastName = value;
          this.handleInputChange();
        })
    }
    .width('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
    .borderRadius(TgUiTokens.COMPOSE_CREATION_FIELD_RADIUS)
    .clip(true)
  }

  @Builder
  private buildPhoneField() {
    TextInput({
      text: this.phoneNumber,
      placeholder: localized($r('app.string.phone_placeholder').id, 'Phone number')
    })
      .width('100%')
      .height(TgUiTokens.COMPOSE_CREATION_FIELD_HEIGHT)
      .fontSize(TgUiTokens.COMPOSE_CREATION_FIELD_TEXT_SIZE)
      .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
      .placeholderColor(TgUiTokens.COLOR_TEXT_PREVIEW)
      .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
      .borderRadius(TgUiTokens.COMPOSE_CREATION_FIELD_RADIUS)
      .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12 })
      .type(InputType.PhoneNumber)
      .maxLength(24)
      .onChange((value: string): void => {
        this.phoneNumber = value;
        this.handleInputChange();
      })
      .onSubmit((): void => this.handleDonePress())
  }

  build() {
    NavDestination() {
      Column() {
        TgForwardPickerNavigationBar({
          title: localized($r('app.string.new_contact').id, 'New Contact'),
          backAccessibilityText: localized($r('app.string.accessibility_back').id, 'Back'),
          trailingTitle: localized($r('app.string.done').id, 'Done'),
          trailingAccessibilityText: localized($r('app.string.done').id, 'Done'),
          trailingEnabled: this.canSubmit(),
          onBackPress: (): void => this.handleBackPress(),
          onTrailingPress: (): void => this.handleDonePress()
        })

        Scroll() {
          Column() {
            this.buildNameFields()
            Column() {
              this.buildPhoneField()
            }
            .margin({ top: TgUiTokens.COMPOSE_CREATION_SECTION_GAP })

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
        .layoutWeight(1)
        .align(Alignment.TopStart)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      .onAppear((): void => this.focusFirstName())
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
export function TgNewContactPageBuilder() {
  TgNewContactPage()
}
