# TgPhotoSelectionPreview

## Reference and scope

Telegram iOS current `MediaPickerSelectedListNode.swift:881-980` preserves identity in an ordered selection and reorders its selection owner. `TGMediaPickerPhotoStripView.m:78,326` supplies a horizontal thumbnail strip and removal event. These sources inform behavior only; no source code or assets are reused. The registered iOS root has no declared license. This approved HarmonyOS slice uses explicit earlier/later buttons. No iOS screenshot or drag parity is claimed.

HarmonyOS Codelabs `ETSUI/ElectronicAlbum/.../DetailListPage.ets:75` demonstrates native `ImageFit.Contain` with a horizontal strip. Installed SDK `component/image.d.ts:1315,1727,1932,1954,2040` defines `autoResize`, decoded `onComplete` status 1, actual rendered content dimensions and `onError`; `component/common.d.ts` supplies accessibility labels. [Official Image documentation](https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/reference/apis-arkui/arkui-ts/ts-basic-components-image.md) says invalid sources can retain an earlier image, so the large image and its loading/error state are recreated with a URI key. `harmonyos_docs` tools are unavailable in this session.

## Inputs and ownership

- `uris: string[]` is the unique, ordered, parent-owned photo selection.
- `disabled` disables thumbnails, remove and move controls. The composer derives it from sending, photo permission, edit and forward mode.
- `onRemove(uri)` and `onMove(uri, direction)` emit the actual selected URI; direction is -1 or +1. The atom never mutates its input array.
- `onImageLoad(uri, success, width, height, contentWidth, contentHeight)` reports only the current keyed image. Success requires native decode status 1, positive source dimensions and positive actual rendered content dimensions; failure reports zeros. Rendered dimensions come directly from the native event.
- `idPrefix` scopes deterministic UI selectors for demos and SDK fixtures.

The atom owns only the viewed URI. Reordering preserves it; removing it falls back to the first remaining URI. The empty selection renders nothing. Caption, reply, picker, send, route/account guards and pending-file lifetime remain in existing composer owners. Thumbnail ordinal labels and selectors derive the current array index of their stable URI, including after reordering.

## Layout and states

A position label, 160vp contained native image, ordered 48vp thumbnail strip and three 44vp native buttons form a compact accessory. Tokens own dimensions, spacing and color names. Both native Images explicitly use `autoResize(true)` to downsample against their display geometry; no absolute 640px/96px decode budget is claimed. Fixed square `sourceSize` was removed because its native output distorted a rectangular synthetic image. Contain preserves the large image aspect, while Cover intentionally crops thumbnails.

The preview resolves color names from its actual mounted context using `resourceManager.getColorByNameSync`, preserving the active theme without numeric resource IDs or palette literals. Primary text on primary/secondary surfaces supplies position, ordinal, loading and unavailable labels. Native SDK checks resolved opacity/contrast and positive label bounds; screenshots still require actual glyph/pixel review. Missing images remain removable. Move boundaries are disabled. Buttons use up to two lines for narrow layouts; thumbnails expose their current ordinal labels.

The demo matrix covers one, two, three, ten, narrow, disabled, missing-image and empty states. A host supplies original local synthetic images; no private assets or network loads are bundled.

## Integration and acceptance

`TgChatComposerDock` mounts the atom only for pending photos, immediately above `TgComposerInput`, and forwards URI callbacks through its existing binding owner. Existing attachment snippet, clear-all, draft/caption and send behavior remain available.

SDK acceptance uses locally generated original PNGs, sandbox `fileUri.getUriFromPath`, the actual atom and actual ChatScreenSession/ComposerController/canonical Context setters. Native decoded callbacks and strict Driver guards check select, reorder, remove, busy, boundary, error and empty states; a screenshot captures the rendered synthetic image. SDK-free evidence cannot establish native rendering. Real account sends, picker/provider grants and iOS drag parity are outside this witness.
