const CONTACT_NAME_MAX_LENGTH = 64;
const CHAT_TITLE_MAX_LENGTH = 128;
const CHANNEL_DESCRIPTION_MAX_LENGTH = 255;
const PHONE_MIN_DIGITS = 5;
const PHONE_MAX_DIGITS = 20;

export function normalizeComposePhoneNumber(rawValue: string): string {
  const digits: string = rawValue.replace(/[^0-9]/g, '');
  return digits.length > 0 ? '+' + digits : '';
}

export function isValidComposeContact(
  firstName: string,
  lastName: string,
  phoneNumber: string
): boolean {
  const normalizedFirstName: string = firstName.trim();
  const normalizedLastName: string = lastName.trim();
  const phoneDigits: string = phoneNumber.replace(/[^0-9]/g, '');
  return normalizedFirstName.length > 0 && normalizedFirstName.length <= CONTACT_NAME_MAX_LENGTH &&
    normalizedLastName.length <= CONTACT_NAME_MAX_LENGTH &&
    phoneDigits.length >= PHONE_MIN_DIGITS && phoneDigits.length <= PHONE_MAX_DIGITS;
}

export function isValidComposeChatTitle(title: string): boolean {
  const normalizedTitle: string = title.trim();
  return normalizedTitle.length > 0 && normalizedTitle.length <= CHAT_TITLE_MAX_LENGTH;
}

export function isValidComposeChannelDescription(description: string): boolean {
  return description.trim().length <= CHANNEL_DESCRIPTION_MAX_LENGTH;
}

export function uniqueComposeUserIds(userIds: number[]): number[] {
  const result: number[] = [];
  const seen: Set<number> = new Set<number>();
  for (const rawId of userIds) {
    const userId: number = Math.trunc(rawId);
    if (userId <= 0 || seen.has(userId)) {
      continue;
    }
    seen.add(userId);
    result.push(userId);
  }
  return result;
}

export function toggleComposeUserSelection(userIds: number[], userId: number): number[] {
  const normalizedIds: number[] = uniqueComposeUserIds(userIds);
  const index: number = normalizedIds.indexOf(Math.trunc(userId));
  if (index >= 0) {
    normalizedIds.splice(index, 1);
  } else if (userId > 0) {
    normalizedIds.push(Math.trunc(userId));
  }
  return normalizedIds;
}
