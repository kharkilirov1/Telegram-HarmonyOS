// BotCommandBar — shows bot commands menu and Mini App button
// Reference: Telegram iOS BotCommandMenu, Android BotKeyboardView

import { UserService } from '../../services/UserService';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface BotCommand {
  command: string;
  description: string;
}

@ComponentV2
export struct BotCommandBar {
  @Param chatId: number = 0;
  @Param botUserId: number = 0;
  @Param onCommandSelected: (command: string) => void = () => {};
  @Param onMiniAppOpen: (url: string) => void = () => {};
  @Local commands: BotCommand[] = [];
  @Local botDescription: string = '';
  @Local hasMenuButton: boolean = false;
  @Local menuButtonText: string = '';
  @Local menuButtonUrl: string = '';
  @Local showCommands: boolean = false;
  @Local isLoading: boolean = true;

  aboutToAppear(): void {
    this.loadBotInfo();
  }

  private async loadBotInfo(): Promise<void> {
    this.isLoading = true;

    try {
      // Get full bot info via TDLib
      const result: Record<string, Object> = await UserService.getInstance().getUserFullInfo(this.botUserId);

      const botInfo: Record<string, Object> | undefined = result['bot_info'] as Record<string, Object>;
      if (botInfo) {
        const shortDesc: Record<string, Object> | undefined = botInfo['short_description'] as Record<string, Object>;
        this.botDescription = shortDesc !== undefined ? ((shortDesc['text'] as string) || '') : '';

        // Commands
        const rawCommands: Record<string, Object>[] | undefined = botInfo['commands'] as Record<string, Object>[];
        if (rawCommands) {
          const parsed: BotCommand[] = [];
          for (const cmd of rawCommands) {
            const cmdObj: BotCommand = {
              command: `/${(cmd['command'] as string) || ''}`,
              description: (cmd['description'] as string) || ''
            };
            parsed.push(cmdObj);
          }
          this.commands = parsed;
        }

        // Menu button (Mini App)
        const menuButton: Record<string, Object> | undefined = botInfo['menu_button'] as Record<string, Object>;
        if (menuButton) {
          const btnType: string = (menuButton['@type'] as string) || '';
          if (btnType === 'botMenuButton') {
            this.hasMenuButton = true;
            this.menuButtonText = (menuButton['text'] as string) || '';
            this.menuButtonUrl = (menuButton['url'] as string) || '';
          }
        }
      }
    } catch (e) {
      hilog.warn(0x0001, 'BotCommandBar', 'Failed to load bot info');
    }

    this.isLoading = false;
  }

  build() {
    Column() {
      // Mini App button (if bot has one)
      if (this.hasMenuButton && this.menuButtonUrl.length > 0) {
        Button() {
          Row({ space: 6 }) {
            Image($r('app.media.ic_settings'))
              .width(16).height(16)
              .fillColor($r('app.color.icon_on_primary'))
            Text(this.menuButtonText.length > 0 ? this.menuButtonText : $r('app.string.open_mini_app'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.icon_on_primary'))
          }
        }
        .width('90%')
        .height(40)
        .borderRadius(20)
        .backgroundColor($r('app.color.telegram_blue'))
        .margin({ top: 8, bottom: 4 })
        .onClick(() => {
          this.onMiniAppOpen(this.menuButtonUrl);
        })
      }

      // Commands toggle
      if (this.commands.length > 0) {
        Row() {
          Image($r('app.media.ic_settings'))
            .width(18).height(18)
            .fillColor($r('app.color.telegram_blue'))

          Text($r('app.string.bot_commands'))
            .fontSize(14)
            .fontColor($r('app.color.telegram_blue'))
            .fontWeight(FontWeight.Medium)
            .margin({ left: 6 })

          Blank()

          Image($r('app.media.ic_arrow_down'))
            .width(16).height(16)
            .fillColor($r('app.color.text_secondary'))
            .rotate({ angle: this.showCommands ? 180 : 0 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .onClick(() => {
          this.showCommands = !this.showCommands;
        })

        // Command list
        if (this.showCommands) {
          Column() {
            ForEach(this.commands, (cmd: BotCommand) => {
              Row() {
                Text(cmd.command)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.telegram_blue'))
                  .constraintSize({ minWidth: 80 })

                Text(cmd.description)
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ left: 12 })
                  .layoutWeight(1)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .onClick(() => {
                this.onCommandSelected(cmd.command);
                this.showCommands = false;
              })
            }, (cmd: BotCommand) => `cmd_${cmd.command}`)
          }
          .backgroundColor($r('app.color.background_secondary'))
          .borderRadius(8)
          .margin({ left: 8, right: 8, bottom: 4 })
        }
      }
    }
    .width('100%')
  }
}
