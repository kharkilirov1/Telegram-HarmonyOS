// Biometric Lock / Passcode Lock settings page
// Reference: Telegram iOS PasscodeController, Android PasscodeActivity

import { PreferencesService } from '../../services/PreferencesService';
import { AutoLockPickerOption, AutoLockPickerOverlay } from './components/AutoLockPickerOverlay';
import { BiometricOptionsCard } from './components/BiometricOptionsCard';
import { BiometricTopBar } from './components/BiometricTopBar';
import { PasscodeActionsCard } from './components/PasscodeActionsCard';
import { PasscodeOverlay } from './components/PasscodeOverlay';
import { PasscodeToggleCard } from './components/PasscodeToggleCard';

enum PasscodeFlowMode {
  NONE,
  SETUP_ENTER,
  SETUP_CONFIRM,
  VERIFY_DISABLE,
  VERIFY_CHANGE
}

@Builder
export function BiometricLockBuilder(name: string, param: Object) {
  BiometricLockPage()
}

@ComponentV2
export struct BiometricLockPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  @Local passcodeEnabled: boolean = false;
  @Local biometricEnabled: boolean = false;
  @Local autoLockTimeout: number = 0;
  @Local showNotificationsContent: boolean = true;

  @Local flowMode: PasscodeFlowMode = PasscodeFlowMode.NONE;
  @Local enteredPasscode: string = '';
  @Local firstPasscode: string = '';
  @Local savedPasscode: string = '';
  @Local passcodeError: string = '';
  @Local passcodeLength: number = 4;
  @Local showAutoLockPicker: boolean = false;

  private readonly autoLockOptions: AutoLockPickerOption[] = [
    { labelRes: $r('app.string.auto_lock_disabled'), seconds: 0 },
    { labelRes: $r('app.string.auto_lock_1min'), seconds: 60 },
    { labelRes: $r('app.string.auto_lock_5min'), seconds: 300 },
    { labelRes: $r('app.string.auto_lock_1hour'), seconds: 3600 },
    { labelRes: $r('app.string.auto_lock_5hours'), seconds: 18000 }
  ];

  aboutToAppear(): void {
    this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    const prefs = PreferencesService.getInstance();
    this.passcodeEnabled = await prefs.getPasscodeEnabled();
    this.biometricEnabled = await prefs.getBiometricEnabled();
    this.autoLockTimeout = await prefs.getAutoLockTimeout();
  }

  private async savePasscodeEnabled(enabled: boolean): Promise<void> {
    const prefs = PreferencesService.getInstance();
    await prefs.setPasscodeEnabled(enabled);
  }

  private async saveBiometricEnabled(enabled: boolean): Promise<void> {
    const prefs = PreferencesService.getInstance();
    await prefs.setBiometricEnabled(enabled);
  }

  private async saveAutoLockTimeout(seconds: number): Promise<void> {
    const prefs = PreferencesService.getInstance();
    await prefs.setAutoLockTimeout(seconds);
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          BiometricTopBar({
            onBack: () => {
              this.navPathStack.pop();
            }
          })

          Scroll() {
            Column() {
              Blank().height(16)

              PasscodeToggleCard({
                passcodeEnabled: this.passcodeEnabled,
                onToggle: (isOn: boolean) => {
                  this.handlePasscodeToggle(isOn);
                }
              })

              if (this.passcodeEnabled) {
                Blank().height(24)

                BiometricOptionsCard({
                  biometricEnabled: this.biometricEnabled,
                  autoLockLabel: this.getAutoLockLabel(),
                  showNotificationsContent: this.showNotificationsContent,
                  onBiometricToggle: (isOn: boolean) => {
                    this.biometricEnabled = isOn;
                    this.saveBiometricEnabled(isOn);
                  },
                  onOpenAutoLock: () => {
                    this.showAutoLockPicker = true;
                  },
                  onNotificationsToggle: (isOn: boolean) => {
                    this.showNotificationsContent = isOn;
                  }
                })

                Blank().height(24)

                PasscodeActionsCard({
                  onChangePasscode: () => {
                    this.startChangePasscodeFlow();
                  },
                  onTurnOffPasscode: () => {
                    this.startDisablePasscodeFlow();
                  }
                })
              }

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

        if (this.flowMode !== PasscodeFlowMode.NONE) {
          PasscodeOverlay({
            title: this.getPasscodeTitle(),
            passcodeLength: this.passcodeLength,
            enteredPasscodeLength: this.enteredPasscode.length,
            passcodeError: this.passcodeError,
            onBack: () => {
              this.resetPasscodeFlow();
            },
            onDigit: (digit: string) => {
              this.onPasscodeDigit(digit);
            },
            onDelete: () => {
              this.onPasscodeDelete();
            }
          })
        }

        if (this.showAutoLockPicker) {
          AutoLockPickerOverlay({
            options: this.autoLockOptions,
            selectedSeconds: this.autoLockTimeout,
            onClose: () => {
              this.showAutoLockPicker = false;
            },
            onSelect: (seconds: number) => {
              this.autoLockTimeout = seconds;
              this.saveAutoLockTimeout(seconds);
              this.showAutoLockPicker = false;
            }
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
  }

  private handlePasscodeToggle(isOn: boolean): void {
    if (isOn) {
      this.firstPasscode = '';
      this.enteredPasscode = '';
      this.passcodeError = '';
      this.flowMode = PasscodeFlowMode.SETUP_ENTER;
    } else {
      this.startDisablePasscodeFlow();
    }
  }

  private startDisablePasscodeFlow(): void {
    this.enteredPasscode = '';
    this.passcodeError = '';
    this.flowMode = PasscodeFlowMode.VERIFY_DISABLE;
  }

  private startChangePasscodeFlow(): void {
    this.firstPasscode = '';
    this.enteredPasscode = '';
    this.passcodeError = '';
    this.flowMode = PasscodeFlowMode.VERIFY_CHANGE;
  }

  private resetPasscodeFlow(): void {
    this.flowMode = PasscodeFlowMode.NONE;
    this.enteredPasscode = '';
    this.firstPasscode = '';
    this.passcodeError = '';
  }

  private onPasscodeDigit(digit: string): void {
    if (this.enteredPasscode.length >= this.passcodeLength) {
      return;
    }

    this.enteredPasscode += digit;
    this.passcodeError = '';

    if (this.enteredPasscode.length === this.passcodeLength) {
      this.onPasscodeComplete();
    }
  }

  private onPasscodeDelete(): void {
    if (this.enteredPasscode.length > 0) {
      this.enteredPasscode = this.enteredPasscode.substring(0, this.enteredPasscode.length - 1);
    }
  }

  private getPasscodeTitle(): Resource {
    switch (this.flowMode) {
      case PasscodeFlowMode.SETUP_CONFIRM:
        return $r('app.string.confirm_passcode');
      case PasscodeFlowMode.VERIFY_DISABLE:
      case PasscodeFlowMode.VERIFY_CHANGE:
      case PasscodeFlowMode.SETUP_ENTER:
      default:
        return $r('app.string.enter_passcode');
    }
  }

  private getAutoLockLabel(): Resource {
    for (let i = 0; i < this.autoLockOptions.length; i++) {
      if (this.autoLockOptions[i].seconds === this.autoLockTimeout) {
        return this.autoLockOptions[i].labelRes;
      }
    }
    return $r('app.string.auto_lock_disabled');
  }

  private getPasscodeMismatchText(): string {
    try {
      return getContext(this).resourceManager.getStringSync($r('app.string.passcode_mismatch'));
    } catch (e) {
      return 'Passcode mismatch';
    }
  }

  private onPasscodeComplete(): void {
    switch (this.flowMode) {
      case PasscodeFlowMode.SETUP_ENTER:
        this.firstPasscode = this.enteredPasscode;
        this.enteredPasscode = '';
        this.flowMode = PasscodeFlowMode.SETUP_CONFIRM;
        break;

      case PasscodeFlowMode.SETUP_CONFIRM:
        if (this.enteredPasscode === this.firstPasscode) {
          this.savedPasscode = this.enteredPasscode;
          this.passcodeEnabled = true;
          this.savePasscodeEnabled(true);
          this.resetPasscodeFlow();
        } else {
          this.passcodeError = this.getPasscodeMismatchText();
          this.enteredPasscode = '';
        }
        break;

      case PasscodeFlowMode.VERIFY_DISABLE:
        if (this.enteredPasscode === this.savedPasscode) {
          this.passcodeEnabled = false;
          this.biometricEnabled = false;
          this.savePasscodeEnabled(false);
          this.saveBiometricEnabled(false);
          this.savedPasscode = '';
          this.resetPasscodeFlow();
        } else {
          this.passcodeError = this.getPasscodeMismatchText();
          this.enteredPasscode = '';
        }
        break;

      case PasscodeFlowMode.VERIFY_CHANGE:
        if (this.enteredPasscode === this.savedPasscode) {
          this.enteredPasscode = '';
          this.firstPasscode = '';
          this.flowMode = PasscodeFlowMode.SETUP_ENTER;
        } else {
          this.passcodeError = this.getPasscodeMismatchText();
          this.enteredPasscode = '';
        }
        break;

      case PasscodeFlowMode.NONE:
      default:
        break;
    }
  }
}
