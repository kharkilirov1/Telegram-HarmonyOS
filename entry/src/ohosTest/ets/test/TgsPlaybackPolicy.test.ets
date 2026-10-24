// RED slice test for the TGS playback policy (S2 / matrix row D13).
//
// Contract under test:
// 1. a sticker animates only while it is visible on a surface that may animate;
// 2. decoded Lottie payloads are cached by TDLib fileId (never by local path)
//    and the cache survives an offscreen transition;
// 3. concurrent renderers are admitted against an explicit budget.

import { describe, expect, it } from '@ohos/hypium';
import {
  TgsPlaybackPolicy,
  TgsPlaybackSurface
} from '../../../main/ets/ui/tg_ui/atoms/TgTgsPlayer';

const DECODED: string = '{"v":"5.5.7","fr":30,"ip":0,"op":60,"w":512,"h":512,"layers":[]}';
const OTHER_DECODED: string = '{"v":"5.5.7","fr":60,"ip":0,"op":30,"w":256,"h":256,"layers":[]}';

export default function tgsPlaybackPolicyTest() {
  describe('TgsPlaybackPolicy', () => {
    it('does not animate an offscreen sticker', 0, () => {
      TgsPlaybackPolicy.reset();

      expect(TgsPlaybackPolicy.shouldPlay(false, TgsPlaybackSurface.Timeline)).assertFalse();
    });

    it('animates a visible sticker in the timeline', 0, () => {
      TgsPlaybackPolicy.reset();

      expect(TgsPlaybackPolicy.shouldPlay(true, TgsPlaybackSurface.Timeline)).assertTrue();
    });

    it('never animates composer grid previews even when visible', 0, () => {
      TgsPlaybackPolicy.reset();

      expect(TgsPlaybackPolicy.shouldPlay(true, TgsPlaybackSurface.PanelPreview)).assertFalse();
      expect(TgsPlaybackPolicy.allowsAnimation(TgsPlaybackSurface.PanelPreview)).assertFalse();
    });

    it('keeps the viewer and custom emoji seams able to animate', 0, () => {
      TgsPlaybackPolicy.reset();

      expect(TgsPlaybackPolicy.shouldPlay(true, TgsPlaybackSurface.StickerViewer)).assertTrue();
      expect(TgsPlaybackPolicy.shouldPlay(true, TgsPlaybackSurface.CustomEmoji)).assertTrue();
      expect(TgsPlaybackPolicy.shouldPlay(false, TgsPlaybackSurface.StickerViewer)).assertFalse();
      expect(TgsPlaybackPolicy.shouldPlay(false, TgsPlaybackSurface.CustomEmoji)).assertFalse();
    });

    it('caches a decoded payload by fileId', 0, () => {
      TgsPlaybackPolicy.reset();

      expect(TgsPlaybackPolicy.recallDecoded(101)).assertEqual('');
      TgsPlaybackPolicy.rememberDecoded(101, DECODED);

      expect(TgsPlaybackPolicy.recallDecoded(101)).assertEqual(DECODED);
      expect(TgsPlaybackPolicy.decodedCacheSize()).assertEqual(1);
    });

    it('does not let one fileId read another fileId payload', 0, () => {
      TgsPlaybackPolicy.reset();

      TgsPlaybackPolicy.rememberDecoded(101, DECODED);
      TgsPlaybackPolicy.rememberDecoded(202, OTHER_DECODED);

      expect(TgsPlaybackPolicy.recallDecoded(101)).assertEqual(DECODED);
      expect(TgsPlaybackPolicy.recallDecoded(202)).assertEqual(OTHER_DECODED);
      expect(TgsPlaybackPolicy.recallDecoded(303)).assertEqual('');
    });

    it('ignores requests that carry no fileId identity', 0, () => {
      TgsPlaybackPolicy.reset();

      TgsPlaybackPolicy.rememberDecoded(0, DECODED);

      expect(TgsPlaybackPolicy.decodedCacheSize()).assertEqual(0);
      expect(TgsPlaybackPolicy.recallDecoded(0)).assertEqual('');
    });

    it('keeps the cache across an offscreen transition', 0, () => {
      TgsPlaybackPolicy.reset();

      TgsPlaybackPolicy.rememberDecoded(101, DECODED);
      expect(TgsPlaybackPolicy.shouldPlay(false, TgsPlaybackSurface.Timeline)).assertFalse();
      expect(TgsPlaybackPolicy.shouldPlay(true, TgsPlaybackSurface.Timeline)).assertTrue();

      expect(TgsPlaybackPolicy.recallDecoded(101)).assertEqual(DECODED);
    });

    it('bounds the decoded cache and evicts the oldest entry first', 0, () => {
      TgsPlaybackPolicy.reset();
      const limit: number = TgsPlaybackPolicy.decodedCacheLimit();
      expect(limit > 0).assertTrue();

      for (let i = 1; i <= limit; i++) {
        TgsPlaybackPolicy.rememberDecoded(i, DECODED);
      }
      expect(TgsPlaybackPolicy.decodedCacheSize()).assertEqual(limit);

      // Touching the oldest entry makes the second oldest the eviction victim.
      expect(TgsPlaybackPolicy.recallDecoded(1)).assertEqual(DECODED);
      TgsPlaybackPolicy.rememberDecoded(limit + 1, OTHER_DECODED);

      expect(TgsPlaybackPolicy.decodedCacheSize()).assertEqual(limit);
      expect(TgsPlaybackPolicy.recallDecoded(1)).assertEqual(DECODED);
      expect(TgsPlaybackPolicy.recallDecoded(2)).assertEqual('');
      expect(TgsPlaybackPolicy.recallDecoded(limit + 1)).assertEqual(OTHER_DECODED);
    });

    it('admits at most the configured number of concurrent renderers', 0, () => {
      TgsPlaybackPolicy.reset();
      const maxPlayers: number = TgsPlaybackPolicy.maxConcurrentPlayers();
      expect(maxPlayers > 0).assertTrue();

      for (let i = 0; i < maxPlayers; i++) {
        expect(TgsPlaybackPolicy.acquirePlayer()).assertTrue();
      }
      expect(TgsPlaybackPolicy.acquirePlayer()).assertFalse();
      expect(TgsPlaybackPolicy.playingPlayers()).assertEqual(maxPlayers);

      TgsPlaybackPolicy.releasePlayer();
      expect(TgsPlaybackPolicy.acquirePlayer()).assertTrue();
      expect(TgsPlaybackPolicy.playingPlayers()).assertEqual(maxPlayers);
    });

    it('does not drop below zero released renderers', 0, () => {
      TgsPlaybackPolicy.reset();

      TgsPlaybackPolicy.releasePlayer();

      expect(TgsPlaybackPolicy.playingPlayers()).assertEqual(0);
    });

    it('clears playback admission and decoded payloads on reset', 0, () => {
      TgsPlaybackPolicy.reset();
      TgsPlaybackPolicy.rememberDecoded(101, DECODED);
      expect(TgsPlaybackPolicy.acquirePlayer()).assertTrue();

      TgsPlaybackPolicy.reset();

      expect(TgsPlaybackPolicy.decodedCacheSize()).assertEqual(0);
      expect(TgsPlaybackPolicy.recallDecoded(101)).assertEqual('');
      expect(TgsPlaybackPolicy.playingPlayers()).assertEqual(0);
    });
  });
}
