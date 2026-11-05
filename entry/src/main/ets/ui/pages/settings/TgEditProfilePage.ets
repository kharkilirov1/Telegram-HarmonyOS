// A5: edit the current user's profile — first/last name, username and bio.
// iOS counterpart: ProfileEditingController pushed from the own-profile screen.
// Data layer: EditProfileUseCase (setName/setBio/setUsername); this page only owns the form.

import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { AvatarImagePreparation } from './avatarImagePrep';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
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
  @Local private usernameSuggestions: string[] = [];
  @Local private photoBusy: boolean = false;
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  private useCase?: EditProfileUseCase;
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
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Use case init failed: %{public}s', String(error));
      this.useCase = undefined;
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
      return this.copyPickedPhoto(sourceUri).then((localPath: string): Promise<void> => {
        if (localPath.length === 0) {
          throw new Error('Could not copy the selected photo');
        }
        return useCase.updatePhoto(localPath).then((): void => {
          this.photoNotice = localized($r('app.string.edit_profile_photo_updated').id, 'Profile photo updated');
          this.errorText = '';
        });
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

  private applySuggestion(value: string): void {
    this.username = value;
    this.usernameTaken = false;
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

  build() {
    NavDestination() {
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
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
    })
  }
}
