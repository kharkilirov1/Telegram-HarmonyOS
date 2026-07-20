import { describe, it, expect } from '@ohos/hypium';
import {
  albumMediaSourceId,
  mediaGeometryTransitionId
} from '../../../main/ets/ui/tg_ui/utils/TgMediaGeometryTransition';

export default function mediaGalleryGeometryTransitionTest() {
  describe('MediaGalleryGeometryTransition', () => {
    it('keeps source and fullscreen destination on one stable message identity', 0, () => {
      expect(mediaGeometryTransitionId('123456789')).assertEqual('tg_chat_media_123456789');
      expect(mediaGeometryTransitionId('  -42  ')).assertEqual('tg_chat_media_-42');
    });

    it('uses a deterministic fallback for an empty identity', 0, () => {
      expect(mediaGeometryTransitionId('')).assertEqual('tg_chat_media_0');
      expect(mediaGeometryTransitionId('   ')).assertEqual('tg_chat_media_0');
    });

    it('gives every album member its own stable source endpoint', 0, () => {
      expect(albumMediaSourceId('100', ' 103 ', 3)).assertEqual('103');
      expect(albumMediaSourceId('100', '', 3)).assertEqual('100_album_3');
      expect(albumMediaSourceId('100', '', 5)).assertEqual('100_album_5');
    });
  });
}
