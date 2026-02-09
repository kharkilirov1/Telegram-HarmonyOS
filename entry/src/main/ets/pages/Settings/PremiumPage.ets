// PremiumPage — Telegram Premium features showcase
// Reference: Telegram iOS PremiumIntroScreen, Android PremiumPreviewFragment

import { hilog } from '@kit.PerformanceAnalysisKit';
import { UserService } from '../../services/UserService';

@Builder
export function PremiumBuilder(name: string, param: Object) {
  PremiumPage()
}

interface PremiumFeature {
  icon: Resource;
  title: Resource;
  color: Resource;
}

@ComponentV2
export struct PremiumPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local isPremium: boolean = false;
  @Local isLoading: boolean = true;

  private readonly features: PremiumFeature[] = [
    { icon: $r('app.media.ic_emoji'), title: $r('app.string.premium_feature_reactions'), color: $r('app.color.settings_icon_orange') },
    { icon: $r('app.media.ic_sticker'), title: $r('app.string.premium_feature_stickers'), color: $r('app.color.settings_icon_blue') },
    { icon: $r('app.media.ic_document'), title: $r('app.string.premium_feature_upload'), color: $r('app.color.settings_icon_green') },
    { icon: $r('app.media.ic_arrow_down'), title: $r('app.string.premium_feature_speed'), color: $r('app.color.telegram_blue') },
    { icon: $r('app.media.ic_mute'), title: $r('app.string.premium_feature_voice_text'), color: $r('app.color.settings_icon_purple') },
    { icon: $r('app.media.ic_unmute'), title: $r('app.string.premium_feature_no_ads'), color: $r('app.color.settings_icon_red') },
  ];

  aboutToAppear(): void {
    this.checkPremiumStatus();
  }

  private async checkPremiumStatus(): Promise<void> {
    try {
      this.isPremium = await UserService.getInstance().isPremium();
    } catch (e) {
      hilog.warn(0x0001, 'PremiumPage', 'Failed to check premium status');
      this.isPremium = false;
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

          Text($r('app.string.telegram_premium'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
            .layoutWeight(1)
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))

        Scroll() {
          Column() {
            // Premium icon / badge
            Column() {
              Text('⭐')
                .fontSize(64)
                .margin({ top: 32 })

              Text($r('app.string.telegram_premium'))
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .margin({ top: 12 })

              Text($r('app.string.premium_subtitle'))
                .fontSize(15)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 8 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding({ bottom: 24 })

            // Features list
            Column() {
              ForEach(this.features, (feature: PremiumFeature, index: number) => {
                Row() {
                  Column() {
                    Image(feature.icon)
                      .width(20).height(20)
                      .fillColor($r('app.color.icon_on_primary'))
                  }
                  .width(36).height(36)
                  .borderRadius(18)
                  .backgroundColor(feature.color)
                  .justifyContent(FlexAlign.Center)

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
                  Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 66 })
                }
              }, (feature: PremiumFeature, index: number) => `premium_${index}`)
            }
            .backgroundColor($r('app.color.glass_card_bg'))
            .borderRadius(16)
            .margin({ left: 16, right: 16 })

            // Subscribe button
            if (!this.isPremium) {
              Button($r('app.string.premium_subscribe'))
                .width('90%')
                .height(48)
                .borderRadius(24)
                .backgroundColor($r('app.color.telegram_blue'))
                .fontColor($r('app.color.icon_on_primary'))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .margin({ top: 32 })
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
