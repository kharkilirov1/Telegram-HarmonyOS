// A5: edit the current user's profile — first/last name, username and bio.
// iOS counterpart: ProfileEditingController pushed from the own-profile screen.
// Data layer: EditProfileUseCase (setName/setBio/setUsername); this page only owns the form.

import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { AvatarImagePreparation, AvatarSourceSize } from './avatarImagePrep';
import {
  AvatarCropRect,
  clampAvatarZoom,
  computeAvatarCropRectFromTransform,
  isValidAvatarCropRect
} from '../../../domain/usecases/avatarCrop';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import {
  EditProfileUseCase,
  PROFILE_BIO_MAX_LENGTH,
  PROFILE_NAME_PART_MAX_LENGTH,
  PROFILE_USERNAME_MAX_LENGTH,
  PROFILE_USERNAME_MIN_LENGTH,
  createEditProfileUseCase,
  isUsernameTakenError,
  isValidProfileUsername,
  suggestProfileUsernameAlternatives
} from '../../../domain/usecases/editProfile';
import {
  CheckUsernameUseCase,
  UsernameAvailability,
  createCheckUsernameUseCase,
  usernameAvailabilityMessage
} from '../../../domain/usecases/checkUsername';
import { TgChatTopBar, TgChatTopBarTrailingAction } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x00A5;
const TAG = 'TgEditProfilePage';

export class EditProfileRouteParams {
  firstName: string = '';
  lastName: string = '';
  username: string = '';
  bio: string = '';

  constructor(firstName: string = '', lastName: string = '', username: string = '', bio: string = '') {
    this.firstName = firstName;
    this.lastName = lastName;
    this.username = username;
    this.bio = bio;
  }
}

@Builder
export function TgEditProfilePageBuilder() {
  TgEditProfilePage();
}

