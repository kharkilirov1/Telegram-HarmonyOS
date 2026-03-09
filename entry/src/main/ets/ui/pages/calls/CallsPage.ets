// CallsPage — Calls tab with real TDLib-backed recent calls list.
// Grounding:
// - HarmonyOS docs: List + ListItem + onScrollIndex for paginated list rendering
// - Android ref: CallLogActivity loads call history via server search + paginates near list end
// - iOS ref: CallListController is backed by a real call list, not placeholder text

import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { AppState, User } from '../../../core/model/AppState';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgTopBar } from '../../tg_ui/atoms/TgTopBar';
import { fileUri } from '@kit.CoreFileKit';
import { TgCallRow, TgCallType } from '../../tg_ui/atoms/TgCallRow';
import { localized } from '../../../core/utils/AppResource';
import {
  computeTopBarHeight,
  computeTabBottomInset,
  getMainWindow,
  removeWindowSizeListener
} from '../../utils/SafeAreaUtils';
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

function formatCallDate(timestampSec: number): string {
  if (timestampSec <= 0) {
    return '';
  }

  const callDate = new Date(timestampSec * 1000);
  const now = new Date();
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
  return padTwo(callDate.getDate()) + '.' + padTwo(callDate.getMonth() + 1) + '.' + padTwo(callDate.getFullYear() % 100);
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

@Component
export struct CallsPage {
  @State private callRows: CallRowVO[] = [];
  @State private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @State private listBottomInset: number = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;
  @State private isLoading: boolean = false;

  private unsubscribe?: () => void;
  private rebuildScheduled: boolean = false;
  private mainWindow?: window.Window;
  private loadCallsUseCase?: LoadCallsUseCase;
  private loadedRecords: CallHistoryRecord[] = [];
  private nextFromMessageId: string = '0';
  private hasMore: boolean = true;
  private initialLoadRequested: boolean = false;
  private loadMoreScheduled: boolean = false;

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'CallsPage aboutToAppear');
    this.computeSafeInsets();
    this.bindWindowSizeListener();

    try {
      const runtime = getAppCoreRuntime();
      const store = runtime.getStore();
      this.loadCallsUseCase = createLoadCallsUseCase(store, getTdGatewayAdapter());
      this.rebuildRows(store.getState());

      this.unsubscribe = store.subscribe((_newState: AppState, _prevState: AppState) => {
        if (!this.rebuildScheduled) {
          this.rebuildScheduled = true;
          setTimeout(() => {
            this.rebuildScheduled = false;
            try {
              this.rebuildRows(getAppCoreRuntime().getStore().getState());
            } catch (error) {
              hilog.error(DOMAIN, TAG, 'Calls rebuild failed: %{public}s', String(error));
            }
          }, 0);
        }
      });

      this.loadInitialIfNeeded();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'CallsPage init failed: %{public}s', String(error));
    }
  }

  aboutToDisappear(): void {
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    removeWindowSizeListener(this.mainWindow);
    this.mainWindow = undefined;
  }

  private bindWindowSizeListener(): void {
    try {
      removeWindowSizeListener(this.mainWindow);
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.mainWindow = getMainWindow(context);
      if (this.mainWindow !== undefined) {
        this.mainWindow.on('windowSizeChange', (_size: window.Size) => {
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
      this.listBottomInset = TgUiTokens.TAB_BAR_CONTENT_SAFE_BOTTOM;
    }
  }

  private loadInitialIfNeeded(): void {
    if (this.initialLoadRequested) {
      return;
    }
    this.initialLoadRequested = true;
    this.loadedRecords = [];
    this.nextFromMessageId = '0';
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
    setTimeout(() => {
      this.loadMoreScheduled = false;
      this.fetchCalls(false);
    }, 0);
  }

  private fetchCalls(reset: boolean): void {
    if (this.isLoading || !this.loadCallsUseCase) {
      return;
    }
    if (!reset && !this.hasMore) {
      return;
    }

    this.isLoading = true;
    const params = new LoadCallsParams();
    params.fromMessageId = reset ? '0' : this.nextFromMessageId;
    params.limit = 40;
    params.onlyMissed = false;

    this.loadCallsUseCase.execute(params)
      .then((result) => {
        if (reset) {
          this.loadedRecords = [];
        }
        this.appendRecords(result.records);
        this.nextFromMessageId = result.nextFromMessageId;
        this.hasMore = result.hasMore;
        this.rebuildRows(getAppCoreRuntime().getStore().getState());
      })
      .catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Failed to load calls: %{public}s', error.message);
      })
      .finally(() => {
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
      return record.isVideo
        ? localized($r('app.string.message_call_declined_video').id, 'Declined video call')
        : localized($r('app.string.message_call_declined_voice').id, 'Declined voice call');
    }
    if (record.direction === 'missed') {
      return record.isVideo
        ? localized($r('app.string.message_call_missed_video').id, 'Missed video call')
        : localized($r('app.string.message_call_missed_voice').id, 'Missed voice call');
    }
    if (record.direction === 'incoming') {
      return record.isVideo
        ? localized($r('app.string.message_call_incoming_video').id, 'Incoming video call')
        : localized($r('app.string.message_call_incoming_voice').id, 'Incoming voice call');
    }
    return record.isVideo
      ? localized($r('app.string.message_call_outgoing_video').id, 'Outgoing video call')
      : localized($r('app.string.message_call_outgoing_voice').id, 'Outgoing voice call');
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
        .contentStartOffset(this.topBarTotalHeight)
        .contentEndOffset(this.listBottomInset)
        .onScrollIndex((_first: number, last: number, _center: number) => {
          this.scheduleLoadMore(last);
        })
      } else {
        Column() {
          Text(this.isLoading
            ? localized($r('app.string.loading').id, 'Loading…')
            : localized($r('app.string.calls_no_recent').id, 'No recent calls'))
            .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }

      TgTopBar({ title: localized($r('app.string.calls_title').id, 'Calls') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
