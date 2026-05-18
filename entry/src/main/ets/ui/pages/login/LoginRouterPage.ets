// LoginRouterPage — Root entry point
// Conditionally renders login flow or MainTabsPage based on auth status
// Transition logic adapts Telegram iOS: spinner → wait for data → show tabs

import { LoginRouter } from './LoginRouter';
import { MainTabsPage } from '../MainTabsPage';
import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'LoginRouterPage';

// Timing constants (adapted from Telegram iOS AppDelegate.swift)
const MIN_WAIT_MS = 750;   // iOS: 0.75s delay before dismiss
const MAX_WAIT_MS = 4000;  // iOS: 4.0s timeout on context ready
const POLL_INTERVAL_MS = 100;

@Entry
@ComponentV2
struct LoginRouterPage {
  pageStack: NavPathStack = new NavPathStack();
  @Local showMainUI: boolean = false;

  private pageLifecycleToken: number = 0;
  private transitionTimerId: number = -1;

  private isCurrentTransitionCallback(scheduledToken: number): boolean {
    return scheduledToken === this.pageLifecycleToken;
  }

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    // If already authenticated (app restart), skip login flow
    const currentAuth = AppStorage.get<string>(StorageKeys.AUTH_STATUS);
    if (currentAuth === 'ready') {
      this.showMainUI = true;
      hilog.info(DOMAIN, TAG, 'Already authenticated — showing main UI');
    } else {
      AppStorage.setOrCreate('pageStack', this.pageStack);
      hilog.info(DOMAIN, TAG, 'Not authenticated — showing login flow');
    }
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.clearTransitionTimer();
  }

  /**
   * Wait for data readiness before showing MainTabsPage.
   * Adapts iOS pattern: isReady signal + timeout.
   *
   * - MIN_WAIT: minimum spinner time (UI preparation)
   * - Polls connectionStatus + dialogsCount every 100ms
   * - MAX_WAIT: safety timeout (show tabs regardless)
   */
  private waitForDataAndTransition(): void {
    const transitionToken: number = this.pageLifecycleToken;
    const startTime = Date.now();

    const check = (): void => {
      if (!this.isCurrentTransitionCallback(transitionToken)) {
        return;
      }
      const elapsed = Date.now() - startTime;
      const connStatus = AppStorage.get<string>(StorageKeys.CONNECTION_STATUS) || '';
      const chatCount = AppStorage.get<number>(StorageKeys.CHATS_COUNT) || 0;
      const chatsIsLoading = AppStorage.get<boolean>(StorageKeys.CHATS_IS_LOADING) || false;
      const chatsLoadPhase = AppStorage.get<string>(StorageKeys.CHATS_LOAD_PHASE) || 'idle';
      const dataReady = (connStatus === 'ready' && !chatsIsLoading && chatsLoadPhase !== 'bootstrap') || chatCount > 0;

      if ((dataReady && elapsed >= MIN_WAIT_MS) || elapsed >= MAX_WAIT_MS) {
        hilog.info(DOMAIN, TAG,
          'Transitioning to main UI (elapsed=%{public}dms, chats=%{public}d, conn=%{public}s, chatsLoading=%{public}s, chatsPhase=%{public}s)',
          elapsed, chatCount, connStatus, chatsIsLoading ? 'true' : 'false', chatsLoadPhase);
        this.showMainUI = true;
      } else {
        this.scheduleTransitionCheck(check, POLL_INTERVAL_MS);
      }
    };

    // Start polling after minimum wait
    this.scheduleTransitionCheck(check, MIN_WAIT_MS);
  }

  private scheduleTransitionCheck(callback: () => void, delayMs: number): void {
    this.clearTransitionTimer();
    const timerId: number = setTimeout(() => {
      if (this.transitionTimerId !== timerId) {
        return;
      }
      this.transitionTimerId = -1;
      callback();
    }, delayMs) as number;
    this.transitionTimerId = timerId;
  }

  private clearTransitionTimer(): void {
    if (this.transitionTimerId !== -1) {
      clearTimeout(this.transitionTimerId);
      this.transitionTimerId = -1;
    }
  }

  @Builder
  PageMap(name: string) {
  }

  build() {
    Stack() {
      if (this.showMainUI) {
        MainTabsPage()
          .transition(TransitionEffect.OPACITY.animation({ duration: 250 }))
      } else {
        Navigation(this.pageStack) {
          Column() {
            LoginRouter({
              onAuthComplete: (): void => {
                hilog.info(DOMAIN, TAG, 'Auth complete — waiting for data...');
                this.waitForDataAndTransition();
              }
            })
          }
          .width('100%')
          .height('100%')
        }
        .hideTitleBar(true)
        .hideToolBar(true)
        .navDestination(this.PageMap)
        .mode(NavigationMode.Stack)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
    }
    .width('100%')
    .height('100%')
  }
}
