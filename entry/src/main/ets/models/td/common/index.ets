// TDLib common types and utilities
// ArkTS compliant - no indexed access, uses regex-based JSON parsing
// Reason: ArkTS forbids obj[key] syntax, so we parse JSON values via regex

/**
 * Union type for TDLib JSON values
 */
export type TdValueType = string | number | boolean | TdObject[];

/**
 * Container for TDLib values - wraps Map to avoid indexed access
 */
export class TdValueContainer {
  private items: Map<string, TdValueType> = new Map<string, TdValueType>();

  get(key: string): TdValueType {
    if (this.items.has(key)) {
      const value = this.items.get(key);
      return value !== undefined ? value : '';
    }
    return '';
  }

  set(key: string, value: TdValueType): void {
    this.items.set(key, value);
  }

  has(key: string): boolean {
    return this.items.has(key);
  }

  keys(): string[] {
    return Array.from(this.items.keys());
  }

  clear(): void {
    this.items.clear();
  }
}

/**
 * TdObject - ArkTS-compliant wrapper for TDLib JSON data.
 * Parses JSON without indexed access using regex extraction.
 *
 * Design: stores raw JSON string and extracts values on demand.
 * Nested objects are parsed recursively when accessed.
 */
export class TdObject {
  private rawJson: string = '';
  private cache: TdValueContainer = new TdValueContainer();

  constructor() {}

  /**
   * Create TdObject from JSON string.
   * Full parsing happens lazily on first access.
   */
  static fromJSON(json: string): TdObject {
    const obj = new TdObject();
    obj.rawJson = json.trim();
    // Pre-cache @type for fast type checking
    const typeValue = extractStringValue(json, '@type');
    if (typeValue) {
      obj.cache.set('@type', typeValue);
    }
    return obj;
  }

  /**
   * Create empty TdObject (for use as default/fallback)
   */
  static empty(): TdObject {
    return new TdObject();
  }

  // ========== Getters ==========

  get(prop: string): TdValueType {
    // Check cache first
    if (this.cache.has(prop)) {
      return this.cache.get(prop);
    }
    // Parse from raw JSON
    const value = this.extractValue(prop);
    if (value !== undefined) {
      this.cache.set(prop, value);
    }
    return value;
  }

  getString(prop: string): string {
    const val = this.get(prop);
    return typeof val === 'string' ? val : '';
  }

  getNumber(prop: string): number {
    const val = this.get(prop);
    if (typeof val === 'number') return val;
    if (typeof val === 'string') {
      const parsed = parseFloat(val);
      return isNaN(parsed) ? 0 : parsed;
    }
    return 0;
  }

  getBool(prop: string): boolean {
    const val = this.get(prop);
    if (typeof val === 'boolean') return val;
    if (typeof val === 'string') {
      return val === 'true';
    }
    return false;
  }

  /**
   * Get nested object by property name.
   * Extracts JSON substring and creates new TdObject.
   */
  getObject(prop: string): TdObject {
    const jsonSubstring = extractObjectJson(this.rawJson, prop);
    if (jsonSubstring) {
      return TdObject.fromJSON(jsonSubstring);
    }
    return TdObject.empty();
  }

  /**
   * Get array of TdObjects by property name.
   * Parses JSON array and creates TdObject for each element.
   */
  getArray(prop: string): TdObject[] {
    const arrayJson = extractArrayJson(this.rawJson, prop);
    if (!arrayJson) {
      return [];
    }
    return parseJsonArray(arrayJson);
  }

  /**
   * Get array of strings/numbers by property name.
   * For arrays of primitives like message_ids: [123, 456, ...]
   */
  getStringArray(prop: string): string[] {
    const arrayJson = extractArrayJson(this.rawJson, prop);
    if (!arrayJson) {
      return [];
    }
    return parseStringArray(arrayJson);
  }

