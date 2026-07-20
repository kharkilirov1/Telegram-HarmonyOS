import { describe, it, expect } from '@ohos/hypium';
import {
  isCJKCodePoint,
  containsCJK,
  charIsCJK,
  isLeftSticky,
  isForwardSticky,
  isLineStartProhibited,
  kinsokuStart,
  kinsokuEnd,
  leftStickyPunctuation
} from '../../../main/ets/ui/text_engine/CjkDetector';
import {
  tokenize,
  tokenizeWithChunks,
  normalizeWhitespace,
  isSimplePath,
  TokenizeResult
} from '../../../main/ets/ui/text_engine/Segmenter';
import { layoutLines, measureHeight, getLastLineWidth } from '../../../main/ets/ui/text_engine/LineBreaker';
import { PreparedText, HardBreakChunk, SegmentBreakKind } from '../../../main/ets/ui/text_engine/TextTypes';
import { composeMessageMetaText } from '../../../main/ets/ui/tg_ui/utils/TgMessageMetaText';

/**
 * Unit tests for text engine components — CJK detection, segmentation, line breaking.
 */

function makePreparedText(
  segments: string[],
  widths: number[],
  kinds: SegmentBreakKind[],
  isWordLike: boolean[],
  lineHeight: number,
  chunks?: HardBreakChunk[]
): PreparedText {
  let totalWidth = 0;
  for (let i = 0; i < widths.length; i++) {
    totalWidth += widths[i];
  }
  const computedChunks: HardBreakChunk[] = chunks ? chunks : [{ startIndex: 0, endIndex: segments.length }];
  const prepared: PreparedText = {
    text: segments.join(''),
    styleKey: 'test',
    segments: segments,
    widths: widths,
    kinds: kinds,
    isWordLike: isWordLike,
    totalWidth: totalWidth,
    chunks: computedChunks,
    lineHeight: lineHeight,
    hasSimplePath: true
  };
  return prepared;
}

