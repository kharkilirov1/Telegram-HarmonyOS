// Profile page with view/edit mode
// Reference: Telegram iOS ProfileController, Android ProfileActivity

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AuthController } from '../../controllers/AuthController';
import { UserService } from '../../services/UserService';
import { ProfileChangeNumberCard } from './components/ProfileChangeNumberCard';
import { ProfileEditModeSection } from './components/ProfileEditModeSection';
import { ProfileInfoRow } from './components/ProfileInfoRow';
import { ProfileLogoutCard } from './components/ProfileLogoutCard';
import { ProfileNotificationsCard } from './components/ProfileNotificationsCard';
import { ProfileSharedMediaCard } from './components/ProfileSharedMediaCard';
import { ProfileTopBar } from './components/ProfileTopBar';
import { ProfileViewHeader } from './components/ProfileViewHeader';

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
        ProfileTopBar({
          isEditing: this.isEditing,
          isSaving: this.isSaving,
          onBack: () => {
            if (this.isEditing) {
              this.isEditing = false;
            } else {
              this.navPathStack.pop();
            }
          },
          onDone: () => {
            this.saveProfile();
          },
          onEdit: () => {
            this.enterEditMode();
          }
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
    ProfileEditModeSection({
      photoUrl: this.photoUrl,
      initials: this.getInitials(),
      editFirstName: this.editFirstName,
      editLastName: this.editLastName,
      editBio: this.editBio,
      editUsername: this.editUsername,
      onFirstNameChange: (value: string) => {
        this.editFirstName = value;
      },
      onLastNameChange: (value: string) => {
        this.editLastName = value;
      },
      onBioChange: (value: string) => {
        this.editBio = value;
      },
      onUsernameChange: (value: string) => {
        this.editUsername = value;
      }
    })
  }

  // --- View Mode ---
  @Builder
  buildViewMode() {
    Column() {
      ProfileViewHeader({
        photoUrl: this.photoUrl,
        initials: this.getInitials(),
        fullName: this.getFullName(),
        isOnline: this.isOnline
      })

      Blank().height(24)

      Column() {
        ProfileInfoRow({
          label: $r('app.string.profile_phone'),
          value: this.phoneNumber,
          icon: $r('app.media.ic_phone_call')
        })
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
        ProfileInfoRow({
          label: $r('app.string.profile_username'),
          value: this.username.length > 0 ? `@${this.username}` : '-',
          icon: $r('app.media.ic_contact')
        })
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 56 })
        ProfileInfoRow({
          label: $r('app.string.profile_bio'),
          value: this.bio.length > 0 ? this.bio : '-',
          icon: $r('app.media.ic_edit')
        })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(16)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 16, right: 16 })

      Blank().height(24)

      ProfileSharedMediaCard({
        onOpen: () => {
          this.navPathStack.pushPath(new NavPathInfo('SharedMedia', new Object()));
        }
      })

      Blank().height(24)

      ProfileNotificationsCard({
        isEnabled: this.notificationsEnabled,
        onToggle: (isOn: boolean) => {
          this.notificationsEnabled = isOn;
        }
      })

      Blank().height(24)

      ProfileChangeNumberCard({
        onOpen: () => {}
      })

      Blank().height(24)

      ProfileLogoutCard({
        onLogout: () => {
          this.showLogoutConfirmation();
        }
      })

      Blank().height(40)
    }
    .width('100%')
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
        await UserService.getInstance().setName(this.editFirstName.trim(), this.editLastName.trim());
        this.firstName = this.editFirstName.trim();
        this.lastName = this.editLastName.trim();
      }
      if (this.editBio !== this.bio) {
        await UserService.getInstance().setBio(this.editBio.trim());
        this.bio = this.editBio.trim();
      }
      if (this.editUsername !== this.username) {
        await UserService.getInstance().setUsername(this.editUsername.trim());
        this.username = this.editUsername.trim();
      }
      this.isEditing = false;
    } catch (e) {
      hilog.warn(0x0001, 'ProfilePage', 'Failed to save profile changes');
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
