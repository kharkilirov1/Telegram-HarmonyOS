// PhoneConfirmationDialog — подтверждение номера перед отправкой
// Референс: Telegram iOS PhoneConfirmationController
//
// iOS: всплывающая карточка с анимацией увеличения номера
// Показывает код и номер крупным шрифтом, кнопки "Edit" и "Continue"

import { TgColor, TgSize } from '../../theme/TelegramTheme';
import { SolidRoundedButton, ButtonState } from './SolidRoundedButton';

@CustomDialog
export struct PhoneConfirmationDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: PhoneConfirmationDialog });
  @Prop countryCode: string = '+1';
  @Prop phoneNumber: string = '';
  @Prop buttonState: ButtonState = 'default';
  onConfirm: () => void = (): void => {};
  onEdit: () => void = (): void => {};

  build() {
    Column({ space: 0 }) {
      // iOS: код + номер крупным шрифтом
      Row({ space: 10 }) {
        Text(this.countryCode)
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(TgColor.PRIMARY)

        Text(this.phoneNumber)
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(TgColor.PRIMARY)
          .letterSpacing(1.6)  // iOS: kern = 1.6
      }
      .justifyContent(FlexAlign.Center)
      .padding({ top: 30 })

      // iOS: "Is this the correct number?"
      Text('Is this the correct number?')
        .fontSize(17)
        .fontColor(TgColor.PRIMARY)
        .textAlign(TextAlign.Center)
        .padding({ top: 24 })

      // iOS: "Edit" link
      Text('Edit')
        .fontSize(19)
        .fontColor(TgColor.ACCENT)
        .padding({ top: 25 })
        .onClick(() => {
          this.onEdit();
          this.controller.close();
        })

      // iOS: SolidRoundedButtonNode "Continue"
      Column() {
        SolidRoundedButton({
          title: 'Continue',
          isEnabled: true,
          buttonState: this.buttonState,
          onPress: (): void => { this.onConfirm(); }
        })
      }
      .width('100%')
      .padding({
        left: TgSize.CONFIRM_INNER_INSET,
        right: TgSize.CONFIRM_INNER_INSET,
        top: 20,
        bottom: TgSize.CONFIRM_INNER_INSET
      })
    }
    .width('100%')
    .padding({ bottom: 0 })
    .borderRadius(TgSize.CONFIRM_CORNER)
    .backgroundColor(TgColor.CARD_BG)
  }
}
