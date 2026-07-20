import { describe, expect, it } from '@ohos/hypium';
import {
  isValidComposeChannelDescription,
  isValidComposeChatTitle,
  isValidComposeContact,
  normalizeComposePhoneNumber,
  toggleComposeUserSelection,
  uniqueComposeUserIds
} from '../../../main/ets/ui/pages/compose/ComposeCreationModel';

export default function composeCreationModelTest() {
  describe('ComposeCreationModel', () => {
    it('normalizes a phone without inventing digits', 0, () => {
      expect(normalizeComposePhoneNumber('+7 (700) 123-45-67')).assertEqual('+77001234567');
      expect(normalizeComposePhoneNumber('abc')).assertEqual('');
    });

    it('requires first name and a plausible phone', 0, () => {
      expect(isValidComposeContact('Alice', '', '+77001234567')).assertTrue();
      expect(isValidComposeContact('', '', '+77001234567')).assertFalse();
      expect(isValidComposeContact('Alice', '', '123')).assertFalse();
    });

    it('enforces TDLib title and description limits', 0, () => {
      expect(isValidComposeChatTitle(' Group ')).assertTrue();
      expect(isValidComposeChatTitle('   ')).assertFalse();
      expect(isValidComposeChatTitle('x'.repeat(129))).assertFalse();
      expect(isValidComposeChannelDescription('x'.repeat(255))).assertTrue();
      expect(isValidComposeChannelDescription('x'.repeat(256))).assertFalse();
    });

    it('keeps stable unique selection and toggles one user', 0, () => {
      const normalized: number[] = uniqueComposeUserIds([3, 0, 3, 2, -1]);
      expect(normalized.length).assertEqual(2);
      expect(normalized[0]).assertEqual(3);
      expect(normalized[1]).assertEqual(2);

      const added: number[] = toggleComposeUserSelection(normalized, 4);
      expect(added.length).assertEqual(3);
      expect(added[2]).assertEqual(4);
      const removed: number[] = toggleComposeUserSelection(added, 3);
      expect(removed.length).assertEqual(2);
      expect(removed[0]).assertEqual(2);
      expect(removed[1]).assertEqual(4);
    });
  });
}
