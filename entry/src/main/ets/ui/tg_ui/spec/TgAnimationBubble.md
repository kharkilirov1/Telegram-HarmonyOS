# TgAnimationBubble — Component Passport

## Purpose
Dedicated bubble for GIF/animation messages. Replaces the previous `TgVideoBubble + hidePlayButton` hack.
The atom now owns a small remote/fetching/local status-control state machine, while the parent router owns download/cancel commands.

## Visual Reference
- iOS: `ChatMessageAnimatedStickerItemNode` + `ChatMessageInteractiveMediaNode` (animation branch)
- GIF auto-plays, no play button overlay, loop indicator optional

## Inputs
| Param | Type | Default | Description |
|---|---|---|---|
| thumbnailPath | string/Resource | '' | Preview image before animation loads |
| animationPath | string/Resource | '' | Local file URI when downloaded |
| caption | string | '' | Optional caption text |
| isOutgoing | boolean | false | Outgoing message styling |
| containerWidth | number | token | Parent container width |
| animationWidth | number | 0 | Original animation width |
| animationHeight | number | 0 | Original animation height |
| maxWidthRatio | number | token | Max width ratio |
| noBubbleWrap | boolean | false | Router integration mode |
| useRegularMaxDimensions | boolean | false | Tablet layout mode |
| isDownloadPending | boolean | false | Currently downloading |
| downloadProgress | number | -1 | Download progress 0..1 |

## Events
| Event | Signature | Description |
|---|---|---|
| onAnimationTap | () => void | Tap on animation surface |
| onDownloadToggle | () => void | Request download or cancel |

## State Matrix
| State | Visual |
|---|---|
| No preview, no file | Placeholder with GIF label + download icon overlay |
| Preview, no file | Thumbnail + download icon overlay |
| Downloading determinate | Thumbnail + ring progress + project-owned close icon |
| Downloading indeterminate | Thumbnail/placeholder + loading spinner + project-owned close icon |
| Local file ready | Auto-playing muted looping `TgInlineVideoView` |

## Layout Rules
- Same sizing logic as TgVideoBubble (aspect-ratio fit)
- No play button overlay (GIF auto-plays)
- Duration badge shows "GIF" label instead of time
- Caption below if present
- Center status overlay follows the shared media state contract:
  - remote preview/no local animation -> download icon
  - fetching -> `Progress`/`LoadingProgress` with `ICON_RES_CLOSE`
  - local animation -> no center status overlay
- `onDownloadToggle` is parent-owned: router decides whether the tap means request or cancel.

## Internal helper ownership: `TgInlineVideoView`
`TgInlineVideoView` is treated as a non-public inline renderer owned by this animation/GIF bubble when the local animation file is available.

Parent-owned contract:
1. `TgAnimationBubble` owns aspect-ratio sizing, bubble/no-bubble wrapper mode, GIF badge, caption, download/progress overlays, and tap/download events.
2. The helper receives final `videoWidth` / `videoHeight` plus `animationPath` as `videoPath`; it must not own animation bubble layout, GIF badge, caption, or download state.
3. In this parent, animation playback is always muted looping preview playback: `autoPlay=true`, `loop=true`, `muted=true`, `showControls=false`, `isCircular=false`.
4. The helper may show the provided thumbnail until playback starts and expose an error affordance on playback failure; parent placeholder/download states remain the source of truth when the local animation file is absent.
5. Standalone `TgInlineVideoView` demo/spec coverage is not required for this GIF path while the helper remains non-public; behavior coverage should live in `TgAnimationBubbleDemo` and the future `TgMediaGalleryPage` contract.

## Token Mapping
- Reuses VIDEO_BUBBLE_* tokens for sizing
- GIF badge uses VIDEO_BUBBLE_DURATION_* tokens
- Shared media status:
  - `MEDIA_PROGRESS_COLOR`
  - `MEDIA_PROGRESS_STROKE`
  - `MEDIA_OVERLAY_DARK`
  - `MEDIA_CANCEL_ICON_SIZE`
  - `MEDIA_STATUS_TRANSITION_SCALE`
  - `MEDIA_STATUS_ANIM_DURATION`
  - `ICON_RES_DOWNLOAD`
  - `ICON_RES_CLOSE`

## Demo Coverage
- Placeholder without preview/local file
- Remote preview with download icon
- Indeterminate fetching with spinner + close icon
- Determinate fetching with ring + close icon
- Local outgoing animation preview

## Current Behavior Boundary
- `TgMessageRouter` maps `onDownloadToggle` to `downloadFile` or `cancelDownloadFile` through the shared media cancel path.
- `TgAnimationBubble` only renders visual status state and delegates behavior; it does not send TDLib commands directly.
- Static demo coverage is not manual device/emulator visual acceptance.
