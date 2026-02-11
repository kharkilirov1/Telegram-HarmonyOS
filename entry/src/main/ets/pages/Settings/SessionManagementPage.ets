// Active Sessions / Devices management page
// Reference: Telegram iOS SessionsController, Android SessionsActivity

import { SessionService, SessionInfo } from '../../services/SessionService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CurrentSessionCard } from './components/CurrentSessionCard';
import { SessionRowItem } from './components/SessionRowItem';
import { SessionSectionHeader } from './components/SessionSectionHeader';
import { SessionTopBar } from './components/SessionTopBar';
import { TerminateAllConfirmSheet } from './components/TerminateAllConfirmSheet';
import { TerminateAllSessionsCard } from './components/TerminateAllSessionsCard';

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
        SessionTopBar({
          onBack: () => {
            this.navPathStack.pop();
          }
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
                SessionSectionHeader({ title: $r('app.string.current_session') })

                Column() {
                  CurrentSessionCard({
                    appDisplayName: `${this.currentSession!.applicationName} ${this.currentSession!.applicationVersion}`,
                    deviceDisplayName: `${this.currentSession!.deviceModel}, ${this.currentSession!.platform} ${this.currentSession!.systemVersion}`,
                    lastActiveLabel: this.formatLastActive(this.currentSession!.lastActiveDate),
                    ip: this.currentSession!.ip,
                    location: this.formatLocation(this.currentSession!)
                  })
                }
                .width('100%')
                .backgroundColor($r('app.color.glass_card_bg'))
                .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
                .borderRadius(24)
                .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
                .margin({ left: 12, right: 12 })

                Blank().height(24)
              }

              // --- Terminate All Other Sessions ---
              if (this.otherSessions.length > 0) {
                TerminateAllSessionsCard({
                  onTap: () => {
                    this.showTerminateAllDialog = true;
                  }
                })

                Text($r('app.string.terminate_all_warning'))
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ left: 32, right: 32, top: 6 })

                Blank().height(24)

                // --- Other Sessions List ---
                SessionSectionHeader({ title: $r('app.string.other_sessions') })

                Column() {
                  ForEach(this.otherSessions, (session: SessionInfo, index: number) => {
                    if (index > 0) {
                      Divider()
                        .strokeWidth(0.5)
                        .color($r('app.color.separator'))
                        .margin({ left: 16 })
                    }
                    SessionRowItem({
                      sessionId: session.id,
                      appDisplayName: `${session.applicationName} ${session.applicationVersion}`,
                      deviceDisplayName: `${session.deviceModel}, ${session.platform} ${session.systemVersion}`,
                      lastActiveLabel: this.formatLastActive(session.lastActiveDate),
                      ip: session.ip,
                      location: this.formatLocation(session),
                      onTerminate: (sessionId: number) => {
                        this.terminateSession(sessionId);
                      }
                    })
                  }, (session: SessionInfo) => session.id.toString())
                }
                .width('100%')
                .backgroundColor($r('app.color.glass_card_bg'))
                .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
                .borderRadius(24)
                .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
                .margin({ left: 12, right: 12 })
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
                .borderRadius(24)
                .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
                .margin({ left: 12, right: 12 })
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
  terminateAllConfirmSheet() {
    TerminateAllConfirmSheet({
      onConfirm: () => {
        this.showTerminateAllDialog = false;
        this.terminateAllOtherSessions();
      },
      onCancel: () => {
        this.showTerminateAllDialog = false;
      }
    })
  }
}
