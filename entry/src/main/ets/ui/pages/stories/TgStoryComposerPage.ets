// I6: story composer. Pick one photo or video, add a caption, choose who can see it and publish through
// PostStoryUseCase. The privacy row cycles like iOS; selected people stay empty until a picker exists, so
// that mode is disabled instead of pretending to work.

import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppState } from '../../../core/model/AppState';
import { PostStoryPayload, StoryPrivacy } from '../../../core/model/AppCommand';
import { StoryFullDto } from '../../../core/model/dto/StoryDto';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { PostStoryUseCase, createPostStoryUseCase, STORY_MAX_CAPTION_LENGTH } from '../../../domain/usecases/postStory';
import {
  canPublishStory,
  clampStoryCaption,
  nextStoryPrivacy,
  storyMediaKindFromPath,
  storyPrivacyLabel,
  buildStoryPayload
} from './StoryComposerModel';
import { StoryMediaPrep } from './storyMediaPrep';
import { localized } from '../../../core/utils/AppResource';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x00B6;
const TAG = 'TgStoryComposerPage';

@ComponentV2
export struct TgStoryComposerPage {
  @Local private mediaPath: string = '';
  @Local private mediaKind: string = 'photo';
  @Local private caption: string = '';
  @Local private privacy: StoryPrivacy = 'everyone';
  @Local private busy: boolean = false;
  @Local private errorText: string = '';
  @Local private noticeText: string = '';
  @Local private topInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;

