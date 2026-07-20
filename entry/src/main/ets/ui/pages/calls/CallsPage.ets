// CallsPage — Calls tab with real TDLib-backed recent calls list.
// Grounding:
// - HarmonyOS docs: List + ListItem + onScrollIndex for paginated list rendering
// - TDLib td_api.tl: searchCallMessages uses opaque offset/next_offset pagination
// - Android ref: CallLogActivity loads call history via server search + paginates near list end
// - iOS ref: CallListController is backed by a real call list, not placeholder text

import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState, User } from '../../../core/model/AppState';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { fileUri } from '@kit.CoreFileKit';
import { TgCallRow, TgCallType } from '../../tg_ui/atoms/TgCallRow';
import { localized } from '../../../core/utils/AppResource';
import {
  computeTopBarHeight,
  computeTabBottomInset,
  getMainWindow,
  removeWindowSizeListener
} from '../../utils/SafeAreaUtils';
import { ROOT_TAB_BAR_FALLBACK_CONTENT_INSET } from '../../utils/RootTabBarGeometry';
import { createLoadCallsUseCase, LoadCallsUseCase, LoadCallsParams, CallHistoryRecord } from '../../../domain/usecases/loadCalls';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0031;
const TAG = 'CallsPage';
const LOAD_MORE_THRESHOLD = 6;

class CallRowVO {
  messageId: string = '0';
  name: string = '';
  initials: string = '';
  avatarPath: string = '';
  dateText: string = '';
  labelText: string = '';
  callType: TgCallType = TgCallType.Outgoing;
  isVideo: boolean = false;
}

