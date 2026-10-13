import { EditMessageEntity, EditMessageLinkPreviewOptions } from '../../core/model/AppCommand';
import { TdObject } from '../../core/utils/tdAccessors';

function isInsideSurrogate(text: string, offset: number): boolean {
  if (offset <= 0 || offset >= text.length) return false;
  const before = text.charCodeAt(offset - 1);
  const after = text.charCodeAt(offset);
  return before >= 0xD800 && before <= 0xDBFF && after >= 0xDC00 && after <= 0xDFFF;
}

function copyEntity(entity: EditMessageEntity, offset: number, length: number): EditMessageEntity {
  const result = new EditMessageEntity();
  result.offset = offset;
  result.length = length;
  result.typeJson = entity.typeJson;
  return result;
}

function entityType(entity: EditMessageEntity): string {
  return TdObject.fromJSON(entity.typeJson).getTopLevelStringStrict('@type') ?? '';
}

const EDIT_FORMATTING_TYPES: string[] = ['textEntityTypeBold', 'textEntityTypeItalic', 'textEntityTypeUnderline',
  'textEntityTypeStrikethrough', 'textEntityTypeSpoiler'];
const EDIT_ISOLATED_TYPES: string[] = ['textEntityTypeCode', 'textEntityTypePre', 'textEntityTypePreCode'];
const EDIT_QUOTE_TYPES: string[] = ['textEntityTypeBlockQuote', 'textEntityTypeExpandableBlockQuote'];

function validEntityType(type: TdObject, name: string): boolean {
  const simple = ['textEntityTypeMention', 'textEntityTypeHashtag', 'textEntityTypeCashtag', 'textEntityTypeBotCommand',
    'textEntityTypeUrl', 'textEntityTypeEmailAddress', 'textEntityTypePhoneNumber', 'textEntityTypeBankCardNumber'];
  if (simple.includes(name) || EDIT_FORMATTING_TYPES.includes(name) || EDIT_QUOTE_TYPES.includes(name) ||
    name === 'textEntityTypeCode' || name === 'textEntityTypePre') return true;
  if (name === 'textEntityTypePreCode') return type.getTopLevelStringStrict('language') !== undefined;
  if (name === 'textEntityTypeTextUrl') return (type.getTopLevelStringStrict('url') ?? '').length > 0;
  if (name === 'textEntityTypeMentionName') {
    const id = type.getTopLevelNumberStrict('user_id');
    return id !== undefined && Number.isSafeInteger(id) && id > 0;
  }
  if (name === 'textEntityTypeMediaTimestamp') {
    const timestamp = type.getTopLevelNumberStrict('media_timestamp');
    return timestamp !== undefined && Number.isInteger(timestamp) && timestamp >= 0 && timestamp <= 2147483647;
  }
  if (name === 'textEntityTypeCustomEmoji') {
    const id = type.getTopLevelStringStrict('custom_emoji_id') ?? '';
    if (!/^-?[1-9][0-9]*$/.test(id)) return false;
    const digits = id.startsWith('-') ? id.slice(1) : id;
    const bound = id.startsWith('-') ? '9223372036854775808' : '9223372036854775807';
    return digits.length < bound.length || (digits.length === bound.length && digits <= bound);
  }
  return false;
}

export function readEditEntities(formatted: TdObject, text: string): EditMessageEntity[] {
  const rows = formatted.getTopLevelObjectArrayStrict('entities');
  if (rows === undefined) throw new Error('Missing edit entities');
  const entities: EditMessageEntity[] = [];
  for (const row of rows) {
    if (row === null || row.getTopLevelStringStrict('@type') !== 'textEntity') throw new Error('Invalid text entity');
    const offset = row.getTopLevelNumberStrict('offset');
    const length = row.getTopLevelNumberStrict('length');
    const type = row.getTopLevelObjectStrict('type');
    const name = type?.getTopLevelStringStrict('@type');
    if (offset === undefined || length === undefined || !Number.isSafeInteger(offset) || !Number.isSafeInteger(length) ||
      offset < 0 || length <= 0 || offset + length > text.length || isInsideSurrogate(text, offset) ||
      isInsideSurrogate(text, offset + length) || type === undefined || name === undefined || !validEntityType(type, name)) {
      throw new Error('Invalid entity range or type');
    }
    const entity = new EditMessageEntity();
    entity.offset = offset;
    entity.length = length;
    entity.typeJson = type.getReceivedJSON() ?? '';
    entities.push(entity);
  }
  validateNesting(entities);
  return entities;
}

function incompatibleEntities(a: EditMessageEntity, b: EditMessageEntity): boolean {
  if (a.offset + a.length <= b.offset || b.offset + b.length <= a.offset) return false;
  const contains = (a.offset <= b.offset && a.offset + a.length >= b.offset + b.length) ||
    (b.offset <= a.offset && b.offset + b.length >= a.offset + a.length);
  const at = entityType(a);
  const bt = entityType(b);
  if (!contains || at === bt) return true;
  // Native get_type_priority puts blockquotes before code and continuous
  // entities for equal ranges. Direction matters: quote may contain code,
  // but code cannot contain anything and a link cannot contain a quote.
  const aPriority = EDIT_QUOTE_TYPES.includes(at) ? 0 : EDIT_ISOLATED_TYPES.includes(at) ? 1 :
    EDIT_FORMATTING_TYPES.includes(at) ? 3 : 2;
  const bPriority = EDIT_QUOTE_TYPES.includes(bt) ? 0 : EDIT_ISOLATED_TYPES.includes(bt) ? 1 :
    EDIT_FORMATTING_TYPES.includes(bt) ? 3 : 2;
  const bOuter = b.offset < a.offset || (b.offset === a.offset &&
    (b.length > a.length || (b.length === a.length && bPriority < aPriority)));
  const outer = bOuter ? bt : at;
  const inner = bOuter ? at : bt;
  if (EDIT_ISOLATED_TYPES.includes(outer)) return true;
  if (EDIT_ISOLATED_TYPES.includes(inner)) return !EDIT_QUOTE_TYPES.includes(outer);
  if (EDIT_QUOTE_TYPES.includes(inner)) return !EDIT_FORMATTING_TYPES.includes(outer);
  const outerSemantic = !EDIT_FORMATTING_TYPES.includes(outer) && !EDIT_QUOTE_TYPES.includes(outer);
  const innerSemantic = !EDIT_FORMATTING_TYPES.includes(inner) && !EDIT_QUOTE_TYPES.includes(inner);
  return outerSemantic && innerSemantic;
}

