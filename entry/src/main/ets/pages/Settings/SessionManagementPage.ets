// Active Sessions / Devices management page
// Reference: Telegram iOS SessionsController, Android SessionsActivity

import { SessionService, SessionInfo } from '../../services/SessionService';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'SessionManagementPage';
const DOMAIN = 0x0001;

@Builder
export function SessionManagementBuilder(name: string, param: Object) {
  SessionManagementPage()
}

@ComponentV2
export struct SessionManagementPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  @Local isLoading: boolean = true;
  @Local currentSession: SessionInfo | null = null;
  @Local otherSessions: SessionInfo[] = [];
  @Local showTerminateAllDialog: boolean = false;
  @Local terminatingSessionId: number = 0;

  private sessionService: SessionService = SessionService.getInstance();

  aboutToAppear(): void {
    this.loadSessions();
  }

  private async loadSessions(): Promise<void> {
    this.isLoading = true;
    try {
      const parsed = await this.sessionService.getActiveSessions();
      this.currentSession = parsed.find((s: SessionInfo) => s.isCurrent) ?? null;
      this.otherSessions = parsed.filter((s: SessionInfo) => !s.isCurrent);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Failed to load sessions: %{public}s', String(e));
    }
    this.isLoading = false;
  }

  private async terminateSession(sessionId: number): Promise<void> {
    this.terminatingSessionId = sessionId;
    const error = await this.sessionService.terminateSession(sessionId);
    if (!error) {
      this.otherSessions = this.otherSessions.filter((s: SessionInfo) => s.id !== sessionId);
    }
    this.terminatingSessionId = 0;
  }

  private async terminateAllOtherSessions(): Promise<void> {
    this.isLoading = true;
    const error = await this.sessionService.terminateAllOtherSessions();
    if (!error) {
      this.otherSessions = [];
    }
    this.isLoading = false;
  }

  private formatLastActive(timestamp: number): string {
    if (timestamp <= 0) {
      return '';
    }
    const now = Math.floor(Date.now() / 1000);
    const diff = now - timestamp;

    if (diff < 60) {
      try {
        return getContext(this).resourceManager.getStringByNameSync('online');
      } catch (e) {
        hilog.debug(DOMAIN, TAG, 'Resource "online" unavailable: %{public}s', String(e));
        return 'online';
      }
    } else if (diff < 3600) {
      const minutes = Math.floor(diff / 60);
      try {
        const template = getContext(this).resourceManager.getStringByNameSync('last_active_minutes');
        return template.replace('%d', minutes.toString());
      } catch (e) {
        hilog.debug(DOMAIN, TAG, 'Resource "last_active_minutes" unavailable: %{public}s', String(e));
        return `${minutes}m ago`;
      }
    } else if (diff < 86400) {
      const hours = Math.floor(diff / 3600);
      try {
        const template = getContext(this).resourceManager.getStringByNameSync('last_active_hours');
        return template.replace('%d', hours.toString());
      } catch (e) {
        hilog.debug(DOMAIN, TAG, 'Resource "last_active_hours" unavailable: %{public}s', String(e));
        return `${hours}h ago`;
      }
    } else {
      const days = Math.floor(diff / 86400);
      try {
        const template = getContext(this).resourceManager.getStringByNameSync('last_active_days');
        return template.replace('%d', days.toString());
      } catch (e) {
        hilog.debug(DOMAIN, TAG, 'Resource "last_active_days" unavailable: %{public}s', String(e));
        return `${days}d ago`;
      }
    }
  }

  private formatLocation(session: SessionInfo): string {
    const parts: string[] = [];
    if (session.region) {
      parts.push(session.region);
    }
    if (session.country) {
      parts.push(session.country);
    }
    return parts.join(', ');
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .accessibilityText($r('app.string.accessibility_back'))
            .onClick(() => this.navPathStack.pop())

          Text($r('app.string.active_sessions'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })

        if (this.isLoading) {
          // Loading state
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color($r('app.color.telegram_blue'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          Scroll() {
            Column() {
              // --- Current Session ---
              if (this.currentSession !== null) {
                this.sectionHeader($r('app.string.current_session'))

                Column() {
                  this.currentSessionCard(this.currentSession!)
                }
                .width('100%')
                .backgroundColor($r('app.color.glass_card_bg'))
                .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
                .borderRadius(16)
                .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
                .margin({ left: 16, right: 16 })

                Blank().height(24)
              }

              // --- Terminate All Other Sessions ---
              if (this.otherSessions.length > 0) {
                Column() {
                  Row() {
                    Text($r('app.string.terminate_all_sessions'))
                      .fontSize(16)
                      .fontColor($r('app.color.logout_red'))
                      .textAlign(TextAlign.Center)
                      .width('100%')
                  }
                  .width('100%')
                  .height(48)
                  .justifyContent(FlexAlign.Center)
                  .accessibilityText($r('app.string.accessibility_terminate_all'))
                  .onClick(() => {
                    this.showTerminateAllDialog = true;
                  })
                }
                .width('100%')
                .backgroundColor($r('app.color.glass_card_bg'))
                .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
                .borderRadius(16)
                .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
                .margin({ left: 16, right: 16 })

                Text($r('app.string.terminate_all_warning'))
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ left: 32, right: 32, top: 6 })

                Blank().height(24)

                // --- Other Sessions List ---
                this.sectionHeader($r('app.string.other_sessions'))

                Column() {
                  ForEach(this.otherSessions, (session: SessionInfo, index: number) => {
                    if (index > 0) {
                      Divider()
                        .strokeWidth(0.5)
                        .color($r('app.color.separator'))
                        .margin({ left: 16 })
                    }
                    this.sessionRow(session)
                  }, (session: SessionInfo) => session.id.toString())
                }
                .width('100%')
                .backgroundColor($r('app.color.glass_card_bg'))
                .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
                .borderRadius(16)
                .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
                .margin({ left: 16, right: 16 })
              } else {
                // No other sessions
                Column() {
                  Text($r('app.string.no_other_sessions'))
                    .fontSize(15)
                    .fontColor($r('app.color.text_secondary'))
                    .textAlign(TextAlign.Center)
                    .width('100%')
                    .padding(24)
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
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
      .bindSheet($$this.showTerminateAllDialog, this.terminateAllConfirmSheet(), {
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        backgroundColor: $r('app.color.glass_card_bg')
      })
    }
    .hideTitleBar(true)
  }

  @Builder
  currentSessionCard(session: SessionInfo) {
    Column() {
      Row() {
        Column() {
          Text(`${session.applicationName} ${session.applicationVersion}`)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.telegram_blue'))

          Text(`${session.deviceModel}, ${session.platform} ${session.systemVersion}`)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .margin({ top: 4 })

          Row() {
            Text(session.ip)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))

            if (this.formatLocation(session).length > 0) {
              Text(' \u2014 ')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))

              Text(this.formatLocation(session))
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }
          }
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    }
  }

  @Builder
  sessionRow(session: SessionInfo) {
    Row() {
      Column() {
        Row() {
          Text(`${session.applicationName} ${session.applicationVersion}`)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)

          Text(this.formatLastActive(session.lastActiveDate))
            .fontSize(13)
            .fontColor($r('app.color.telegram_blue'))
        }
        .width('100%')

        Text(`${session.deviceModel}, ${session.platform} ${session.systemVersion}`)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })

        Row() {
          Text(session.ip)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))

          if (this.formatLocation(session).length > 0) {
            Text(' \u2014 ')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))

            Text(this.formatLocation(session))
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .gesture(
      SwipeGesture({ direction: SwipeDirection.Horizontal })
        .onAction(() => {
          this.terminateSession(session.id);
        })
    )
  }

  @Builder
  terminateAllConfirmSheet() {
    Column() {
      Text($r('app.string.terminate_all_confirm'))
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
        .margin({ top: 24, left: 24, right: 24 })

      Text($r('app.string.terminate_all_warning'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .margin({ top: 12, left: 24, right: 24 })

      // Terminate All button
      Button($r('app.string.terminate_all_sessions'))
        .type(ButtonType.Capsule)
        .width('80%')
        .height(44)
        .backgroundColor($r('app.color.logout_red'))
        .fontColor($r('app.color.icon_on_primary'))
        .fontSize(16)
        .margin({ top: 24 })
        .onClick(() => {
          this.showTerminateAllDialog = false;
          this.terminateAllOtherSessions();
        })

      // Cancel button
      Button($r('app.string.cancel'))
        .type(ButtonType.Capsule)
        .width('80%')
        .height(44)
        .backgroundColor($r('app.color.overlay_gradient_end'))
        .fontColor($r('app.color.telegram_blue'))
        .fontSize(16)
        .margin({ top: 8, bottom: 24 })
        .onClick(() => {
          this.showTerminateAllDialog = false;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  sectionHeader(title: ResourceStr) {
    Text(title)
      .fontSize(13)
      .fontColor($r('app.color.text_secondary'))
      .margin({ left: 32, bottom: 6, top: 2 })
  }
}