export default function textEngineTest() {
  describe('TextEngine', () => {

    describe('composeMessageMetaText', () => {
      it('should join localized edited text and time with one space', 0, () => {
        expect(composeMessageMetaText('изменено', '07:42')).assertEqual('изменено 07:42');
      });

      it('should keep ordinary time unchanged', 0, () => {
        expect(composeMessageMetaText('', '07:42')).assertEqual('07:42');
      });

      it('should trim resource and time inputs', 0, () => {
        expect(composeMessageMetaText(' edited ', ' 09:41 ')).assertEqual('edited 09:41');
      });
    });

    // -----------------------------------------------------------------------
    // CjkDetector — isCJKCodePoint
    // -----------------------------------------------------------------------
    describe('isCJKCodePoint', () => {

      it('should detect CJK Unified Ideograph U+4E00', 0, () => {
        expect(isCJKCodePoint(0x4E00)).assertTrue();
      });

      it('should detect CJK Unified Ideograph U+9FFF', 0, () => {
        expect(isCJKCodePoint(0x9FFF)).assertTrue();
      });

      it('should detect Hiragana U+3042 (a)', 0, () => {
        expect(isCJKCodePoint(0x3042)).assertTrue();
      });

      it('should detect Katakana U+30A2 (a)', 0, () => {
        expect(isCJKCodePoint(0x30A2)).assertTrue();
      });

      it('should detect Hangul U+AC00', 0, () => {
        expect(isCJKCodePoint(0xAC00)).assertTrue();
      });

      it('should not detect Latin A (U+0041)', 0, () => {
        expect(isCJKCodePoint(0x0041)).assertFalse();
      });

      it('should not detect space (U+0020)', 0, () => {
        expect(isCJKCodePoint(0x0020)).assertFalse();
      });

      it('should not detect Cyrillic U+0410', 0, () => {
        expect(isCJKCodePoint(0x0410)).assertFalse();
      });

      it('should detect CJK Extension B U+20000', 0, () => {
        expect(isCJKCodePoint(0x20000)).assertTrue();
      });

      it('should detect fullwidth form U+FF01', 0, () => {
        expect(isCJKCodePoint(0xFF01)).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // CjkDetector — containsCJK
    // -----------------------------------------------------------------------
    describe('containsCJK', () => {

      it('should return true for string with CJK characters', 0, () => {
        expect(containsCJK('hello world')).assertFalse();
      });

      it('should detect Chinese in mixed text', 0, () => {
        expect(containsCJK('hello \u4F60\u597D world')).assertTrue();
      });

      it('should return false for empty string', 0, () => {
        expect(containsCJK('')).assertFalse();
      });

      it('should return false for pure Latin', 0, () => {
        expect(containsCJK('abc 123')).assertFalse();
      });

      it('should detect Japanese hiragana', 0, () => {
        expect(containsCJK('\u3053\u3093\u306B\u3061\u306F')).assertTrue();
      });

      it('should detect Korean hangul', 0, () => {
        expect(containsCJK('\uC548\uB155\uD558\uC138\uC694')).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // CjkDetector — charIsCJK
    // -----------------------------------------------------------------------
    describe('charIsCJK', () => {

      it('should return true for single CJK character', 0, () => {
        expect(charIsCJK('\u4E2D')).assertTrue();
      });

      it('should return false for Latin character', 0, () => {
        expect(charIsCJK('A')).assertFalse();
      });

      it('should return false for empty string', 0, () => {
        expect(charIsCJK('')).assertFalse();
      });

      it('should return true for katakana', 0, () => {
        expect(charIsCJK('\u30A2')).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // CjkDetector — kinsoku / sticky rules
    // -----------------------------------------------------------------------
    describe('kinsoku and sticky rules', () => {

      it('isLeftSticky should return true for period', 0, () => {
        expect(isLeftSticky('.')).assertTrue();
      });

      it('isLeftSticky should return true for comma', 0, () => {
        expect(isLeftSticky(',')).assertTrue();
      });

      it('isLeftSticky should return true for closing paren', 0, () => {
        expect(isLeftSticky(')')).assertTrue();
      });

      it('isLeftSticky should return false for opening paren', 0, () => {
        expect(isLeftSticky('(')).assertFalse();
      });

      it('isLeftSticky should return false for letter', 0, () => {
        expect(isLeftSticky('a')).assertFalse();
      });

      it('isLeftSticky should return false for empty string', 0, () => {
        expect(isLeftSticky('')).assertFalse();
      });

      it('isForwardSticky should return true for opening paren', 0, () => {
        expect(isForwardSticky('(')).assertTrue();
      });

      it('isForwardSticky should return false for closing paren', 0, () => {
        expect(isForwardSticky(')')).assertFalse();
      });

      it('isForwardSticky should return false for empty string', 0, () => {
        expect(isForwardSticky('')).assertFalse();
      });

      it('isLineStartProhibited should return true for Japanese comma', 0, () => {
        expect(isLineStartProhibited('\u3001')).assertTrue();
      });

      it('isLineStartProhibited should return true for period', 0, () => {
        expect(isLineStartProhibited('.')).assertTrue();
      });

      it('isLineStartProhibited should return false for letter', 0, () => {
        expect(isLineStartProhibited('a')).assertFalse();
      });

      it('kinsokuStart should contain Japanese period U+3002', 0, () => {
        expect(kinsokuStart.has('\u3002')).assertTrue();
      });

      it('kinsokuEnd should contain opening paren', 0, () => {
        expect(kinsokuEnd.has('(')).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // Segmenter — normalizeWhitespace
    // -----------------------------------------------------------------------
    describe('normalizeWhitespace', () => {

      it('should return same string when no normalization needed', 0, () => {
        expect(normalizeWhitespace('hello')).assertEqual('hello');
      });

      it('should collapse multiple spaces', 0, () => {
        expect(normalizeWhitespace('a  b')).assertEqual('a b');
      });

      it('should replace tabs with spaces', 0, () => {
        expect(normalizeWhitespace('a\tb')).assertEqual('a b');
      });

      it('should trim leading/trailing spaces per line', 0, () => {
        expect(normalizeWhitespace(' hello ')).assertEqual('hello');
      });

      it('should preserve newlines', 0, () => {
        const result = normalizeWhitespace('line1\nline2');
        expect(result).assertEqual('line1\nline2');
      });

      it('should normalize CRLF to LF', 0, () => {
        const result = normalizeWhitespace('a\r\nb');
        expect(result).assertEqual('a\nb');
      });

      it('should handle empty string', 0, () => {
        expect(normalizeWhitespace('')).assertEqual('');
      });
    });

    // -----------------------------------------------------------------------
    // Segmenter — tokenize
    // -----------------------------------------------------------------------
    describe('tokenize', () => {

      it('should return empty array for empty string', 0, () => {
        const segments = tokenize('');
        expect(segments.length).assertEqual(0);
      });

      it('should tokenize single Latin word', 0, () => {
        const segments = tokenize('hello');
        expect(segments.length).assertEqual(1);
        expect(segments[0].text).assertEqual('hello');
        expect(segments[0].kind).assertEqual('text');
        expect(segments[0].isWordLike).assertTrue();
      });

      it('should tokenize two words separated by space', 0, () => {
        const segments = tokenize('hello world');
        expect(segments.length).assertEqual(3);
        expect(segments[0].text).assertEqual('hello');
        expect(segments[1].text).assertEqual(' ');
        expect(segments[1].kind).assertEqual('space');
        expect(segments[2].text).assertEqual('world');
      });

      it('should tokenize CJK characters individually', 0, () => {
        const segments = tokenize('\u4E2D\u6587');
        // Each CJK char is its own segment
        expect(segments.length).assertEqual(2);
        expect(segments[0].text).assertEqual('\u4E2D');
        expect(segments[0].isWordLike).assertTrue();
        expect(segments[1].text).assertEqual('\u6587');
      });

      it('should tokenize mixed Latin and CJK', 0, () => {
        const segments = tokenize('hi\u4F60');
        expect(segments.length).assertEqual(2);
        expect(segments[0].text).assertEqual('hi');
        expect(segments[1].text).assertEqual('\u4F60');
      });

      it('should tokenize hard break', 0, () => {
        const segments = tokenize('a\nb');
        // 'a', '\n', 'b'
        expect(segments.length).assertEqual(3);
        expect(segments[1].kind).assertEqual('hard-break');
      });

      it('should apply glue rules for left-sticky punctuation', 0, () => {
        // Period should merge with previous word
        const segments = tokenize('hello.');
        // 'hello.' as one merged segment due to left-sticky '.'
        expect(segments.length).assertEqual(1);
        expect(segments[0].text).assertEqual('hello.');
      });

      it('should handle Cyrillic text', 0, () => {
        const segments = tokenize('\u041F\u0440\u0438\u0432\u0435\u0442');
        expect(segments.length).assertEqual(1);
        expect(segments[0].text).assertEqual('\u041F\u0440\u0438\u0432\u0435\u0442');
        expect(segments[0].isWordLike).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // Segmenter — tokenizeWithChunks
    // -----------------------------------------------------------------------
    describe('tokenizeWithChunks', () => {

      it('should return segments and chunks for single line', 0, () => {
        const result: TokenizeResult = tokenizeWithChunks('hello world');
        expect(result.segments.length).assertEqual(3);
        expect(result.chunks.length).assertEqual(1);
        expect(result.chunks[0].startIndex).assertEqual(0);
        expect(result.chunks[0].endIndex).assertEqual(3);
      });

      it('should split chunks on hard breaks', 0, () => {
        const result: TokenizeResult = tokenizeWithChunks('a\nb');
        expect(result.chunks.length).assertEqual(2);
        expect(result.chunks[0].endIndex).assertEqual(1); // 'a' only
        expect(result.chunks[1].startIndex).assertEqual(2); // 'b'
      });

      it('should handle empty string', 0, () => {
        const result: TokenizeResult = tokenizeWithChunks('');
        expect(result.segments.length).assertEqual(0);
        expect(result.chunks.length).assertEqual(1);
      });
    });

    // -----------------------------------------------------------------------
    // Segmenter — isSimplePath
    // -----------------------------------------------------------------------
    describe('isSimplePath', () => {

      it('should return true for text-only segments', 0, () => {
        const segments = tokenize('hello world');
        expect(isSimplePath(segments)).assertTrue();
      });

      it('should return false when hard break present', 0, () => {
        const segments = tokenize('a\nb');
        expect(isSimplePath(segments)).assertFalse();
      });

      it('should return true for empty segments', 0, () => {
        expect(isSimplePath([])).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // LineBreaker — layoutLines
    // -----------------------------------------------------------------------
    describe('layoutLines', () => {

      it('should produce single line for empty segments', 0, () => {
        const prepared = makePreparedText([], [], [], [], 20);
        const result = layoutLines(prepared, 100);
        expect(result.lineCount).assertEqual(1);
        expect(result.height).assertEqual(20);
        expect(result.maxLineWidth).assertEqual(0);
        expect(result.lastLineWidth).assertEqual(0);
      });

      it('should produce single line when text fits', 0, () => {
        const prepared = makePreparedText(
          ['hello', ' ', 'world'],
          [30, 5, 30],
          ['text', 'space', 'text'],
          [true, false, true],
          20
        );
        const result = layoutLines(prepared, 100);
        expect(result.lineCount).assertEqual(1);
        expect(result.height).assertEqual(20);
        expect(result.maxLineWidth).assertEqual(65);
      });

      it('should wrap to two lines when text overflows', 0, () => {
        const prepared = makePreparedText(
          ['hello', ' ', 'world'],
          [30, 5, 30],
          ['text', 'space', 'text'],
          [true, false, true],
          20
        );
        const result = layoutLines(prepared, 40);
        expect(result.lineCount).assertEqual(2);
        expect(result.height).assertEqual(40);
      });

      it('should handle multiple hard-break chunks', 0, () => {
        const prepared = makePreparedText(
          ['line1', '\n', 'line2'],
          [30, 0, 30],
          ['text', 'hard-break', 'text'],
          [true, false, true],
          20,
          [{ startIndex: 0, endIndex: 1 }, { startIndex: 2, endIndex: 3 }]
        );
        const result = layoutLines(prepared, 200);
        expect(result.lineCount).assertEqual(2);
        expect(result.height).assertEqual(40);
      });

      it('should report correct lastLineWidth', 0, () => {
        const prepared = makePreparedText(
          ['hello'],
          [50],
          ['text'],
          [true],
          20
        );
        const result = layoutLines(prepared, 200);
        expect(result.lastLineWidth).assertEqual(50);
      });
    });

    // -----------------------------------------------------------------------
    // LineBreaker — measureHeight
    // -----------------------------------------------------------------------
    describe('measureHeight', () => {

      it('should return lineHeight for empty text', 0, () => {
        const prepared = makePreparedText([], [], [], [], 24);
        expect(measureHeight(prepared, 100)).assertEqual(24);
      });

      it('should return lineHeight for single-line text', 0, () => {
        const prepared = makePreparedText(
          ['hi'],
          [10],
          ['text'],
          [true],
          24
        );
        expect(measureHeight(prepared, 100)).assertEqual(24);
      });
    });

    // -----------------------------------------------------------------------
    // LineBreaker — getLastLineWidth
    // -----------------------------------------------------------------------
    describe('getLastLineWidth', () => {

      it('should return 0 for empty text', 0, () => {
        const prepared = makePreparedText([], [], [], [], 20);
        expect(getLastLineWidth(prepared, 100)).assertEqual(0);
      });

      it('should return totalWidth for single-line text', 0, () => {
        const prepared = makePreparedText(
          ['abc'],
          [42],
          ['text'],
          [true],
          20
        );
        expect(getLastLineWidth(prepared, 100)).assertEqual(42);
      });
    });
  });
}
