import { CustomEmojiTextEntity } from '../../../core/model/AppCommand';

export class TgCustomEmojiDraftChange {
  text: string = '';
  entities: CustomEmojiTextEntity[] = [];
  caretOffset: number = 0;
}

function cloneEntity(entity: CustomEmojiTextEntity): CustomEmojiTextEntity {
  return new CustomEmojiTextEntity(entity.offset, entity.length, entity.customEmojiId);
}

function isValidEntity(entity: CustomEmojiTextEntity, textLength: number): boolean {
  return entity.offset >= 0 && entity.length > 0 &&
    entity.offset + entity.length <= textLength &&
    entity.customEmojiId.length > 0 && entity.customEmojiId !== '0';
}

function sortedValidEntities(
  entities: CustomEmojiTextEntity[],
  textLength: number
): CustomEmojiTextEntity[] {
  const result: CustomEmojiTextEntity[] = [];
  for (const entity of entities) {
    if (isValidEntity(entity, textLength)) {
      result.push(cloneEntity(entity));
    }
  }
  result.sort((left: CustomEmojiTextEntity, right: CustomEmojiTextEntity): number => {
    if (left.offset !== right.offset) {
      return left.offset - right.offset;
    }
    return left.length - right.length;
  });
  return result;
}

// ArkTS/TDLib string offsets are UTF-16 code-unit offsets. JavaScript string
// length and slice indexes therefore match TDLib's entity coordinate system.
export function reconcileCustomEmojiEntities(
  oldText: string,
  newText: string,
  entities: CustomEmojiTextEntity[]
): CustomEmojiTextEntity[] {
  if (entities.length === 0) {
    return [];
  }
  if (oldText === newText) {
    return sortedValidEntities(entities, newText.length);
  }

  let sharedPrefix = 0;
  const prefixLimit = Math.min(oldText.length, newText.length);
  while (sharedPrefix < prefixLimit && oldText.charCodeAt(sharedPrefix) === newText.charCodeAt(sharedPrefix)) {
    sharedPrefix++;
  }

  let sharedSuffix = 0;
  const oldSuffixLimit = oldText.length - sharedPrefix;
  const newSuffixLimit = newText.length - sharedPrefix;
  const suffixLimit = Math.min(oldSuffixLimit, newSuffixLimit);
  while (sharedSuffix < suffixLimit &&
    oldText.charCodeAt(oldText.length - 1 - sharedSuffix) ===
      newText.charCodeAt(newText.length - 1 - sharedSuffix)) {
    sharedSuffix++;
  }

  const oldChangeStart = sharedPrefix;
  const oldChangeEnd = oldText.length - sharedSuffix;
  const newChangeEnd = newText.length - sharedSuffix;
  const offsetDelta = (newChangeEnd - oldChangeStart) - (oldChangeEnd - oldChangeStart);
  const result: CustomEmojiTextEntity[] = [];

  for (const entity of entities) {
    if (!isValidEntity(entity, oldText.length)) {
      continue;
    }
    const entityEnd = entity.offset + entity.length;
    if (entityEnd <= oldChangeStart) {
      result.push(cloneEntity(entity));
    } else if (entity.offset >= oldChangeEnd) {
      result.push(new CustomEmojiTextEntity(
        entity.offset + offsetDelta,
        entity.length,
        entity.customEmojiId
      ));
    }
    // An edit that intersects a custom-emoji span removes that entity instead
    // of silently attaching its int64 id to different fallback text.
  }

  return sortedValidEntities(result, newText.length);
}

export function replaceDraftSelection(
  text: string,
  selectionStart: number,
  selectionEnd: number,
  replacementText: string,
  entities: CustomEmojiTextEntity[],
  customEmojiId: string = '0'
): TgCustomEmojiDraftChange {
  const firstOffset = Math.max(0, Math.min(text.length, Math.min(selectionStart, selectionEnd)));
  const lastOffset = Math.max(firstOffset, Math.min(text.length, Math.max(selectionStart, selectionEnd)));
  const nextText = text.slice(0, firstOffset) + replacementText + text.slice(lastOffset);
  const nextEntities = reconcileCustomEmojiEntities(text, nextText, entities);

  if (replacementText.length > 0 && customEmojiId.length > 0 && customEmojiId !== '0') {
    nextEntities.push(new CustomEmojiTextEntity(firstOffset, replacementText.length, customEmojiId));
  }

  const result = new TgCustomEmojiDraftChange();
  result.text = nextText;
  result.entities = sortedValidEntities(nextEntities, nextText.length);
  result.caretOffset = firstOffset + replacementText.length;
  return result;
}

export function normalizeCustomEmojiEntitiesForSubstring(
  rawText: string,
  substring: string,
  entities: CustomEmojiTextEntity[]
): CustomEmojiTextEntity[] {
  if (entities.length === 0 || substring.length === 0) {
    return [];
  }
  const leadingOffset = rawText.indexOf(substring);
  if (leadingOffset < 0) {
    return [];
  }
  const substringEnd = leadingOffset + substring.length;
  const result: CustomEmojiTextEntity[] = [];
  for (const entity of entities) {
    const entityEnd = entity.offset + entity.length;
    if (isValidEntity(entity, rawText.length) &&
      entity.offset >= leadingOffset && entityEnd <= substringEnd) {
      result.push(new CustomEmojiTextEntity(
        entity.offset - leadingOffset,
        entity.length,
        entity.customEmojiId
      ));
    }
  }
  return sortedValidEntities(result, substring.length);
}

export function customEmojiEntitiesEqual(
  left: CustomEmojiTextEntity[],
  right: CustomEmojiTextEntity[]
): boolean {
  if (left.length !== right.length) {
    return false;
  }
  for (let index = 0; index < left.length; index++) {
    if (left[index].offset !== right[index].offset ||
      left[index].length !== right[index].length ||
      left[index].customEmojiId !== right[index].customEmojiId) {
      return false;
    }
  }
  return true;
}
