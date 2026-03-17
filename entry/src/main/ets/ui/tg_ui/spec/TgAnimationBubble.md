# TgAnimationBubble — Component Passport

## Purpose
Dedicated bubble for GIF/animation messages. Replaces the previous `TgVideoBubble + hidePlayButton` hack.

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
| No preview, no file | Placeholder with GIF icon |
| Preview, no file | Thumbnail + download icon overlay |
| Downloading | Thumbnail + progress ring + cancel |
| Local file ready | Auto-playing animation (Image component) |

## Layout Rules
- Same sizing logic as TgVideoBubble (aspect-ratio fit)
- No play button overlay (GIF auto-plays)
- Duration badge shows "GIF" label instead of time
- Caption below if present

## Token Mapping
- Reuses VIDEO_BUBBLE_* tokens for sizing
- GIF badge uses VIDEO_BUBBLE_DURATION_* tokens
