# ArkUI Layout Playbook (Telegram-HarmonyOS)

Status: active baseline  
Date: 2026-02-26  
Scope: global layout rules for `entry/src/main/ets/ui/**` to avoid ad-hoc markup decisions.

---

## 1) Зачем этот playbook

Цель: чтобы при верстке атомов/экранов мы не переучивали ArkUI каждый раз.  
Работаем по фиксированным паттернам + чеклисту, а в официальную документацию идём только при новых/спорных API.

Playbook совместим с замороженным контрактом:
- `docs/ai/MASTER_PLAN_TELEGRAM_UI.md`
- пайплайн: `SPEC → DEMO → ATOM → INTEGRATION`

---

## 2) Канонический выбор контейнера (без догм)

1. **Row / Column** — базовый каркас (предпочтительно по умолчанию).
2. **Stack** — только когда нужен реальный overlay (floating island, badge поверх icon, modal layer).
3. **Flex** — когда нужен контролируемый `shrink/stretch` нескольких sibling-элементов.
4. **RelativeContainer** — когда линейная верстка ведет к чрезмерной вложенности и сложной 2D-геометрии.
5. **List / Grid / Tabs / Swiper** — использовать по назначению как контейнеры контента.

Ключ: **Stack не “плохой”**, он просто не должен подменять обычный page skeleton.

---

## 3) Базовый page skeleton

```ts
Column() {
  Header()

  MainContent()
    .layoutWeight(1)

  Footer()
}
.width('100%')
.height('100%')
```

Правило:
- главный скроллируемый/контентный блок почти всегда получает `layoutWeight(1)`;
- header/footer обычно фиксированы по высоте;
- не использовать фиксированный размер экрана (`360x640`) в production-коде.

---

## 4) `layoutWeight` — что это и где ломают

`layoutWeight` работает внутри **линейных контейнеров** (`Row/Column`) между sibling-элементами.

Использовать:
- для “занять оставшееся пространство”;
- для пропорционального деления пространства в row/column.

Не использовать как “магическое лекарство”:
- если проблема в неверном контейнере/safe-area/overlay-слое, `layoutWeight` это не починит.

---

## 4.1) `height` vs `minHeight` (важный нюанс)

- По умолчанию для текстовых/контентных блоков адаптивность чаще достигается через `minHeight` + constraints.
- **Исключение:** anti-jump кластеры (например правый meta-кластер в chat row), где фиксированная высота строки используется намеренно для геометрической стабильности между состояниями.
- Запрещены массовые рефакторы `height -> minHeight` без проверки no-jump контракта.

---

## 5) Safe Area контракт для проекта

1. Фон/стеклянные слои можно тянуть в системные зоны через:
   - `.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])`
2. Контентные отступы распределяем централизованно:
   - top-inset: через `AppTopBar`/верхний shell-контракт;
   - bottom clearance: через токены (`AppShellTokens.TAB_BAR_CONTENT_SAFE_PADDING` и атомные токены).
3. Не дублировать одновременно несколько независимых top/bottom inset-механик в одном экране.

---

## 6) Списки и производительность (обязательный минимум)

Для list-based экранов:
- `List + LazyForEach`;
- стабильный key (`chatId`, `messageId`), без дорогостоящих ключей из сериализации;
- тяжелые item-компоненты: `@Reusable` + осмысленный `reuseId`;
- обновление состояния при reuse: `aboutToReuse(...)`;
- `cachedCount` настраиваем осознанно, не “на глаз”.

---

## 7) Tabs и overlay-паттерны

- Для root tabs допускается `Stack`, если есть настоящий overlay (например island tab bar).
- При этом основной слой (`Tabs`/контент) остается структурно валидным и растягивается на экран.
- Нельзя смешивать несколько конкурирующих систем нижнего отступа без единого токена.

---

## 8) Anti-patterns (запрещено)

1. “Stack везде” как основной layout engine.
2. Жесткие magic numbers, когда есть токены.
3. Случайные `padding/margin`, не закрепленные в spec/токенах.
4. Отсутствие `layoutWeight(1)` у главного контентного блока там, где он обязан заполнять экран.
5. Дублированные divider-механизмы (`List.divider` + внутренний separator в row одновременно).

---

## 9) Чеклист перед merge любого UI-патча

- [ ] Контейнер выбран по назначению (Row/Column/Stack/Flex/Relative).
- [ ] Main content корректно растягивается (`layoutWeight` где нужно).
- [ ] Safe-area обработан единым способом, без дублирования inset.
- [ ] Все ключевые размеры/цвета/отступы через токены.
- [ ] Для списков соблюдены reuse/keys/perf правила.
- [ ] Визуальные гейты из `MASTER_PLAN_TELEGRAM_UI.md` и `VISUAL_QA_CHECKLIST.md` пройдены.

---

## 10) Когда снова идти в официальную документацию

Открываем доку снова, если:
- используем новый для проекта API/компонент;
- поведение отличается между API level/устройствами;
- есть конфликт между текущим playbook и фактическим runtime-поведением.

Во всех остальных случаях используем этот playbook как дефолтный контракт.

---

## 11) Официальные источники (Huawei)

- Layout overview / выбор контейнера:  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/-V13/arkts-layout-development-overview-V13
- Linear layout и `layoutWeight`:  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/-V14/arkts-layout-development-linear-V14
- Safe area / immersive effects / `expandSafeArea`:  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/-V14/arkts-develop-apply-immersive-effects-V14
- Reusable components / list reuse:
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/-V14/arkts-reusable-V14
- ArkUI lint: предпочтение Row/Column вместо нецелевого Flex:  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/-V14/ide_hp-arkui-use-row-column-to-replace-flex-V14
- ArkUI lint: on-demand loading / `reuseId` в `LazyForEach`:  
  https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide_hp-arkui-load-on-demand
