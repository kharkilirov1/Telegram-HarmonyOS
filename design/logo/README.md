# Логотип Telegram-HarmonyOS

4 концепта в векторе (SVG), созданы 2026-08-26. Все масштабируются от фавиконки до иконки приложения.

## Варианты

| Файл | Что это | Где использовать |
|---|---|---|
| `logo-appicon-light.svg` | Сквркл с «небесным» градиентом + белый бумажный самолёт | главный кандидат на иконку приложения |
| `logo-appicon-dark.svg` | Тёмно-синий фон, градиентный самолёт, градиентная обводка | тёмная тема / альтернативная иконка |
| `logo-orbit.svg` | Самолёт, прорывающий орбиту (Telegram × HarmonyOS) | нейтральная марка: сплэш, README, watermark |
| `logo-wordmark.svg` | Бейдж + «Telegram / FOR HARMONYOS» | шапка README, обложка релиза |

## Палитра

| Токен | HEX | Роль |
|---|---|---|
| sky | `#37BBFE` | верх градиента (Telegram sky) |
| tg-blue | `#229ED9` | фирменный Telegram blue |
| deep | `#1C8FD6` | низ градиента |
| harmony | `#0A59F7` | HarmonyOS-синий акцент |
| night | `#0D1522` | тёмный фон |
| ink | `#10192B` | текст wordmark |

## Просмотр

Открыть SVG в браузере, VS Code (плагин SVG Preview) или Inkscape.

## Экспорт в PNG

```powershell
# Inkscape
inkscape design/logo/logo-appicon-light.svg -w 512 -o icon-512.png
# ImageMagick
magick design/logo/logo-appicon-light.svg -resize 512x512 icon-512.png
```

## Применение как иконка приложения

Сейчас лончер берёт `AppScope/resources/base/media/app_layered_image.json`
→ `app_icon_background.png` + `app_icon_foreground.png` (шаблон DevEco).

Варианты замены:

1. Экспортировать SVG в PNG и заменить foreground/background — сохранится
   системная маска лончера.
2. Или указать в `AppScope/app.json5` `"icon": "$media:app_icon"` и положить
   свой `app_icon.svg` в `AppScope/resources/base/media/`.

Точные размеры и безопасные поля layered-иконки сверить с актуальной
документацией DevEco (MCP `harmonyos_docs` в сессии создания был недоступен).

## Идеи для итерации

- наклон самолёта (сейчас −12°) и его размер внутри бейджа;
- радиус/толщина орбиты, дополнительные «спутники» на треке;
- название проекта в wordmark (сейчас нейтральное «Telegram for HarmonyOS»).
