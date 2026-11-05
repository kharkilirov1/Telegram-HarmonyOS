// I6: story viewers screen. Lists who watched an owned story, with their reaction, and pages until TDLib
// runs out. Rows resolve names from the users/chats stores so no extra request is needed per viewer.

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppState, User } from '../../../core/model/AppState';
import { StoryInteractionDto, StoryInteractionsPageDto } from '../../../core/model/dto/StoryDto';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { LoadStoryInteractionsUseCase, createLoadStoryInteractionsUseCase } from '../../../domain/usecases/loadStoryInteractions';
import { localized } from '../../../core/utils/AppResource';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x00B6;
const TAG = 'TgStoryViewsPage';

export class StoryViewsRouteParams {
  storyId: number = 0;
  totalViewCount: number = 0;
  totalReactionCount: number = 0;

  constructor(storyId: number = 0, totalViewCount: number = 0, totalReactionCount: number = 0) {
    this.storyId = storyId;
    this.totalViewCount = totalViewCount;
    this.totalReactionCount = totalReactionCount;
  }
}

class StoryViewerRow {
  userId: number = 0;
  chatId: number = 0;
  title: string = '';
  initials: string = '';
  reactionKey: string = '';
  kind: string = 'view';
}

@ComponentV2
export struct TgStoryViewsPage {
  @Local private rows: StoryViewerRow[] = [];
  @Local private totalViewCount: number = 0;
  @Local private totalReactionCount: number = 0;
  @Local private loading: boolean = false;
  @Local private topInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;

  private pageStack: NavPathStack = new NavPathStack();
  private storyId: number = 0;
  private useCase?: LoadStoryInteractionsUseCase;
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
    this.useCase = createLoadStoryInteractionsUseCase(getTdGatewayAdapter());
    this.state = store.getState();
    const token = this.pageLifecycleToken;
    let activeUnsubscribe: (() => void) | undefined = undefined;
    activeUnsubscribe = store.subscribe((newState: AppState, prevState: AppState) => {
      if (token !== this.pageLifecycleToken || this.unsubscribe !== activeUnsubscribe) {
        return;
      }
      if (newState.users !== prevState.users || newState.chats !== prevState.chats) {
        this.state = newState;
        this.rows = this.rebuildRows(this.rows);
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
    this.useCase = undefined;
    this.state = undefined;
  }

  private applyParams(params: StoryViewsRouteParams): void {
    this.storyId = params.storyId;
    this.totalViewCount = params.totalViewCount;
    this.totalReactionCount = params.totalReactionCount;
    this.useCase?.reset(this.storyId);
    this.loadPage();
  }

  private loadPage(): void {
    const useCase = this.useCase;
    if (useCase === undefined || this.storyId === 0 || this.loading) {
      return;
    }
    this.loading = true;
    const token = this.pageLifecycleToken;
    useCase.load(this.storyId).then((page: StoryInteractionsPageDto) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.loading = false;
      if (page.totalCount > 0) {
        this.totalViewCount = page.totalCount;
        this.totalReactionCount = page.totalReactionCount;
      }
      this.rows = this.rebuildRows(this.rows.concat(this.toRows(page.interactions)));
    }).catch((error: Object) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.loading = false;
      hilog.info(DOMAIN, TAG, 'Viewers page settled with an error: %{public}s', String(error));
    });
  }

  private toRows(interactions: StoryInteractionDto[]): StoryViewerRow[] {
    const rows: StoryViewerRow[] = [];
    for (const interaction of interactions) {
      const row = new StoryViewerRow();
      row.userId = interaction.actorUserId;
      row.chatId = interaction.actorChatId;
      row.reactionKey = interaction.reactionKey;
      row.kind = interaction.kind;
      rows.push(row);
    }
    return rows;
  }

