// BusinessAccountPage — Telegram Business features
// Reference: Telegram iOS BusinessAccountSetup, Android BusinessActivity

import { hilog } from '@kit.PerformanceAnalysisKit';
import { UserService } from '../../services/UserService';

@Builder
export function BusinessAccountBuilder(name: string, param: Object) {
  BusinessAccountPage()
}

interface BusinessFeature {
  icon: Resource;
  title: Resource;
  type: string;
}

@ComponentV2
export struct BusinessAccountPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local isBusiness: boolean = false;
  @Local isLoading: boolean = true;

  private readonly features: BusinessFeature[] = [
    { icon: $r('app.media.ic_location'), title: $r('app.string.business_location'), type: 'location' },
    { icon: $r('app.media.ic_settings'), title: $r('app.string.business_hours'), type: 'hours' },
    { icon: $r('app.media.ic_edit'), title: $r('app.string.business_greeting'), type: 'greeting' },
    { icon: $r('app.media.ic_mute'), title: $r('app.string.business_away'), type: 'away' },
    { icon: $r('app.media.ic_send'), title: $r('app.string.business_quick_replies'), type: 'quick_replies' },
    { icon: $r('app.media.ic_settings'), title: $r('app.string.business_chatbots'), type: 'chatbots' },
  ];

  aboutToAppear(): void {
    this.checkBusinessStatus();
  }

  private async checkBusinessStatus(): Promise<void> {
    try {
      // Business features require premium
      this.isBusiness = await UserService.getInstance().isPremium();
    } catch (e) {
      hilog.warn(0x0001, 'BusinessAccountPage', 'Failed to check business status');
      this.isBusiness = false;
    }
    this.isLoading = false;
  }

  build() {
    NavDestination() {
      Column() {
        // Title bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => this.navPathStack.pop())
            .accessibilityText($r('app.string.accessibility_back'))

          Text($r('app.string.business_account'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
            .layoutWeight(1)
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 16, bottomRight: 16 })
        .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 2 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        Scroll() {
          Column() {
            // Header
            Column() {
              Image($r('app.media.ic_settings'))
                .width(56).height(56)
                .fillColor($r('app.color.telegram_blue'))
                .margin({ top: 32 })

              Text($r('app.string.business_account'))
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .margin({ top: 16 })

              Text($r('app.string.business_subtitle'))
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
                .margin({ top: 8 })
                .padding({ left: 40, right: 40 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding({ bottom: 24 })

            // Feature list
            Column() {
              ForEach(this.features, (feature: BusinessFeature, index: number) => {
                Row() {
                  Image(feature.icon)
                    .width(24).height(24)
                    .fillColor($r('app.color.telegram_blue'))

                  Text(feature.title)
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                    .margin({ left: 14 })
                    .layoutWeight(1)

                  Image($r('app.media.ic_settings'))
                    .width(16).height(16)
                    .fillColor($r('app.color.text_secondary'))
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 14, bottom: 14 })

                if (index < this.features.length - 1) {
                  Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })
                }
              }, (feature: BusinessFeature, index: number) => `business_${index}`)
            }
            .backgroundColor($r('app.color.glass_card_bg'))
            .borderRadius(24)
            .margin({ left: 12, right: 12 })

            // Premium required notice
            if (!this.isBusiness) {
              Text($r('app.string.premium_subscribe'))
                .fontSize(14)
                .fontColor($r('app.color.telegram_blue'))
                .fontWeight(FontWeight.Medium)
                .textAlign(TextAlign.Center)
                .margin({ top: 24 })
                .onClick(() => {
                  this.navPathStack.pushPath(new NavPathInfo('Premium', new Object()));
                })
            }

            Blank().height(40)
          }
          .width('100%')
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
    }
    .hideTitleBar(true)
  }
}
