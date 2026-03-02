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
@Component
struct LoginRouterPage {
  pageStack: NavPathStack = new NavPathStack();
  @State showMainUI: boolean = false;

  aboutToAppear(): void {
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

  /**
   * Wait for data readiness before showing MainTabsPage.
   * Adapts iOS pattern: isReady signal + timeout.
   *
   * - MIN_WAIT: minimum spinner time (UI preparation)
   * - Polls connectionStatus + dialogsCount every 100ms
   * - MAX_WAIT: safety timeout (show tabs regardless)
   */
  private waitForDataAndTransition(): void {
    const startTime = Date.now();

    const check = (): void => {
      const elapsed = Date.now() - startTime;
      const connStatus = AppStorage.get<string>(StorageKeys.CONNECTION_STATUS) || '';
      const chatCount = AppStorage.get<number>(StorageKeys.CHATS_COUNT) || 0;
      const dataReady = connStatus === 'ready' || chatCount > 0;

      if ((dataReady && elapsed >= MIN_WAIT_MS) || elapsed >= MAX_WAIT_MS) {
        hilog.info(DOMAIN, TAG, 'Transitioning to main UI (elapsed=%{public}dms, chats=%{public}d, conn=%{public}s)',
          elapsed, chatCount, connStatus);
        this.showMainUI = true;
      } else {
        setTimeout(check, POLL_INTERVAL_MS);
      }
    };

    // Start polling after minimum wait
    setTimeout(check, MIN_WAIT_MS);
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
