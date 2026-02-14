// Active call UI page — voice/video call screen
// Reference: Telegram iOS CallViewController, Android VoIPActivity
// HarmonyOS: NavDestination, immersive window, timer

import { CallsController } from '../../controllers/CallsController';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';

@Builder
export function CallUIBuilder(name: string, param: Object) {
  CallUIPage({
    userId: (param as Record<string, number>)['userId'] ?? 0,
    userName: (param as Record<string, string>)['userName'] ?? '',
    isVideo: (param as Record<string, boolean>)['isVideo'] ?? false,
    isIncoming: (param as Record<string, boolean>)['isIncoming'] ?? false
  })
}

@ComponentV2
export struct CallUIPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param userId: number = 0;
  @Param userName: string = '';
  @Param isVideo: boolean = false;
  @Param isIncoming: boolean = false;

  @Local callState: string = 'connecting';  // connecting, ringing, active, ended
  @Local callDuration: number = 0;
  @Local isMuted: boolean = false;
  @Local isSpeaker: boolean = false;
  @Local isVideoEnabled: boolean = false;
  @Local showControls: boolean = true;

  private durationTimerId: number = -1;

  private callStateHandler = (args?: Record<string, Object>): void => {
    if (!args) return;
    const state = args['state'] as string;
    if (state === 'callStateReady') {
      this.callState = 'active';
      this.startDurationTimer();
    } else if (state === 'callStateDiscarded' || state === 'callStateError') {
      this.callState = 'ended';
      this.stopDurationTimer();
      // Auto-close after 1.5s
      setTimeout(() => {
        this.navPathStack.pop();
      }, 1500);
    }
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance()
      .addObserver(EventId.CALL_STATE_UPDATED, this.callStateHandler);

    this.isVideoEnabled = this.isVideo;

    if (this.isIncoming) {
      this.callState = 'ringing';
    } else {
      this.callState = 'connecting';
    }
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance()
      .removeObserver(EventId.CALL_STATE_UPDATED, this.callStateHandler);
    this.stopDurationTimer();
  }

  build() {
    NavDestination() {
      Stack() {
        // Background — gradient or video feed
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.call_bg_dark'))
          .linearGradient({
            direction: GradientDirection.LeftTop,
            colors: [[$r('app.color.call_bg_dark'), 0.0], [$r('app.color.call_bg_mid'), 0.5], [$r('app.color.call_bg_deep'), 1.0]]
          })

        // Call UI content
        Column() {
          Blank().height(60)

          // --- Caller info ---
          Column() {
            // Avatar
            Text(this.getDisplayName().charAt(0))
              .fontSize(44)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width(120).height(120)
              .borderRadius(60)
              .backgroundColor($r('app.color.telegram_blue'))
              .textAlign(TextAlign.Center)

            Text(this.getDisplayName())
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .margin({ top: 16 })

            // Call status
            Text(this.getCallStatusText())
              .fontSize(16)
              .fontColor($r('app.color.call_status_text'))
              .margin({ top: 6 })
          }
          .alignItems(HorizontalAlign.Center)

          Blank().layoutWeight(1)

          // --- Controls ---
          if (this.callState === 'ringing' && this.isIncoming) {
            // Incoming call: Decline / Accept
            Row({ space: 60 }) {
              // Decline
              Column() {
                Column() {
                  Image($r('app.media.ic_close'))
                    .width(28).height(28)
                    .fillColor(Color.White)
                }
                .width(64).height(64)
                .borderRadius(32)
                .backgroundColor($r('app.color.error_red'))
                .justifyContent(FlexAlign.Center)

                Text($r('app.string.decline'))
                  .fontSize(14)
                  .fontColor(Color.White)
                  .margin({ top: 8 })
              }
              .alignItems(HorizontalAlign.Center)
              .onClick(() => { this.declineCall(); })

              // Accept
              Column() {
                Column() {
                  Image($r('app.media.ic_phone_call'))
                    .width(28).height(28)
                    .fillColor(Color.White)
                }
                .width(64).height(64)
                .borderRadius(32)
                .backgroundColor($r('app.color.call_accept_green'))
                .justifyContent(FlexAlign.Center)

                Text($r('app.string.accept'))
                  .fontSize(14)
                  .fontColor(Color.White)
                  .margin({ top: 8 })
              }
              .alignItems(HorizontalAlign.Center)
              .onClick(() => { this.acceptCall(); })
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
          } else if (this.callState !== 'ended') {
            // Active/connecting: Mute / Speaker / Video / End
            Row({ space: 24 }) {
              // Mute
              this.controlButton($r('app.media.ic_mic'), $r('app.string.mute'),
                this.isMuted, () => { this.isMuted = !this.isMuted; })

              // Speaker
              this.controlButton($r('app.media.ic_unmute'), $r('app.string.call_control_speaker'),
                this.isSpeaker, () => { this.isSpeaker = !this.isSpeaker; })

              // Video
              this.controlButton($r('app.media.ic_settings'), $r('app.string.call_control_video'),
                this.isVideoEnabled, () => { this.isVideoEnabled = !this.isVideoEnabled; })

              // Flip camera (when video)
              if (this.isVideoEnabled) {
                this.controlButton($r('app.media.ic_camera'), $r('app.string.call_control_flip'),
                  false, () => {})
              }
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .margin({ bottom: 32 })

            // End call button
            Column() {
              Column() {
                Image($r('app.media.ic_close'))
                  .width(28).height(28)
                  .fillColor(Color.White)
              }
              .width(64).height(64)
              .borderRadius(32)
              .backgroundColor($r('app.color.error_red'))
              .justifyContent(FlexAlign.Center)
              .onClick(() => { this.endCall(); })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          } else {
            // Ended state
            Text($r('app.string.call_ended'))
              .fontSize(22)
              .fontColor($r('app.color.call_ended_text'))
          }

          Blank().height(60)
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
  }

  @Builder
  controlButton(icon: Resource, label: Resource, isActive: boolean, onTap: () => void) {
    Column() {
      Column() {
        Image(icon)
          .width(24).height(24)
          .fillColor(isActive ? $r('app.color.call_bg_dark') : Color.White)
      }
      .width(52).height(52)
      .borderRadius(26)
      .backgroundColor(isActive ? Color.White : $r('app.color.call_button_inactive'))
      .justifyContent(FlexAlign.Center)
      .onClick(onTap)

      Text(label)
        .fontSize(12)
        .fontColor(Color.White)
        .margin({ top: 6 })
    }
    .alignItems(HorizontalAlign.Center)
  }

  private getCallStatusText(): string {
    switch (this.callState) {
      case 'connecting': return this.getString('call_connecting', 'Connecting...');
      case 'ringing': return this.isIncoming
        ? this.getString('incoming_call', 'Incoming call')
        : this.getString('call_ringing', 'Ringing...');
      case 'active': return this.formatDuration(this.callDuration);
      case 'ended': return this.getString('call_ended', 'Call Ended');
      default: return '';
    }
  }

  private getDisplayName(): string {
    if (this.userName.length > 0) {
      return this.userName;
    }
    return this.getString('user_fallback', 'User');
  }

  private getString(name: string, fallback: string): string {
    try {
      return getContext(this).resourceManager.getStringByNameSync(name);
    } catch (_e) {
      return fallback;
    }
  }

  private formatDuration(seconds: number): string {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
  }

  private startDurationTimer(): void {
    this.callDuration = 0;
    this.durationTimerId = setInterval(() => {
      this.callDuration++;
    }, 1000);
  }

  private stopDurationTimer(): void {
    if (this.durationTimerId >= 0) {
      clearInterval(this.durationTimerId);
      this.durationTimerId = -1;
    }
  }

  private acceptCall(): void {
    this.callState = 'active';
    this.startDurationTimer();
  }

  private declineCall(): void {
    const callId = CallsController.getInstance().getActiveCallId();
    if (callId > 0) {
      CallsController.getInstance().discardCall(callId);
    }
    this.callState = 'ended';
    setTimeout(() => { this.navPathStack.pop(); }, 1000);
  }

  private endCall(): void {
    this.stopDurationTimer();
    const callId = CallsController.getInstance().getActiveCallId();
    if (callId > 0) {
      CallsController.getInstance().discardCall(callId);
    }
    this.callState = 'ended';
    setTimeout(() => { this.navPathStack.pop(); }, 1000);
  }
}
