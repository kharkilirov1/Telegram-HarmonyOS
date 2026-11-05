// D18: a link, e-mail or phone typed inside a message opens on tap.
// Span extends CommonMethod, so the atom can attach onClick per link span; the value is resolved from the
// TDLib entity (textUrl carries the real URL) and travels the same opening path as preview taps.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const etsRoot = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(etsRoot, relative), 'utf8').replaceAll('\r\n', '\n');

function checkChain() {
  const body = read('ui/tg_ui/atoms/TgTextBodyV3.ets');
  // The resolver maps each entity kind to a value the OS can open.
  assert.match(body, /function linkTargetForSpan\(typed: string, entity: TextEntity\): string \{/);
  assert.match(body, /if \(entity\.type === 'url' \|\| entity\.type === 'textUrl'\) \{/);
  assert.match(body, /const explicit = entity\.url !== undefined \? String\(entity\.url\)\.trim\(\) : '';/);
  assert.match(body, /return value\.length > 0 \? 'mailto:' \+ value : '';/);
  assert.match(body, /return digits\.length > 0 \? 'tel:' \+ digits : '';/);
  assert.match(body, /span\.target = linkTargetForSpan\(span\.text, e\);/);
  // Only link spans react, and only when they resolved to something.
  assert.match(body, /@Event onLinkPress: \(target: string\) => void = \(_: string\) => \{\}/);
  assert.match(body, /\.onClick\(\(\): void => \{\n                if \(span\.isLink && span\.target\.length > 0\) \{\n                  this\.onLinkPress\(span\.target\);/);

  const bubble = read('ui/tg_ui/atoms/TgTextBubbleV3.ets');
  assert.match(bubble, /@Event onTextLinkPress: \(target: string\) => void/);
  assert.match(bubble, /onLinkPress: \(target: string\): void => \{ this\.onTextLinkPress\(target\); \}/);

  const router = read('ui/tg_ui/molecules/TgMessageRouter.ets');
  assert.match(router, /onTextLinkPress: \(target: string\): void => \{\n            this\.onMessageLinkPress\(target\);\n          \},/);

  // Same single opening path as preview taps: bindings -> session delegate -> ability context.
  const row = read('ui/pages/chat/TgChatTimelineRow.ets');
  assert.match(row, /onMessageLinkPress: \(url: string\): void => \{\n          this\.bindings\.openMessageTarget\(url\);\n        \},/);
  const bindings = read('ui/pages/chat/ChatScreenViewBindings.ets');
  assert.match(bindings, /openSharedMediaLink\(value: string\): boolean \{ return this\.session\.openSharedMediaLink\(value\); \}/);

  // Spans are render-time only: no entity means no target and no click behaviour.
  assert.ok(!body.includes('linkTargetForSpan(span.text, e);\n            break;\n          default'),
    'only link entities resolve a target');


  // @username mentions resolve inside the app and only fall back to the browser.
  const actions = read('ui/pages/chat/ChatContactCardActions.ets');
  assert.match(actions, /export function openMessageTarget\(host: ChatMessageTargetPort, value: string\): boolean \{/);
  assert.match(actions, /function isTelegramUsernameLink\(target: string\): boolean \{/);
  assert.match(actions, /createResolveUsernameUseCase\(gateway\)\.resolve\(username\)/);
  assert.match(actions, /pushChatScreenRoute\(params, host\.pageStack, getAppCoreRuntime\(\)\.getStore\(\)\)/);
  assert.match(actions, /chatGateway\?: TdGatewayPort;/);
  assert.match(actions, /host\.openSharedMediaLink\(target\);\n    \}\);/, 'fallback opens externally');
  console.log('PASS text link tap contract');
}

checkChain();