  /**
   * Get array of numbers by property name.
   */
  getNumberArray(prop: string): number[] {
    const arrayJson = extractArrayJson(this.rawJson, prop);
    if (!arrayJson) {
      return [];
    }
    return parseNumberArray(arrayJson);
  }

  getType(): string {
    return this.getString('@type');
  }

  hasType(): boolean {
    const type = this.getType();
    return type.length > 0;
  }

  // ========== Setters (for building requests) ==========

  setString(prop: string, value: string): void {
    this.cache.set(prop, value);
  }

  setNumber(prop: string, value: number): void {
    this.cache.set(prop, value);
  }

  setBool(prop: string, value: boolean): void {
    this.cache.set(prop, value);
  }

  /**
   * Copy all cached values from another TdObject.
   * Used for building requests with params.
   */
  copyFrom(other: TdObject): void {
    const keys = other.cache.keys();
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const val = other.cache.get(key);
      this.cache.set(key, val);
    }
    // Also copy raw JSON if this object is empty
    if (!this.rawJson && other.rawJson) {
      this.rawJson = other.rawJson;
    }
  }

  /**
   * Check if this TdObject has any data.
   */
  isEmpty(): boolean {
    return !this.rawJson && this.cache.keys().length === 0;
  }

  /**
   * Convert TdObject to JSON string for sending to TDLib.
   * Serializes all cached values into JSON format.
   */
  toJSON(): string {
    const keys = this.cache.keys();
    if (keys.length === 0) {
      return '{}';
    }

    const parts: string[] = [];
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = this.cache.get(key);
      const jsonValue = this.valueToJsonString(value);
      parts.push(`"${key}":${jsonValue}`);
    }

    return `{${parts.join(',')}}`;
  }

  /**
   * Convert a value to JSON string representation.
   */
  private valueToJsonString(value: TdValueType): string {
    if (typeof value === 'string') {
      return `"${escapeJsonString(value)}"`;
    }
    if (typeof value === 'number') {
      return value.toString();
    }
    if (typeof value === 'boolean') {
      return value ? 'true' : 'false';
    }
    if (Array.isArray(value)) {
      const items: string[] = [];
      for (let i = 0; i < value.length; i++) {
        const item = value[i];
        if (item instanceof TdObject) {
          items.push(item.toJSON());
        }
      }
      return `[${items.join(',')}]`;
    }
    return '""';
  }

  // ========== Private helpers ==========

  private extractValue(prop: string): TdValueType {
    if (!this.rawJson) {
      return '';
    }

    // Try string value first
    const strVal = extractStringValue(this.rawJson, prop);
    if (strVal !== null) {
      return strVal;
    }

    // Try number value
    const numVal = extractNumberValue(this.rawJson, prop);
    if (numVal !== null) {
      return numVal;
    }

    // Try boolean value
    const boolVal = extractBoolValue(this.rawJson, prop);
    if (boolVal !== null) {
      return boolVal;
    }

    return '';
  }
}

// =====================================================
// JSON Extraction Helpers (regex-based, no indexed access)
// =====================================================

/**
 * Extract string value from JSON by property name.
 * Pattern: "propName": "value"
 */
function extractStringValue(json: string, prop: string): string | null {
  // Escape special regex chars in property name
  const escapedProp = prop.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = new RegExp(`"${escapedProp}"\\s*:\\s*"([^"\\\\]*(?:\\\\.[^"\\\\]*)*)"`);
  const match = json.match(pattern);
  if (match && match[1] !== undefined) {
    // Unescape JSON string escapes
    return unescapeJsonString(match[1]);
  }
  return null;
}

/**
 * Extract number value from JSON by property name.
 * Pattern: "propName": 123 or "propName": -123.45
 */
function extractNumberValue(json: string, prop: string): number | null {
  const escapedProp = prop.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = new RegExp(`"${escapedProp}"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)`);
  const match = json.match(pattern);
  if (match && match[1] !== undefined) {
    const num = parseFloat(match[1]);
    return isNaN(num) ? null : num;
  }
  return null;
}

