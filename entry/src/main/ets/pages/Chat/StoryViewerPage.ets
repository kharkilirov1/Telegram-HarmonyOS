// StoryViewerPage — fullscreen story viewer with progress bars
// Reference: Telegram iOS StoryContainerScreen, Android StoryViewer

import { StoriesController } from '../../controllers/StoriesController';
import { Story, StoryContentType, ChatActiveStories } from '../../models/Story';

@Builder
export function StoryViewerBuilder(name: string, param: Object) {
  StoryViewerPage({ chatId: param as number })
}

@ComponentV2
export struct StoryViewerPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param chatId: number = 0;
  @Local stories: Story[] = [];
  @Local currentIndex: number = 0;
  @Local chatTitle: string = '';
  @Local chatInitial: string = '';
  @Local chatPhotoUrl: string = '';
  @Local isLoading: boolean = true;
  @Local progress: number = 0;
  @Local isPaused: boolean = false;

  private progressTimerId: number = -1;
  private videoController: VideoController = new VideoController();
  private readonly STORY_DURATION_MS: number = 5000; // 5 seconds per story
  private readonly TICK_MS: number = 50;

  aboutToAppear(): void {
    this.loadStories();
  }

  aboutToDisappear(): void {
    this.stopTimer();
    // Close the current story
    if (this.currentIndex < this.stories.length) {
      const story = this.stories[this.currentIndex];
      StoriesController.getInstance().closeStory(this.chatId, story.id);
    }
  }

  private async loadStories(): Promise<void> {
    const controller = StoriesController.getInstance();
    const activeStories = controller.getSortedActiveStories();
    const chatStories = activeStories.find((s: ChatActiveStories) => s.chatId === this.chatId);

    if (!chatStories || chatStories.storyIds.length === 0) {
      this.isLoading = false;
      return;
    }

    this.chatTitle = chatStories.chatTitle;
    this.chatInitial = chatStories.chatInitial;
    this.chatPhotoUrl = chatStories.chatPhotoUrl;

    // Load each story
    const loaded: Story[] = [];
    for (const storyId of chatStories.storyIds) {
      const story = await controller.getStory(this.chatId, storyId);
      if (story) {
        loaded.push(story);
      }
    }

    this.stories = loaded;
    this.isLoading = false;

    // Find first unread story
    const firstUnreadIdx = loaded.findIndex((s: Story) => s.id > chatStories.maxReadStoryId);
    this.currentIndex = firstUnreadIdx >= 0 ? firstUnreadIdx : 0;

    if (this.stories.length > 0) {
      this.openCurrentStory();
      this.startTimer();
    }
  }

  private openCurrentStory(): void {
    if (this.currentIndex < this.stories.length) {
      StoriesController.getInstance().openStory(this.chatId, this.stories[this.currentIndex].id);
    }
  }

  private startTimer(): void {
    this.progress = 0;
    this.progressTimerId = setInterval(() => {
      if (this.isPaused) return;
      this.progress += this.TICK_MS / this.STORY_DURATION_MS;
      if (this.progress >= 1.0) {
        this.goToNext();
      }
    }, this.TICK_MS);
  }

  private stopTimer(): void {
    if (this.progressTimerId >= 0) {
      clearInterval(this.progressTimerId);
      this.progressTimerId = -1;
    }
  }

  private goToNext(): void {
    this.stopTimer();
    if (this.currentIndex < this.stories.length - 1) {
      this.currentIndex++;
      this.openCurrentStory();
      this.startTimer();
    } else {
      // End of stories for this chat
      this.navPathStack.pop();
    }
  }

  private goToPrev(): void {
    this.stopTimer();
    if (this.currentIndex > 0) {
      this.currentIndex--;
      this.openCurrentStory();
      this.startTimer();
    } else {
      this.progress = 0;
      this.startTimer();
    }
  }

  private formatTime(timestamp: number): string {
    const now = Math.floor(Date.now() / 1000);
    const diff = now - timestamp;
    if (diff < 60) return `${diff}s`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
    return `${Math.floor(diff / 86400)}d`;
  }

  build() {
    NavDestination() {
      Stack() {
        // Background
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.media_viewer_bg'))

        if (this.isLoading) {
          LoadingProgress()
            .width(40).height(40)
            .color($r('app.color.icon_on_primary'))
        } else if (this.stories.length > 0) {
          // Story content
          this.storyContent()

          // Top overlay: progress bars + header
          Column() {
            // Progress bars
            Row({ space: 2 }) {
              ForEach(this.stories, (story: Story, index: number) => {
                Stack({ alignContent: Alignment.Start }) {
                  // Background track
                  Column()
                    .height(2)
                    .width('100%')
                    .borderRadius(1)
                    .backgroundColor($r('app.color.slider_track_dark'))

                  // Filled portion
                  Column()
                    .height(2)
                    .borderRadius(1)
                    .backgroundColor($r('app.color.icon_on_primary'))
                    .width(index < this.currentIndex ? '100%' :
                      (index === this.currentIndex ? `${Math.min(this.progress * 100, 100)}%` : '0%'))
                }
                .layoutWeight(1)
                .height(2)
              }, (story: Story, index: number) => `progress_${story.id}_${index}`)
            }
            .width('100%')
            .padding({ left: 8, right: 8, top: 8 })

            // Header: avatar, name, time, close
            Row() {
              // Avatar
              if (this.chatPhotoUrl.length > 0) {
                Image(this.chatPhotoUrl)
                  .width(32).height(32)
                  .borderRadius(16)
                  .alt(this.chatInitial)
                  .autoResize(true)
                  .onError(() => {})
              } else {
                Text(this.chatInitial)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.icon_on_primary'))
                  .width(32).height(32)
                  .borderRadius(16)
                  .backgroundColor($r('app.color.telegram_blue'))
                  .textAlign(TextAlign.Center)
              }

              Column() {
                Text(this.chatTitle)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.icon_on_primary'))
                  .maxLines(1)

                if (this.currentIndex < this.stories.length) {
                  Text(this.formatTime(this.stories[this.currentIndex].date))
                    .fontSize(12)
                    .fontColor($r('app.color.story_time_text'))
                }
              }
              .margin({ left: 8 })
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              // Close button
              Image($r('app.media.ic_close'))
                .width(24).height(24)
                .fillColor($r('app.color.icon_on_primary'))
                .onClick(() => { this.navPathStack.pop(); })
                .accessibilityText($r('app.string.cancel'))
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8 })
          }
          .width('100%')
          .position({ top: 0 })

          // Tap zones: left = prev, right = next
          Row() {
            // Left tap zone — previous
            Column()
              .layoutWeight(1)
              .height('100%')
              .onClick(() => { this.goToPrev(); })

            // Right tap zone — next
            Column()
              .layoutWeight(2)
              .height('100%')
              .onClick(() => { this.goToNext(); })
          }
          .width('100%')
          .height('100%')
          .gesture(
            LongPressGesture({ repeat: false, duration: 200 })
              .onAction(() => { this.isPaused = true; })
              .onActionEnd(() => { this.isPaused = false; })
          )

          // Caption overlay at bottom
          if (this.currentIndex < this.stories.length && this.stories[this.currentIndex].caption.length > 0) {
            Column() {
              Text(this.stories[this.currentIndex].caption)
                .fontSize(15)
                .fontColor($r('app.color.icon_on_primary'))
                .padding({ left: 16, right: 16, bottom: 24 })
                .maxLines(5)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .position({ bottom: 0 })
            .linearGradient({
              direction: GradientDirection.Bottom,
              colors: [[$r('app.color.overlay_gradient_end'), 0.0], [$r('app.color.story_caption_overlay'), 1.0]]
            })
          }
        } else {
          // No stories
          Text($r('app.string.no_stories'))
            .fontSize(16)
            .fontColor($r('app.color.icon_on_primary'))
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
  }

  @Builder
  storyContent() {
    if (this.currentIndex < this.stories.length) {
      if (this.stories[this.currentIndex].contentType === StoryContentType.PHOTO) {
        if (this.stories[this.currentIndex].photoUrl.length > 0) {
          Image(this.stories[this.currentIndex].photoUrl)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .alt($r('app.string.photo'))
            .autoResize(true)
            .onError(() => {})
        }
      } else {
        if (this.stories[this.currentIndex].videoUrl.length > 0) {
          Video({
            src: this.stories[this.currentIndex].videoUrl,
            controller: this.videoController
          })
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .autoPlay(true)
            .controls(false)
            .onPrepared(() => {})
            .onError(() => {})
        } else {
          Column() {
            Text($r('app.string.video'))
              .fontSize(14)
              .fontColor($r('app.color.icon_on_primary'))
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
    }
  }
}
