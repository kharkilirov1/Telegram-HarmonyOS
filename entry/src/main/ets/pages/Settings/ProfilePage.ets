// Profile page with view/edit mode
// Reference: Telegram iOS ProfileController, Android ProfileActivity

import { AuthController } from '../../controllers/AuthController';
import { TDLibClient } from '../../services/TDLibClient';

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

  // Edit mode state
  @Local isEditing: boolean = false;
  @Local editFirstName: string = '';
  @Local editLastName: string = '';
  @Local editBio: string = '';
  @Local editUsername: string = '';
  @Local isSaving: boolean = false;

  build() {
    NavDestination() {
      Column() {
        // Top bar — "Back" left, "Edit/Done" right
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => {
              if (this.isEditing) {
                this.isEditing = false;
              } else {
                this.navPathStack.pop();
              }
            })

          Blank()

          if (this.isEditing) {
            if (this.isSaving) {
              LoadingProgress()
                .width(20).height(20).color($r('app.color.telegram_blue'))
            } else {
              Text($r('app.string.done'))
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.telegram_blue'))
                .onClick(() => { this.saveProfile(); })
            }
          } else {
            Text($r('app.string.profile_edit'))
              .fontSize(17)
              .fontColor($r('app.color.telegram_blue'))
              .onClick(() => { this.enterEditMode(); })
          }
        }
        .width('100%')
        .height(44)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })

        Divider().strokeWidth(0.5).color($r('app.color.separator'))

        Scroll() {
          Column() {
            if (this.isEditing) {
              this.buildEditMode()
            } else {
              this.buildViewMode()
            }
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

  // --- Edit Mode (like Telegram iOS/Android edit profile) ---
  @Builder
  buildEditMode() {
    Column() {
      // Avatar with camera overlay
      Column() {
        Stack({ alignContent: Alignment.BottomEnd }) {
          if (this.photoUrl) {
            Image(this.photoUrl)
              .alt($r('app.media.app_icon'))
              .autoResize(true)
              .onError(() => {})
              .width(100).height(100)
              .borderRadius(50)
          } else {
            Text(this.getInitials())
              .fontSize(40)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width(100).height(100)
              .borderRadius(50)
              .backgroundColor($r('app.color.telegram_blue'))
              .textAlign(TextAlign.Center)
          }

          Column() {
            Image($r('app.media.ic_photo'))
              .width(16).height(16)
              .fillColor(Color.White)
          }
          .width(32).height(32)
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

      // Name fields
      Column() {
        this.editField('First Name', this.editFirstName, (v: string) => { this.editFirstName = v; })
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
        this.editField('Last Name', this.editLastName, (v: string) => { this.editLastName = v; })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 16, right: 16 })

      Blank().height(24)

      // Bio
      Column() {
        this.editField('Bio', this.editBio, (v: string) => { this.editBio = v; })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 16, right: 16 })

      Text('Any details such as age, occupation or city.')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 32, top: 6 })

      Blank().height(24)

      // Username
      Column() {
        this.editField('Username', this.editUsername, (v: string) => { this.editUsername = v; })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 16, right: 16 })

      Text('You can choose a username on Telegram. Others will be able to find you by this username.')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 32, top: 6, right: 32 })

      Blank().height(40)
    }
    .width('100%')
  }

  @Builder
  editField(label: string, value: string, onChange: (v: string) => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.telegram_blue'))
        .width(100)

      TextInput({ text: value, placeholder: label })
        .fontSize(16)
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .onChange(onChange)
    }
    .width('100%').height(48)
    .padding({ left: 16, right: 16 })
  }

  // --- View Mode ---
  @Builder
  buildViewMode() {
    Column() {
      // Large avatar + Name header
      Column() {
        Stack({ alignContent: Alignment.BottomEnd }) {
          if (this.photoUrl) {
            Image(this.photoUrl)
              .alt($r('app.media.app_icon'))
              .autoResize(true)
              .onError(() => {})
              .width(100).height(100)
              .borderRadius(50)
          } else {
            Text(this.getInitials())
              .fontSize(40)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width(100).height(100)
              .borderRadius(50)
              .backgroundColor($r('app.color.telegram_blue'))
              .textAlign(TextAlign.Center)
          }

          if (this.isOnline) {
            Circle()
              .width(16).height(16)
              .fill($r('app.color.online_indicator'))
              .stroke(Color.White)
              .strokeWidth(2)
              .position({ right: 2, bottom: 2 })
          }
        }

        Text($r('app.string.profile_set_photo'))
          .fontSize(14)
          .fontColor($r('app.color.telegram_blue'))
          .margin({ top: 10 })

        Text(this.getFullName())
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ top: 12 })

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

      // Info section
      Column() {
        this.infoRow($r('app.string.profile_phone'), this.phoneNumber, $r('app.media.ic_phone_call'))
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
        this.infoRow(
          $r('app.string.profile_username'),
          this.username.length > 0 ? `@${this.username}` : '-',
          $r('app.media.ic_contact')
        )
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
        this.infoRow(
          $r('app.string.profile_bio'),
          this.bio.length > 0 ? this.bio : '-',
          $r('app.media.ic_edit')
        )
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 16, right: 16 })

      Blank().height(24)

      // Shared Media
      Column() {
        Row() {
          Image($r('app.media.ic_photo'))
            .width(22).height(22)
            .fillColor($r('app.color.telegram_blue'))
            .margin({ right: 12 })
          Text($r('app.string.profile_shared_media'))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Image($r('app.media.ic_forward'))
            .width(14).height(14)
            .fillColor($r('app.color.text_secondary'))
        }
        .width('100%').height(48)
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 16, right: 16 })
      .onClick(() => {
        this.navPathStack.pushPath({ name: 'SharedMedia' });
      })

      Blank().height(24)

      // Notifications toggle
      Column() {
        Row() {
          Image($r('app.media.ic_unmute'))
            .width(22).height(22)
            .fillColor($r('app.color.settings_icon_green'))
            .margin({ right: 12 })
          Text($r('app.string.settings_notifications'))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.notificationsEnabled })
            .selectedColor($r('app.color.telegram_blue'))
            .onChange((isOn: boolean) => { this.notificationsEnabled = isOn; })
        }
        .width('100%').height(48)
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 16, right: 16 })

      Blank().height(24)

      // Change Number
      Column() {
        Row() {
          Image($r('app.media.ic_phone_call'))
            .width(22).height(22)
            .fillColor($r('app.color.settings_icon_orange'))
            .margin({ right: 12 })
          Text($r('app.string.profile_change_number'))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Image($r('app.media.ic_forward'))
            .width(14).height(14)
            .fillColor($r('app.color.text_secondary'))
        }
        .width('100%').height(48)
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 16, right: 16 })

      Blank().height(24)

      // Log Out
      Column() {
        Text($r('app.string.settings_log_out'))
          .fontSize(16)
          .fontColor($r('app.color.logout_red'))
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(48)
          .onClick(() => { this.showLogoutConfirmation(); })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 16, right: 16 })

      Blank().height(40)
    }
    .width('100%')
  }

  @Builder
  infoRow(label: Resource, value: string, icon: Resource) {
    Row() {
      Image(icon)
        .width(22).height(22)
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

  private enterEditMode(): void {
    this.editFirstName = this.firstName;
    this.editLastName = this.lastName;
    this.editBio = this.bio;
    this.editUsername = this.username;
    this.isEditing = true;
  }

  private async saveProfile(): Promise<void> {
    this.isSaving = true;
    try {
      if (this.editFirstName !== this.firstName || this.editLastName !== this.lastName) {
        await TDLibClient.getInstance().send('setName', {
          first_name: this.editFirstName.trim(),
          last_name: this.editLastName.trim()
        });
        this.firstName = this.editFirstName.trim();
        this.lastName = this.editLastName.trim();
      }
      if (this.editBio !== this.bio) {
        await TDLibClient.getInstance().send('setBio', { bio: this.editBio.trim() });
        this.bio = this.editBio.trim();
      }
      if (this.editUsername !== this.username) {
        await TDLibClient.getInstance().send('setUsername', { username: this.editUsername.trim() });
        this.username = this.editUsername.trim();
      }
      this.isEditing = false;
    } catch (e) {
      // Handle error
    } finally {
      this.isSaving = false;
    }
  }

  private getFullName(): string {
    return this.lastName.length > 0
      ? `${this.firstName} ${this.lastName}`
      : this.firstName;
  }

  private getInitials(): string {
    let initials = this.firstName.length > 0 ? this.firstName.charAt(0) : '';
    if (this.lastName.length > 0) initials += this.lastName.charAt(0);
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
        action: () => { AuthController.getInstance().logout(); }
      }
    });
  }
}