/**
 * Extract boolean value from JSON by property name.
 * Pattern: "propName": true or "propName": false
 */
function extractBoolValue(json: string, prop: string): boolean | null {
  const escapedProp = prop.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = new RegExp(`"${escapedProp}"\\s*:\\s*(true|false)`);
  const match = json.match(pattern);
  if (match && match[1] !== undefined) {
    return match[1] === 'true';
  }
  return null;
}

/**
 * Extract nested object JSON by property name.
 * Uses bracket matching to find complete object.
 * Pattern: "propName": { ... }
 */
function extractObjectJson(json: string, prop: string): string | null {
  const escapedProp = prop.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const startPattern = new RegExp(`"${escapedProp}"\\s*:\\s*\\{`);
  const match = json.match(startPattern);
  if (!match || match.index === undefined) {
    return null;
  }

  // Find the opening brace position
  const objStart = json.indexOf('{', match.index);
  if (objStart === -1) return null;

  // Match braces to find end of object
  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let i = objStart; i < json.length; i++) {
    const char = json.charAt(i);

    if (escaped) {
      escaped = false;
      continue;
    }

    if (char === '\\') {
      escaped = true;
      continue;
    }

    if (char === '"' && !escaped) {
      inString = !inString;
      continue;
    }

    if (!inString) {
      if (char === '{') {
        depth++;
      } else if (char === '}') {
        depth--;
        if (depth === 0) {
          return json.substring(objStart, i + 1);
        }
      }
    }
  }

  return null;
}

/**
 * Extract array JSON by property name.
 * Uses bracket matching to find complete array.
 * Pattern: "propName": [ ... ]
 */
function extractArrayJson(json: string, prop: string): string | null {
  const escapedProp = prop.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const startPattern = new RegExp(`"${escapedProp}"\\s*:\\s*\\[`);
  const match = json.match(startPattern);
  if (!match || match.index === undefined) {
    return null;
  }

  // Find the opening bracket position
  const arrStart = json.indexOf('[', match.index);
  if (arrStart === -1) return null;

  // Match brackets to find end of array
  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let i = arrStart; i < json.length; i++) {
    const char = json.charAt(i);

    if (escaped) {
      escaped = false;
      continue;
    }

    if (char === '\\') {
      escaped = true;
      continue;
    }

    if (char === '"' && !escaped) {
      inString = !inString;
      continue;
    }

    if (!inString) {
      if (char === '[') {
        depth++;
      } else if (char === ']') {
        depth--;
        if (depth === 0) {
          return json.substring(arrStart, i + 1);
        }
      }
    }
  }

  return null;
}

/**
 * Parse JSON array of strings/numbers into string array.
 * Handles: [123, 456] or ["a", "b"] or [123456789012345, ...]
 */
