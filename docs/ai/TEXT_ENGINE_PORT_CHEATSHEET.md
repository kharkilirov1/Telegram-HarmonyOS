# Text Engine Port Cheatsheet — Pretext → HarmonyOS ArkTS

Last updated: 2026-04-04

## Источник

- **Pretext** by Cheng Lou: https://github.com/chenglou/pretext
- Идея: двухфазная архитектура `prepare()` (дорогое измерение) → `layout()` (чистая арифметика, ~0.02ms)
- Цель порта: точная высота пузырей для виртуализации `List` в чат-таймлайне без layout reflow

---

## 1. Критические API замены

### 1.1 Text Measurement

| Pretext (Browser) | HarmonyOS | Модуль | API level |
|---|---|---|---|
| `canvas.measureText(text).width` | `MeasureUtils.measureText(options)` → `number` (px) | `@kit.ArkUI` | 12+ |
| `canvas.measureText()` + font | `MeasureUtils.measureTextSize(options)` → `{width, height}` (px) | `@kit.ArkUI` | 12+ |
| `OffscreenCanvas` | Не нужен | — | — |
| DOM `<span>` + `getBoundingClientRect` | Не нужен (один рендерер) | — | — |

**Получение MeasureUtils (НЕ статический вызов!):**
```typescript
import { MeasureUtils } from '@kit.ArkUI'
const measureUtils: MeasureUtils = this.getUIContext().getMeasureUtils()
```

**MeasureOptions (ключевые поля):**
```typescript
{
  textContent: string | Resource,     // обязательное
  constraintWidth?: number | string,  // vp, без него — single-line
  fontSize?: number,                  // fp (с API 12!), default 16
  fontWeight?: FontWeight | number,   // default Normal (400)
  fontFamily?: string,                // ТОЛЬКО 'HarmonyOS Sans'
  lineHeight?: number | string,
  maxLines?: number,
  wordBreak?: WordBreak,
  textIndent?: number | string        // API 11+
}
```

**GOTCHAS:**
- Возвращает **px**, не vp → конвертация: `uiContext.px2vp(result.width)`
- `fontSize` number = **fp** (с API 12), раньше было vp
- Без `constraintWidth` — ширина одной строки (без переноса)
- `fontFamily` — реально работает только `'HarmonyOS Sans'`
- `measureText()` → number (ширина) ИГНОРИРУЕТ `constraintWidth` и `maxLines`
- `measureTextSize()` → {width, height} УЧИТЫВАЕТ constraints

**DEPRECATED (не использовать):**
- `import measure from '@ohos.measure'` → deprecated с API 18
- `MeasureText.measureTextSize()` → статический, без UIContext привязки

### 1.2 Typography Engine (мощная альтернатива)

**`text.Paragraph`** из `@kit.ArkGraphics2D` — полноценный typography engine, аналог Skia Paragraph / Android StaticLayout / iOS NSLayoutManager.

```typescript
import { text } from '@kit.ArkGraphics2D'

// Build
let textStyle: text.TextStyle = { fontSize: 50, color: { alpha: 255, red: 0, green: 0, blue: 0 } }
let paragraphStyle: text.ParagraphStyle = { textStyle, wordBreak: text.WordBreak.NORMAL }
let fontCollection = text.FontCollection.getGlobalInstance()
let builder = new text.ParagraphBuilder(paragraphStyle, fontCollection)
builder.pushStyle(textStyle)
builder.addText('Hello World')
let paragraph = builder.build()

// Layout (sync, px units)
paragraph.layoutSync(maxWidthPx)

// Rich metrics
paragraph.getLineCount()                    // number
paragraph.getHeight()                       // number (px)
paragraph.getLineWidth(lineNumber)          // number (px)
paragraph.getLineHeight(lineNumber)         // number (px)
paragraph.getLongestLine()                   // number (px)
paragraph.getLineMetrics()                  // Array<LineMetrics>
paragraph.getLineMetrics(lineNo)            // LineMetrics | undefined
paragraph.getWordBoundary(offset)           // Range { start, end }
paragraph.getGlyphPositionAtCoordinate(x,y) // PositionWithAffinity
paragraph.getRectsForRange(range, w, h)     // Array<TextBox>
paragraph.getTextLines()                    // Array<TextLine>
paragraph.getActualTextRange(lineIdx, includeSpaces) // Range
paragraph.getAlphabeticBaseline()           // number
paragraph.getIdeographicBaseline()          // number
```

