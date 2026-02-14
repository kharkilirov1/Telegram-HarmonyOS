// PassportPage — Telegram Passport identity documents
// Reference: Telegram iOS PassportController, Android PassportActivity

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatService } from '../../services/ChatService';

@Builder
export function PassportBuilder(name: string, param: Object) {
  PassportPage()
}

interface PassportField {
  icon: Resource;
  title: Resource;
  type: string;
}

@ComponentV2
export struct PassportPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local hasPassport: boolean = false;

  private readonly fields: PassportField[] = [
    { icon: $r('app.media.ic_contact'), title: $r('app.string.passport_personal_details'), type: 'personalDetails' },
    { icon: $r('app.media.ic_document'), title: $r('app.string.passport_id_document'), type: 'idDocument' },
    { icon: $r('app.media.ic_location'), title: $r('app.string.passport_address'), type: 'address' },
    { icon: $r('app.media.ic_phone_call'), title: $r('app.string.passport_phone'), type: 'phone' },
    { icon: $r('app.media.ic_edit'), title: $r('app.string.passport_email'), type: 'email' },
  ];

  aboutToAppear(): void {
    this.loadPassportData();
  }

  private async loadPassportData(): Promise<void> {
    try {
      const result = await ChatService.getInstance().getPassportAuthorizationForm(0, '', '');
      this.hasPassport = result !== null;
    } catch (e) {
      hilog.warn(0x0001, 'PassportPage', 'Failed to load passport authorization form');
      this.hasPassport = false;
    }
  }

  build() {
    NavDestination() {
      Column() {
        // Title bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .padding(12)
            .onClick(() => this.navPathStack.pop())
            .accessibilityText($r('app.string.accessibility_back'))

          Text($r('app.string.passport_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
            .layoutWeight(1)
        }
        .width('100%')
        .height(48)
        .padding({ left: 4, right: 12 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 24, bottomRight: 24 })
        .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 2 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        Scroll() {
          Column() {
            // Header
            Column() {
              Image($r('app.media.ic_document'))
                .width(56).height(56)
                .fillColor($r('app.color.telegram_blue'))
                .margin({ top: 32 })

              Text($r('app.string.passport_title'))
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .margin({ top: 16 })

              Text($r('app.string.passport_subtitle'))
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
                .margin({ top: 8 })
                .padding({ left: 40, right: 40 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding({ bottom: 24 })

            // Fields
            Column() {
              ForEach(this.fields, (field: PassportField, index: number) => {
                Row() {
                  Image(field.icon)
                    .width(24).height(24)
                    .fillColor($r('app.color.telegram_blue'))

                  Text(field.title)
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                    .margin({ left: 14 })
                    .layoutWeight(1)

                  Image($r('app.media.ic_arrow_right'))
                    .width(16).height(16)
                    .fillColor($r('app.color.text_secondary'))
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 14, bottom: 14 })

                if (index < this.fields.length - 1) {
                  Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })
                }
              }, (field: PassportField, index: number) => `passport_${index}`)
            }
            .backgroundColor($r('app.color.glass_card_bg'))
            .borderRadius(24)
            .margin({ left: 12, right: 12 })

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