function padTwo(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

function weekdayShort(day: number): string {
  switch (day) {
    case 0:
      return localized($r('app.string.weekday_sun').id, 'Sun');
    case 1:
      return localized($r('app.string.weekday_mon').id, 'Mon');
    case 2:
      return localized($r('app.string.weekday_tue').id, 'Tue');
    case 3:
      return localized($r('app.string.weekday_wed').id, 'Wed');
    case 4:
      return localized($r('app.string.weekday_thu').id, 'Thu');
    case 5:
      return localized($r('app.string.weekday_fri').id, 'Fri');
    case 6:
      return localized($r('app.string.weekday_sat').id, 'Sat');
    default:
      return localized($r('app.string.weekday_sun').id, 'Sun');
  }
}

function monthShort(month: number): string {
  switch (month) {
    case 0:
      return localized($r('app.string.month_jan').id, 'Jan');
    case 1:
      return localized($r('app.string.month_feb').id, 'Feb');
    case 2:
      return localized($r('app.string.month_mar').id, 'Mar');
    case 3:
      return localized($r('app.string.month_apr').id, 'Apr');
    case 4:
      return localized($r('app.string.month_may').id, 'May');
    case 5:
      return localized($r('app.string.month_jun').id, 'Jun');
    case 6:
      return localized($r('app.string.month_jul').id, 'Jul');
    case 7:
      return localized($r('app.string.month_aug').id, 'Aug');
    case 8:
      return localized($r('app.string.month_sep').id, 'Sep');
    case 9:
      return localized($r('app.string.month_oct').id, 'Oct');
    case 10:
      return localized($r('app.string.month_nov').id, 'Nov');
    case 11:
      return localized($r('app.string.month_dec').id, 'Dec');
    default:
      return '';
  }
}

function formatCallDate(timestampSec: number, nowMs: number = Date.now()): string {
  if (timestampSec <= 0) {
    return '';
  }

  const callDate = new Date(timestampSec * 1000);
  const now = new Date(nowMs);
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const callDayStart = new Date(callDate.getFullYear(), callDate.getMonth(), callDate.getDate()).getTime();
  const diffDays = Math.floor((todayStart - callDayStart) / 86400000);

  if (diffDays === 0) {
    return padTwo(callDate.getHours()) + ':' + padTwo(callDate.getMinutes());
  }
  if (diffDays === 1) {
    return localized($r('app.string.yesterday').id, 'Yesterday');
  }
  if (diffDays < 7) {
    return weekdayShort(callDate.getDay());
  }
  const shortDate = callDate.getDate().toString() + ' ' + monthShort(callDate.getMonth());
  if (callDate.getFullYear() !== now.getFullYear()) {
    return shortDate + ' ' + callDate.getFullYear().toString();
  }
  return shortDate;
}

function buildInitialsFromName(name: string): string {
  const trimmed = name.trim();
  if (trimmed.length === 0) {
    return '?';
  }
  const firstSpace = trimmed.indexOf(' ');
  if (firstSpace > 0 && firstSpace < trimmed.length - 1) {
    return (trimmed.charAt(0) + trimmed.charAt(firstSpace + 1)).toUpperCase();
  }
  return trimmed.charAt(0).toUpperCase();
}

function displayNameForUser(user: User): string {
  const fullName = (user.firstName + ' ' + user.lastName).trim();
  if (fullName.length > 0) {
    return fullName;
  }
  if (user.username.length > 0) {
    return '@' + user.username;
  }
  return localized($r('app.string.calls_unknown').id, 'Unknown');
}

function initialsForUser(user: User): string {
  const first = user.firstName.length > 0 ? user.firstName.charAt(0) : '';
  const last = user.lastName.length > 0 ? user.lastName.charAt(0) : '';
  if (first.length > 0 && last.length > 0) {
    return (first + last).toUpperCase();
  }
  if (first.length > 0) {
    return first.toUpperCase();
  }
  if (user.username.length > 0) {
    return user.username.charAt(0).toUpperCase();
  }
  return '?';
}

@ComponentV2
export struct CallsPage {
  @Param onlyMissed: boolean = false;
  @Local private callRows: CallRowVO[] = [];
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private listBottomInset: number = ROOT_TAB_BAR_FALLBACK_CONTENT_INSET;
  @Local private isLoading: boolean = false;

  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private rebuildTimerId: number = -1;
  private loadMoreTimerId: number = -1;
  private pageLifecycleToken: number = 0;
  private mainWindow?: window.Window;
  private loadCallsUseCase?: LoadCallsUseCase;
  private loadedRecords: CallHistoryRecord[] = [];
  private nextOffset: string = '';
  private hasMore: boolean = true;
  private initialLoadRequested: boolean = false;
  private loadMoreScheduled: boolean = false;
  private callsQueryGeneration: number = 0;

  @Monitor('onlyMissed')
  private onOnlyMissedChanged(_monitor: IMonitor): void {
    this.callsQueryGeneration += 1;
    this.loadedRecords = [];
    this.callRows = [];
    this.nextOffset = '';
    this.hasMore = true;
    this.initialLoadRequested = false;
    this.isLoading = false;
    if (this.unsubscribe !== undefined && this.loadCallsUseCase !== undefined) {
      this.loadInitialIfNeeded();
    }
  }

  private clearRebuildTimer(): void {
    if (this.rebuildTimerId !== -1) {
      clearTimeout(this.rebuildTimerId);
      this.rebuildTimerId = -1;
    }
    this.rebuildScheduled = false;
  }

  private clearLoadMoreTimer(): void {
    if (this.loadMoreTimerId !== -1) {
      clearTimeout(this.loadMoreTimerId);
      this.loadMoreTimerId = -1;
    }
    this.loadMoreScheduled = false;
  }

  private isCurrentLoadCallsContinuation(scheduledToken: number, loadCallsUseCase: LoadCallsUseCase): boolean {
    return scheduledToken === this.pageLifecycleToken && this.loadCallsUseCase === loadCallsUseCase;
  }

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    this.clearRebuildTimer();
    this.clearLoadMoreTimer();
    hilog.info(DOMAIN, TAG, 'CallsPage aboutToAppear');
    this.computeSafeInsets();
    this.bindWindowSizeListener();

    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }

    try {
      const runtime = getAppCoreRuntime();
      const store = runtime.getStore();
      this.loadCallsUseCase = createLoadCallsUseCase(store, getTdGatewayAdapter());
      this.rebuildRows(store.getState());

      const subscriptionToken: number = this.pageLifecycleToken;
      let activeUnsubscribe: (() => void) | undefined = undefined;
      activeUnsubscribe = store.subscribe((_newState: AppState, _prevState: AppState) => {
        if (subscriptionToken !== this.pageLifecycleToken || this.unsubscribe !== activeUnsubscribe) {
          return;
        }
        if (!this.rebuildScheduled) {
          this.rebuildScheduled = true;
          const scheduledToken: number = this.pageLifecycleToken;
          let scheduledTimerId: number = -1;
          scheduledTimerId = setTimeout(() => {
            if (scheduledToken !== this.pageLifecycleToken ||
              this.rebuildTimerId !== scheduledTimerId ||
              this.unsubscribe !== activeUnsubscribe) {
              return;
            }
            this.rebuildTimerId = -1;
            this.rebuildScheduled = false;
            try {
              this.rebuildRows(getAppCoreRuntime().getStore().getState());
            } catch (error) {
              hilog.error(DOMAIN, TAG, 'Calls rebuild failed: %{public}s', String(error));
            }
          }, 300) as number;
          this.rebuildTimerId = scheduledTimerId;
        }
      });
      this.unsubscribe = activeUnsubscribe;

      this.loadInitialIfNeeded();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'CallsPage init failed: %{public}s', String(error));
    }
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.clearRebuildTimer();
    this.clearLoadMoreTimer();
    if (this.isLoading && this.loadedRecords.length === 0) {
      this.initialLoadRequested = false;
    }
    this.isLoading = false;
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    this.loadCallsUseCase = undefined;
    removeWindowSizeListener(this.mainWindow);
    this.mainWindow = undefined;
  }

  private bindWindowSizeListener(): void {
    try {
      removeWindowSizeListener(this.mainWindow);
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.mainWindow = getMainWindow(context);
      if (this.mainWindow !== undefined) {
        const lifecycleToken: number = this.pageLifecycleToken;
        const boundWindow: window.Window = this.mainWindow;
        this.mainWindow.on('windowSizeChange', (_size: window.Size) => {
          if (lifecycleToken !== this.pageLifecycleToken || this.mainWindow !== boundWindow) {
            return;
          }
          this.computeSafeInsets();
        });
      }
    } catch (_error) {
      this.mainWindow = undefined;
    }
  }

  private computeSafeInsets(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topBarTotalHeight = computeTopBarHeight(context);
      this.listBottomInset = computeTabBottomInset(context);
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
      this.listBottomInset = ROOT_TAB_BAR_FALLBACK_CONTENT_INSET;
    }
  }

  private loadInitialIfNeeded(): void {
    if (this.initialLoadRequested) {
      return;
    }
    this.initialLoadRequested = true;
    this.loadedRecords = [];
    this.nextOffset = '';
    this.hasMore = true;
    this.fetchCalls(true);
  }

  private scheduleLoadMore(lastIndex: number): void {
    if (this.isLoading || !this.hasMore || this.callRows.length === 0) {
      return;
    }
    if (lastIndex < this.callRows.length - LOAD_MORE_THRESHOLD) {
      return;
    }
    if (this.loadMoreScheduled) {
      return;
    }
    this.loadMoreScheduled = true;
    const scheduledToken: number = this.pageLifecycleToken;
    let scheduledTimerId: number = -1;
    scheduledTimerId = setTimeout(() => {
      if (scheduledToken !== this.pageLifecycleToken ||
        this.loadMoreTimerId !== scheduledTimerId ||
        this.unsubscribe === undefined) {
        return;
      }
      this.loadMoreTimerId = -1;
      this.loadMoreScheduled = false;
      this.fetchCalls(false);
    }, 0) as number;
    this.loadMoreTimerId = scheduledTimerId;
  }

  private fetchCalls(reset: boolean): void {
    const loadCallsUseCase: LoadCallsUseCase | undefined = this.loadCallsUseCase;
    if (this.isLoading || loadCallsUseCase === undefined) {
      return;
    }
    if (!reset && !this.hasMore) {
      return;
    }

    this.isLoading = true;
    const params = new LoadCallsParams();
    params.offset = reset ? '' : this.nextOffset;
    params.limit = 40;
    params.onlyMissed = this.onlyMissed;

    const scheduledToken: number = this.pageLifecycleToken;
    const queryGeneration: number = this.callsQueryGeneration;
    loadCallsUseCase.execute(params)
      .then((result) => {
        if (!this.isCurrentLoadCallsContinuation(scheduledToken, loadCallsUseCase) ||
          queryGeneration !== this.callsQueryGeneration) {
          return;
        }
        if (reset) {
          this.loadedRecords = [];
        }
        this.appendRecords(result.records);
        this.nextOffset = result.nextOffset;
        this.hasMore = result.hasMore;
        this.rebuildRows(getAppCoreRuntime().getStore().getState());
      })
      .catch((error: Error) => {
        if (!this.isCurrentLoadCallsContinuation(scheduledToken, loadCallsUseCase) ||
          queryGeneration !== this.callsQueryGeneration) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Failed to load calls: %{public}s', error.message);
      })
      .finally(() => {
        if (!this.isCurrentLoadCallsContinuation(scheduledToken, loadCallsUseCase) ||
          queryGeneration !== this.callsQueryGeneration) {
          return;
        }
        this.isLoading = false;
      });
  }

  private appendRecords(records: CallHistoryRecord[]): void {
    if (records.length === 0) {
      return;
    }
    const seen: Set<string> = new Set<string>();
    const merged: CallHistoryRecord[] = [];
    for (const existing of this.loadedRecords) {
      seen.add(existing.messageId);
      merged.push(existing);
    }
    for (const record of records) {
      if (seen.has(record.messageId)) {
        continue;
      }
      seen.add(record.messageId);
      merged.push(record);
    }
    this.loadedRecords = merged;
  }

  private callTypeForRecord(record: CallHistoryRecord): TgCallType {
    if (record.direction === 'missed') {
      return TgCallType.Missed;
    }
    return record.direction === 'incoming' ? TgCallType.Incoming : TgCallType.Outgoing;
  }

  private labelForRecord(record: CallHistoryRecord): string {
    if (record.discardReasonType === 'callDiscardReasonDeclined') {
      return localized($r('app.string.calls_cancelled').id, 'Cancelled');
    }
    if (record.direction === 'missed') {
      return localized($r('app.string.calls_missed_label').id, 'Missed');
    }
    if (record.direction === 'incoming') {
      return localized($r('app.string.calls_incoming_label').id, 'Incoming');
    }
    return localized($r('app.string.calls_outgoing_label').id, 'Outgoing');
  }

  private rebuildRows(state: AppState): void {
    const rows: CallRowVO[] = [];
    for (const record of this.loadedRecords) {
      const row = new CallRowVO();
      row.messageId = record.messageId;
      row.callType = this.callTypeForRecord(record);
      row.dateText = formatCallDate(record.timestamp);
      row.isVideo = record.isVideo;
      row.labelText = this.labelForRecord(record);

      const user = record.peerUserId > 0 ? state.users.users.get(record.peerUserId) : undefined;
      if (user !== undefined) {
        row.name = displayNameForUser(user);
        row.initials = initialsForUser(user);
        row.avatarPath = user.photoSmall.length > 0 ? fileUri.getUriFromPath(user.photoSmall) : '';
      } else {
        const fallbackName = record.fallbackTitle.length > 0
          ? record.fallbackTitle
          : localized($r('app.string.calls_unknown').id, 'Unknown');
        row.name = fallbackName;
        row.initials = buildInitialsFromName(fallbackName);
        row.avatarPath = record.fallbackAvatarPath;
      }

      rows.push(row);
    }
    this.callRows = rows;
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.callRows.length > 0) {
        List() {
          ForEach(this.callRows, (row: CallRowVO, index: number) => {
            ListItem() {
              TgCallRow({
                name: row.name,
                initials: row.initials,
                avatarPath: row.avatarPath,
                callType: row.callType,
                dateText: row.dateText,
                labelText: row.labelText,
                isVideo: row.isVideo,
                showSeparator: index < this.callRows.length - 1
              })
            }
          }, (row: CallRowVO) => row.messageId)
        }
        .width('100%')
        .height('100%')
        .edgeEffect(EdgeEffect.Spring)
        .contentStartOffset(this.topBarTotalHeight + TgUiTokens.CALLS_FILTER_BAR_HEIGHT +
          TgUiTokens.CALLS_FILTER_LIST_GAP)
        .contentEndOffset(this.listBottomInset)
        .onScrollIndex((_first: number, last: number, _center: number) => {
          this.scheduleLoadMore(last);
        })
      } else {
        Column() {
          Text(this.isLoading
            ? localized($r('app.string.loading').id, 'Loading…')
            : this.onlyMissed
              ? localized($r('app.string.calls_no_missed').id, 'No missed calls')
              : localized($r('app.string.calls_no_recent').id, 'No recent calls'))
            .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }

    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
