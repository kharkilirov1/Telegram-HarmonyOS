// I6: selected-people picker for a story audience. Lists private chats, filters by title/username and pops
// the chosen user ids back to the composer.

import { common } from '@kit.AbilityKit';
import { AppState } from '../../../core/model/AppState';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { localized } from '../../../core/utils/AppResource';
import {
  StoryAudienceCandidate,
  audienceInitials,
  audienceSelectionLabel,
  canConfirmAudience,
  filterAudienceCandidates,
  isAudienceSelected,
  toggleAudienceSelection
} from './StoryAudienceModel';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

export class StoryAudienceRouteParams {
  selectedIds: number[] = [];

  constructor(selectedIds: number[] = []) {
    this.selectedIds = selectedIds.slice();
  }
}

export class StoryAudienceResult {
  selectedIds: number[] = [];

  constructor(selectedIds: number[] = []) {
    this.selectedIds = selectedIds.slice();
  }
}

@ComponentV2
export struct TgStoryAudiencePage {
  @Local private candidates: StoryAudienceCandidate[] = [];
  @Local private filtered: StoryAudienceCandidate[] = [];
  @Local private selectedIds: number[] = [];
  @Local private query: string = '';
  @Local private topInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;

  private pageStack: NavPathStack = new NavPathStack();
  private state?: AppState;
  private unsubscribe?: () => void;
  private pageLifecycleToken: number = 0;

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topInset = computeTopBarHeight(context);
    } catch (_error) {
    }
    const store = getAppCoreRuntime().getStore();
    this.state = store.getState();
    this.rebuildCandidates();
    const token = this.pageLifecycleToken;
    let activeUnsubscribe: (() => void) | undefined = undefined;
    activeUnsubscribe = store.subscribe((newState: AppState, prevState: AppState) => {
      if (token !== this.pageLifecycleToken || this.unsubscribe !== activeUnsubscribe) {
        return;
      }
      if (newState.chats !== prevState.chats || newState.users !== prevState.users) {
        this.state = newState;
        this.rebuildCandidates();
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
    this.state = undefined;
  }

  private applyParams(params: StoryAudienceRouteParams): void {
    this.selectedIds = params.selectedIds.slice();
    this.rebuildCandidates();
  }

  // Only private chats can be story recipients, and the user is never a candidate for their own audience.
  private rebuildCandidates(): void {
    const state = this.state;
    if (state === undefined) {
      return;
    }
    const list: StoryAudienceCandidate[] = [];
    const selfUserId = state.auth.userId;
    state.chats.chats.forEach((chat) => {
      if (chat.type !== 'private' || chat.peerUserId <= 0 || chat.peerUserId === selfUserId) {
        return;
      }
      const candidate = new StoryAudienceCandidate();
      candidate.chatId = chat.id;
      candidate.title = chat.title.length > 0 ? chat.title : 'Chat';
      candidate.initials = audienceInitials(candidate.title);
      const user = state.users.users.get(chat.peerUserId);
      if (user !== undefined) {
        candidate.username = user.username;
      }
      list.push(candidate);
    });
    list.sort((left, right) => left.title.localeCompare(right.title));
    this.candidates = list;
    this.filtered = filterAudienceCandidates(list, this.query);
  }

  private toggle(chatId: number): void {
    this.selectedIds = toggleAudienceSelection(this.selectedIds, chatId);
  }

  private confirm(): void {
    if (!canConfirmAudience(this.selectedIds)) {
      return;
    }
    this.pageStack.pop(new StoryAudienceResult(this.selectedIds));
  }

  @Builder
  private buildTopBar() {
    Row() {
      Text(localized($r('app.string.story_audience_cancel').id, 'Cancel'))
        .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        .onClick((): void => {
          this.pageStack.pop();
        })
      Column() {
        Text(audienceSelectionLabel(this.selectedIds.length))
          .fontSize(TgUiTokens.SETTINGS_ROW_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        Text(localized($r('app.string.story_audience_subtitle').id, 'Who can see your story'))
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      Text(localized($r('app.string.story_audience_done').id, 'Done'))
        .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(canConfirmAudience(this.selectedIds) ? TgUiTokens.MSG_LINK_INCOMING : TgUiTokens.COLOR_TEXT_PREVIEW)
        .onClick((): void => {
          this.confirm();
        })
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
      right: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
      top: TgUiTokens.SPACE_12,
      bottom: TgUiTokens.SPACE_8
    })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildRow(candidate: StoryAudienceCandidate) {
    Row() {
      Text(candidate.initials)
        .width(TgUiTokens.AVATAR_SIZE_SM)
        .height(TgUiTokens.AVATAR_SIZE_SM)
        .borderRadius(TgUiTokens.AVATAR_SIZE_SM / 2)
        .backgroundColor(TgUiTokens.COLOR_AVATAR_PLACEHOLDER_BG)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .textAlign(TextAlign.Center)
      Text(candidate.title)
        .fontSize(TgUiTokens.SETTINGS_ROW_TITLE_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: TgUiTokens.SPACE_12 })
      Text(isAudienceSelected(this.selectedIds, candidate.chatId) ? '✓' : '')
        .fontSize(TgUiTokens.SETTINGS_ROW_TITLE_SIZE)
        .fontColor(TgUiTokens.MSG_LINK_INCOMING)
    }
    .width('100%')
    .height(TgUiTokens.SETTINGS_ROW_HEIGHT)
    .padding({ left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET, right: TgUiTokens.SETTINGS_SECTION_SIDE_INSET })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      this.toggle(candidate.chatId);
    })
  }

  build() {
    NavDestination() {
      Column() {
        this.buildTopBar()
        TextInput({ text: this.query, placeholder: localized($r('app.string.story_audience_search').id, 'Search') })
          .height(TgUiTokens.GENERIC_TEXT_FIELD_HEIGHT)
          .fontSize(TgUiTokens.GENERIC_TEXT_FIELD_FONT_SIZE)
          .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
          .borderRadius(TgUiTokens.RADIUS_10)
          .margin({
            left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
            right: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
            bottom: TgUiTokens.SPACE_8
          })
          .onChange((value: string): void => {
            this.query = value;
            this.filtered = filterAudienceCandidates(this.candidates, value);
          })
        List() {
          ForEach(this.filtered, (candidate: StoryAudienceCandidate) => {
            ListItem() {
              this.buildRow(candidate)
            }
          }, (candidate: StoryAudienceCandidate) => candidate.chatId.toString())
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .divider({ strokeWidth: 0.5, color: TgUiTokens.COLOR_SEPARATOR,
          startMargin: TgUiTokens.SETTINGS_SECTION_SIDE_INSET + TgUiTokens.AVATAR_SIZE_SM + TgUiTokens.SPACE_12 })
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.topInset })
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext): void => {
      this.pageStack = context.pathStack;
      const params = context.pathInfo.param as StoryAudienceRouteParams;
      if (params !== undefined) {
        this.applyParams(params);
      }
    })
  }
}

@Builder
export function TgStoryAudiencePageBuilder() {
  TgStoryAudiencePage()
}
