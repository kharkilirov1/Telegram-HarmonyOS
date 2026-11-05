// D25: tapping a location bubble opens the point in a maps application.
// The bubble reports coordinates, the router forwards them, the row turns them into "geo:lat,lon" and the
// message-target owner opens a maps URL through the shared link opener (one opening path).

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const etsRoot = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(etsRoot, relative), 'utf8').replaceAll('\r\n', '\n');

function checkChain() {
  const bubble = read('ui/tg_ui/atoms/TgLocationBubble.ets');
  assert.match(bubble, /@Event onLocationPress: \(latitude: number, longitude: number\) => void =/);
  assert.match(bubble, /\.onClick\(\(\): void => \{\n        this\.onLocationPress\(this\.latitude, this\.longitude\);/);

  const router = read('ui/tg_ui/molecules/TgMessageRouter.ets');
  assert.match(router, /@Event onLocationMessagePress: \(latitude: number, longitude: number\) => void =/);
  assert.match(router, /onLocationPress: \(latitude: number, longitude: number\): void => \{\n          this\.onLocationMessagePress\(latitude, longitude\);/);
  // Both location call sites (plain bubble and meta-pill variant) forward the press.
  const forwards = router.split('onLocationPress: (latitude: number, longitude: number): void =>').length - 1;
  assert.equal(forwards, 2, 'both location bubble call sites forward the press');

  const row = read('ui/pages/chat/TgChatTimelineRow.ets');
  assert.match(row, /onLocationMessagePress: \(latitude: number, longitude: number\): void => \{\n          this\.bindings\.openMessageTarget\('geo:' \+ latitude \+ ',' \+ longitude\);/);

  const actions = read('ui/pages/chat/ChatContactCardActions.ets');
  assert.match(actions, /if \(target\.startsWith\('geo:'\)\) \{/);
  assert.match(actions, /function openGeoPoint\(host: ChatMessageTargetPort, target: string\): boolean \{/);
  assert.match(actions, /const coords = target\.slice\('geo:'\.length\)\.split\(','\);/);
  assert.match(actions, /return host\.openSharedMediaLink\('https:\/\/maps\.google\.com\/\?q=' \+ latitude \+ ',' \+ longitude\);/);

  console.log('PASS location tap contract');
}

checkChain();
