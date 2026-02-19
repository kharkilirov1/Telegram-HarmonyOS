// TDLib object accessors for ArkTS
// ArkTS compliant - no indexed access, no 'in' operator
// Uses TdObject wrapper class from models/td/common

import { TdObject, TdValueType } from '../../models/TdTypes';

// Re-export TdObject as the main type for TDLib data
export { TdObject };

/**
 * Get string property from TdObject.
 * ArkTS compliant - uses TdObject.getString() method.
 */
export function tdGetString(obj: TdObject, propName: string): string {
  return obj.getString(propName);
}

/**
 * Get number property from TdObject.
 */
export function tdGetNumber(obj: TdObject, propName: string): number {
  return obj.getNumber(propName);
}

/**
 * Get boolean property from TdObject.
 */
export function tdGetBoolean(obj: TdObject, propName: string): boolean {
  return obj.getBool(propName);
}

/**
 * Get int64 property as string from TdObject.
 * Int64 values stored as strings to avoid precision loss.
 */
export function tdGetInt64(obj: TdObject, propName: string): string {
  const value = obj.get(propName);
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number') {
    return value.toString();
  }
  return '0';
}

/**
 * Get nested object from TdObject.
 */
export function tdGetObject(obj: TdObject, propName: string): TdObject {
  return obj.getObject(propName);
}

/**
 * Get array property from TdObject.
 * Returns empty array if property is not an array.
 */
export function tdGetArray(obj: TdObject, propName: string): TdObject[] {
  return obj.getArray(propName);
}

/**
 * Get array of strings from TdObject.
 * For arrays of primitives like message_ids.
 */
export function tdGetStringArray(obj: TdObject, propName: string): string[] {
  return obj.getStringArray(propName);
}

/**
 * Get array of numbers from TdObject.
 */
export function tdGetNumberArray(obj: TdObject, propName: string): number[] {
  return obj.getNumberArray(propName);
}

/**
 * Check if TdObject has @type field (is valid TDLib object).
 */
export function tdHasKeys(obj: TdObject): boolean {
  return obj.hasType();
}

/**
 * Get @type from TdObject.
 */
export function tdGetType(obj: TdObject): string {
  return obj.getType();
}

/**
 * Compare two int64 string values numerically.
 * Returns negative if a < b, positive if a > b, 0 if equal.
 */
export function compareInt64(a: string, b: string): number {
  // Remove leading zeros for consistent comparison
  const aClean = a.replace(/^0+/, '') || '0';
  const bClean = b.replace(/^0+/, '') || '0';

  // Different lengths → longer string is larger
  if (aClean.length !== bClean.length) {
    return aClean.length - bClean.length;
  }
  // Same length → lexicographic comparison
  if (aClean < bClean) return -1;
  if (aClean > bClean) return 1;
  return 0;
}

// Explicit getters for common TDLib fields (optimization)
export function tdGetId(obj: TdObject): number {
  return obj.getNumber('id');
}

export function tdGetChatId(obj: TdObject): number {
  return obj.getNumber('chat_id');
}

export function tdGetUserId(obj: TdObject): number {
  return obj.getNumber('user_id');
}

export function tdGetMessageId(obj: TdObject): string {
  return tdGetInt64(obj, 'message_id');
}

export function tdGetDate(obj: TdObject): number {
  return obj.getNumber('date');
}

export function tdGetText(obj: TdObject): string {
  return obj.getString('text');
}

export function tdGetFirstName(obj: TdObject): string {
  return obj.getString('first_name');
}

export function tdGetLastName(obj: TdObject): string {
  return obj.getString('last_name');
}

export function tdGetUsername(obj: TdObject): string {
  return obj.getString('username');
}

export function tdGetPhoneNumber(obj: TdObject): string {
  return obj.getString('phone_number');
}

export function tdGetTitle(obj: TdObject): string {
  return obj.getString('title');
}

export function tdGetUnreadCount(obj: TdObject): number {
  return obj.getNumber('unread_count');
}

export function tdGetIsPinned(obj: TdObject): boolean {
  return obj.getBool('is_pinned');
}

export function tdGetOrder(obj: TdObject): string {
  return obj.getString('order');
}

export function tdGetIsOutgoing(obj: TdObject): boolean {
  return obj.getBool('is_outgoing');
}

export function tdGetIsRead(obj: TdObject): boolean {
  return obj.getBool('is_read');
}

export function tdGetEditDate(obj: TdObject): number {
  return obj.getNumber('edit_date');
}

export function tdGetReplyToMessageId(obj: TdObject): string {
  return tdGetInt64(obj, 'reply_to_message_id');
}
