# Master Plan: Telegram iOS UI → HarmonyOS (ArkUI ArkTS API 22)

> Status: **frozen by user request**  
> Date: **2026-02-25**  
> Priority: this document is the canonical UI migration contract for `tg_ui`.

---

## 0) Главные принципы

- Цель: **high-fidelity UI** (телеграмное ощущение), не “похожее”.
- Правила разработки UI:
  - Работаем **атомами**, не экранами.
  - Для каждого атома: **SPEC → DEMO → ATOM → INTEGRATION**.
  - Все числа/цвета/шрифты только через **tokens**.
  - Никакой “примерной верстки” без demo-матрицы состояний и anti-jump проверок.
  - Legacy UI не удаляем: feature-flag переключает `legacy` ↔ `tg_ui`.

## 1) Артефакты, которые фиксируют контекст (чтобы никто не “плыл”)

### 1.1 `entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets`
Единая таблица токенов:
- colors, typography, spacing, radius, opacity
- размеры row/avatar/badge/meta
- значения placeholder/reserve-width для anti-jump

### 1.2 `entry/src/main/ets/ui/tg_ui/spec/*.md`
“Паспорта компонентов” — обязательны.  
В каждом: iOS refs, props, states, layout rules, token mapping, acceptance checklist.

### 1.3 `entry/src/main/ets/ui/tg_ui/demos/*Demo.ets`
Демо-страницы с матрицами состояний + jump-probe.

### 1.4 `AGENTS.md` в корне
Жёсткие правила для всех ИИ-агентов.

## 2) Roadmap по UI (что именно делаем и в каком порядке)

### Phase A — Foundations (у вас уже почти сделано)
- ✅ Tokens
- ✅ TgIcon
- ✅ TgAvatar
- ✅ TgUnreadBadge
- ✅ TgChatMeta

**Гейт A:** есть демо для каждого, и meta не прыгает.

### Phase B — ChatList MVP (самый важный рывок “не детский рисунок”)

#### Шаг 5: TgChatRow
- `@Reusable + reuseId`
- Avatar + Title(+mute) + Preview + ChatMeta + separator inset
- demo 10+ states + jump-probe

#### Шаг 6: TgChatListScreen/Page
- List virtualization + reuse
- один divider-механизм (или separator в row, или `List.divider`, но не оба)
- интеграция через feature flag в реальный `ChatListPage`

**Гейт B:** tg_ui chatlist визуально лучше legacy на 5–10 реальных чатах + не лагает при скролле.

### Phase C — Chat screen MVP (сложнее, но дальше по инерции)
- Message bubble atoms (incoming/outgoing/reply/media)
- Input panel
- Date separators, unread markers
- Сначала “статик high-fidelity”, потом анимации

### Phase D — Polish
- TopBar glass, TabBar
- Advanced gestures/transitions
- Theme parity, blur/vibrancy аналоги

## 3) Quality Gates (чтобы не было галлюцинаций и “вроде готово”)

Для любого атома/экрана он считается “принятым” только если:
- **No-jump**: геометрия стабильна при смене состояний
- **Ellipsis**: title/preview корректны на длинных строках
- **Tokens only**: нет magic numbers в компонентах
- **Right cluster stable**: meta не влияет на ширину/дыхание левой части
- **Reuse**: в списках только `@Reusable + reuseId` (где нужно)

## 4) Интеграция с ядром (runtime safety)

Контракт:
- UI читает VO/State из store (main thread)
- любая фон-работа через taskpool только DTO (AppStorage трогать нельзя)
- UI-порт не должен менять эти invariants

Итог: `tg_ui` развивается независимо от core/runtime логики.

## 5) Как общаемся и не теряем глобальный контекст

Каждый шаг агента заканчивается:
- ✅ что сделано
- список изменённых файлов
- spec path
- как открыть demo
- (опц.) diff/commit message

Ревью:
- проверка, не расползаются ли токены/геометрия
- ловля скрытых jump’ов
- корректировка следующего шага и гейтов