function parseStringArray(arrayJson: string): string[] {
  const result: string[] = [];
  if (!arrayJson || arrayJson.length < 2) {
    return result;
  }

  // Remove outer brackets
  const inner = arrayJson.substring(1, arrayJson.length - 1).trim();
  if (!inner) {
    return result;
  }

  // Match numbers and strings
  const numberPattern = /-?\d+(?:\.\d+)?/g;
  const stringPattern = /"([^"\\]*(?:\\.[^"\\]*)*)"/g;

  // First try to find numbers
  let match = numberPattern.exec(inner);
  while (match !== null) {
    result.push(match[0]);
    match = numberPattern.exec(inner);
  }

  // If no numbers found, try strings
  if (result.length === 0) {
    let strMatch = stringPattern.exec(inner);
    while (strMatch !== null) {
      if (strMatch[1] !== undefined) {
        result.push(unescapeJsonString(strMatch[1]));
      }
      strMatch = stringPattern.exec(inner);
    }
  }

  return result;
}

/**
 * Parse JSON array of numbers into number array.
 */
function parseNumberArray(arrayJson: string): number[] {
  const strings = parseStringArray(arrayJson);
  const result: number[] = [];
  for (const s of strings) {
    const num = parseFloat(s);
    if (!isNaN(num)) {
      result.push(num);
    }
  }
  return result;
}

/**
 * Parse JSON array string into array of TdObjects.
 * Handles arrays of objects: [ {...}, {...}, ... ]
 */
function parseJsonArray(arrayJson: string): TdObject[] {
  const result: TdObject[] = [];
  if (!arrayJson || arrayJson.length < 2) {
    return result;
  }

  // Remove outer brackets
  const inner = arrayJson.substring(1, arrayJson.length - 1).trim();
  if (!inner) {
    return result;
  }

  // Split by objects (find each {...})
  let depth = 0;
  let inString = false;
  let escaped = false;
  let objStart = -1;

  for (let i = 0; i < inner.length; i++) {
    const char = inner.charAt(i);

    if (escaped) {
      escaped = false;
      continue;
    }

    if (char === '\\') {
      escaped = true;
      continue;
    }

    if (char === '"' && !escaped) {
      inString = !inString;
      continue;
    }

    if (!inString) {
      if (char === '{') {
        if (depth === 0) {
          objStart = i;
        }
        depth++;
      } else if (char === '}') {
        depth--;
        if (depth === 0 && objStart !== -1) {
          const objJson = inner.substring(objStart, i + 1);
          result.push(TdObject.fromJSON(objJson));
          objStart = -1;
        }
      }
    }
  }

  return result;
}

/**
 * Unescape JSON string escape sequences.
 */
function unescapeJsonString(str: string): string {
  return str
    .replace(/\\n/g, '\n')
    .replace(/\\r/g, '\r')
    .replace(/\\t/g, '\t')
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, '\\');
}

/**
 * Escape string for JSON serialization.
 */
function escapeJsonString(str: string): string {
  return str
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\r')
    .replace(/\t/g, '\\t');
}

// =====================================================
// TDLib formatted text
// =====================================================

/**
 * TDLib formatted text with entities
 */
export interface TdFormattedText {
  '@type': 'formattedText';
  text: string;
  entities?: TdTextEntity[];
}

export interface TdTextEntity {
  '@type': string;
  offset: number;
  length: number;
  type?: TdTextEntityType;
}

export interface TdTextEntityType {
  '@type': string;
}

// =====================================================
// Utility functions
// =====================================================

/**
 * Get @type from TDLib object
 */
export function tdType(obj: TdObject | null): string {
  if (!obj) return '';
  return obj.getType();
}

/**
 * Check if object is TDLib error
 */
export function isTdError(obj: TdObject | null): boolean {
  return obj !== null && tdType(obj) === 'error';
}

/**
 * Get error code from TDLib error object
 */
export function getTdErrorCode(obj: TdObject | null): number {
  if (!obj) return 0;
  return obj.getNumber('code');
}

/**
 * Get error message from TDLib error object
 */
export function getTdErrorMessage(obj: TdObject | null): string {
  if (!obj) return '';
  return obj.getString('message');
}

/**
 * Safely get number from value
 */
export function safeNumber(value: TdValueType): number {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const parsed = parseFloat(value);
    return isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}

/**
 * Safely get string from value
 */
export function safeString(value: TdValueType): string {
  if (typeof value === 'string') return value;
  return '';
}

/**
 * Safely get boolean from value
 */
export function safeBool(value: TdValueType): boolean {
  if (typeof value === 'boolean') return value;
  return false;
}

/**
 * Cast value to TdObject (returns empty TdObject if not valid)
 */
export function asRecord(value: TdValueType): TdObject {
  if (value instanceof TdObject) return value;
  return TdObject.empty();
}

/**
 * Get property from TDLib object safely
 */
export function tdGetProperty(obj: TdObject | null, prop: string): TdValueType {
  if (!obj) return '';
  return obj.get(prop);
}
