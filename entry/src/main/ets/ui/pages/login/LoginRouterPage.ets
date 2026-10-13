// LoginRouterPage — Root entry point
// Conditionally renders login flow or MainTabsPage based on auth status
// Transition logic adapts Telegram iOS: spinner → wait for data → show tabs

import { LoginRouter } from './LoginRouter';
import { MainTabsPage } from '../MainTabsPage';
import { StorageKeys } from '../../../app/bridge/AppStoreBridge';
import { AppCoreRuntime, getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'LoginRouterPage';

// Timing constants (adapted from Telegram iOS AppDelegate.swift)
const MIN_WAIT_MS = 750;   // iOS: 0.75s delay before dismiss
const MAX_WAIT_MS = 4000;  // iOS: 4.0s timeout on context ready
const POLL_INTERVAL_MS = 100;

@Entry
@ComponentV2
export struct LoginRouterPage {
  @Param runtimeProvider: () => AppCoreRuntime = getAppCoreRuntime;
  pageStack: NavPathStack = new NavPathStack();
  @Local showMainUI: boolean = false;

  private pageLifecycleToken: number = 0;
  private transitionGeneration: number = 0;
  private transitionTimerId: number = -1;
  private unsubscribe?: () => void;

  private isCurrentTransitionCallback(scheduledToken: number, scheduledGeneration: number): boolean {
    return scheduledToken === this.pageLifecycleToken && scheduledGeneration === this.transitionGeneration;
  }

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    this.invalidateTransition();
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
    const store = this.runtimeProvider().getLifecycleStore();
    const subscriptionToken: number = this.pageLifecycleToken;
    let activeUnsubscribe: (() => void) | undefined = undefined;
    activeUnsubscribe = store.subscribe((state, prevState) => {
      if (subscriptionToken !== this.pageLifecycleToken || this.unsubscribe !== activeUnsubscribe) {
        return;
      }
      // Network reconnect is not auth loss. Keep this root subscription across accounts.
      if (state.auth.status === prevState.auth.status) {
        return;
      }
      if (state.auth.status !== 'ready') {
        this.showMainUI = false;
        this.invalidateTransition();
        if (prevState.auth.status === 'ready') {
          this.clearAccountNavigation();
        }
      } else {
        this.waitForDataAndTransition();
      }
    });
    this.unsubscribe = activeUnsubscribe;
    // If already authenticated (app restart), skip login flow
    const currentAuth = store.getState().auth.status;
    this.showMainUI = currentAuth === 'ready';
    if (currentAuth === 'ready') {
      hilog.info(DOMAIN, TAG, 'Already authenticated — showing main UI');
    } else {
      this.clearAccountNavigation();
      hilog.info(DOMAIN, TAG, 'Not authenticated — showing login flow');
    }
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.invalidateTransition();
    if (this.unsubscribe !== undefined) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
  }

  private invalidateTransition(): void {
    this.transitionGeneration += 1;
    this.clearTransitionTimer();
  }

  private clearAccountNavigation(): void {
    // The bridge may still point at a stack owned by the previous account UI.
    const storedStack = AppStorage.get<NavPathStack>('pageStack');
    if (storedStack !== undefined && storedStack !== this.pageStack) {
      storedStack.clear();
    }
    this.pageStack.clear();
    AppStorage.setOrCreate('pageStack', this.pageStack);
  }

  /**
   * Wait for data readiness before showing MainTabsPage.
   * Adapts iOS pattern: isReady signal + timeout.
   *
   * - MIN_WAIT: minimum spinner time (UI preparation)
   * - Polls connectionStatus + dialogsCount every 100ms
   * - MAX_WAIT: data timeout (never bypasses current auth readiness)
   */
  private waitForDataAndTransition(): void {
    if (this.unsubscribe === undefined || this.showMainUI || this.transitionTimerId !== -1 ||
        this.runtimeProvider().getLifecycleStore().getState().auth.status !== 'ready') {
      return;
    }
    const transitionToken: number = this.pageLifecycleToken;
    const transitionGeneration: number = this.transitionGeneration;
    const startTime = Date.now();

    const check = (): void => {
      if (!this.isCurrentTransitionCallback(transitionToken, transitionGeneration)) {
        return;
      }
      if (this.runtimeProvider().getLifecycleStore().getState().auth.status !== 'ready') {
        this.showMainUI = false;
        this.invalidateTransition();
        this.clearAccountNavigation();
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
              runtimeProvider: this.runtimeProvider,
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
