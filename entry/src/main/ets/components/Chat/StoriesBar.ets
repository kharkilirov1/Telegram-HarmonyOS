// StoriesBar — horizontal scrollable row of story circles at top of chat list
// Reference: Telegram iOS StoryPeerListComponent, Android StoriesListPlaceProvider

import { StoriesController } from '../../controllers/StoriesController';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { ChatActiveStories } from '../../models/Story';

@ComponentV2
export struct StoriesBar {
  @Param onStoryClick: (chatId: number) => void = () => {};
  @Local activeStories: ChatActiveStories[] = [];

  private storiesHandler = (): void => {
    this.activeStories = [...StoriesController.getInstance().getSortedActiveStories()];
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance().addObserver(EventId.STORIES_UPDATED, this.storiesHandler);
    StoriesController.getInstance().loadActiveStories();
    // Load initial data
    this.activeStories = [...StoriesController.getInstance().getSortedActiveStories()];
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance().removeObserver(EventId.STORIES_UPDATED, this.storiesHandler);
  }

  build() {
    if (this.activeStories.length > 0) {
      Column() {
        Scroll() {
          Row({ space: 12 }) {
            ForEach(this.activeStories, (item: ChatActiveStories) => {
              this.storyCircle(item)
            }, (item: ChatActiveStories) => `story_${item.chatId}`)
          }
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        Divider()
          .strokeWidth(0.5)
          .color($r('app.color.separator'))
      }
    }
  }

  @Builder
  storyCircle(item: ChatActiveStories) {
    Column({ space: 4 }) {
      Stack() {
        // Gradient ring for unread, gray ring for read
        Column()
          .width(56)
          .height(56)
          .borderRadius(28)
          .border({
            width: 2.5,
            color: item.hasUnread ? $r('app.color.story_ring_unread') : $r('app.color.story_ring_read')
          })

        // Avatar
        if (item.chatPhotoUrl.length > 0) {
          Image(item.chatPhotoUrl)
            .width(48)
            .height(48)
            .borderRadius(24)
            .alt(item.chatInitial)
            .autoResize(true)
            .onError(() => {})
        } else {
          Text(item.chatInitial)
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.icon_on_primary'))
            .width(48)
            .height(48)
            .borderRadius(24)
            .backgroundColor($r('app.color.telegram_blue'))
            .textAlign(TextAlign.Center)
        }
      }
      .alignContent(Alignment.Center)

      // Name
      Text(item.chatTitle)
        .fontSize(12)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 64 })
        .textAlign(TextAlign.Center)
    }
    .onClick(() => {
      this.onStoryClick(item.chatId);
    })
    .accessibilityText(item.chatTitle)
  }
}
