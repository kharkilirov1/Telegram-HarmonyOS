// D26: the system contact picker. HarmonyOS shows its own UI, so no contact permission is requested and the
// app only receives the entries the user picked.

import { contact } from '@kit.ContactsKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x00D26;
const TAG = 'DeviceContacts';

export class PickedContact {
  phoneNumber: string = '';
  firstName: string = '';
  lastName: string = '';
}

// Splits a single full name the way TDLib expects it: the first token is the name, the rest the surname.
export function splitContactName(fullName: string): string[] {
  const parts = fullName.trim().split(/\s+/).filter((part: string): boolean => part.length > 0);
  if (parts.length === 0) {
    return ['', ''];
  }
  return [parts[0], parts.slice(1).join(' ')];
}

// Normalises a picked entry: one phone number, a name split into first/last, empty fields allowed.
export function toPickedContact(name: string, givenName: string, familyName: string,
  phoneNumber: string): PickedContact | undefined {
  const phone = phoneNumber.trim();
  if (phone.length === 0) {
    return undefined;
  }
  const picked = new PickedContact();
  picked.phoneNumber = phone;
  const split = splitContactName(name);
  picked.firstName = givenName.trim().length > 0 ? givenName.trim() : split[0];
  picked.lastName = familyName.trim().length > 0 ? familyName.trim() : split[1];
  return picked;
}

// Resolves undefined when the user cancels the picker or the entry has no phone number.
export async function pickContactOnce(): Promise<PickedContact | undefined> {
  try {
    const selection = await contact.selectContacts();
    if (selection.length === 0) {
      return undefined;
    }
    const entry = selection[0];
    const numbers = entry.phoneNumbers;
    if (numbers === undefined || numbers.length === 0) {
      return undefined;
    }
    const names = entry.name;
    return toPickedContact(names !== undefined && names.fullName.length > 0 ? names.fullName : '',
      names !== undefined && names.givenName !== undefined ? names.givenName : '',
      names !== undefined && names.familyName !== undefined ? names.familyName : '',
      numbers[0].phoneNumber);
  } catch (error) {
    hilog.info(DOMAIN, TAG, 'Contact picker failed: %{public}s', String(error));
    return undefined;
  }
}
