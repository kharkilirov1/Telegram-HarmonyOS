@ComponentV2
export struct GroupAdminPermissionsSection {
  @Param canSendMessages: boolean = true;
  @Param canSendMedia: boolean = true;
  @Param canSendPolls: boolean = true;
  @Param canSendStickers: boolean = true;
  @Param canAddMembers: boolean = true;
  @Param canPinMessages: boolean = true;
  @Param canChangeInfo: boolean = true;

  @Event onSendMessagesChange: (isOn: boolean) => void = (_isOn: boolean) => {};
  @Event onSendMediaChange: (isOn: boolean) => void = (_isOn: boolean) => {};
  @Event onSendPollsChange: (isOn: boolean) => void = (_isOn: boolean) => {};
  @Event onSendStickersChange: (isOn: boolean) => void = (_isOn: boolean) => {};
  @Event onAddMembersChange: (isOn: boolean) => void = (_isOn: boolean) => {};
  @Event onPinMessagesChange: (isOn: boolean) => void = (_isOn: boolean) => {};
  @Event onChangeInfoChange: (isOn: boolean) => void = (_isOn: boolean) => {};

  build() {
    Column() {
      Text($r('app.string.permissions_label'))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 8 })

      Column() {
        this.permissionRow($r('app.string.send_messages'), this.canSendMessages, (isOn: boolean) => {
          this.onSendMessagesChange(isOn);
        })
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

        this.permissionRow($r('app.string.send_media'), this.canSendMedia, (isOn: boolean) => {
          this.onSendMediaChange(isOn);
        })
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

        this.permissionRow($r('app.string.send_polls'), this.canSendPolls, (isOn: boolean) => {
          this.onSendPollsChange(isOn);
        })
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

        this.permissionRow($r('app.string.send_stickers_gifs'), this.canSendStickers, (isOn: boolean) => {
          this.onSendStickersChange(isOn);
        })
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

        this.permissionRow($r('app.string.add_members'), this.canAddMembers, (isOn: boolean) => {
          this.onAddMembersChange(isOn);
        })
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

        this.permissionRow($r('app.string.pin_messages'), this.canPinMessages, (isOn: boolean) => {
          this.onPinMessagesChange(isOn);
        })
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

        this.permissionRow($r('app.string.change_group_info'), this.canChangeInfo, (isOn: boolean) => {
          this.onChangeInfoChange(isOn);
        })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private permissionRow(label: string | Resource, isOn: boolean, onChange: (isOn: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.telegram_blue'))
        .onChange((value: boolean) => {
          onChange(value);
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
  }
}
