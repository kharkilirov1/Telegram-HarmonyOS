// MultiAccountPage — account switcher and manager
// Reference: Telegram iOS AccountContext, Android AccountSwitcher
// HarmonyOS: Uses PreferencesService for persistent account data

import { hilog } from '@kit.PerformanceAnalysisKit';
import { UserService } from '../../services/UserService';
import { AuthController } from '../../controllers/AuthController';
import { PreferencesService } from '../../services/PreferencesService';

@Builder
export function MultiAccountBuilder(name: string, param: Object) {
  MultiAccountPage()
}

interface AccountEntry {
  userId: number;
  phoneNumber: string;
  firstName: string;
  lastName: string;
  photoUrl: string;
  initial: string;
  isActive: boolean;
}

@ComponentV2
export struct MultiAccountPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local accounts: AccountEntry[] = [];
  @Local isLoading: boolean = true;

  aboutToAppear(): void {
    this.loadAccounts();
  }

  private async loadAccounts(): Promise<void> {
    this.isLoading = true;

    // Get current user info
    try {
      const meResult = await UserService.getInstance().getMe();
      const userId = meResult.id || 0;
      const firstName = meResult.first_name || '';
      const lastName = meResult.last_name || '';
      const phoneNumber = meResult.phone_number || '';

      let photoUrl = '';
      const profilePhoto = meResult.profile_photo;
      if (profilePhoto) {
        const small = profilePhoto.small;
        if (small) {
          const localFile = small.local;
          if (localFile && localFile.is_downloading_completed) {
            photoUrl = localFile.path || '';
          }
        }
      }

      const initial = firstName.length > 0 ? firstName.charAt(0).toUpperCase() : '?';

      this.accounts = [{
        userId: userId,
        phoneNumber: phoneNumber,
        firstName: firstName,
        lastName: lastName,
        photoUrl: photoUrl,
        initial: initial,
        isActive: true
      }];
    } catch (e) {
      hilog.warn(0x0001, 'MultiAccountPage', 'Failed to load current user info');
      this.accounts = [];
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

          Text($r('app.string.switch_account'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
            .layoutWeight(1)
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        // Account list
        if (this.isLoading) {
          Column() {
            LoadingProgress().width(32).height(32).color($r('app.color.telegram_blue'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.accounts, (account: AccountEntry) => {
              ListItem() {
                this.accountRow(account)
              }
            }, (account: AccountEntry) => `account_${account.userId}`)

            // Add account button
            ListItem() {
              Row() {
                Column() {
                  Image($r('app.media.ic_edit'))
                    .width(20).height(20)
                    .fillColor($r('app.color.icon_on_primary'))
                }
                .width(44).height(44)
                .borderRadius(22)
                .backgroundColor($r('app.color.telegram_blue'))
                .justifyContent(FlexAlign.Center)

                Text($r('app.string.add_account'))
                  .fontSize(16)
                  .fontColor($r('app.color.telegram_blue'))
                  .fontWeight(FontWeight.Medium)
                  .margin({ left: 14 })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .onClick(() => {
                this.navPathStack.pushPath(new NavPathInfo('PhonePage', new Object()));
              })
            }

            // Info section
            ListItem() {
              Column() {
                Text($r('app.string.max_accounts_reached'))
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .padding({ left: 16, right: 16, top: 16 })
              }
              .width('100%')
            }
          }
          .width('100%')
          .layoutWeight(1)
          .divider({
            strokeWidth: 0.5,
            color: $r('app.color.separator'),
            startMargin: 74,
            endMargin: 0
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_primary'))
    }
    .hideTitleBar(true)
  }

  @Builder
  accountRow(account: AccountEntry) {
    Row() {
      // Avatar
      if (account.photoUrl.length > 0) {
        Image(account.photoUrl)
          .width(44).height(44)
          .borderRadius(22)
          .alt(account.initial)
          .autoResize(true)
          .onError(() => {})
      } else {
        Text(account.initial)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.icon_on_primary'))
          .width(44).height(44)
          .borderRadius(22)
          .backgroundColor($r('app.color.telegram_blue'))
          .textAlign(TextAlign.Center)
      }

      Column() {
        Text(`${account.firstName} ${account.lastName}`.trim())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (account.phoneNumber.length > 0) {
          Text(`+${account.phoneNumber}`)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
        }
      }
      .margin({ left: 14 })
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // Active indicator
      if (account.isActive) {
        Image($r('app.media.ic_check'))
          .width(20).height(20)
          .fillColor($r('app.color.telegram_blue'))
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }
}
