import { describe, expect, it } from '@ohos/hypium';
import { mergeGalleryItemsInPlace } from '../../../main/ets/ui/pages/chat/MediaGalleryState';
import { MediaGalleryItem } from '../../../main/ets/models/MediaGalleryItem';

function makeItem(messageId: string, fileId: number, type: string = 'photo'): MediaGalleryItem {
  const item = new MediaGalleryItem();
  item.messageId = messageId;
  item.fileId = fileId;
  item.type = type;
  return item;
}

export default function mediaGalleryStateTest() {
  describe('MediaGalleryState', () => {
    it('carries file-state deltas into the existing item objects', 0, () => {
      const prev = [makeItem('10', 100), makeItem('11', 101)];
      const keptIdentity = prev[1];
      const next = [makeItem('10', 100), makeItem('11', 101)];
      next[1].path = '/data/photo.jpg';
      next[1].isDownloading = true;
      next[1].downloadProgress = 0.4;

      expect(mergeGalleryItemsInPlace(prev, next)).assertTrue();
      expect(prev[1] === keptIdentity).assertTrue();
      expect(prev[1].path).assertEqual('/data/photo.jpg');
      expect(prev[1].isDownloading).assertTrue();
      expect(prev[1].downloadProgress).assertEqual(0.4);
    });

    it('refuses to merge when the member composition changed', 0, () => {
      const prev = [makeItem('10', 100), makeItem('11', 101)];
      expect(mergeGalleryItemsInPlace(prev, [makeItem('10', 100)])).assertFalse();
      expect(mergeGalleryItemsInPlace(prev, [makeItem('10', 100), makeItem('12', 102)])).assertFalse();
      expect(mergeGalleryItemsInPlace(prev, [makeItem('10', 100), makeItem('11', 999)])).assertFalse();
      expect(mergeGalleryItemsInPlace(prev,
        [makeItem('10', 100), makeItem('11', 101, 'video')])).assertFalse();
    });

    it('never merges into an empty previous state', 0, () => {
      expect(mergeGalleryItemsInPlace([], [])).assertFalse();
      expect(mergeGalleryItemsInPlace([], [makeItem('10', 100)])).assertFalse();
    });
  });
}