function validateNesting(entities: EditMessageEntity[]): void {
  for (let i = 0; i < entities.length; i++) {
    for (let j = i + 1; j < entities.length; j++) {
      if (incompatibleEntities(entities[i], entities[j])) {
        throw new Error('Edit would create incompatible entity ranges');
      }
    }
  }
}

// Plain composer fallback: one UTF-16 splice, consistent boundary affinity.
// Stable entities survive; touched identity-bearing entities are not attached
// to new text. Multiple disjoint edits remain a rich-editor/history parity gate.
export function reconcileEditEntities(oldText: string, newText: string, entities: EditMessageEntity[]): EditMessageEntity[] {
  validateNesting(entities);
  if (oldText === newText) return entities.map((entity: EditMessageEntity): EditMessageEntity =>
    copyEntity(entity, entity.offset, entity.length));
  let prefix = 0;
  while (prefix < Math.min(oldText.length, newText.length) && oldText.charCodeAt(prefix) === newText.charCodeAt(prefix)) prefix++;
  if (isInsideSurrogate(oldText, prefix) || isInsideSurrogate(newText, prefix)) prefix--;
  let suffix = 0;
  while (suffix < Math.min(oldText.length - prefix, newText.length - prefix) &&
    oldText.charCodeAt(oldText.length - suffix - 1) === newText.charCodeAt(newText.length - suffix - 1)) suffix++;
  if (isInsideSurrogate(oldText, oldText.length - suffix) || isInsideSurrogate(newText, newText.length - suffix)) suffix--;
  const oldEnd = oldText.length - suffix;
  const newEnd = newText.length - suffix;
  const delta = newText.length - oldText.length;
  const formatting = EDIT_FORMATTING_TYPES.concat(EDIT_ISOLATED_TYPES).concat(EDIT_QUOTE_TYPES);
  const result: EditMessageEntity[] = [];
  const changed: boolean[] = [];
  for (const entity of entities) {
    const end = entity.offset + entity.length;
    if (end <= prefix) { result.push(copyEntity(entity, entity.offset, entity.length)); changed.push(false); }
    else if (entity.offset >= oldEnd) { result.push(copyEntity(entity, entity.offset + delta, entity.length)); changed.push(false); }
    else if (formatting.includes(entityType(entity))) {
      const start = entity.offset < prefix ? entity.offset : prefix;
      const finish = end > oldEnd ? end + delta : newEnd;
      if (finish > start) { result.push(copyEntity(entity, start, finish - start)); changed.push(true); }
    }
  }
  for (const entity of result) {
    if (entity.offset < 0 || entity.length <= 0 || entity.offset + entity.length > newText.length ||
      isInsideSurrogate(newText, entity.offset) || isInsideSurrogate(newText, entity.offset + entity.length)) {
      throw new Error('Invalid remapped entity');
    }
  }
  // A replacement spanning separate styles can make them conflict. Preserve
  // untouched entities and drop only ambiguous remapped styles, not the text.
  const discarded = new Set<number>();
  for (let i = 0; i < result.length; i++) {
    for (let j = i + 1; j < result.length; j++) {
      if (!incompatibleEntities(result[i], result[j])) continue;
      if (changed[i]) discarded.add(i);
      if (changed[j]) discarded.add(j);
    }
  }
  const compatible = result.filter((_entity: EditMessageEntity, index: number): boolean => !discarded.has(index));
  validateNesting(compatible);
  return compatible;
}

export function readEditPreviewOptions(content: TdObject): EditMessageLinkPreviewOptions | undefined {
  if (content.isTopLevelNullOrMissing('link_preview_options')) return undefined;
  const source = content.getTopLevelObjectStrict('link_preview_options');
  if (source === undefined || source.getTopLevelStringStrict('@type') !== 'linkPreviewOptions') throw new Error('Invalid preview options');
  const disabled = source.getTopLevelBooleanStrict('is_disabled');
  const url = source.getTopLevelStringStrict('url');
  const small = source.getTopLevelBooleanStrict('force_small_media');
  const large = source.getTopLevelBooleanStrict('force_large_media');
  const above = source.getTopLevelBooleanStrict('show_above_text');
  if (disabled === undefined || url === undefined || small === undefined || large === undefined || above === undefined) {
    throw new Error('Incomplete preview options');
  }
  const result = new EditMessageLinkPreviewOptions();
  result.isDisabled = disabled;
  result.url = url;
  result.forceSmallMedia = small;
  result.forceLargeMedia = large;
  result.showAboveText = above;
  return result;
}
