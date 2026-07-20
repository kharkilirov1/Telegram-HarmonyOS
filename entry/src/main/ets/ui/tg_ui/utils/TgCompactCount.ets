import { TgUiTokens } from '../tokens/TgUiTokens';

function compactCountForUnit(count: number, unit: number, suffix: string, decimalSeparator: string): string {
  const whole = Math.floor(count / unit);
  const decimal = Math.floor((count % unit) /
    (unit / TgUiTokens.UNREAD_BADGE_COMPACT_DECIMAL_DIVISOR));
  return decimal > 0 ? `${whole}${decimalSeparator}${decimal}${suffix}` : `${whole}${suffix}`;
}

// Clean-room port of Telegram iOS NumericFormat.compactNumericCountString.
export function formatTelegramCompactCount(count: number, decimalSeparator: string = '.'): string {
  const safeCount = Math.max(0, Math.floor(count));
  if (safeCount >= TgUiTokens.UNREAD_BADGE_COMPACT_MILLION) {
    return compactCountForUnit(
      safeCount,
      TgUiTokens.UNREAD_BADGE_COMPACT_MILLION,
      TgUiTokens.UNREAD_BADGE_COMPACT_MILLION_SUFFIX,
      decimalSeparator
    );
  }
  if (safeCount >= TgUiTokens.UNREAD_BADGE_COMPACT_THOUSAND) {
    return compactCountForUnit(
      safeCount,
      TgUiTokens.UNREAD_BADGE_COMPACT_THOUSAND,
      TgUiTokens.UNREAD_BADGE_COMPACT_THOUSAND_SUFFIX,
      decimalSeparator
    );
  }
  return safeCount.toString();
}