  private pageStack: NavPathStack = new NavPathStack();
  private postUseCase?: PostStoryUseCase;
  private unsubscribe?: () => void;
  private pageLifecycleToken: number = 0;
  private selfUserId: number = 0;

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topInset = computeTopBarHeight(context);
    } catch (_error) {
    }
    const runtime = getAppCoreRuntime();
    const store = runtime.getStore();
    this.postUseCase = createPostStoryUseCase(store, getTdGatewayAdapter());
    this.selfUserId = store.getState().auth.userId;
    const token = this.pageLifecycleToken;
    let activeUnsubscribe: (() => void) | undefined = undefined;
    activeUnsubscribe = store.subscribe((newState: AppState, _prevState: AppState) => {
      if (token !== this.pageLifecycleToken || this.unsubscribe !== activeUnsubscribe) {
        return;
      }
      if (newState.auth.userId !== this.selfUserId) {
        this.selfUserId = newState.auth.userId;
      }
    });
    this.unsubscribe = activeUnsubscribe;
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    this.postUseCase = undefined;
  }

  private pickMedia(): void {
    if (this.busy) {
      return;
    }
    const picker = new photoAccessHelper.PhotoViewPicker();
    picker.select({
      MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_VIDEO_TYPE,
      maxSelectNumber: 1
    }).then((result: photoAccessHelper.PhotoSelectResult) => {
      const uris = result.photoUris;
      if (uris.length === 0) {
        return;
      }
      const uri = uris[0];
      this.busy = true;
      this.errorText = '';
      return this.copyMedia(uri).then((path: string): void => {
        if (path.length === 0) {
          this.errorText = localized($r('app.string.story_error_prepare').id, 'Could not read the selected media');
          return;
        }
        this.mediaPath = path;
        this.mediaKind = storyMediaKindFromPath(path);
      });
    }).catch((error: Error) => {
      this.errorText = error.message;
      hilog.warn(DOMAIN, TAG, 'Picking story media failed: %{public}s', error.message);
    }).finally((): void => {
      this.busy = false;
    });
  }

  private copyMedia(uri: string): Promise<string> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      return StoryMediaPrep.copyPickedMedia(context, uri);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Copying story media failed: %{public}s', String(error));
      return Promise.resolve('');
    }
  }

  private cyclePrivacy(): void {
    this.privacy = nextStoryPrivacy(this.privacy, 1);
    if (this.privacy === 'selectedUsers') {
      // Without a people picker this mode cannot publish, so skip it instead of blocking the user.
      this.privacy = nextStoryPrivacy(this.privacy, 1);
    }
  }

  private publish(): void {
    const useCase = this.postUseCase;
    if (useCase === undefined || this.busy || this.selfUserId <= 0) {
      return;
    }
    if (!canPublishStory(this.mediaPath, this.privacy, 0)) {
      this.errorText = localized($r('app.string.story_error_media').id, 'Choose a photo or a video first');
      return;
    }
    const payload: PostStoryPayload = buildStoryPayload(this.selfUserId, this.mediaPath,
      clampStoryCaption(this.caption), this.privacy);
    this.busy = true;
    this.errorText = '';
    this.noticeText = '';
    const token = this.pageLifecycleToken;
    useCase.execute(payload).then((story: StoryFullDto | undefined) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      if (story === undefined) {
        this.errorText = localized($r('app.string.story_error_publish').id, 'Could not publish the story');
        return;
      }
      this.noticeText = localized($r('app.string.story_published').id, 'Story published');
      this.pageStack.pop();
    }).catch((error: Object) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.errorText = String(error);
    }).finally((): void => {
      this.busy = false;
    });
  }

  @Builder
  private buildTopBar() {
    Row() {
      Text(localized($r('app.string.story_composer_cancel').id, 'Cancel'))
        .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .onClick((): void => {
          if (!this.busy) {
            this.pageStack.pop();
          }
        })
      Text(localized($r('app.string.story_composer_title').id, 'New Story'))
        .fontSize(TgUiTokens.SETTINGS_ROW_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text(this.busy
        ? localized($r('app.string.story_composer_publishing').id, 'Publishing…')
        : localized($r('app.string.story_composer_publish').id, 'Publish'))
        .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.canPublish() ? TgUiTokens.MSG_LINK_INCOMING : TgUiTokens.COLOR_TEXT_PREVIEW)
        .onClick((): void => {
          this.publish();
        })
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
      right: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
      top: TgUiTokens.SPACE_12,
      bottom: TgUiTokens.SPACE_12
    })
    .alignItems(VerticalAlign.Center)
  }

  private canPublish(): boolean {
    return !this.busy && canPublishStory(this.mediaPath, this.privacy, 0);
  }

  @Builder
  private buildMediaArea() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.mediaPath.length > 0) {
        if (this.mediaKind === 'video') {
          Video({ src: this.mediaPath })
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .controls(true)
            .autoPlay(false)
        } else {
          Image(this.mediaPath)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
        }
      } else {
        Column() {
          Text('＋')
            .fontSize(TgUiTokens.STORY_COMPOSER_PLUS_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          Text(localized($r('app.string.story_composer_pick').id, 'Photo or video'))
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
            .margin({ top: TgUiTokens.SPACE_8 })
        }
      }
    }
    .width('100%')
    .height(TgUiTokens.STORY_COMPOSER_MEDIA_HEIGHT)
    .backgroundColor(TgUiTokens.STORY_COMPOSER_MEDIA_BG)
    .borderRadius(TgUiTokens.RADIUS_12)
    .clip(true)
    .onClick((): void => {
      this.pickMedia();
    })
  }

  @Builder
  private buildCaptionAndPrivacy() {
    Column() {
      TextInput({ text: this.caption, placeholder: localized($r('app.string.story_composer_caption').id, 'Add a caption') })
        .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .placeholderColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .maxLength(STORY_MAX_CAPTION_LENGTH)
        .backgroundColor(Color.Transparent)
        .onChange((value: string): void => {
          this.caption = value;
        })
      Row() {
        Text(localized($r('app.string.story_composer_who_sees').id, 'Who can see'))
          .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .layoutWeight(1)
        Text(storyPrivacyLabel(this.privacy))
          .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        Text('›')
          .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .margin({ left: TgUiTokens.SPACE_4 })
      }
      .width('100%')
      .height(TgUiTokens.SETTINGS_ROW_HEIGHT)
      .onClick((): void => {
        this.cyclePrivacy();
      })
    }
    .width('100%')
    .margin({ top: TgUiTokens.SPACE_12 })
  }

  build() {
    NavDestination() {
      Column() {
        this.buildTopBar()
        Scroll() {
          Column() {
            this.buildMediaArea()
            this.buildCaptionAndPrivacy()
            if (this.errorText.length > 0) {
              Text(this.errorText)
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_ERROR)
                .margin({ top: TgUiTokens.SPACE_8 })
            }
            if (this.noticeText.length > 0) {
              Text(this.noticeText)
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.MSG_LINK_INCOMING)
                .margin({ top: TgUiTokens.SPACE_8 })
            }
          }
          .width('100%')
          .padding({
            left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
            right: TgUiTokens.SETTINGS_SECTION_SIDE_INSET
          })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.topInset })
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext): void => {
      this.pageStack = context.pathStack;
    })
  }
}

@Builder
export function TgStoryComposerPageBuilder() {
  TgStoryComposerPage()
}