@ComponentV2
export struct TgEditProfilePage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private firstName: string = '';
  @Local private lastName: string = '';
  @Local private username: string = '';
  @Local private bio: string = '';
  @Local private saving: boolean = false;
  @Local private errorText: string = '';
  @Local private photoNotice: string = '';
  @Local private usernameTaken: boolean = false;
  @Local private usernameAvailability: UsernameAvailability = 'idle';
  @Local private usernameSuggestions: string[] = [];
  @Local private photoBusy: boolean = false;
  // A5: the picked photo is framed before upload (pinch to zoom, drag to pan).
  @Local private editorOpen: boolean = false;
  @Local private editorUri: string = '';
  @Local private editorWidth: number = 0;
  @Local private editorHeight: number = 0;
  @Local private editorZoom: number = 1;
  @Local private editorOffsetX: number = 0;
  @Local private editorOffsetY: number = 0;
  private pinchStartZoom: number = 1;
  private panStartX: number = 0;
  private panStartY: number = 0;
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  private useCase?: EditProfileUseCase;
  private checkUsernameUseCase?: CheckUsernameUseCase;
  private usernameCheckTimer: number = -1;
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
      this.useCase = createEditProfileUseCase(getTdGatewayAdapter());
    this.checkUsernameUseCase = createCheckUsernameUseCase(getTdGatewayAdapter());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Use case init failed: %{public}s', String(error));
      this.useCase = undefined;
    this.checkUsernameUseCase = undefined;
    this.cancelUsernameCheck();
    }
    const params = this.pageStack.getParamByName('TgEditProfilePage') as Object[];
    if (params.length > 0) {
      const routeParams = params[0] as EditProfileRouteParams;
      this.firstName = routeParams.firstName;
      this.lastName = routeParams.lastName;
      this.username = routeParams.username;
      this.bio = routeParams.bio;
    }
  }

  private canSave(): boolean {
    if (this.saving || this.useCase === undefined) {
      return false;
    }
    if (this.firstName.trim().length === 0) {
      return false;
    }
    const username = this.username.trim().replace(/^@/, '');
    return username.length === 0 || isValidProfileUsername(username);
  }

  // A5: pick one image, copy it into the sandbox, then hand the real path to setProfilePhoto.
  private pickProfilePhoto(): void {
    const useCase = this.useCase;
    if (useCase === undefined || this.photoBusy || this.saving) {
      return;
    }
    const picker = new photoAccessHelper.PhotoViewPicker();
    picker.select({
      MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1
    }).then((result: photoAccessHelper.PhotoSelectResult) => {
      const uris = result.photoUris;
      if (uris.length === 0) {
        return;
      }
      const sourceUri = uris[0];
      return AvatarImagePreparation.measure(sourceUri).then((size: AvatarSourceSize): void => {
        if (size.width <= 0 || size.height <= 0) {
          throw new Error('Could not read the selected photo');
        }
        this.editorUri = sourceUri;
        this.editorWidth = size.width;
        this.editorHeight = size.height;
        this.editorZoom = 1;
        this.editorOffsetX = 0;
        this.editorOffsetY = 0;
        this.editorOpen = true;
      });
    }).catch((error: Error) => {
      if (isUsernameTakenError(error)) {
        this.usernameTaken = true;
        this.usernameSuggestions = suggestProfileUsernameAlternatives(this.username);
        this.errorText = '';
        return;
      }
      this.errorText = error.message;
      hilog.warn(DOMAIN, TAG, 'Profile photo update failed: %{public}s', error.message);
    }).finally(() => {
      this.photoBusy = false;
    });
    this.photoBusy = true;
    this.photoNotice = '';
    this.errorText = '';
  }

  // A5: the picked image is cropped to a square and packed as JPEG before upload.
  private copyPickedPhoto(sourceUri: string): Promise<string> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      return AvatarImagePreparation.prepare(context, sourceUri);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Preparing the picked photo failed: %{public}s', String(error));
      return Promise.resolve('');
    }
  }

  // A5: the frame the user chose is exactly the crop that reaches TDLib.
  private commitEditorCrop(): void {
    const useCase = this.useCase;
    if (useCase === undefined || this.photoBusy || this.editorUri.length === 0) {
      return;
    }
    const rect = computeAvatarCropRectFromTransform(this.editorWidth, this.editorHeight,
      TgUiTokens.AVATAR_EDITOR_VIEWPORT_SIZE, this.editorZoom, this.editorOffsetX, this.editorOffsetY);
    if (!isValidAvatarCropRect(rect, this.editorWidth, this.editorHeight)) {
      this.errorText = localized($r('app.string.edit_profile_error').id, 'Could not update the profile');
      return;
    }
    const uri = this.editorUri;
    this.photoBusy = true;
    this.photoNotice = '';
    this.errorText = '';
    this.cropPickedPhoto(uri, rect).then((localPath: string): Promise<void> => {
      if (localPath.length === 0) {
        throw new Error('Could not prepare the selected photo');
      }
      return useCase.updatePhoto(localPath).then((): void => {
        this.photoNotice = localized($r('app.string.edit_profile_photo_updated').id, 'Profile photo updated');
        this.editorOpen = false;
        this.editorUri = '';
      });
    }).catch((error: Error) => {
      this.errorText = error.message;
    }).finally((): void => {
      this.photoBusy = false;
    });
  }

  private cancelEditor(): void {
    this.editorOpen = false;
    this.editorUri = '';
    this.editorZoom = 1;
    this.editorOffsetX = 0;
    this.editorOffsetY = 0;
  }

  private cropPickedPhoto(sourceUri: string, rect: AvatarCropRect): Promise<string> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      return AvatarImagePreparation.prepare(context, sourceUri, rect);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Preparing the cropped photo failed: %{public}s', String(error));
      return Promise.resolve('');
    }
  }

  // A5: check availability while typing, like iOS. Each keystroke cancels the previous check so a stale
  // answer cannot label the current username.
  private scheduleUsernameCheck(): void {
    this.cancelUsernameCheck();
    const useCase = this.checkUsernameUseCase;
    const selfUserId = getAppCoreRuntime().getStore().getState().auth.userId;
    const candidate = this.username.trim().replace(/^@/, '');
    if (useCase === undefined || selfUserId <= 0 || candidate.length === 0) {
      this.usernameAvailability = 'idle';
      return;
    }
    const token = this.pageLifecycleToken;
    const sequence = useCase.nextSequence();
    this.usernameAvailability = 'checking';
    this.usernameCheckTimer = setTimeout((): void => {
      this.usernameCheckTimer = -1;
      useCase.check(selfUserId, candidate).then((availability: UsernameAvailability) => {
        if (token !== this.pageLifecycleToken || !useCase.isCurrent(sequence)) {
          return;
        }
        this.usernameAvailability = availability;
      }).catch((): void => {
        if (token === this.pageLifecycleToken && useCase.isCurrent(sequence)) {
          this.usernameAvailability = 'unknown';
        }
      });
    }, 400);
  }

  private cancelUsernameCheck(): void {
    if (this.usernameCheckTimer >= 0) {
      clearTimeout(this.usernameCheckTimer);
      this.usernameCheckTimer = -1;
    }
  }

  private usernameAvailabilityText(): string {
    if (this.usernameAvailability === 'checking') {
      return localized($r('app.string.edit_profile_username_checking').id, 'Checking…');
    }
    return usernameAvailabilityMessage(this.usernameAvailability);
  }

  private usernameAvailabilityColor(): ResourceColor {
    if (this.usernameAvailability === 'available') {
      return TgUiTokens.MSG_LINK_INCOMING;
    }
    if (this.usernameAvailability === 'checking' || this.usernameAvailability === 'idle') {
      return TgUiTokens.COLOR_TEXT_PREVIEW;
    }
    return TgUiTokens.COLOR_TEXT_ERROR;
  }

  private applySuggestion(value: string): void {
    this.username = value;
    this.usernameTaken = false;
    this.usernameAvailability = 'idle';
    this.usernameSuggestions = [];
    this.errorText = '';
  }

  private save(): void {
    const useCase = this.useCase;
    if (!this.canSave() || useCase === undefined) {
      return;
    }
    const lifecycleToken = this.pageLifecycleToken;
    this.saving = true;
    this.errorText = '';
    const username = this.username.trim().replace(/^@/, '');
    // Order matters only for the inline error: a rejected name stops before the other calls.
    useCase.updateName(this.firstName, this.lastName)
      .then((): Promise<void> => useCase.updateUsername(username))
      .then((): Promise<void> => useCase.updateBio(this.bio))
      .then((): void => {
        if (lifecycleToken !== this.pageLifecycleToken) {
          return;
        }
        this.saving = false;
        this.pageStack.pop(true);
      })
      .catch((error: Error) => {
        if (lifecycleToken !== this.pageLifecycleToken) {
          return;
        }
        this.saving = false;
        this.errorText = error.message;
        hilog.warn(DOMAIN, TAG, 'Profile update failed: %{public}s', error.message);
      });
  }

  @Builder
  private buildFieldLabel(text: string) {
    Text(text)
      .fontSize(TgUiTokens.FONT_META_SIZE)
      .fontColor(TgUiTokens.COLOR_TEXT_META)
      .width('100%')
      .margin({ top: TgUiTokens.SPACE_12, bottom: TgUiTokens.SPACE_4 })
  }

  @Builder
  private buildNameFields() {
    Row({ space: TgUiTokens.SPACE_8 }) {
      TextInput({ text: this.firstName, placeholder: localized($r('app.string.edit_profile_first_name').id, 'First name') })
        .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
        .borderRadius(TgUiTokens.RADIUS_12)
        .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12 })
        .height(TgUiTokens.GENERIC_TEXT_FIELD_HEIGHT)
        .layoutWeight(1)
        .maxLength(PROFILE_NAME_PART_MAX_LENGTH)
        .enabled(!this.saving)
        .onChange((value: string) => {
          this.firstName = value;
        })
      TextInput({ text: this.lastName, placeholder: localized($r('app.string.edit_profile_last_name').id, 'Last name') })
        .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
        .borderRadius(TgUiTokens.RADIUS_12)
        .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12 })
        .height(TgUiTokens.GENERIC_TEXT_FIELD_HEIGHT)
        .layoutWeight(1)
        .maxLength(PROFILE_NAME_PART_MAX_LENGTH)
        .enabled(!this.saving)
        .onChange((value: string) => {
          this.lastName = value;
        })
    }
    .width('100%')
  }

  @Builder
  private buildUsernameField() {
    Row() {
      Text('@')
        .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .margin({ left: TgUiTokens.SPACE_12 })
      TextInput({ text: this.username, placeholder: localized($r('app.string.edit_profile_username').id, 'Username') })
        .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .backgroundColor(Color.Transparent)
        .layoutWeight(1)
        .maxLength(PROFILE_USERNAME_MAX_LENGTH)
        .enabled(!this.saving)
        .onChange((value: string) => {
          this.username = value;
          this.scheduleUsernameCheck();
        })
    }
    .width('100%')
    .height(TgUiTokens.GENERIC_TEXT_FIELD_HEIGHT)
    .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
    .borderRadius(TgUiTokens.RADIUS_12)
  }

  @Builder
  private buildBioField() {
    TextArea({ text: this.bio, placeholder: localized($r('app.string.edit_profile_bio').id, 'Bio') })
      .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
      .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
      .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
      .borderRadius(TgUiTokens.RADIUS_12)
      .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_12 })
      .width('100%')
      .height(TgUiTokens.EDIT_PROFILE_BIO_HEIGHT)
      .maxLength(PROFILE_BIO_MAX_LENGTH)
      .enabled(!this.saving)
      .onChange((value: string) => {
        this.bio = value;
      })
  }

  @Builder
  private buildHint() {
    if (this.username.trim().replace(/^@/, '').length > 0 &&
      !isValidProfileUsername(this.username.trim().replace(/^@/, ''))) {
      Text(localized($r('app.string.edit_profile_username_hint').id,
        'Username must be 5–32 characters: latin letters, digits or underscores, starting with a letter.'))
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_ERROR)
        .width('100%')
        .margin({ top: TgUiTokens.SPACE_4 })
    }
  }

  @Builder
  private buildSaveButton() {
    Text(this.saving
      ? localized($r('app.string.edit_profile_saving').id, 'Saving…')
      : localized($r('app.string.edit_profile_save').id, 'Save'))
      .fontSize(TgUiTokens.CHAT_ROW_TITLE_FONT_SIZE)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.canSave() ? TgUiTokens.LINK_PREVIEW_ACCENT_INCOMING : TgUiTokens.COLOR_TEXT_META)
      .onClick(() => {
        this.save();
      })
  }

  // A5: frame the picked photo; the square viewport is what the upload will contain.
  @Builder
  private buildAvatarEditor() {
    Column() {
      Text(localized($r('app.string.edit_profile_photo_frame').id, 'Frame your photo'))
        .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .margin({ bottom: TgUiTokens.SPACE_16 })

      Stack({ alignContent: Alignment.Center }) {
        Image(this.editorUri)
          .width(TgUiTokens.AVATAR_EDITOR_VIEWPORT_SIZE)
          .height(TgUiTokens.AVATAR_EDITOR_VIEWPORT_SIZE)
          .objectFit(ImageFit.Cover)
          .scale({ x: this.editorZoom, y: this.editorZoom })
          .translate({ x: this.editorOffsetX, y: this.editorOffsetY })
          .gesture(
            GestureGroup(GestureMode.Parallel,
              PinchGesture({ fingers: 2 })
                .onActionStart((): void => {
                  this.pinchStartZoom = this.editorZoom;
                })
                .onActionUpdate((event: GestureEvent): void => {
                  this.editorZoom = clampAvatarZoom(this.pinchStartZoom * event.scale);
                }),
              PanGesture({ fingers: 1, direction: PanDirection.All })
                .onActionStart((): void => {
                  this.panStartX = this.editorOffsetX;
                  this.panStartY = this.editorOffsetY;
                })
                .onActionUpdate((event: GestureEvent): void => {
                  const limit = (this.editorZoom - 1) * TgUiTokens.AVATAR_EDITOR_VIEWPORT_SIZE / 2;
                  this.editorOffsetX = Math.max(-limit, Math.min(limit, this.panStartX + event.offsetX));
                  this.editorOffsetY = Math.max(-limit, Math.min(limit, this.panStartY + event.offsetY));
                })
            )
          )
        // The circular frame matches the avatar the user will get.
        Circle()
          .width(TgUiTokens.AVATAR_EDITOR_VIEWPORT_SIZE)
          .height(TgUiTokens.AVATAR_EDITOR_VIEWPORT_SIZE)
          .fill(Color.Transparent)
          .stroke(TgUiTokens.COLOR_TEXT_TITLE)
          .strokeWidth(1)
      }
      .width(TgUiTokens.AVATAR_EDITOR_VIEWPORT_SIZE)
      .height(TgUiTokens.AVATAR_EDITOR_VIEWPORT_SIZE)
      .clip(true)
      .borderRadius(TgUiTokens.AVATAR_EDITOR_VIEWPORT_SIZE / 2)
      .margin({ bottom: TgUiTokens.SPACE_16 })

      Row() {
        Text(this.photoBusy
          ? localized($r('app.string.edit_profile_photo_busy').id, 'Updating photo…')
          : localized($r('app.string.edit_profile_photo_use').id, 'Use photo'))
          .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.MSG_LINK_INCOMING)
          .onClick((): void => {
            if (!this.photoBusy) {
              this.commitEditorCrop();
            }
          })
        Text(localized($r('app.string.cancel').id, 'Cancel'))
          .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .margin({ left: TgUiTokens.SPACE_16 })
          .onClick((): void => {
            if (!this.photoBusy) {
              this.cancelEditor();
            }
          })
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .height(TgUiTokens.AVATAR_EDITOR_CONTROL_HEIGHT)
    }
    .width('100%')
    .height('100%')
    .padding({ left: TgUiTokens.AVATAR_EDITOR_VIEWPORT_INSET, right: TgUiTokens.AVATAR_EDITOR_VIEWPORT_INSET })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        Column() {
        TgChatTopBar({
          title: localized($r('app.string.edit_profile_title').id, 'Edit Profile'),
          subtitle: '',
          topInset: this.topBarInset,
          showMoreAction: false,
          trailingAction: TgChatTopBarTrailingAction.Search,
          onBackPress: (): void => {
            this.pageStack.pop();
          }
        })
        Scroll() {
          Column() {
            Row() {
              Text(this.photoBusy
                ? localized($r('app.string.edit_profile_photo_busy').id, 'Updating photo…')
                : localized($r('app.string.edit_profile_change_photo').id, 'Change photo'))
                .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
                .fontColor(this.photoBusy ? TgUiTokens.COLOR_TEXT_META : TgUiTokens.LINK_PREVIEW_ACCENT_INCOMING)
                .onClick(() => {
                  this.pickProfilePhoto();
                })
            }
            .width('100%')
            .margin({ top: TgUiTokens.SPACE_8 })

            if (this.photoNotice.length > 0) {
              Text(this.photoNotice)
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_META)
                .width('100%')
                .margin({ top: TgUiTokens.SPACE_4 })
            }

            this.buildFieldLabel(localized($r('app.string.edit_profile_name').id, 'Name'))
            this.buildNameFields()
            this.buildFieldLabel(localized($r('app.string.edit_profile_username').id, 'Username'))
            this.buildUsernameField()
            this.buildHint()
            if (this.usernameAvailabilityText().length > 0 && !this.usernameTaken) {
              Text(this.usernameAvailabilityText())
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(this.usernameAvailabilityColor())
                .width('100%')
                .margin({ top: TgUiTokens.SPACE_4 })
            }
            if (this.usernameTaken) {
              Text(localized($r('app.string.edit_profile_username_taken').id,
                'This username is already taken'))
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_ERROR)
                .width('100%')
                .margin({ top: TgUiTokens.SPACE_4 })

              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.usernameSuggestions, (suggestion: string) => {
                  Text('@' + suggestion)
                    .fontSize(TgUiTokens.FONT_META_SIZE)
                    .fontColor(TgUiTokens.LINK_PREVIEW_ACCENT_INCOMING)
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .margin({ right: TgUiTokens.SPACE_4, top: TgUiTokens.SPACE_4 })
                    .borderRadius(TgUiTokens.RADIUS_8)
                    .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
                    .onClick(() => {
                      this.applySuggestion(suggestion);
                    })
                }, (suggestion: string) => suggestion)
              }
              .width('100%')
            }

            this.buildFieldLabel(localized($r('app.string.edit_profile_bio').id, 'Bio'))
            this.buildBioField()
            if (this.errorText.length > 0) {
              Text(this.errorText)
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_ERROR)
                .width('100%')
                .margin({ top: TgUiTokens.SPACE_8 })
            }
            Row() {
              this.buildSaveButton()
            }
            .width('100%')
            .margin({ top: TgUiTokens.SPACE_16 })
            .justifyContent(FlexAlign.End)
            Text(`${this.bio.length}/${PROFILE_BIO_MAX_LENGTH}`)
              .fontSize(TgUiTokens.FONT_META_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_META)
              .width('100%')
              .textAlign(TextAlign.End)
              .margin({ top: TgUiTokens.SPACE_4 })
          }
          .width('100%')
          .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, bottom: TgUiTokens.SPACE_24 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .align(Alignment.Top)
      }
        .width('100%')
        .height('100%')
        .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)

        if (this.editorOpen) {
          this.buildAvatarEditor()
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
    })
  }
}
