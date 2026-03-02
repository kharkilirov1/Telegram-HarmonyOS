// CallsPage — Calls tab (Phase E-5)
// Stack overlay: content under translucent TgTopBar
// Currently shows empty state (call history not yet in store)

import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { TgTopBar } from '../../tg_ui/atoms/TgTopBar';
import { localized } from '../../../core/utils/AppResource';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';
import { common } from '@kit.AbilityKit';

@Component
export struct CallsPage {
  @State private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;

  aboutToAppear(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topBarTotalHeight = computeTopBarHeight(context);
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        Text(localized($r('app.string.no_recent_calls').id, 'No recent calls'))
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      TgTopBar({ title: localized($r('app.string.calls_title').id, 'Calls') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
