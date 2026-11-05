// D17: a tapped link preview opens its URL, the way iOS does.
// Chain: TgLinkPreviewBubble -> TgTextBubbleV3 -> TgMessageRouter -> TgChatTimelineRow -> bindings ->
// ChatScreenSession.openSharedMediaLink (one resolver for every link origin).

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const etsRoot = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(etsRoot, relative), 'utf8').replaceAll('\r\n', '\n');

function checkChain() {
  const bubble = read('ui/tg_ui/atoms/TgLinkPreviewBubble.ets');
  assert.match(bubble, /@Event onPreviewPress: \(url: string\) => void = \(_: string\) => \{\};/);
  assert.match(bubble, /\.onClick\(\(\): void => \{\n      if \(this\.url\.trim\(\)\.length > 0\) \{\n        this\.onPreviewPress\(this\.url\);/);

  const textBubble = read('ui/tg_ui/atoms/TgTextBubbleV3.ets');
  assert.match(textBubble, /@Event onLinkPreviewPress: \(url: string\) => void/);
  assert.match(textBubble, /onPreviewPress: \(url: string\): void => \{ this\.onLinkPreviewPress\(url\); \}/);

  const router = read('ui/tg_ui/molecules/TgMessageRouter.ets');
  assert.match(router, /@Event onMessageLinkPress: \(url: string\) => void = \(_: string\) => \{\};/);
  assert.match(router, /onLinkPreviewPress: \(url: string\): void => \{\n            this\.onMessageLinkPress\(url\);\n          \},/);

  const row = read('ui/pages/chat/TgChatTimelineRow.ets');
  assert.match(row, /onMessageLinkPress: \(url: string\): void => \{\n          this\.bindings\.openSharedMediaLink\(url\);\n        \},/);

  const ports = read('ui/pages/chat/ChatScreenViewPorts.ets');
  assert.match(ports, /openSharedMediaLink\(value: string\): boolean;/);

  const bindings = read('ui/pages/chat/ChatScreenViewBindings.ets');
  assert.match(bindings, /openSharedMediaLink\(value: string\): boolean \{ return this\.session\.openSharedMediaLink\(value\); \}/);

  // One resolver: the session helper normalizes and opens links through the ability context.
  const session = read('ui/pages/chat/ChatScreenSession.ets');
  assert.match(session, /openSharedMediaLink\(value: string\): boolean \{ return delegateOpenSharedMediaLink\(this, value\); \}/);
  const coordinator = read('ui/pages/chat/ChatSharedMediaActionCoordinator.ets');
  assert.match(coordinator, /context\.openLink\(link\)/);

  console.log('PASS link preview tap contract');
}

checkChain();
