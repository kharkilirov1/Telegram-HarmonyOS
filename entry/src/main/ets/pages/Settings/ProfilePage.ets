import { AuthController } from '../../controllers/AuthController';

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
  @Local isOnline: boolean = false;
  @Local notificationsEnabled: boolean = true;

  build() {
    NavDestination() {
      Column() {
        // Top bar — like Telegram iOS profile: "Back" left, "Edit" right
        Row() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => this.navPathStack.pop())

          Blank()

          Text($r('app.string.profile_edit'))
            .fontSize(17)
            .fontColor($r('app.color.telegram_blue'))
        }
        .width('100%')
        .height(44)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.background_primary'))

        Divider().strokeWidth(0.5).color($r('app.color.separator'))

        Scroll() {
          Column() {
            // --- Large avatar + Name header (like Telegram iOS/Android profile) ---
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
                  Text(this.getInitials())
                    .fontSize(40)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Color.White)
                    .width(100)
                    .height(100)
                    .borderRadius(50)
                    .backgroundColor($r('app.color.telegram_blue'))
                    .textAlign(TextAlign.Center)
                }

                // Online indicator dot (like both platforms)
                if (this.isOnline) {
                  Circle()
                    .width(16)
                    .height(16)
                    .fill($r('app.color.online_indicator'))
                    .stroke(Color.White)
                    .strokeWidth(2)
                    .position({ right: 2, bottom: 2 })
                }
              }

              // "Set Profile Photo" link (like iOS Telegram)
              Text($r('app.string.profile_set_photo'))
                .fontSize(14)
                .fontColor($r('app.color.telegram_blue'))
                .margin({ top: 10 })

              // Name
              Text(this.getFullName())
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .margin({ top: 12 })

              // Online status
              Text(this.isOnline ? $r('app.string.online') : $r('app.string.last_seen_recently'))
                .fontSize(14)
                .fontColor(this.isOnline
                  ? $r('app.color.online_indicator')
                  : $r('app.color.text_secondary'))
                .margin({ top: 4 })
            }
            .width('100%')
            .padding({ top: 24, bottom: 24 })
            .alignItems(HorizontalAlign.Center)
            .backgroundColor($r('app.color.background_primary'))

            Blank().height(24)

            // --- Info section (like Telegram iOS grouped list) ---
            Column() {
              // Phone
              this.infoRow($r('app.string.profile_phone'), this.phoneNumber, $r('app.media.ic_phone_call'))
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })

              // Username
              this.infoRow(
                $r('app.string.profile_username'),
                this.username.length > 0 ? `@${this.username}` : '-',
                $r('app.media.ic_contact')
              )
              Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })

              // Bio
              this.infoRow(
                $r('app.string.profile_bio'),
                this.bio.length > 0 ? this.bio : '-',
                $r('app.media.ic_edit')
              )
            }
            .width('100%')
            .backgroundColor($r('app.color.settings_section_bg'))
            .borderRadius(10)
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Shared Media section (like both platforms) ---
            Column() {
              Row() {
                Image($r('app.media.ic_photo'))
                  .width(22)
                  .height(22)
                  .fillColor($r('app.color.telegram_blue'))
                  .margin({ right: 12 })

                Text($r('app.string.profile_shared_media'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)

                Image($r('app.media.ic_forward'))
                  .width(14)
                  .height(14)
                  .fillColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
            }
            .width('100%')
            .backgroundColor($r('app.color.settings_section_bg'))
            .borderRadius(10)
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Notifications toggle (like real Telegram profile) ---
            Column() {
              Row() {
                Image($r('app.media.ic_unmute'))
                  .width(22)
                  .height(22)
                  .fillColor($r('app.color.settings_icon_green'))
                  .margin({ right: 12 })

                Text($r('app.string.settings_notifications'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: this.notificationsEnabled })
                  .selectedColor($r('app.color.telegram_blue'))
                  .onChange((isOn: boolean) => {
                    this.notificationsEnabled = isOn;
                  })
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
            }
            .width('100%')
            .backgroundColor($r('app.color.settings_section_bg'))
            .borderRadius(10)
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Change Number (like real Telegram settings) ---
            Column() {
              Row() {
                Image($r('app.media.ic_phone_call'))
                  .width(22)
                  .height(22)
                  .fillColor($r('app.color.settings_icon_orange'))
                  .margin({ right: 12 })

                Text($r('app.string.profile_change_number'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)

                Image($r('app.media.ic_forward'))
                  .width(14)
                  .height(14)
                  .fillColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
            }
            .width('100%')
            .backgroundColor($r('app.color.settings_section_bg'))
            .borderRadius(10)
            .margin({ left: 16, right: 16 })

            Blank().height(24)

            // --- Log Out (like real Telegram — red text) ---
            Column() {
              Text($r('app.string.settings_log_out'))
                .fontSize(16)
                .fontColor($r('app.color.logout_red'))
                .textAlign(TextAlign.Center)
                .width('100%')
                .height(48)
                .onClick(() => {
                  this.showLogoutConfirmation();
                })
            }
            .width('100%')
            .backgroundColor($r('app.color.settings_section_bg'))
            .borderRadius(10)
            .margin({ left: 16, right: 16 })

            Blank().height(40)
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
  infoRow(label: Resource, value: string, icon: Resource) {
    Row() {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor($r('app.color.telegram_blue'))
        .margin({ right: 12 })

      Column() {
        Text(value)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))

        Text(label)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
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

  private showLogoutConfirmation(): void {
    AlertDialog.show({
      title: $r('app.string.settings_log_out'),
      message: undefined,
      primaryButton: {
        value: 'Cancel',
        action: () => {}
      },
      secondaryButton: {
        value: 'Log Out',
        fontColor: $r('app.color.logout_red'),
        action: () => {
          AuthController.getInstance().logout();
        }
      }
    });
  }
}