**LineMetrics:**
```typescript
{
  startIndex: number,      // начало строки в тексте
  endIndex: number,        // конец строки
  ascent: number,
  descent: number,
  height: number,          // Math.round(ascent + descent)
  width: number,           // ширина строки
  left: number,            // левый край
  baseline: number,        // Y baseline от верха параграфа
  lineNumber: number,      // от 0
  topHeight: number,       // высота от верха до строки
  runMetrics: Map<number, RunMetrics>,
  textStyle: TextStyle,
  fontMetrics: drawing.FontMetrics
}
```

**Поддержка styled spans:**
```typescript
builder.pushStyle({ fontSize: 20, color: red })
builder.addText('Bold ')
builder.popStyle()
builder.pushStyle({ fontSize: 14, color: gray })
builder.addText('small')
builder.popStyle()
```

**Placeholders (для inline images):**
```typescript
builder.addPlaceholder({ width: 40, height: 40, align: text.PlaceholderAlignment.MIDDLE, ... })
```

**API level:** 12+ (TypeScript API), Atomic service API с version 22

### 1.3 Segmentation

| Pretext | HarmonyOS | Статус |
|---|---|---|
| `Intl.Segmenter('en', {granularity: 'word'})` | **НЕ ДОКУМЕНТИРОВАН** в ArkTS | Нужна эмпирическая проверка |
| `Intl.Segmenter(undefined, {granularity: 'grapheme'})` | **НЕ ДОКУМЕНТИРОВАН** | Нужна проверка |
| `i18n.BreakIterator` (ICU) | `i18n.getLineInstance(locale)` — **ТОЛЬКО line breaks** | API 8+ |
| Word boundary | `text.Paragraph.getWordBoundary(offset)` | API 22 (heavyweight) |
| Grapheme iteration | Нет прямого API | — |

**`i18n.BreakIterator`** (единственный доступный):
```typescript
import { i18n } from '@kit.LocalizationKit'

let bi = i18n.getLineInstance('en')
bi.setLineBreakText('Hello world! Привет мир!')
bi.first()           // 0
bi.next()            // следующая точка разрыва
bi.following(offset) // точка разрыва после offset
bi.isBoundary(offset) // является ли позиция точкой разрыва
```
- **Только line-break points!** Нет `getWordInstance()`, `getCharacterInstance()`, `getSentenceInstance()`
- Бесполезен для word/grapheme segmentation

**Стратегия замены `Intl.Segmenter`:**

Приоритет 1: Проверить эмпирически на устройстве:
```typescript
try {
  const seg = new Intl.Segmenter('en', { granularity: 'word' })
  // если работает — используем
} catch (e) {
  // fallback
}
```

Приоритет 2: Кастомный word tokenizer (простой, для Latin/Cyrillic/CJK):
- Слово = `[a-zA-Zа-яА-ЯёЁ0-9]+` с апострофами
- CJK = каждый символ отдельно (проверка `isCJKCodePoint`)
- Пробелы = отдельные сегменты
- Пунктуация = отдельные сегменты + glue rules

Приоритет 3: C++ NAPI bridge к ICU4C `BreakIterator` (гарантированная работа, но тяжёлая интеграция)

---

## 2. Что портируется 1:1 из Pretext

### 2.1 CJK detection (analysis.ts)
```typescript
function isCJKCodePoint(cp: number): boolean {
  return (
    (cp >= 0x4E00 && cp <= 0x9FFF) ||   // CJK Unified Ideographs
    (cp >= 0x3400 && cp <= 0x4DBF) ||   // Ext A
    (cp >= 0x20000 && cp <= 0x2A6DF) || // Ext B
    (cp >= 0x2A700 && cp <= 0x2B73F) || // Ext C
    (cp >= 0x2B740 && cp <= 0x2B81F) || // Ext D
    (cp >= 0x2B820 && cp <= 0x2CEAF) || // Ext E
    (cp >= 0x2CEB0 && cp <= 0x2EBEF) || // Ext F
    (cp >= 0x2EBF0 && cp <= 0x2EE5D) || // Ext I
    (cp >= 0x2F800 && cp <= 0x2FA1F) || // CJK Compat Supp
    (cp >= 0x30000 && cp <= 0x3134F) || // Ext G
    (cp >= 0x31350 && cp <= 0x323AF) || // Ext H
    (cp >= 0x323B0 && cp <= 0x33479) || // Latest ext
    (cp >= 0xF900 && cp <= 0xFAFF) ||   // CJK Compatibility
    (cp >= 0x3000 && cp <= 0x303F) ||   // Symbols & Punctuation
    (cp >= 0x3040 && cp <= 0x309F) ||   // Hiragana
    (cp >= 0x30A0 && cp <= 0x30FF) ||   // Katakana
    (cp >= 0xAC00 && cp <= 0xD7AF) ||   // Hangul Syllables
    (cp >= 0xFF00 && cp <= 0xFFEF)      // Halfwidth/Fullwidth
  )
}
```
- Оптимизация: `if (first < 0x3000) continue` отсекает Latin/Cyrillic без входа в функцию

