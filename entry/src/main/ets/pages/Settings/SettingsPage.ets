import { PreferencesService } from '../../services/PreferencesService';
import { AuthController } from '../../controllers/AuthController';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { SettingsChatSection } from './components/SettingsChatSection';
import { SettingsCoreSettingsSection } from './components/SettingsCoreSettingsSection';
import { SettingsLogoutSection } from './components/SettingsLogoutSection';
import { SettingsNotificationsSection } from './components/SettingsNotificationsSection';
import { SettingsPrivacySection } from './components/SettingsPrivacySection';
import { SettingsProfileCard } from './components/SettingsProfileCard';
import { SettingsQuickActionsSection } from './components/SettingsQuickActionsSection';
import { SettingsThemeSection } from './components/SettingsThemeSection';
import { SettingsTopBar } from './components/SettingsTopBar';
import { UserService } from '../../services/UserService';

@Builder
export function SettingsBuilder(name: string, param: Object) {
  SettingsPage()
}

@ComponentV2
export struct SettingsPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  @Local themeMode: string = 'system';
  @Local notificationsEnabled: boolean = true;
  @Local sendByEnter: boolean = true;
  @Local fontSize: number = 16;
  @Local lastSeenVisibility: string = 'everybody';

  @Local userName: string = '';
  @Local userPhone: string = '';

  aboutToAppear(): void {
    void this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    const prefs = PreferencesService.getInstance();
    this.themeMode = await prefs.getThemeMode();
    this.notificationsEnabled = await prefs.getNotificationsEnabled();
    this.sendByEnter = await prefs.getSendByEnter();
    this.fontSize = await prefs.getFontSize();
    this.lastSeenVisibility = await prefs.getLastSeenVisibility();

    try {
      const me = await UserService.getInstance().getMe();
      const fullName = `${me.first_name || ''} ${me.last_name || ''}`.trim();
      if (fullName.length > 0) {
        this.userName = fullName;
      }
      if (me.phone_number && me.phone_number.length > 0) {
        this.userPhone = `+${me.phone_number}`;
      }
    } catch (_e) {
      // Keep defaults if profile request fails.
    }

    if (this.userName.length === 0) {
      this.userName = getContext(this).resourceManager.getStringByNameSync('user_fallback');
    }
  }

  build() {
    NavDestination() {
      Column() {
        SettingsTopBar({
          onBack: () => {
            this.navPathStack.pop();
          },
          onEditProfile: () => {
            this.openProfile();
          }
        })

        Scroll() {
          Column() {
            SettingsProfileCard({
              userName: this.userName,
              userPhone: this.userPhone,
              onOpenProfile: () => {
                this.openProfile();
              }
            })

            this.sectionGap()

            SettingsQuickActionsSection({
              onOpenSavedMessages: () => {
                this.navPathStack.pushPath(new NavPathInfo('SavedMessages', new Object()));
              },
              onOpenRecentCalls: () => {
                this.navPathStack.pushPath(new NavPathInfo('Calls', new Object()));
              },
              onOpenDevices: () => {
                this.navPathStack.pushPath(new NavPathInfo('SessionManagement', new Object()));
              },
              onOpenChatFolders: () => {
                this.navPathStack.pushPath(new NavPathInfo('ChatFolders', new Object()));
              }
            })

            this.sectionGap()

            SettingsCoreSettingsSection({
              onOpenNotifications: () => {
                this.navPathStack.pushPath(new NavPathInfo('NotificationsSettings', new Object()));
              },
              onOpenPrivacy: () => {
                this.navPathStack.pushPath(new NavPathInfo('PrivacySettings', new Object()));
              },
              onOpenBiometric: () => {
                this.navPathStack.pushPath(new NavPathInfo('BiometricLock', new Object()));
              },
              onOpenDataStorage: () => {
                this.navPathStack.pushPath(new NavPathInfo('DataStorage', new Object()));
              },
              onOpenProxy: () => {
                this.navPathStack.pushPath(new NavPathInfo('ProxySettings', new Object()));
              },
              onOpenAppearance: () => {
                this.navPathStack.pushPath(new NavPathInfo('Appearance', new Object()));
              },
              onOpenLanguage: () => {
                this.navPathStack.pushPath(new NavPathInfo('Language', new Object()));
              }
            })

            this.sectionGap()

            SettingsThemeSection({
              themeMode: this.themeMode,
              onThemeChange: (mode: string) => {
                this.themeMode = mode;
                void PreferencesService.getInstance().setThemeMode(mode);
                this.applyTheme(mode);
              }
            })

            this.sectionGap()

            SettingsNotificationsSection({
              notificationsEnabled: this.notificationsEnabled,
              onNotificationsEnabledChange: (isOn: boolean) => {
                this.notificationsEnabled = isOn;
                void PreferencesService.getInstance().setNotificationsEnabled(isOn);
              }
            })

            this.sectionGap()

            SettingsChatSection({
              sendByEnter: this.sendByEnter,
              fontSize: this.fontSize,
              onSendByEnterChange: (isOn: boolean) => {
                this.sendByEnter = isOn;
                void PreferencesService.getInstance().setSendByEnter(isOn);
              },
              onFontSizeChange: (size: number) => {
                this.fontSize = size;
                void PreferencesService.getInstance().setFontSize(size);
              }
            })

            this.sectionGap()

            SettingsPrivacySection({
              lastSeenLabel: this.getLastSeenLabel(),
              onPickLastSeen: () => {
                this.showLastSeenPicker();
              }
            })

            this.sectionGap()

            SettingsLogoutSection({
              onLogout: () => {
                AuthController.getInstance().logout();
              }
            })

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
  private sectionGap() {
    Blank().height(24)
  }

  private openProfile(): void {
    this.navPathStack.pushPath(new NavPathInfo('Profile', new Object()));
  }

  private getLastSeenLabel(): string {
    switch (this.lastSeenVisibility) {
      case 'everybody':
        return getContext(this).resourceManager.getStringByNameSync('settings_everybody');
      case 'contacts':
        return getContext(this).resourceManager.getStringByNameSync('settings_my_contacts');
      case 'nobody':
        return getContext(this).resourceManager.getStringByNameSync('settings_nobody');
      default:
        return getContext(this).resourceManager.getStringByNameSync('settings_everybody');
    }
  }

  private applyTheme(mode: string): void {
    try {
      const ctx = getContext(this).getApplicationContext();
      switch (mode) {
        case 'light':
          ctx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
          break;
        case 'dark':
          ctx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
          break;
        default:
          ctx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
          break;
      }
    } catch (_e) {
      promptAction.showToast({
        message: getContext(this).resourceManager.getStringByNameSync('action_failed'),
        duration: 1200,
        bottom: 96
      });
    }
  }

  private showLastSeenPicker(): void {
    const options = ['everybody', 'contacts', 'nobody'];
    const current = options.indexOf(this.lastSeenVisibility);
    const nextIndex = (current + 1) % options.length;
    this.lastSeenVisibility = options[nextIndex];
    void PreferencesService.getInstance().setLastSeenVisibility(this.lastSeenVisibility);
  }
}
