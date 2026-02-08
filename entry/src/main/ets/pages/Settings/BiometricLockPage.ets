// Biometric Lock / Passcode Lock settings page
// Reference: Telegram iOS PasscodeController, Android PasscodeActivity

import { PreferencesService } from '../../services/PreferencesService';

enum PasscodeFlowMode {
  NONE,
  SETUP_ENTER,
  SETUP_CONFIRM,
  VERIFY_DISABLE,
  VERIFY_CHANGE
}

interface AutoLockOption {
  labelRes: Resource;
  seconds: number;
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

  private readonly autoLockOptions: AutoLockOption[] = [
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
        // --- Main settings view ---
        Column() {
          // Top bar
          Row() {
            Image($r('app.media.ic_back'))
              .width(24).height(24)
              .fillColor($r('app.color.telegram_blue'))
              .accessibilityText($r('app.string.accessibility_back'))
              .onClick(() => this.navPathStack.pop())

            Text($r('app.string.passcode_lock'))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ left: 16 })

            Blank()
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .backgroundColor($r('app.color.glass_nav_bg'))
          .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
            colorMode: ThemeColorMode.SYSTEM,
            adaptiveColor: AdaptiveColor.DEFAULT,
            scale: 1.0
          })

          Scroll() {
            Column() {
              Blank().height(16)

              // --- Passcode toggle section ---
              Column() {
                Row() {
                  Text($r('app.string.enable_passcode'))
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)

                  Toggle({ type: ToggleType.Switch, isOn: this.passcodeEnabled })
                    .selectedColor($r('app.color.telegram_blue'))
                    .accessibilityText($r('app.string.accessibility_toggle_passcode'))
                    .onChange((isOn: boolean) => {
                      if (isOn) {
                        this.firstPasscode = '';
                        this.enteredPasscode = '';
                        this.passcodeError = '';
                        this.flowMode = PasscodeFlowMode.SETUP_ENTER;
                      } else {
                        this.enteredPasscode = '';
                        this.passcodeError = '';
                        this.flowMode = PasscodeFlowMode.VERIFY_DISABLE;
                      }
                    })
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

              if (this.passcodeEnabled) {
                Blank().height(24)

                // --- Biometric + Options section ---
                Column() {
                  // Biometric toggle
                  Row() {
                    Text($r('app.string.use_biometric'))
                      .fontSize(16)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)

                    Toggle({ type: ToggleType.Switch, isOn: this.biometricEnabled })
                      .selectedColor($r('app.color.telegram_blue'))
                      .accessibilityText($r('app.string.accessibility_toggle_biometric'))
                      .onChange((isOn: boolean) => {
                        this.biometricEnabled = isOn;
                        this.saveBiometricEnabled(isOn);
                      })
                  }
                  .width('100%').height(48)
                  .padding({ left: 16, right: 16 })

                  Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

                  // Auto-lock timeout
                  Row() {
                    Text($r('app.string.auto_lock_timeout'))
                      .fontSize(16)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)

                    Text(this.getAutoLockLabel())
                      .fontSize(15)
                      .fontColor($r('app.color.text_secondary'))

                    Image($r('app.media.ic_forward'))
                      .width(14).height(14)
                      .fillColor($r('app.color.text_secondary'))
                      .margin({ left: 6 })
                  }
                  .width('100%').height(48)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => {
                    this.showAutoLockPicker = true;
                  })

                  Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

                  // Show notifications content
                  Row() {
                    Text($r('app.string.show_notifications_content'))
                      .fontSize(16)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)

                    Toggle({ type: ToggleType.Switch, isOn: this.showNotificationsContent })
                      .selectedColor($r('app.color.telegram_blue'))
                      .onChange((isOn: boolean) => {
                        this.showNotificationsContent = isOn;
                      })
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

                // --- Change / Turn off passcode ---
                Column() {
                  // Change passcode
                  Row() {
                    Text($r('app.string.change_passcode'))
                      .fontSize(16)
                      .fontColor($r('app.color.telegram_blue'))
                      .layoutWeight(1)
                  }
                  .width('100%').height(48)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => {
                    this.firstPasscode = '';
                    this.enteredPasscode = '';
                    this.passcodeError = '';
                    this.flowMode = PasscodeFlowMode.VERIFY_CHANGE;
                  })

                  Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

                  // Turn off passcode
                  Row() {
                    Text($r('app.string.turn_off_passcode'))
                      .fontSize(16)
                      .fontColor($r('app.color.error_red'))
                      .layoutWeight(1)
                  }
                  .width('100%').height(48)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => {
                    this.enteredPasscode = '';
                    this.passcodeError = '';
                    this.flowMode = PasscodeFlowMode.VERIFY_DISABLE;
                  })
                }
                .width('100%')
                .backgroundColor($r('app.color.glass_card_bg'))
                .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
                .borderRadius(16)
                .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
                .margin({ left: 16, right: 16 })
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

        // --- Passcode input overlay ---
        if (this.flowMode !== PasscodeFlowMode.NONE) {
          Column() {
            // Top bar
            Row() {
              Image($r('app.media.ic_back'))
                .width(24).height(24)
                .fillColor($r('app.color.telegram_blue'))
                .onClick(() => {
                  this.flowMode = PasscodeFlowMode.NONE;
                  this.enteredPasscode = '';
                  this.firstPasscode = '';
                  this.passcodeError = '';
                })

              Blank()
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })

            Blank().height(40)

            // Title based on flow mode
            Text(this.getPasscodeTitle())
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ bottom: 32 })

            // Dot indicators
            Row({ space: 16 }) {
              ForEach(this.getDotArray(), (index: number) => {
                Circle()
                  .width(14).height(14)
                  .fill(index < this.enteredPasscode.length
                    ? $r('app.color.telegram_blue')
                    : Color.Transparent)
                  .stroke($r('app.color.telegram_blue'))
                  .strokeWidth(1.5)
                  .accessibilityText($r('app.string.accessibility_passcode_dot'))
              }, (index: number) => index.toString())
            }
            .margin({ bottom: 12 })

            // Error message
            if (this.passcodeError.length > 0) {
              Text(this.passcodeError)
                .fontSize(13)
                .fontColor($r('app.color.error_red'))
                .margin({ top: 4, bottom: 4 })
                .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
            } else {
              Blank().height(21)
            }

            Blank()

            // Numeric keyboard
            Column({ space: 12 }) {
              // Row 1: 1 2 3
              Row({ space: 24 }) {
                this.numKey('1')
                this.numKey('2')
                this.numKey('3')
              }

              // Row 2: 4 5 6
              Row({ space: 24 }) {
                this.numKey('4')
                this.numKey('5')
                this.numKey('6')
              }

              // Row 3: 7 8 9
              Row({ space: 24 }) {
                this.numKey('7')
                this.numKey('8')
                this.numKey('9')
              }

              // Row 4: [empty] 0 [delete]
              Row({ space: 24 }) {
                // Empty spacer matching key size
                Column()
                  .width(72).height(72)

                this.numKey('0')

                // Delete button
                Column() {
                  Image($r('app.media.ic_back'))
                    .width(24).height(24)
                    .fillColor($r('app.color.text_primary'))
                }
                .width(72).height(72)
                .borderRadius(36)
                .justifyContent(FlexAlign.Center)
                .onClick(() => {
                  if (this.enteredPasscode.length > 0) {
                    this.enteredPasscode = this.enteredPasscode.substring(0, this.enteredPasscode.length - 1);
                  }
                })
              }
            }
            .margin({ bottom: 40 })
          }
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.background_primary'))
          .alignItems(HorizontalAlign.Center)
          .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        }

        // --- Auto-lock timeout picker overlay ---
        if (this.showAutoLockPicker) {
          Column() {
            // Backdrop
            Column()
              .width('100%')
              .layoutWeight(1)
              .backgroundColor($r('app.color.overlay_dark'))
              .onClick(() => {
                this.showAutoLockPicker = false;
              })

            // Bottom sheet
            Column() {
              // Handle bar
              Row() {
                Column()
                  .width(36).height(4)
                  .borderRadius(2)
                  .backgroundColor($r('app.color.separator'))
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding({ top: 8, bottom: 16 })

              Text($r('app.string.auto_lock_timeout'))
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .margin({ bottom: 8, left: 16 })

              ForEach(this.autoLockOptions, (option: AutoLockOption, index: number) => {
                Row() {
                  Text(option.labelRes)
                    .fontSize(16)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)

                  if (this.autoLockTimeout === option.seconds) {
                    Image($r('app.media.ic_check'))
                      .width(20).height(20)
                      .fillColor($r('app.color.telegram_blue'))
                  }
                }
                .width('100%').height(48)
                .padding({ left: 16, right: 16 })
                .accessibilityText(option.labelRes)
                .onClick(() => {
                  this.autoLockTimeout = option.seconds;
                  this.saveAutoLockTimeout(option.seconds);
                  this.showAutoLockPicker = false;
                })

                if (index < this.autoLockOptions.length - 1) {
                  Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
                }
              }, (option: AutoLockOption) => option.seconds.toString())

              Blank().height(34)
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius({ topLeft: 16, topRight: 16 })
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: -2 })
          }
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
  }

  @Builder
  numKey(digit: string) {
    Column() {
      Text(digit)
        .fontSize(28)
        .fontWeight(FontWeight.Regular)
        .fontColor($r('app.color.text_primary'))
    }
    .width(72).height(72)
    .borderRadius(36)
    .backgroundColor($r('app.color.background_secondary'))
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.enteredPasscode.length < this.passcodeLength) {
        this.enteredPasscode += digit;
        this.passcodeError = '';

        if (this.enteredPasscode.length === this.passcodeLength) {
          this.onPasscodeComplete();
        }
      }
    })
  }

  private getPasscodeTitle(): Resource {
    switch (this.flowMode) {
      case PasscodeFlowMode.SETUP_CONFIRM:
        return $r('app.string.confirm_passcode');
      case PasscodeFlowMode.VERIFY_DISABLE:
      case PasscodeFlowMode.VERIFY_CHANGE:
        return $r('app.string.enter_passcode');
      default:
        return $r('app.string.enter_passcode');
    }
  }

  private getDotArray(): number[] {
    let dots: number[] = [];
    for (let i = 0; i < this.passcodeLength; i++) {
      dots.push(i);
    }
    return dots;
  }

  private getAutoLockLabel(): Resource {
    for (let i = 0; i < this.autoLockOptions.length; i++) {
      if (this.autoLockOptions[i].seconds === this.autoLockTimeout) {
        return this.autoLockOptions[i].labelRes;
      }
    }
    return $r('app.string.auto_lock_disabled');
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
          this.flowMode = PasscodeFlowMode.NONE;
          this.enteredPasscode = '';
          this.firstPasscode = '';
        } else {
          this.passcodeError = getContext(this).resourceManager.getStringSync($r('app.string.passcode_mismatch'));
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
          this.flowMode = PasscodeFlowMode.NONE;
          this.enteredPasscode = '';
        } else {
          this.passcodeError = getContext(this).resourceManager.getStringSync($r('app.string.passcode_mismatch'));
          this.enteredPasscode = '';
        }
        break;

      case PasscodeFlowMode.VERIFY_CHANGE:
        if (this.enteredPasscode === this.savedPasscode) {
          this.enteredPasscode = '';
          this.firstPasscode = '';
          this.flowMode = PasscodeFlowMode.SETUP_ENTER;
        } else {
          this.passcodeError = getContext(this).resourceManager.getStringSync($r('app.string.passcode_mismatch'));
          this.enteredPasscode = '';
        }
        break;

      default:
        break;
    }
  }
}
