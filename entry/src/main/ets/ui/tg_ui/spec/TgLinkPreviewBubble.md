# TgLinkPreviewBubble passport

## Reference evidence

- Current Telegram iOS hierarchy:
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\Chat\ChatMessageWebpageBubbleContentNode\Sources\ChatMessageWebpageBubbleContentNode.swift`
  - `C:\Refs\Telegram\Telegram-iOS-current\submodules\TelegramUI\Components\Chat\ChatMessageAttachedContentNode\Sources\ChatMessageAttachedContentNode.swift`
- TDLib contract: `messageText.link_preview` in `tdlib/td/generate/scheme/td_api.tl`; `web_page` is accepted only as a compatibility fallback for the older local typed model.
- iOS hierarchy maps `websiteName -> accent title`, webpage `title -> semibold subtitle`, and webpage text/description -> body. The attached-content node uses an accent line, 6pt media/text spacing, `14pt` base typography, up to `2` title, `5` subtitle and `12` description lines.
- ArkUI grounding: official `Image.objectFit(ImageFit.Cover)` behavior and `Text.textOverflow({ overflow: TextOverflow.Ellipsis })` together with `maxLines`.

## Inputs

- Identity: `url`, `displayUrl`, `siteName`, `title`, `description`, `author`.
- Media: resolved `photoPath`, immediate `photoMinithumb`.
- Layout flags: `showLargeMedia`, `showMediaAboveDescription`, `isOutgoing`, `availableWidth`.
- Parent order flag `showAboveText` stays in `TgTextBubbleV3`, because it controls the preview relative to the message text rather than the preview's internal layout.

## State matrix

1. text-only preview;
2. small trailing media for article-style previews;
3. large media below description;
4. large media above description;
5. outgoing bubble colors;
6. missing `siteName` fallback to `displayUrl`, then `url`;
7. title fallback to `author`;
8. downloaded photo, thumbnail-only and no-media states.

## Layout contract

- The preview is embedded inside `TgTextBubbleV3`; it does not create a second message bubble.
- Accent rail remains attached to the preview block, not the outer message edge.
- Link-preview messages establish a readable tokenized minimum content width and force message meta onto a separate row so the time/status cannot overlap the preview.
- Small media is the iOS source-defined `54pt` square trailing thumbnail with a `4pt` radius; large media uses the tokenized aspect ratio and bounded height.
- `TextOverflow.Ellipsis` is always paired with `maxLines`.

## Token mapping

All geometry, typography, colors, line limits and media sizing come from `TgUiTokens.LINK_PREVIEW_*`.

## Data path

`MessageDto` (`link_preview`) -> `messagesReducer` -> `MessageContent` -> `ChatTimelineVO` -> `TgChatScreenPage` -> `TgMessageRouter` -> `TgTextBubbleV3` -> `TgLinkPreviewBubble`.

The bounded background media policy downloads only `linkPreviewPhotoThumbFileId`; full preview media remains outside this UI slice.
