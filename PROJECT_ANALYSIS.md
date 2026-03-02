# Анализ проекта Telegram-HarmonyOS

## Общая информация
- **Название**: Telegram-HarmonyOS
- **Описание**: Telegram клиент для HarmonyOS NEXT (API 22+)
- **Архитектура**: Clean Architecture + Redux-like state management
- **Технологии**: ArkTS/ArkUI, TDLib (нативный мост через NAPI)

## Структура проекта

### Основные модули
```
entry/src/main/
├── ets/
│   ├── app/bootstrap/        # AppCoreRuntime - оркестрация пайплайна событий
│   ├── core/                 # события, модель, редьюсеры, store
│   ├── domain/               # селекторы, usecases
│   ├── infra/                # td gateway, threading
│   ├── ui/                   # UI компоненты (страницы, компоненты, контроллеры)
│   └── entryability/         # EntryAbility
├── cpp/
│   ├── tdlib_napi.cpp        # Нативный мост к TDLib
│   └── third_party/tdlib/    # Предварительно собранный TDLib
└── resources/
```

### Архитектура пайплайна событий
```
TDLib (native) → TdGateway → MainThreadDispatcher → EventNormalizer → AppStore → UI
```

## Ключевые особенности

### 1. Многопоточная архитектура
- **TDLib native thread** → сырой JSON
- **MainThreadDispatcher** → доставка в ArkTS обработчики
- **EventNormalizer** → типизированные AppEvent[]
- **AppStore.dispatch()** → редьюсеры → новое состояние
- **UI subscribers** (main thread) → re-render

### 2. UI архитектура
- **Clean Architecture** с четким разделением слоев
- **Redux-like** состояние управления через AppStore
- **Feature-flag** система для плавного перехода на новый UI
- **Token-based** дизайн система через TgUiTokens

### 3. Нативная интеграция TDLib
- **NAPI мост** для взаимодействия с TDLib
- **Thread-safe** обработка событий
- **Гибкая конфигурация** через конфигурационные файлы

## Конфигурация

### Основные конфигурационные файлы
- `oh-package.json5` - зависимости проекта
- `build-profile.json5` - конфигурация сборки
- `module.json5` - конфигурация модуля
- `hvigorfile.ts` - конфигурация сборщика

### Системные требования
- DevEco Studio 5.0+
- HarmonyOS SDK **6.0.2 (API 22)** или совместимый
- TDLib предварительно собранные бинарники для HarmonyOS

## UI/UX подход

### Текущее состояние
Проект находится в фазе миграции с legacy UI на `tg_ui` систему:
- **Phase A**: Foundations (токены, базовые атомы) - почти завершено
- **Phase B**: ChatList MVP - в процессе
- **Phase C**: Chat screen MVP - планируется
- **Phase D**: Polish - планируется

### Принципы разработки UI
1. **Атомный подход** - работа с мелкими компонентами
2. **Tokens-first** - все числа/цвета/шрифты через токены
3. **No magic numbers** - строгое следование дизайн системе
4. **Reusability** - использование `@Reusable` и `reuseId` для производительности

## Безопасность и производительность

### Безопасность
- API credentials загружаются из gitignored файлов
- Логирование без чувствительных данных
- Thread-safe операции с нативным кодом

### Производительность
- **Virtualized lists** с кэшированием
- **Serial dispatch queue** для упорядоченной обработки событий
- **Memory management** с очисткой кэша при нехватке памяти

## CI/CD

### GitHub Actions workflow
- **smoke-static**: статические проверки документации и UI
- **smoke-build-harmony**: реальная сборка на self-hosted Windows HarmonyOS runner

### Скрипты сборки
- `scripts/smoke-build.ps1` - PowerShell скрипт для сборки
- `scripts/smoke-ui-phase0.ps1` - проверки UI Phase 0

## Документация

### Основные документы
- `docs/ai/MASTER_PLAN_TELEGRAM_UI.md` - основной план миграции UI
- `AGENTS.md` - правила для AI агентов
- `README.md` - общая документация проекта

## Статус проекта

### ✅ Завершено
- Базовая архитектура приложения
- Интеграция TDLib через NAPI
- Legacy UI система
- CI/CD пайплайн

### 🔄 В процессе
- Миграция на `tg_ui` систему (Phase B - ChatList MVP)
- Создание атомных компонентов
- Интеграция через feature flags

### 📋 Планируется
- Chat screen MVP (Phase C)
- Polish phase (Phase D)
- Анимации и переходы
- Расширенная тематизация

## Заключение
Проект демонстрирует профессиональный подход к разработке мессенджера на HarmonyOS с:
- Четкой архитектурой
- Модульной структурой
- Безопасной многопоточной обработкой
- Поэтапной миграцией UI
- Комплексной системой тестирования и CI/CD