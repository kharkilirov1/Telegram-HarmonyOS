@Builder
export function ProfileBuilder(name: string, param: Object) {
  ProfilePage()
}

@ComponentV2
export struct ProfilePage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  @Local firstName: string = 'User';
  @Local lastName: string = '';
  @Local username: string = '';
  @Local phoneNumber: string = '+1 234 567 890';
  @Local bio: string = '';
  @Local photoUrl: string | null = null;

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => this.navPathStack.pop())

          Text($r('app.string.profile_title'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })

          Blank()
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.background_primary'))

        Divider().strokeWidth(0.5).color($r('app.color.separator'))

        Scroll() {
          Column() {
            // --- Avatar + Name header ---
            Column() {
              if (this.photoUrl) {
                Image(this.photoUrl)
                  .alt($r('app.media.app_icon'))
                  .autoResize(true)
                  .onError(() => {})
                  .width(90)
                  .height(90)
                  .borderRadius(45)
              } else {
                Text(this.getInitials())
                  .fontSize(36)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Color.White)
                  .width(90)
                  .height(90)
                  .borderRadius(45)
                  .backgroundColor($r('app.color.telegram_blue'))
                  .textAlign(TextAlign.Center)
              }

              Text(this.getFullName())
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .margin({ top: 12 })

              if (this.username.length > 0) {
                Text(`@${this.username}`)
                  .fontSize(15)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 4 })
              }
            }
            .width('100%')
            .padding({ top: 24, bottom: 24 })
            .alignItems(HorizontalAlign.Center)
            .backgroundColor($r('app.color.background_primary'))

            Blank().height(24)

            // --- Info section ---
            Column() {
              // Phone
              this.infoRow($r('app.string.profile_phone'), this.phoneNumber)
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

              // Username
              this.infoRow(
                $r('app.string.profile_username'),
                this.username.length > 0 ? `@${this.username}` : '-'
              )
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

              // Bio
              this.infoRow(
                $r('app.string.profile_bio'),
                this.bio.length > 0 ? this.bio : '-'
              )
            }
            .width('100%')
            .backgroundColor($r('app.color.settings_section_bg'))
            .borderRadius(10)
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Action buttons ---
            Column() {
              // Notifications
              Row() {
                Image($r('app.media.ic_unmute'))
                  .width(22)
                  .height(22)
                  .fillColor($r('app.color.telegram_blue'))
                  .margin({ right: 12 })

                Text($r('app.string.settings_notifications'))
                  .fontSize(16)
                  .fontColor($r('app.color.telegram_blue'))
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
            }
            .width('100%')
            .backgroundColor($r('app.color.settings_section_bg'))
            .borderRadius(10)
            .margin({ left: 16, right: 16 })

            Blank().height(32)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
    }
    .hideTitleBar(true)
  }

  @Builder
  infoRow(label: Resource, value: string) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))

      Text(value)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 2 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
  }

  private getFullName(): string {
    return this.lastName.length > 0
      ? `${this.firstName} ${this.lastName}`
      : this.firstName;
  }

  private getInitials(): string {
    let initials = this.firstName.length > 0 ? this.firstName.charAt(0) : '';
    if (this.lastName.length > 0) {
      initials += this.lastName.charAt(0);
    }
    return initials.length > 0 ? initials : '?';
  }
}
