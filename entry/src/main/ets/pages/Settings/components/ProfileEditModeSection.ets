@ComponentV2
export struct ProfileEditModeSection {
  @Param photoUrl: string | null = null;
  @Param initials: string = '?';
  @Param editFirstName: string = '';
  @Param editLastName: string = '';
  @Param editBio: string = '';
  @Param editUsername: string = '';

  @Event onFirstNameChange: (value: string) => void = (_value: string) => {};
  @Event onLastNameChange: (value: string) => void = (_value: string) => {};
  @Event onBioChange: (value: string) => void = (_value: string) => {};
  @Event onUsernameChange: (value: string) => void = (_value: string) => {};

  @Builder
  private editField(label: string, value: string, onChange: (value: string) => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.telegram_blue'))
        .width(100)

      TextInput({ text: value, placeholder: label })
        .fontSize(16)
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .onChange((newValue: string) => {
          onChange(newValue);
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
  }

  build() {
    Column() {
      Column() {
        Stack({ alignContent: Alignment.BottomEnd }) {
          if (this.photoUrl) {
            Image(this.photoUrl)
              .alt($r('app.media.app_icon'))
              .autoResize(true)
              .onError(() => {})
              .width(100)
              .height(100)
              .borderRadius(50)
          } else {
            Text(this.initials)
              .fontSize(40)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width(100)
              .height(100)
              .borderRadius(50)
              .backgroundColor($r('app.color.telegram_blue'))
              .textAlign(TextAlign.Center)
          }

          Column() {
            Image($r('app.media.ic_photo'))
              .width(16)
              .height(16)
              .fillColor(Color.White)
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor($r('app.color.telegram_blue'))
          .justifyContent(FlexAlign.Center)
          .position({ right: 0, bottom: 0 })
        }

        Text($r('app.string.profile_set_photo'))
          .fontSize(14)
          .fontColor($r('app.color.telegram_blue'))
          .margin({ top: 10 })
      }
      .width('100%')
      .padding({ top: 24, bottom: 16 })
      .alignItems(HorizontalAlign.Center)

      Column() {
        this.editField(getContext(this).resourceManager.getStringByNameSync('profile_first_name'), this.editFirstName, (value: string) => {
          this.onFirstNameChange(value);
        })
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
        this.editField(getContext(this).resourceManager.getStringByNameSync('profile_last_name'), this.editLastName, (value: string) => {
          this.onLastNameChange(value);
        })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(24)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 12, right: 12 })

      Blank().height(24)

      Column() {
        this.editField(getContext(this).resourceManager.getStringByNameSync('profile_bio'), this.editBio, (value: string) => {
          this.onBioChange(value);
        })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(24)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 12, right: 12 })

      Text($r('app.string.profile_bio_hint'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 32, top: 6 })

      Blank().height(24)

      Column() {
        this.editField(getContext(this).resourceManager.getStringByNameSync('profile_username'), this.editUsername, (value: string) => {
          this.onUsernameChange(value);
        })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(24)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 12, right: 12 })

      Text($r('app.string.profile_username_hint'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 32, top: 6, right: 32 })

      Blank().height(40)
    }
    .width('100%')
  }
}
