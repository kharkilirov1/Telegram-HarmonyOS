@ComponentV2
export struct BiometricOptionsCard {
  @Param biometricEnabled: boolean = false;
  @Param autoLockLabel: Resource = $r('app.string.auto_lock_disabled');
  @Param showNotificationsContent: boolean = true;

  @Event onBiometricToggle: (isOn: boolean) => void = (_isOn: boolean) => {};
  @Event onOpenAutoLock: () => void = () => {};
  @Event onNotificationsToggle: (isOn: boolean) => void = (_isOn: boolean) => {};

  build() {
    Column() {
      Row() {
        Text($r('app.string.use_biometric'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.biometricEnabled })
          .selectedColor($r('app.color.telegram_blue'))
          .accessibilityText($r('app.string.accessibility_toggle_biometric'))
          .onChange((isOn: boolean) => {
            this.onBiometricToggle(isOn);
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })

      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

      Row() {
        Text($r('app.string.auto_lock_timeout'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Text(this.autoLockLabel)
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))

        Image($r('app.media.ic_forward'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.text_secondary'))
          .margin({ left: 6 })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.onOpenAutoLock();
      })

      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

      Row() {
        Text($r('app.string.show_notifications_content'))
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.showNotificationsContent })
          .selectedColor($r('app.color.telegram_blue'))
          .onChange((isOn: boolean) => {
            this.onNotificationsToggle(isOn);
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(24)
    .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    .margin({ left: 12, right: 12 })
  }
}
