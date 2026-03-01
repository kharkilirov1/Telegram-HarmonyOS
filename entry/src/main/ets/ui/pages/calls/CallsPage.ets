// CallsPage — Calls tab (Phase E-5)
// Stack overlay: content under translucent TgTopBar
// Currently shows empty state (call history not yet in store)

import { AppShellTokens } from '../../theme/AppShellTokens';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgTopBar } from '../../tg_ui/atoms/TgTopBar';
import { getString } from '../../../core/utils/AppResource';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

declare function px2vp(value: number): number;

@Component
export struct CallsPage {
  @State private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;

  aboutToAppear(): void {
    this.computeTopBarHeight();
  }

  private computeTopBarHeight(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const windowStage = context.windowStage;
      if (windowStage) {
        const mainWindow = windowStage.getMainWindowSync();
        const avoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        const topInset = px2vp(avoidArea.topRect.height);
        this.topBarTotalHeight = topInset + TgUiTokens.TOP_BAR_HEIGHT;
      }
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
    }
  }

  private localized(resourceId: number, fallback: string): string {
    const value = getString(resourceId);
    return value.length > 0 ? value : fallback;
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        Text(this.localized($r('app.string.no_recent_calls').id, 'No recent calls'))
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      TgTopBar({ title: this.localized($r('app.string.calls_title').id, 'Calls') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppShellTokens.BACKGROUND)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
