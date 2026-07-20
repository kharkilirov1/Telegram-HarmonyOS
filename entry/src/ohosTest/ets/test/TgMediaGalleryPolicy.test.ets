import { describe, expect, it } from '@ohos/hypium';
import {
  resolveGalleryDoubleTapTransform,
  resolveGalleryPreviewKind,
  resolveGalleryPhotoOffset,
  resolveGalleryPinchTransform,
  resolveGalleryTransferActive,
  resolvePhotoAlbumTapMode,
  resolveVisualMediaTapMode
} from '../../../main/ets/ui/tg_ui/utils/TgMediaGalleryPolicy';

export default function tgMediaGalleryPolicyTest() {
  describe('TgMediaGalleryPolicy', () => {
    it('opens remote video immediately while starting only an idle download', 0, () => {
      expect(resolveVisualMediaTapMode(false, false)).assertEqual('downloadAndOpen');
      expect(resolveVisualMediaTapMode(false, true)).assertEqual('open');
      expect(resolveVisualMediaTapMode(true, false)).assertEqual('open');
    });

    it('downloads a remote album cell before allowing the gallery to open', 0, () => {
      expect(resolvePhotoAlbumTapMode(true, false, 77)).assertEqual('open');
      expect(resolvePhotoAlbumTapMode(false, false, 77)).assertEqual('download');
      expect(resolvePhotoAlbumTapMode(false, true, 77)).assertEqual('none');
      expect(resolvePhotoAlbumTapMode(false, false, 0)).assertEqual('none');
    });

    it('releases an optimistic gallery spinner when the exact file fails', 0, () => {
      expect(resolveGalleryTransferActive(false, -1, true, false)).assertTrue();
      expect(resolveGalleryTransferActive(false, -1, true, true)).assertFalse();
      expect(resolveGalleryTransferActive(true, 0.4, false, false)).assertTrue();
    });

    it('prefers a local thumbnail and falls back to the blurred TDLib minithumbnail', 0, () => {
      expect(resolveGalleryPreviewKind('/data/thumb.jpg', 'data:image/jpeg;base64,a')).assertEqual('thumbnail');
      expect(resolveGalleryPreviewKind('', 'data:image/jpeg;base64,a')).assertEqual('minithumb');
      expect(resolveGalleryPreviewKind('', '')).assertEqual('none');
    });

    it('zooms around the double-tap point and resets without toggling controls', 0, () => {
      const zoomed = resolveGalleryDoubleTapTransform(1, 75, 25, 200, 100, 200, 100, 2);
      expect(zoomed.scale).assertEqual(2);
      expect(zoomed.offsetX).assertEqual(25);
      expect(zoomed.offsetY).assertEqual(25);

      const reset = resolveGalleryDoubleTapTransform(2, 75, 25, 200, 100, 200, 100, 2);
      expect(reset.scale).assertEqual(1);
      expect(reset.offsetX).assertEqual(0);
      expect(reset.offsetY).assertEqual(0);
    });

    it('clamps zoomed photo pan to contained-media overflow', 0, () => {
      const bounded = resolveGalleryPhotoOffset(500, -500, 2, 200, 100, 100, 100);
      expect(bounded.offsetX).assertEqual(0);
      expect(bounded.offsetY).assertEqual(-50);
    });

    it('keeps the grabbed photo point under a moving pinch center', 0, () => {
      const zoomed = resolveGalleryPinchTransform(
        1,
        0,
        0,
        2,
        75,
        25,
        95,
        35,
        200,
        100,
        200,
        100
      );
      expect(zoomed.scale).assertEqual(2);
      expect(zoomed.offsetX).assertEqual(45);
      expect(zoomed.offsetY).assertEqual(35);
    });
  });
}
