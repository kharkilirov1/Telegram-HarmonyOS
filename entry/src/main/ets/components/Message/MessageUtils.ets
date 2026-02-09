// MessageUtils — pure utility functions extracted from MessageBubble
// URL detection, text formatting, time formatting

const URL_REGEX = /https?:\/\/[^\s<>"{}|\\^`\[\]]+/gi;

export interface TextPart {
  text: string;
  isUrl: boolean;
}

export function containsUrl(text: string): boolean {
  URL_REGEX.lastIndex = 0;
  return URL_REGEX.test(text);
}

export function extractDomain(text: string): string {
  URL_REGEX.lastIndex = 0;
  const match = text.match(URL_REGEX);
  if (match && match.length > 0) {
    try {
      const url = match[0];
      const domainMatch = url.match(/https?:\/\/([^/]+)/);
      return domainMatch ? domainMatch[1] : url;
    } catch (_e) {
      return '';
    }
  }
  return '';
}

export function splitByUrls(text: string): TextPart[] {
  const parts: TextPart[] = [];
  let lastIndex = 0;
  const regex = /https?:\/\/[^\s<>"{}|\\^`\[\]]+/gi;
  let match: RegExpExecArray | null;

  while ((match = regex.exec(text)) !== null) {
    if (match.index > lastIndex) {
      parts.push({ text: text.substring(lastIndex, match.index), isUrl: false });
    }
    parts.push({ text: match[0], isUrl: true });
    lastIndex = match.index + match[0].length;
  }

  if (lastIndex < text.length) {
    parts.push({ text: text.substring(lastIndex), isUrl: false });
  }

  return parts.length > 0 ? parts : [{ text: text, isUrl: false }];
}

export function formatMessageTime(timestamp: number): string {
  if (timestamp === 0) return '';
  const date = new Date(timestamp * 1000);
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' } as Intl.DateTimeFormatOptions);
}

export function formatMediaDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (hours > 0) {
    return `${hours}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export function getSenderColor(senderId: number): ResourceColor {
  const colors: Resource[] = [
    $r('app.color.sender_color_1'), $r('app.color.sender_color_2'),
    $r('app.color.sender_color_3'), $r('app.color.sender_color_4'),
    $r('app.color.sender_color_5'), $r('app.color.sender_color_6'),
    $r('app.color.sender_color_7')
  ];
  return colors[Math.abs(senderId) % colors.length];
}