### 2.2 Kinsoku tables (analysis.ts)
4 набора `Set<string>` — портируются как `Set<string>` в ArkTS:
- `kinsokuStart` — запрещены в начале строки (30+ fullwidth символов)
- `kinsokuEnd` — запрещены в конце строки (20+ открывающих скобок/кавычек)
- `leftStickyPunctuation` — приклеиваются слева к слову (`.`, `,`, `!`, `)`, etc.)
- `forwardStickyGlue` — приклеиваются справа (`'`, `'`)

### 2.3 Whitespace normalization (analysis.ts)
```typescript
// Normal mode: collapse whitespace runs
const collapsibleRe = /[ \t\n\r\f]+/g
function normalizeNormal(text: string): string {
  return text.replace(collapsibleRe, ' ').trim()
}

// Pre-wrap mode: normalize line endings only
function normalizePreWrap(text: string): string {
  return text.replace(/\r\n/g, '\n').replace(/[\r\f]/g, '\n')
}
```

### 2.4 Segment break kinds
```typescript
type SegmentBreakKind =
  | 'text' | 'space' | 'preserved-space' | 'tab'
  | 'glue' | 'zero-width-break' | 'soft-hyphen' | 'hard-break'
```
Классификация:
- `\u00A0`, `\u202F`, `\u2060`, `\uFEFF` → `'glue'` (non-breaking)
- `\u200B` → `'zero-width-break'`
- `\u00AD` → `'soft-hyphen'`
- `\n` (pre-wrap) → `'hard-break'`

### 2.5 Line break algorithm (line-break.ts)
Greedy line break — O(n):
- Накапливает `lineW += segmentWidth`
- Overflow → break at last valid break point
- No break point → force break (overflow-wrap, per-grapheme)
- Trailing whitespace hangs past edge (`lineEndFitAdvances` vs `lineEndPaintAdvances`)
- Soft hyphen → добавляет визуальный `-`
- Binary search для chunk lookup
- Fast path для простого текста без tabs/soft-hyphens/overflow-wrap

### 2.6 SoA data layout (layout.ts)
Параллельные массивы вместо массива объектов — cache-friendly:
```typescript
type PreparedCore = {
  widths: number[]
  lineEndFitAdvances: number[]
  lineEndPaintAdvances: number[]
  kinds: SegmentBreakKind[]
  simpleLineWalkFastPath: boolean
  breakableWidths: (number[] | null)[]
  breakablePrefixWidths: (number[] | null)[]
  discretionaryHyphenWidth: number
  tabStopAdvance: number
  chunks: PreparedLineChunk[]
}
```

### 2.7 LRU Cache
Двухуровневый:
- L1: `Map<styleKey, Map<segment, SegmentMetrics>>` — ширины сегментов
- L2: `Map<preparedKey + maxWidth, LayoutResult>` — результаты layout
- Размеры по умолчанию: 5000 prepared, 10000 layouts

---

## 3. Что НЕ НУЖНО портировать

| Компонент Pretext | Причина |
|---|---|
| Emoji correction (DOM calibration) | HarmonyOS = один рендерер, нет canvas/DOM дельты |
| EngineProfile detection (userAgent) | Статический профиль: `lineFitEpsilon: 0` |
| `OffscreenCanvas` fallback | Нет canvas, используем `MeasureUtils` |
| `carryCJKAfterClosingQuote` (Chromium quirk) | Не релевантно |
| `preferPrefixWidthsForBreakableRuns` (Safari quirk) | Не релевантно |
| `preferEarlySoftHyphenBreak` (Safari quirk) | Не релевантно |

---

## 4. Что проверить эмпирически на устройстве

