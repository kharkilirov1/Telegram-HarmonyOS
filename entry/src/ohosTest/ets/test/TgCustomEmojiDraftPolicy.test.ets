import { describe, it, expect } from '@ohos/hypium';
import { CustomEmojiTextEntity } from '../../../main/ets/core/model/AppCommand';
import {
  customEmojiEntitiesEqual,
  normalizeCustomEmojiEntitiesForSubstring,
  reconcileCustomEmojiEntities,
  replaceDraftSelection
} from '../../../main/ets/ui/tg_ui/utils/TgCustomEmojiDraftPolicy';

export default function tgCustomEmojiDraftPolicyTest() {
  describe('TgCustomEmojiDraftPolicy', () => {
    it('shifts an untouched entity after insertion', 0, () => {
      const entities = [new CustomEmojiTextEntity(3, 1, '101')];
      const result = reconcileCustomEmojiEntities('a😀b', 'xa😀b', entities);

      expect(result.length).assertEqual(1);
      expect(result[0].offset).assertEqual(4);
      expect(result[0].customEmojiId).assertEqual('101');
    });

    it('drops an entity intersected by deletion', 0, () => {
      const entities = [new CustomEmojiTextEntity(1, 2, '202')];
      const result = reconcileCustomEmojiEntities('a😀b', 'ab', entities);

      expect(result.length).assertEqual(0);
    });

    it('uses UTF-16 offsets for surrogate pairs', 0, () => {
      const result = replaceDraftSelection('A😀B', 3, 3, 'X',
        [new CustomEmojiTextEntity(1, 2, '303')]);

      expect(result.text).assertEqual('A😀XB');
      expect(result.entities.length).assertEqual(1);
      expect(result.entities[0].offset).assertEqual(1);
      expect(result.entities[0].length).assertEqual(2);
      expect(result.caretOffset).assertEqual(4);
    });

    it('inserts custom emoji at the active selection', 0, () => {
      const result = replaceDraftSelection('hello world', 6, 11, '😀', [], '404');

      expect(result.text).assertEqual('hello 😀');
      expect(result.entities.length).assertEqual(1);
      expect(result.entities[0].offset).assertEqual(6);
      expect(result.entities[0].length).assertEqual(2);
      expect(result.entities[0].customEmojiId).assertEqual('404');
      expect(result.caretOffset).assertEqual(8);
    });

    it('normalizes entities after trimming the draft', 0, () => {
      const normalized = normalizeCustomEmojiEntitiesForSubstring(
        '  😀 ok  ',
        '😀 ok',
        [new CustomEmojiTextEntity(2, 2, '505')]
      );

      expect(normalized.length).assertEqual(1);
      expect(normalized[0].offset).assertEqual(0);
      expect(customEmojiEntitiesEqual(normalized,
        [new CustomEmojiTextEntity(0, 2, '505')])).assertTrue();
    });
  });
}
