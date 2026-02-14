// Create Poll page — compose a poll/quiz to send in a chat
// Reference: Telegram Android CreatePollActivity, iOS CreatePollController

import { MessagesController } from '../../controllers/MessagesController';
import { promptAction } from '@kit.ArkUI';

@Builder
export function CreatePollBuilder(name: string, param: Object) {
  CreatePollPage({ chatId: (param as Record<string, number>)['chatId'] || 0 })
}

@ComponentV2
export struct CreatePollPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param chatId: number = 0;

  @Local question: string = '';
  @Local options: string[] = ['', ''];
  @Local isAnonymous: boolean = true;
  @Local isQuiz: boolean = false;
  @Local correctOptionIndex: number = -1;
  @Local isSending: boolean = false;

  private readonly minOptions: number = 2;
  private readonly maxOptions: number = 10;

  build() {
    NavDestination() {
      Column() {
        // Top bar
        this.buildTopBar()

        // Content
        Scroll() {
          Column() {
            // Question section
            this.buildQuestionSection()

            // Options section
            this.buildOptionsSection()

            // Settings section
            this.buildSettingsSection()

            Blank().height(40)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        // Create button
        this.buildCreateButton()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_primary'))
    }
    .hideTitleBar(true)
  }

  @Builder
  buildTopBar() {
    Row() {
      Image($r('app.media.ic_back'))
        .width(24).height(24)
        .fillColor($r('app.color.telegram_blue'))
        .padding(12)
        .onClick(() => this.navPathStack.pop())

      Text($r('app.string.new_poll'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 16 })
        .layoutWeight(1)
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 12 })
    .backgroundColor($r('app.color.glass_nav_bg'))
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
      colorMode: ThemeColorMode.SYSTEM,
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 1.0
    })
    .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 24, bottomRight: 24 })
    .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 2 })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  buildQuestionSection() {
    Column() {
      Text($r('app.string.question_label'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 16, top: 16, bottom: 8 })
        .width('100%')

      Column() {
        TextInput({ placeholder: $r('app.string.ask_a_question'), text: this.question })
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor(Color.Transparent)
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onChange((value: string) => {
            this.question = value;
          })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(24)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 12, right: 12 })
    }
    .width('100%')
  }

  @Builder
  buildOptionsSection() {
    Column() {
      Text($r('app.string.options_label'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 16, top: 20, bottom: 8 })
        .width('100%')

      Column() {
        ForEach(this.options, (option: string, index: number) => {
          Column() {
            Row() {
              if (this.isQuiz) {
                Radio({ value: `option_${index}`, group: 'correctAnswer' })
                  .checked(this.correctOptionIndex === index)
                  .onChange((isChecked: boolean) => {
                    if (isChecked) {
                      this.correctOptionIndex = index;
                    }
                  })
                  .width(20).height(20)
                  .margin({ right: 8 })
              }

              TextInput({ placeholder: this.formatOptionPlaceholder(index), text: option })
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor(Color.Transparent)
                .layoutWeight(1)
                .onChange((value: string) => {
                  let updated = [...this.options];
                  updated[index] = value;
                  this.options = updated;
                })

              if (this.options.length > this.minOptions) {
                Image($r('app.media.ic_close'))
                  .width(18).height(18)
                  .fillColor($r('app.color.text_secondary'))
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.removeOption(index);
                  })
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })

            if (index < this.options.length - 1) {
              Divider()
                .strokeWidth(0.5)
                .color($r('app.color.separator'))
                .margin({ left: this.isQuiz ? 52 : 16 })
            }
          }
        }, (option: string, index: number) => `option_${index}_${this.options.length}`)

        // Add Option button
        if (this.options.length < this.maxOptions) {
          Divider()
            .strokeWidth(0.5)
            .color($r('app.color.separator'))
            .margin({ left: 16 })

          Row() {
            Text('+')
              .fontSize(20)
              .fontColor($r('app.color.telegram_blue'))
              .margin({ right: 12 })

            Text($r('app.string.add_option'))
              .fontSize(16)
              .fontColor($r('app.color.telegram_blue'))
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            this.addOption();
          })
        }
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(24)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 12, right: 12 })

      if (this.isQuiz) {
        Text($r('app.string.quiz_correct_hint'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 16, right: 16, top: 8 })
          .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  buildSettingsSection() {
    Column() {
      Text($r('app.string.settings'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 16, top: 20, bottom: 8 })
        .width('100%')

      Column() {
        // Anonymous toggle
        Row() {
          Text($r('app.string.anonymous_voting'))
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.isAnonymous })
            .selectedColor($r('app.color.telegram_blue'))
            .onChange((isOn: boolean) => {
              this.isAnonymous = isOn;
            })
        }
        .width('100%')
        .height(52)
        .padding({ left: 16, right: 16 })

        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

        // Quiz mode toggle
        Row() {
          Column() {
            Text($r('app.string.quiz_mode'))
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))

            Text($r('app.string.quiz_hint'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.isQuiz })
            .selectedColor($r('app.color.telegram_blue'))
            .onChange((isOn: boolean) => {
              this.isQuiz = isOn;
              if (!isOn) {
                this.correctOptionIndex = -1;
              }
            })
        }
        .width('100%')
        .constraintSize({ minHeight: 52 })
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }
      .width('100%')
      .backgroundColor($r('app.color.glass_card_bg'))
      .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
      .borderRadius(24)
      .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
      .margin({ left: 12, right: 12 })
    }
    .width('100%')
  }

  @Builder
  buildCreateButton() {
    Column() {
      Button(this.isSending ? $r('app.string.sending') : $r('app.string.create_poll'))
        .type(ButtonType.Capsule)
        .width('100%')
        .height(48)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.canCreate() ? $r('app.color.telegram_blue') : $r('app.color.text_secondary'))
        .fontColor(Color.White)
        .enabled(this.canCreate() && !this.isSending)
        .onClick(() => {
          this.sendPoll();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 16 })
    .backgroundColor($r('app.color.background_primary'))
  }

  private canCreate(): boolean {
    if (this.question.trim().length === 0) {
      return false;
    }

    const filledOptions = this.options.filter(o => o.trim().length > 0);
    if (filledOptions.length < this.minOptions) {
      return false;
    }

    if (this.isQuiz && this.correctOptionIndex < 0) {
      return false;
    }

    if (this.isQuiz && this.correctOptionIndex >= this.options.length) {
      return false;
    }

    if (this.isQuiz && this.options[this.correctOptionIndex].trim().length === 0) {
      return false;
    }

    return true;
  }

  private addOption(): void {
    if (this.options.length >= this.maxOptions) return;
    this.options = [...this.options, ''];
  }

  private removeOption(index: number): void {
    if (this.options.length <= this.minOptions) return;

    let updated = this.options.filter((_: string, i: number) => i !== index);
    this.options = updated;

    // Adjust correctOptionIndex after removal
    if (this.correctOptionIndex === index) {
      this.correctOptionIndex = -1;
    } else if (this.correctOptionIndex > index) {
      this.correctOptionIndex = this.correctOptionIndex - 1;
    }
  }

  private async sendPoll(): Promise<void> {
    if (!this.canCreate() || this.isSending) return;
    this.isSending = true;

    // Filter out empty options and collect only filled ones
    const filledOptions = this.options.filter(o => o.trim().length > 0);

    // Recalculate correct option index for the filtered list
    let correctId = -1;
    if (this.isQuiz && this.correctOptionIndex >= 0) {
      const correctText = this.options[this.correctOptionIndex];
      correctId = filledOptions.indexOf(correctText);
    }

    try {
      await MessagesController.getInstance().sendPoll(
        this.chatId,
        this.question.trim(),
        filledOptions.map(o => o.trim()),
        this.isAnonymous,
        this.isQuiz,
        correctId
      );
      this.navPathStack.pop();
    } catch (_e) {
      promptAction.showToast({
        message: getContext(this).resourceManager.getStringByNameSync('action_failed'),
        duration: 1500,
        bottom: 96
      });
      this.isSending = false;
    }
  }

  private formatOptionPlaceholder(index: number): string {
    const template = getContext(this).resourceManager.getStringByNameSync('poll_option_placeholder');
    return template.replace('%d', (index + 1).toString());
  }
}
