import { describe, expect, it } from '@ohos/hypium';
import {
  UNICODE_EMOJI_CATEGORIES,
  UNICODE_EMOJI_COUNT,
  UNICODE_EMOJI_VERSION
} from '../../../main/ets/ui/tg_ui/data/TgUnicodeEmojiCatalog';

export default function tgUnicodeEmojiCatalogTest() {
  describe('TgUnicodeEmojiCatalog', () => {
    it('keeps the nine CLDR keyboard groups in Telegram order', 0, () => {
      const expectedIds: string[] = [
        'smileys', 'people', 'animals', 'food', 'travel',
        'activity', 'objects', 'symbols', 'flags'
      ];
      expect(UNICODE_EMOJI_VERSION).assertEqual('17.0');
      expect(UNICODE_EMOJI_CATEGORIES.length).assertEqual(expectedIds.length);
      for (let index = 0; index < expectedIds.length; index++) {
        expect(UNICODE_EMOJI_CATEGORIES[index].id).assertEqual(expectedIds[index]);
      }
    });

    it('contains the complete neutral base catalog without skin-tone duplicates', 0, () => {
      let actualCount: number = 0;
      for (const category of UNICODE_EMOJI_CATEGORIES) {
        actualCount += category.emojis.length;
        for (const emoji of category.emojis) {
          expect(emoji.includes('🏻')).assertFalse();
          expect(emoji.includes('🏼')).assertFalse();
          expect(emoji.includes('🏽')).assertFalse();
          expect(emoji.includes('🏾')).assertFalse();
          expect(emoji.includes('🏿')).assertFalse();
        }
      }
      expect(actualCount).assertEqual(UNICODE_EMOJI_COUNT);
      expect(actualCount >= 1500).assertTrue();
    });

    it('does not collapse people gestures or flags to a sample row', 0, () => {
      let peopleCount: number = 0;
      let flagsCount: number = 0;
      for (const category of UNICODE_EMOJI_CATEGORIES) {
        if (category.id === 'people') {
          peopleCount = category.emojis.length;
        } else if (category.id === 'flags') {
          flagsCount = category.emojis.length;
        }
      }
      expect(peopleCount >= 350).assertTrue();
      expect(flagsCount >= 260).assertTrue();
    });
  });
}
