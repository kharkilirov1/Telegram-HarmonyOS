import { describe, expect, it } from '@ohos/hypium';
import {
  computeTgPhotoAlbumLayout,
  TgPhotoAlbumItemSize,
  TgPhotoAlbumLayoutResult,
  TgPhotoAlbumPosition,
} from '../../../main/ets/ui/tg_ui/layout/TgPhotoAlbumLayout';

function size(width: number, height: number): TgPhotoAlbumItemSize {
  return {
    width: width,
    height: height,
  };
}

function assertPositiveFrames(layout: TgPhotoAlbumLayoutResult, expectedCount: number): void {
  expect(layout.frames.length).assertEqual(expectedCount);
  for (let index = 0; index < layout.frames.length; index++) {
    const frame = layout.frames[index];
    expect(frame.index).assertEqual(index);
    expect(frame.width > 0).assertTrue();
    expect(frame.height > 0).assertTrue();
    expect(frame.x >= 0).assertTrue();
    expect(frame.y >= 0).assertTrue();
    expect(frame.x + frame.width <= layout.width + 0.001).assertTrue();
    expect(frame.y + frame.height <= layout.height + 0.001).assertTrue();
  }
}

export default function tgPhotoAlbumLayoutTest() {
  describe('TgPhotoAlbumLayout', () => {
    it('places two square photos in equal side-by-side cells', 0, () => {
      const layout = computeTgPhotoAlbumLayout([size(1000, 1000), size(800, 800)], 300, 380, 2);

      expect(layout.width).assertEqual(300);
      expect(layout.height).assertEqual(149);
      expect(layout.frames[0].x).assertEqual(0);
      expect(layout.frames[0].width).assertEqual(149);
      expect(layout.frames[1].x).assertEqual(151);
      expect(layout.frames[1].width).assertEqual(149);
      expect(layout.frames[0].position).assertEqual(
        TgPhotoAlbumPosition.Top | TgPhotoAlbumPosition.Left | TgPhotoAlbumPosition.Bottom);
      expect(layout.frames[1].position).assertEqual(
        TgPhotoAlbumPosition.Top | TgPhotoAlbumPosition.Right | TgPhotoAlbumPosition.Bottom);
    });

    it('stacks two similarly wide photos like Telegram iOS', 0, () => {
      const layout = computeTgPhotoAlbumLayout([size(1600, 900), size(1920, 1080)], 300, 380, 2);

      expect(layout.width).assertEqual(300);
      expect(layout.height).assertEqual(338);
      expect(layout.frames[0].height).assertEqual(168);
      expect(layout.frames[1].y).assertEqual(170);
      expect(layout.frames[0].position).assertEqual(
        TgPhotoAlbumPosition.Top | TgPhotoAlbumPosition.Left | TgPhotoAlbumPosition.Right);
      expect(layout.frames[1].position).assertEqual(
        TgPhotoAlbumPosition.Bottom | TgPhotoAlbumPosition.Left | TgPhotoAlbumPosition.Right);
    });

    it('uses the portrait-leading three-item composition', 0, () => {
      const layout = computeTgPhotoAlbumLayout([
        size(600, 1200),
        size(1000, 1000),
        size(1000, 1000),
      ], 300, 380, 2);

      expect(layout.width).assertEqual(300);
      expect(layout.height).assertEqual(380);
      expect(layout.frames[0].width).assertEqual(149);
      expect(layout.frames[0].height).assertEqual(380);
      expect(layout.frames[1].x).assertEqual(151);
      expect(layout.frames[1].height).assertEqual(229);
      expect(layout.frames[2].x).assertEqual(151);
      expect(layout.frames[2].y).assertEqual(231);
      expect(layout.frames[2].height).assertEqual(149);
    });

    it('keeps all ten items in deterministic aspect-aware rows', 0, () => {
      const items: TgPhotoAlbumItemSize[] = [
        size(1600, 900),
        size(1000, 1000),
        size(900, 1600),
        size(1200, 900),
        size(900, 1200),
        size(1800, 1000),
        size(1000, 1500),
        size(1500, 1000),
        size(1100, 1100),
        size(900, 1400),
      ];
      const first = computeTgPhotoAlbumLayout(items, 300, 380, 2);
      const second = computeTgPhotoAlbumLayout(items, 300, 380, 2);

      assertPositiveFrames(first, 10);
      expect(JSON.stringify(first)).assertEqual(JSON.stringify(second));
      expect(first.frames[0].position & TgPhotoAlbumPosition.Top).assertEqual(TgPhotoAlbumPosition.Top);
      expect(first.frames[9].position & TgPhotoAlbumPosition.Bottom).assertEqual(TgPhotoAlbumPosition.Bottom);
    });

    it('keeps every item for each Telegram album size from two through ten', 0, () => {
      const source: TgPhotoAlbumItemSize[] = [
        size(1600, 900), size(900, 1600), size(1000, 1000), size(1400, 900), size(900, 1200),
        size(1800, 1000), size(1000, 1500), size(1500, 1000), size(1100, 1100), size(900, 1400),
      ];
      for (let count = 2; count <= 10; count++) {
        const layout = computeTgPhotoAlbumLayout(source.slice(0, count), 300, 380, 2);
        assertPositiveFrames(layout, count);
      }
    });

    it('keeps a five-item mixed album valid in a narrow message lane', 0, () => {
      const layout = computeTgPhotoAlbumLayout([
        size(1600, 900), size(900, 1600), size(1000, 1000), size(1400, 900), size(900, 1200),
      ], 180, 280, 2);

      assertPositiveFrames(layout, 5);
      expect(layout.width >= 179).assertTrue();
    });

    it('produces positive geometry for every Telegram album size from two through ten', 0, () => {
      const catalog: TgPhotoAlbumItemSize[] = [
        size(1600, 900),
        size(1000, 1000),
        size(900, 1600),
        size(1200, 900),
        size(900, 1200),
        size(1800, 1000),
        size(1000, 1500),
        size(1500, 1000),
        size(1100, 1100),
        size(900, 1400),
      ];

      for (let count = 2; count <= 10; count++) {
        const items: TgPhotoAlbumItemSize[] = [];
        for (let index = 0; index < count; index++) {
          items.push(catalog[index]);
        }
        assertPositiveFrames(computeTgPhotoAlbumLayout(items, 300, 380, 2), count);
      }
    });

    it('changes the three-item geometry when the leading aspect ratio changes', 0, () => {
      const portrait = computeTgPhotoAlbumLayout([
        size(600, 1200),
        size(1000, 1000),
        size(1000, 1000),
      ], 300, 380, 2);
      const landscape = computeTgPhotoAlbumLayout([
        size(1600, 900),
        size(1000, 1000),
        size(1000, 1000),
      ], 300, 380, 2);

      expect(portrait.frames[0].width).assertEqual(149);
      expect(landscape.frames[0].width).assertEqual(300);
      expect(portrait.frames[1].x).assertEqual(151);
      expect(landscape.frames[1].x).assertEqual(0);
    });

    it('normalizes invalid source dimensions and rejects a non-positive container', 0, () => {
      const normalized = computeTgPhotoAlbumLayout([size(0, 0), size(-10, Number.NaN)], 300, 380, 2);
      assertPositiveFrames(normalized, 2);

      const empty = computeTgPhotoAlbumLayout([size(100, 100), size(100, 100)], 0, 380, 2);
      expect(empty.frames.length).assertEqual(0);
      expect(empty.width).assertEqual(0);
      expect(empty.height).assertEqual(0);
    });
  });
}
