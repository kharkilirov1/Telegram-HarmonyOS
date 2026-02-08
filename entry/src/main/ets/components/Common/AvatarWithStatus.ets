@ComponentV2
export struct AvatarWithStatus {
  @Param photoUrl: string = '';
  @Param initials: string = '';
  @Param avatarColor: string = '#2196F3';
  @Param avatarSize: number = 54;
  @Param isOnline: boolean = false;
  @Param showOnlineDot: boolean = true;

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.photoUrl.length > 0) {
        Image(this.photoUrl)
          .alt($r('app.media.app_icon'))
          .autoResize(true)
          .onError(() => {})
          .width(this.avatarSize)
          .height(this.avatarSize)
          .borderRadius(this.avatarSize / 2)
      } else {
        Text(this.initials)
          .fontSize(this.avatarSize * 0.37)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .width(this.avatarSize)
          .height(this.avatarSize)
          .borderRadius(this.avatarSize / 2)
          .backgroundColor(this.avatarColor)
          .textAlign(TextAlign.Center)
      }

      if (this.showOnlineDot && this.isOnline) {
        Circle()
          .width(this.avatarSize * 0.26)
          .height(this.avatarSize * 0.26)
          .fill($r('app.color.online_indicator'))
          .stroke(Color.White)
          .strokeWidth(2)
      }
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
  }
}

export function formatLastSeen(isOnline: boolean, lastSeenDate: number): string {
  if (isOnline) return 'online';
  if (lastSeenDate === 0) return 'last seen a long time ago';

  const now = Math.floor(Date.now() / 1000);
  const diff = now - lastSeenDate;
  const date = new Date(lastSeenDate * 1000);
  const today = new Date();
  const timeStr = date.toLocaleTimeString([], {
    hour: '2-digit', minute: '2-digit'
  } as Intl.DateTimeFormatOptions);

  if (diff < 60) return 'last seen just now';
  if (diff < 3600) return `last seen ${Math.floor(diff / 60)} min ago`;

  if (date.toDateString() === today.toDateString()) {
    return `last seen today at ${timeStr}`;
  }

  const yesterday = new Date(today.getTime() - 86400000);
  if (date.toDateString() === yesterday.toDateString()) {
    return `last seen yesterday at ${timeStr}`;
  }

  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `last seen ${months[date.getMonth()]} ${date.getDate()} at ${timeStr}`;
}
