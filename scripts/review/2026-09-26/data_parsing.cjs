/**
 * Audit reproduction for production base dev@2d2f683, reviewed 2026-09-26.
 * These assertions CONFIRM KNOWN DEFECTS; they are not passing acceptance tests.
 * A production fix should make the corresponding assertion fail until this
 * historical audit probe is retired or replaced with a regression test.
 *
 * Run with Node.js 24: node scripts/review/2026-09-26/data_parsing.cjs
 * Executes actual ETS source after removing module syntax and transpiling types.
 * Only hilog is stubbed. This does not compile ArkTS or run HarmonyOS/TDLib.
 */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { stripTypeScriptTypes } = require('node:module');

const repoRoot = path.resolve(__dirname, '../../..');
const sourceRoot = path.join(repoRoot, 'entry/src/main/ets');
const files = [
  'models/td/common/index.ets',
  'core/utils/tdAccessors.ets',
  'core/model/AppCommand.ets',
  'core/model/dto/MessageDto.ets',
  'core/model/dto/ChatDto.ets',
  'infra/td/serialization/CommandSerializer.ets'
];

let source = 'const hilog = {info(){},warn(){},debug(){},error(){}};\n';
for (const [index, file] of files.entries()) {
  let text = fs.readFileSync(path.join(sourceRoot, file), 'utf8');
  text = text.replace(/^import\s+[\s\S]*?from\s+['"][^'"]+['"];?\s*/gm, '');
  text = text.replace(/^export\s+\{[^}]*\};?\s*/gm, '');
  text = text.replace(/\bexport\s+/g, '');
  // Module-local logging constants would collide in the combined host context.
  text = text.replace(/\b(DOMAIN|TAG|DTO_DOMAIN|DTO_TAG)\b/g, name => name + index);
  source += stripTypeScriptTypes(text, { mode: 'transform' }) + '\n';
}

function verifyKnownDefects() {
  let confirmed = 0;
  function report(name, input, output) {
    confirmed++;
    console.log(JSON.stringify({ confirmedDefect: name, input, output }));
  }

  const strings = [
    { input: String.raw`C:\temp`, expected: 'C:\\' + '\t' + 'emp' },
    { input: String.raw`\n`, expected: '\\' + '\n' },
    { input: String.raw`\u0041`, expected: 'A' },
    { input: 'a\bb', expected: String.raw`a\bb` }
  ];
  for (const { input, expected } of strings) {
    const output = TdObject.fromJSON(JSON.stringify({
      '@type': 'formattedText', text: input
    })).getString('text');
    assert.equal(output, expected, 'Known JSON string corruption changed');
    assert.notEqual(output, input, 'This audit case expects the known defect');
    report('incoming-json-string-corruption', input, output);
  }

  for (const codepoint of [0, 8, 12, 27]) {
    const input = 'before' + String.fromCharCode(codepoint) + 'after';
    const command = serializeCommand(createSendMessageCommand(42, input, '0'));
    // Match TdGateway.send's production request assembly, including toJSON().
    const request = new TdObject();
    request.copyFrom(command.params);
    request.setString('@type', command.method);
    request.setString('@extra', 'req_host');
    const json = request.toJSON();
    assert.ok(json.includes(String.fromCharCode(codepoint)), 'Control character was unexpectedly escaped');
    assert.throws(() => JSON.parse(json), { name: 'SyntaxError' });
    report('outgoing-control-U+' + codepoint.toString(16).padStart(4, '0'), input, 'invalid JSON');
  }

  for (const state of ['messageSendingStatePending', 'messageSendingStateFailed']) {
    const raw = {
      '@type': 'message', id: 123, chat_id: 42, date: 1700000000,
      is_outgoing: true,
      sending_state: {
        '@type': state,
        error: { '@type': 'error', code: 400, message: 'failed' }
      },
      content: {
        '@type': 'messageText',
        text: { '@type': 'formattedText', text: 'hello', entities: [] }
      }
    };
    const dto = createMessageDtoFromTd(TdObject.fromJSON(JSON.stringify(raw)));
    assert.equal(dto.id, '123');
    assert.equal(dto.isOutgoing, true);
    assert.equal(dto.isPending, false, 'Known sending-state loss changed');
    // DTO exposes no separate failed state to restore from a full message.
    assert.equal(dto.sendStatus, undefined);
    report('sending-state-discarded', state, { isPending: dto.isPending });
  }

  const locationRaw = {
    '@type': 'messageLocation',
    location: { '@type': 'location', latitude: 1e-7, longitude: -1e-7, horizontal_accuracy: 0 }
  };
  const locationDto = parseMessageContent(TdObject.fromJSON(JSON.stringify(locationRaw)));
  assert.equal(locationDto.locationLatitude, 1, 'Known exponent truncation changed');
  assert.equal(locationDto.locationLongitude, -1, 'Known exponent truncation changed');
  report('scientific-notation-location', locationRaw.location, {
    latitude: locationDto.locationLatitude, longitude: locationDto.locationLongitude
  });

  const rawChat = {
    '@type': 'chat', id: 42,
    type: { '@type': 'chatTypePrivate', user_id: 42 },
    title: 'test', unread_mention_count: 7
  };
  const chat = createChatDtoFromTd(TdObject.fromJSON(JSON.stringify(rawChat)));
  assert.equal(chat.unreadMentionCount, 0, 'Known initial mention-count loss changed');
  report('chat-initial-mentions', 7, chat.unreadMentionCount);

  const nestedBeforeRoot = JSON.stringify({ '@type': 'message', nested: { id: 7 }, id: 42 });
  const nestedId = TdObject.fromJSON(nestedBeforeRoot).getInt64String('id');
  assert.equal(nestedId, '7', 'Known nested-key shadowing changed');
  assert.equal(TdObject.fromJSON(nestedBeforeRoot).getTopLevelInt64String('id'), '42');
  report('nested-id-shadows-root-id', { rootId: 42, nestedId: 7 }, nestedId);

  const missingRoot = JSON.stringify({ '@type': 'message', nested: { id: 7 } });
  const fallbackId = TdObject.fromJSON(missingRoot).getTopLevelInt64String('id');
  assert.equal(fallbackId, '7', 'Known top-level getter fallback changed');
  report('top-level-getter-falls-back-to-nested-id', { rootId: 'absent', nestedId: 7 }, fallbackId);

  assert.equal(confirmed, 14);
  console.log('Confirmed 14 known-defect cases against actual ETS; not an acceptance-test pass.');
}

source += '\n(' + verifyKnownDefects.toString() + ')();\n';
vm.runInNewContext(source, { assert, console }, { filename: 'actual-ets-data-audit.js' });