| Вопрос | Как проверить | Влияние |
|---|---|---|
| `Intl.Segmenter` доступен? | `try { new Intl.Segmenter('en', {granularity:'word'}) }` | Определяет всю стратегию сегментации |
| `\p{Emoji_Presentation}` в regex? | `/\p{Emoji_Presentation}/u.test('😀')` | Emoji detection |
| `MeasureUtils` точность для emoji | Сравнить измеренную и реальную ширину emoji | Нужна ли emoji correction |
| `text.Paragraph.layoutSync()` latency | Benchmark на 1000 строк | Определяет Path A vs B |
| `text.Paragraph.getWordBoundary()` | Проверить на CJK + Latin mix | Word segmentation fallback |

---

## 5. Стратегическое решение: Path A vs B

### Path A — Full Pretext Port (custom engine)
```
Segmenter.ets (custom/Intl.Segmenter)
  → TextMeasurer.ets (MeasureUtils per-segment)
  → LineBreaker.ets (greedy line break, 1:1 port)
  → LayoutCache.ets (LRU)
  → TgTextLayout.ets (facade)
```
**Плюсы:** полный контроль, предсказуемость, совпадение с Telegram iOS bubble sizing
**Минусы:** ~2000 LoC порта, нужна замена Intl.Segmenter, ручной кэш

### Path B — text.Paragraph Wrapper (native engine)
```
TgTextLayout.ets
  → ParagraphBuilder cache (reuse builders)
  → paragraph.layoutSync(width) для каждого текста
  → paragraph.getLineMetrics() для метрик
  → LRU cache поверх
```
**Плюсы:** меньше кода (~500 LoC), HarmonyOS делает segmentation + line break + measurement
**Минусы:** меньше контроля, overhead от ParagraphBuilder на каждый текст, поведение может меняться между API

### Path C — Hybrid (рекомендация)
```
Segmenter.ets (custom CJK/Latin/Cyrillic tokenizer + Intl.Segmenter if available)
  → TextMeasurer.ets (MeasureUtils.measureText для per-segment widths)
  → LineBreaker.ets (Pretext greedy algo, 1:1)
  → LayoutCache.ets (LRU)
  → TgTextLayout.ets (facade: prepare + layout)
  
Fallback: text.Paragraph для rich text (styled spans, placeholders)
```
**Плюсы:** Pretext-level контроль для plain text (95% чата), native engine для rich text
**Минусы:** два code paths

---

## 6. Целевая файловая структура

```
entry/src/main/ets/ui/text_engine/
├── TextTypes.ets            # Типы: SegmentBreakKind, PreparedText, LayoutResult, TextStyleKey
├── Segmenter.ets            # Токенизация: word/CJK/emoji/punct/whitespace
├── CjkDetector.ets          # isCJKCodePoint, kinsoku tables (port 1:1)
├── TextMeasurer.ets         # MeasureUtils wrapper + segment width cache
├── LineBreaker.ets          # Greedy line break (port 1:1 from Pretext)
├── LayoutCache.ets          # Two-level LRU cache
├── TgTextLayout.ets         # Facade: prepare(text, style) → layout(prepared, width)
├── ParagraphMeasurer.ets    # [optional] text.Paragraph wrapper for rich text
└── __tests__/
    └── TextEngineTest.ets   # Unit tests
```

---

## 7. Интеграция с проектом

Текущее состояние: пузыри (`TgTextBubbleV2`, `TgMessageBubbleBase`) используют автоматический ArkUI Text layout.

Интеграция text engine:
1. `TgTextLayout.prepare(messageText, style)` при получении сообщения → кэш
2. `TgTextLayout.layout(prepared, bubbleMaxWidth)` при рендере → точная высота
3. `ChatTimelineDataSource` передаёт предрассчитанную высоту в `List` item
4. `List` получает точные размеры → no layout thrashing → 60fps scroll

Токены из `TgUiTokens.ets`:
```typescript
MSG_TEXT_SIZE: 15          → fontSize для TextStyleKey
MSG_TEXT_LINE_HEIGHT: 16   → lineHeight для TextStyleKey
MSG_TEXT_WEIGHT: Regular   → fontWeight для TextStyleKey
```

---

## 8. Открытые вопросы

1. **Intl.Segmenter runtime check** — первый шаг перед написанием кода
2. **Unicode property escapes** (`\p{Emoji}`) — runtime check
3. **text.Paragraph performance** — benchmark layoutSync() vs MeasureUtils
4. **Emoji width accuracy** — MeasureUtils vs real render comparison
5. **HarmonyOS Sans metrics** — baseline, ascent, descent для bubble padding calculation
