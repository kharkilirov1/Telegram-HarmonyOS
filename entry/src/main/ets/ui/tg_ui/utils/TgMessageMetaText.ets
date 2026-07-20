export function composeMessageMetaText(editedText: string, timeText: string): string {
  const edited = editedText.trim();
  const time = timeText.trim();
  if (edited.length === 0) {
    return time;
  }
  if (time.length === 0) {
    return edited;
  }
  return edited + ' ' + time;
}