  // Names come from the store; a row is kept even when the user is not loaded yet so the list is stable.
  private rebuildRows(rows: StoryViewerRow[]): StoryViewerRow[] {
    const state = this.state;
    if (state === undefined) {
      return rows;
    }
    for (const row of rows) {
      if (row.userId !== 0) {
        const user = state.users.users.get(row.userId);
        if (user !== undefined) {
          row.title = userTitle(user);
        }
      } else if (row.chatId !== 0) {
        const chat = state.chats.chats.get(row.chatId);
        if (chat !== undefined) {
          row.title = chat.title.length > 0 ? chat.title : 'Chat';
        }
      }
      row.initials = initialsOf(row.title);
    }
    return rows;
  }

  private reactionLabel(key: string): string {
    if (key.startsWith('emoji:')) {
      return key.substring('emoji:'.length);
    }
    if (key.length > 0) {
      return '★';
    }
    return '';
  }

  @Builder
  private buildTopBar() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(TgUiTokens.SETTINGS_ROW_TITLE_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .onClick((): void => {
            this.pageStack.pop();
          })
        Text(localized($r('app.string.story_views_title').id, 'Viewers'))
          .fontSize(TgUiTokens.SETTINGS_ROW_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('')
          .width(TgUiTokens.SETTINGS_ROW_TITLE_SIZE)
      }
      .width('100%')
      .padding({ top: TgUiTokens.SPACE_8, bottom: TgUiTokens.SPACE_8 })
      .alignItems(VerticalAlign.Center)

      if (this.totalViewCount > 0) {
        Row() {
          Text(localized($r('app.string.story_views_count').id, 'Views'))
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          Text(' ' + this.totalViewCount.toString())
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          if (this.totalReactionCount > 0) {
            Text('   ♥ ' + this.totalReactionCount.toString())
              .fontSize(TgUiTokens.FONT_META_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          }
        }
        .width('100%')
        .padding({ bottom: TgUiTokens.SPACE_8 })
      }
    }
    .width('100%')
    .padding({ left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET, right: TgUiTokens.SETTINGS_SECTION_SIDE_INSET })
  }

  @Builder
  private buildRow(row: StoryViewerRow) {
    Row() {
      Text(row.initials)
        .width(TgUiTokens.AVATAR_SIZE_SM)
        .height(TgUiTokens.AVATAR_SIZE_SM)
        .borderRadius(TgUiTokens.AVATAR_SIZE_SM / 2)
        .backgroundColor(TgUiTokens.COLOR_AVATAR_PLACEHOLDER_BG)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .textAlign(TextAlign.Center)
      Text(row.title.length > 0 ? row.title : '…')
        .fontSize(TgUiTokens.SETTINGS_ROW_TITLE_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: TgUiTokens.SPACE_12 })
      Text(this.reactionLabel(row.reactionKey))
        .fontSize(TgUiTokens.STORY_REACTION_EMOJI_SIZE)
    }
    .width('100%')
    .height(TgUiTokens.SETTINGS_ROW_HEIGHT)
    .padding({ left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET, right: TgUiTokens.SETTINGS_SECTION_SIDE_INSET })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    NavDestination() {
      Column() {
        this.buildTopBar()
        List() {
          ForEach(this.rows, (row: StoryViewerRow, index: number) => {
            ListItem() {
              this.buildRow(row)
            }
            .onAppear((): void => {
              if (index >= this.rows.length - 3) {
                this.loadPage();
              }
            })
          }, (row: StoryViewerRow, index: number) => row.userId.toString() + ':' + row.chatId.toString() + ':' + index.toString())
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
      const params = context.pathInfo.param as StoryViewsRouteParams;
      if (params !== undefined) {
        this.applyParams(params);
      }
    })
  }
}

function userTitle(user: User): string {
  const full = (user.firstName + ' ' + user.lastName).trim();
  return full.length > 0 ? full : (user.username.length > 0 ? user.username : 'User');
}

function initialsOf(title: string): string {
  const parts = title.trim().split(' ').filter((part) => part.length > 0);
  if (parts.length === 0) {
    return '';
  }
  if (parts.length === 1) {
    return parts[0].substring(0, 1).toUpperCase();
  }
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

@Builder
export function TgStoryViewsPageBuilder() {
  TgStoryViewsPage()
}
