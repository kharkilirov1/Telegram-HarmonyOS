// TgRootMiniPlayer — voice/audio mini player content for the root island
// miniBar slot. HDS owns material, clip and the expand/collapse morph; the
// leading 48vp control is what remains visible in the collapsed lens, so its
// tap expands the bar instead of toggling playback while collapsed.
import { TgUiTokens } from '../tokens/TgUiTokens';
import { ROOT_SEARCH_DOCK_CONTROL_SIZE } from '../../utils/RootTabBarGeometry';
import { TgIcon } from './TgIcon';

@ComponentV2
export struct TgRootMiniPlayer {
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param isPlaying: boolean = false;
  @Param progress: number = 0;
  @Param collapsed: boolean = false;
  @Param stopLabel: string = 'Stop';
  // Music-bar pattern (native Music app): a skip-next control inside the bar.
  @Param showNext: boolean = false;

  @Event onTogglePlay: () => void = (): void => {};
  @Event onExpandRequest: () => void = (): void => {};
  @Event onStop: () => void = (): void => {};
  @Event onNext: () => void = (): void => {};
  @Event onBodyTap: () => void = (): void => {};

  private clampedProgress(): number {
    return Math.max(0, Math.min(1, this.progress));
  }

  @Builder
  private buildLeadingControl() {
    Stack({ alignContent: Alignment.Center }) {
      TgIcon({
        src: this.isPlaying ? TgUiTokens.ICON_RES_PAUSE : TgUiTokens.ICON_RES_PLAY,
        iconSize: TgUiTokens.CHAT_TOP_BAR_ACTION_ICON_SIZE,
        tintColor: TgUiTokens.COLOR_TEXT_TITLE
      })
    }
    .width(ROOT_SEARCH_DOCK_CONTROL_SIZE)
    .height(ROOT_SEARCH_DOCK_CONTROL_SIZE)
    .accessibilityGroup(true)
    .accessibilityLevel('yes')
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
    .onClick(() => {
      if (this.collapsed) {
        this.onExpandRequest();
        return;
      }
      this.onTogglePlay();
    })
  }

  @Builder
  private buildNextAction() {
    Stack({ alignContent: Alignment.Center }) {
      TgIcon({
        src: TgUiTokens.ICON_RES_SKIP_NEXT,
        iconSize: TgUiTokens.CHAT_TOP_BAR_ACTION_ICON_SIZE,
        tintColor: TgUiTokens.COLOR_TEXT_TITLE
      })
    }
    .width(ROOT_SEARCH_DOCK_CONTROL_SIZE)
    .height(ROOT_SEARCH_DOCK_CONTROL_SIZE)
    .accessibilityGroup(true)
    .accessibilityLevel('yes')
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
    .onClick(() => this.onNext())
  }

  @Builder
  private buildStopAction() {
    Stack({ alignContent: Alignment.Center }) {
      TgIcon({
        src: TgUiTokens.ICON_RES_CLOSE,
        iconSize: TgUiTokens.CHAT_TOP_BAR_ACTION_ICON_SIZE,
        tintColor: TgUiTokens.COLOR_TEXT_TITLE
      })
    }
    .width(ROOT_SEARCH_DOCK_CONTROL_SIZE)
    .height(ROOT_SEARCH_DOCK_CONTROL_SIZE)
    .accessibilityGroup(true)
    .accessibilityLevel('yes')
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.stopLabel)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
    .onClick(() => this.onStop())
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Row() {
        this.buildLeadingControl()

        Column() {
          Text(this.title.length > 0 ? this.title : ' ')
            .fontSize(TgUiTokens.REPLY_SNIPPET_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.subtitle.length > 0) {
            Text(this.subtitle)
              .fontSize(TgUiTokens.REPLY_SNIPPET_PREVIEW_SIZE - 2)
              .fontColor(TgUiTokens.TAB_ITEM_UNSELECTED)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .onClick(() => this.onBodyTap())

        if (this.showNext) {
          this.buildNextAction()
        }
        this.buildStopAction()
      }
      .width('100%')
      .height(ROOT_SEARCH_DOCK_CONTROL_SIZE)
      .alignItems(VerticalAlign.Center)

      // Thin playback progress line along the island's bottom edge.
      Row()
        .height(2)
        .width(`${this.clampedProgress() * 100}%`)
        .backgroundColor(TgUiTokens.COMPOSER_ACTION_ACTIVE)
        .borderRadius(1)
    }
    .width('100%')
    .height(ROOT_SEARCH_DOCK_CONTROL_SIZE)
    .clip(true)
  }
}
