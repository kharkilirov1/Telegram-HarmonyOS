import { CallsController } from '../../controllers/CallsController';
import { ContactsController } from '../../controllers/ContactsController';
import { NotificationCenter, EventId } from '../../controllers/NotificationCenter';
import { Call } from '../../models/Call';
import { AvatarWithStatus } from '../../components/Common/AvatarWithStatus';
import { BasicDataSource } from '../../datasources/BasicDataSource';

@ComponentV2
export struct CallsPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local isLoading: boolean = true;
  @Local showMissedOnly: boolean = false;

  private callDataSource: BasicDataSource<Call> = new BasicDataSource<Call>();

  private callsHandler = (): void => {
    this.refreshCalls();
    this.isLoading = false;
  };

  private userHandler = (): void => {
    // Refresh to update user names
    this.refreshCalls();
  };

  aboutToAppear(): void {
    NotificationCenter.getInstance()
      .addObserver(EventId.CALLS_UPDATED, this.callsHandler);
    NotificationCenter.getInstance()
      .addObserver(EventId.USER_INFO_UPDATED, this.userHandler);

    CallsController.getInstance().loadCallHistory();
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance()
      .removeObserver(EventId.CALLS_UPDATED, this.callsHandler);
    NotificationCenter.getInstance()
      .removeObserver(EventId.USER_INFO_UPDATED, this.userHandler);
  }

  build() {
    Column() {
      // Top bar with segmented control
      Row() {
        Text($r('app.string.edit'))
          .fontSize(16)
          .fontColor($r('app.color.telegram_blue'))

        Blank()

        // Segmented control: All / Missed
        Row() {
          Text($r('app.string.calls_all'))
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(!this.showMissedOnly
              ? Color.White
              : $r('app.color.telegram_blue'))
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .backgroundColor(!this.showMissedOnly
              ? $r('app.color.telegram_blue')
              : Color.Transparent)
            .borderRadius(8)
            .onClick(() => {
              this.showMissedOnly = false;
              this.refreshCalls();
            })

          Text($r('app.string.calls_missed'))
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.showMissedOnly
              ? Color.White
              : $r('app.color.telegram_blue'))
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .backgroundColor(this.showMissedOnly
              ? $r('app.color.telegram_blue')
              : Color.Transparent)
            .borderRadius(8)
            .onClick(() => {
              this.showMissedOnly = true;
              this.refreshCalls();
            })
        }
        .backgroundColor($r('app.color.background_secondary'))
        .borderRadius(8)

        Blank()

        // New call button
        Button() {
          Image($r('app.media.ic_phone_call'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.telegram_blue'))
        }
        .backgroundColor(Color.Transparent)
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.glass_nav_bg'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
        colorMode: ThemeColorMode.SYSTEM,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0
      })

      Divider().strokeWidth(0.5).color($r('app.color.separator'))

      // Content
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color($r('app.color.telegram_blue'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.callDataSource.totalCount() === 0) {
        // Empty state
        Column() {
          Image($r('app.media.ic_phone_call'))
            .width(64)
            .height(64)
            .fillColor($r('app.color.text_secondary'))
            .opacity(0.4)
          Text(this.showMissedOnly
            ? $r('app.string.calls_no_missed')
            : $r('app.string.calls_no_recent'))
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          LazyForEach(this.callDataSource, (call: Call) => {
            ListItem() {
              this.callRow(call)
            }
          }, (call: Call) => `${call.id}_${call.date}`)
        }
        .width('100%')
        .layoutWeight(1)
        .cachedCount(5)
        .edgeEffect(EdgeEffect.Spring)
        .divider({
          strokeWidth: 0.5,
          color: $r('app.color.separator'),
          startMargin: 82,
          endMargin: 0
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_primary'))
  }

  @Builder
  callRow(call: Call) {
    Row() {
      // Avatar
      AvatarWithStatus({
        photoUrl: call.userPhotoUrl || '',
        initials: call.userName.length > 0 ? call.userName.charAt(0) : '?',
        avatarColor: this.getAvatarColor(call.userId),
        size: 50,
        isOnline: false,
        showOnlineDot: false
      })
      .margin({ left: 16, right: 12 })

      // Name + call type info
      Column() {
        Text(call.userName.length > 0 ? call.userName : $r('app.string.calls_unknown'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(call.isMissed
            ? $r('app.color.error_red')
            : $r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          // Direction arrow
          Image(call.isOutgoing ? $r('app.media.ic_call_outgoing') : $r('app.media.ic_call_incoming'))
            .width(14)
            .height(14)
            .fillColor(call.isMissed
              ? $r('app.color.error_red')
              : $r('app.color.text_secondary'))
            .margin({ right: 4 })

          // Call type + date
          Text(this.getCallDescription(call))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // Info button (opens call detail)
      Button() {
        Image($r('app.media.ic_info'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.telegram_blue'))
      }
      .backgroundColor(Color.Transparent)
      .margin({ right: 16 })
    }
    .width('100%')
    .height(60)
    .onClick(() => {
      // Start a call to this user
      CallsController.getInstance().startCall(call.userId, call.isVideo);
    })
  }

  private getCallDescription(call: Call): string {
    const dateStr = this.formatCallDate(call.date);
    const typeStr = call.isVideo ? 'Video' : 'Voice';

    if (call.duration > 0) {
      return `${typeStr} (${this.formatDuration(call.duration)}), ${dateStr}`;
    }

    if (call.isMissed) {
      return call.isOutgoing ? `Cancelled, ${dateStr}` : `Missed, ${dateStr}`;
    }

    return `${typeStr}, ${dateStr}`;
  }

  private formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    if (hours > 0) {
      return `${hours}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    if (mins > 0) {
      return `${mins}:${secs.toString().padStart(2, '0')}`;
    }
    return `0:${secs.toString().padStart(2, '0')}`;
  }

  private formatCallDate(timestamp: number): string {
    if (timestamp === 0) return '';
    const date = new Date(timestamp * 1000);
    const now = new Date();

    if (date.toDateString() === now.toDateString()) {
      return date.toLocaleTimeString([], {
        hour: '2-digit',
        minute: '2-digit'
      } as Intl.DateTimeFormatOptions);
    }

    const yesterday = new Date(now.getTime() - 86400000);
    if (date.toDateString() === yesterday.toDateString()) {
      return 'Yesterday';
    }

    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    if (days < 7) {
      const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return weekdays[date.getDay()];
    }

    return `${date.getDate()}.${(date.getMonth() + 1).toString().padStart(2, '0')}`;
  }

  private getAvatarColor(userId: number): string {
    const colors: string[] = [
      '#FF5733', '#E91E63', '#9C27B0', '#673AB7',
      '#3F51B5', '#2196F3', '#00BCD4', '#009688'
    ];
    return colors[Math.abs(userId) % colors.length];
  }

  private refreshCalls(): void {
    const controller = CallsController.getInstance();
    let calls = this.showMissedOnly ? controller.getMissedCalls() : controller.getCalls();

    // Populate user names from ContactsController
    const contactsCtrl = ContactsController.getInstance();
    for (const call of calls) {
      if (call.userName.length === 0 && call.userId > 0) {
        const user = contactsCtrl.getUser(call.userId);
        if (user) {
          call.userName = `${user.firstName} ${user.lastName}`.trim();
          call.userPhotoUrl = user.photoUrl;
        }
      }
    }

    this.callDataSource.setData(calls);
  }
}
