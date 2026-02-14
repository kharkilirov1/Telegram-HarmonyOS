@ComponentV2
export struct DateSeparator {
  @Param dateText: string = '';

  build() {
    Row() {
      Blank().layoutWeight(1)

      Text(this.dateText)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        .borderRadius(12)
        .backgroundColor($r('app.color.date_separator_bg'))

      Blank().layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }
}

export function formatDateSeparator(timestamp: number): string {
  const date = new Date(timestamp * 1000);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const yesterday = new Date(today.getTime() - 86400000);
  const msgDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());

  if (msgDate.getTime() === today.getTime()) return 'Today';
  if (msgDate.getTime() === yesterday.getTime()) return 'Yesterday';

  const months = ['January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];

  if (date.getFullYear() === now.getFullYear()) {
    return `${months[date.getMonth()]} ${date.getDate()}`;
  }
  return `${months[date.getMonth()]} ${date.getDate()}, ${date.getFullYear()}`;
}
