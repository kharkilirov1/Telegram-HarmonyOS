// Node >=24. Real ETS serializer, TdObject and gateway send body; no device/network.
// Native/platform logging and gateway lifecycle are test boundaries, not emulated TDLib.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const serializerPath = 'infra/td/serialization/CommandSerializer.ets';
const tdObjectPath = 'models/td/common/index.ets';
const mutant = process.argv.find(arg => arg.startsWith('--mutant='))?.slice(9);
assert.ok(!mutant || ['previous-escape', 'identity', 'td-previous-escape', 'td-identity',
  'td-previous-unescape'].includes(mutant),
  'unknown mutant');
const sources = {};
let mutationEngaged = false;

function load(file, deps = {}) {
  let source = fs.readFileSync(path.join(root, file), 'utf8').replaceAll('\r\n', '\n');
  sources[file] = createHash('sha256').update(source).digest('hex');
  const helperName = file === serializerPath && ['previous-escape', 'identity'].includes(mutant)
    ? 'escapeForJson' : file === tdObjectPath && ['td-previous-escape', 'td-identity'].includes(mutant)
      ? 'escapeJsonString' : undefined;
  if (helperName) {
    const marker = new RegExp(`function ${helperName}\\(str: string\\): string \\{[\\s\\S]*?\\n\\}`);
    assert.ok(marker.test(source), 'escape helper mutation must engage');
    const previous = String.raw`function ${helperName}(str: string): string {
  return str.replace(/\\/g, '\\\\').replace(/"/g, '\\"')
    .replace(/\n/g, '\\n').replace(/\r/g, '\\r').replace(/\t/g, '\\t');
}`;
    source = source.replace(marker, () => mutant.endsWith('identity')
      ? `function ${helperName}(str: string): string { return str; }` : previous);
    mutationEngaged = true;
  }
  if (file === tdObjectPath && mutant === 'td-previous-unescape') {
    const marker = /function unescapeJsonString\(str: string\): string \{[\s\S]*?\n\}/;
    assert.ok(marker.test(source), 'unescape helper mutation must engage');
    const previous = String.raw`function unescapeJsonString(str: string): string {
  return str.replace(/\\n/g, '\n').replace(/\\r/g, '\r').replace(/\\t/g, '\t')
    .replace(/\\"/g, '"').replace(/\\\\/g, '\\')
    .replace(/\\u([0-9a-fA-F]{4})/g, (match: string, hex: string) => String.fromCharCode(Number.parseInt(hex, 16)));
}`;
    source = source.replace(marker, () => previous);
    mutationEngaged = true;
  }
  const names = [...source.matchAll(/^export\s+(?:default\s+)?(?:class|function|const|enum)\s+(\w+)/gm)]
    .map(match => match[1]);
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s+(?:default\s+)?/gm, ''), { mode: 'transform', sourceUrl: file });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}

const hilog = { info() {}, warn() {}, error() {}, debug() {} };
const C = load('core/model/AppCommand.ets');
const { TdObject } = load(tdObjectPath);
const { tdGetText } = load('core/utils/tdAccessors.ets', { TdObject });
const errors = load('core/model/AppError.ets');
const serializer = load(serializerPath, { ...C, TdObject, hilog });
const useCase = load('domain/usecases/sendMessage.ets', { ...C, ...errors, TdObject, hilog });
const nativeCalls = [];
const { TdGatewayImpl } = load('infra/td/gateway/TdGateway.ets', {
  ...errors, TdObject, hilog,
    systemDateTime: { TimeType: { STARTUP: 0 }, getUptime: () => performance.now() },
  tdlib: { send(clientId, json) { nativeCalls.push({ clientId, json }); } }
});
const gateway = TdGatewayImpl.getInstance();
// Bypass only startup, never the actual send implementation or request serialization.
gateway.state = 'ready';
gateway.clientId = 7;

async function gatewayWire(serialized) {
  const before = nativeCalls.length;
  const pending = gateway.send(serialized.method, serialized.params);
  try {
    assert.equal(nativeCalls.length, before + 1, 'actual gateway send must reach native seam');
    assert.equal(nativeCalls.at(-1).clientId, 7);
    return nativeCalls.at(-1).json;
  } finally {
    // Settle transport promises without executing TDLib or a receive loop.
    for (const request of gateway.pendingRequests.values()) {
      clearTimeout(request.timeoutId);
      request.resolve(new TdObject());
    }
    gateway.pendingRequests.clear();
    await pending;
  }
}

function cString(json) {
  // NAPI encodes UTF-8; td_send(client_id, request.c_str()) takes a zero-terminated string.
  const bytes = Buffer.from(json, 'utf8');
  const zero = bytes.indexOf(0);
  return bytes.subarray(0, zero < 0 ? bytes.length : zero).toString('utf8');
}

async function checkWire(command, select, expected) {
  const serialized = serializer.serializeCommand(command);
  const helper = serializer.buildTdlibRequestJson(serialized.method, serialized.params);
  const actual = await gatewayWire(serialized);
  for (const [route, json] of [['request helper', helper], ['gateway/TdObject/native boundary', actual]]) {
    assert.equal(cString(json), json, `${route}: UTF-8/C-string transport must not alter JSON`);
    const parsed = JSON.parse(json);
    assert.equal(parsed['@type'], serialized.method, `${route}: method cannot be injected`);
    assert.equal(parsed.chat_id, command.payload.chatId, `${route}: chat cannot be injected`);
    assert.deepEqual(select(parsed), expected, `${route}: exact field round trip`);
    assert.ok(!Object.hasOwn(parsed, 'injected'), `${route}: no injected sibling`);
  }
}

const tests = [];
const test = (name, run) => tests.push({ name, run });
test('oracle/null twin: JSON.parse rejects raw control, C-string truncates NUL', () => {
  assert.throws(() => JSON.parse('{"text":"a\u0001b"}'), SyntaxError);
  assert.equal(JSON.parse('{"text":"a\\u0001b"}').text, 'a\u0001b');
  assert.equal(cString('before\0after'), 'before');
});

// Includes characters the previous helper already handled: those are negative controls.
for (let code = 0; code < 32; code++) {
  test(`U+${code.toString(16).padStart(4, '0')} in message text`, async () => {
    const text = 'left' + String.fromCharCode(code) + 'right';
    await checkWire(C.createSendMessageCommand(-1001, text), r => r.input_message_content.text.text, text);
  });
}
test('NUL in accepted use-case input reaches gateway without C-string truncation', async () => {
  let wire;
  const sender = new useCase.SendMessageUseCase({ send: async command => {
    wire = await gatewayWire(serializer.serializeCommand(command));
    return TdObject.fromJSON(`{"@type":"message","id":900,"chat_id":${command.payload.chatId}}`);
  } });
  const params = Object.assign(new useCase.SendMessageParams(), { chatId: -1001, text: 'left\0right' });
  await sender.execute(params);
  assert.equal(cString(wire), wire, 'NUL must be escaped before native C-string transport');
  assert.equal(JSON.parse(wire).input_message_content.text.text, params.text);
});

for (const text of ['', 'ordinary', 'quote" slash\\ end\\', '\\u0000 is literal',
  'Русский 中文 العربية', '😀👨‍👩‍👧‍👦', '\u2028\u2029\u0085\u007f', '\ud800', '\udc00']) {
  test(`Unicode/escape control ${JSON.stringify(text)}`, () =>
    checkWire(C.createSendMessageCommand(-1001, text), r => r.input_message_content.text.text, text));
}

for (const text of ['"},"injected":true,"text":"', '\\"},"@type":"logOut","x":"',
  '"}},"chat_id":42,"injected":true,"x":{', '\u2028"},"injected":true,"x":"']) {
  test(`injection-shaped text stays data ${JSON.stringify(text)}`, () =>
    checkWire(C.createSendMessageCommand(-1001, text), r => r.input_message_content.text.text, text));
}

const controls = 'left' + Array.from({ length: 32 }, (_, code) => String.fromCharCode(code)).join('') + 'right';
test('draft text preserves all controls', () => checkWire(C.createSetChatDraftCommand(-1001, controls),
  r => r.draft_message.input_message_text.text.text, controls));
for (const kind of ['photo', 'video', 'document', 'voice']) {
  test(`${kind} file path/caption preserve controls`, () => checkWire(
    C.createSendMediaMessageCommand(-1001, kind, controls, controls, '0', 1, controls),
    r => [r.input_message_content[kind === 'voice' ? 'voice_note' : kind].path,
      r.input_message_content.caption.text,
      ...(kind === 'voice' ? [r.input_message_content.waveform] : [])],
    [controls, controls, ...(kind === 'voice' ? [controls] : [])]));
}
test('imported contact nested strings preserve controls', () => checkWire(
  C.createImportContactsCommand([{ phoneNumber: controls, firstName: controls, lastName: controls }]),
  r => [r.contacts[0].phone_number, r.contacts[0].first_name, r.contacts[0].last_name],
  [controls, controls, controls]));
test('language-code array uses the same escape helper', () => checkWire(
  C.createSearchEmojisCommand('cat', [controls]), r => r.input_language_codes, [controls]));
test('remote sticker ID and emoji preserve controls', () => checkWire(
  C.createSendStickerCommand(-1001, controls, 64, 64, controls),
  r => [r.input_message_content.sticker.id, r.input_message_content.emoji], [controls, controls]));
test('remote animation ID preserves controls', () => checkWire(
  C.createSendAnimationCommand(-1001, controls, 1, 64, 64), r => r.input_message_content.animation.id, controls));
test('primitive helper field preserves controls (not the gateway primitive encoder)', () => {
  const params = new TdObject();
  params.setString('query', controls);
  assert.equal(JSON.parse(serializer.buildTdlibRequestJson('searchChats', params)).query, controls);
});
test('raw int64 nested values stay exact, no parse/stringify of whole requests', async () => {
  const id = '5368324170671202286';
  const command = C.createSendMessageCommand(-1001, '😀', '1048576', [new C.CustomEmojiTextEntity(0, 2, id)]);
  const serialized = serializer.serializeCommand(command);
  for (const json of [serializer.buildTdlibRequestJson(serialized.method, serialized.params),
    await gatewayWire(serialized)]) {
    assert.ok(json.includes('"custom_emoji_id":' + id), 'exact raw int64 token');
    assert.equal(JSON.parse(json).reply_to.message_id, 1048576, 'int53 reply remains numeric');
  }
});

// Sibling encoder: ordinary setString fields bypass CommandSerializer.escapeForJson
// in production. checkWire must reach the real TdGateway.send -> TdObject.toJSON path.
for (let code = 0; code < 32; code++) {
  test(`TdObject U+${code.toString(16).padStart(4, '0')} in production query`, () => {
    const text = 'left' + String.fromCharCode(code) + 'right';
    return checkWire(C.createSearchPublicChatsCommand(text), r => r.query, text);
  });
}
for (const text of ['', 'ordinary', 'quote" slash\\ end\\', '\\u0000 is literal',
  'Русский 中文 العربية', '😀👨‍👩‍👧‍👦', '\u2028\u2029\u0085\u007f', '\ud800', '\udc00',
  'x","injected":true,"probe":"', '\\"},"@type":"logOut","x":"']) {
  test(`TdObject Unicode/injection negative control ${JSON.stringify(text)}`, () =>
    checkWire(C.createSearchPublicChatsCommand(text), r => r.query, text));
}
test('TdObject auth password preserves controls at the native send seam', () => checkWire(
  C.createCheckAuthPasswordCommand(controls), r => r.password, controls));
test('TdObject phone field preserves controls alongside raw settings', () => checkWire(
  C.createSetPhoneNumberCommand(controls),
  r => [r.phone_number, r.settings['@type'], r.settings.allow_flash_call],
  [controls, 'phoneNumberAuthenticationSettings', false]));
test('TdObject title/description preserve controls alongside primitive and raw fields', () => checkWire(
  C.createNewSupergroupChatCommand(controls, false, true, controls, 60, false),
  r => [r.title, r.description, r.is_forum, r.is_channel, r.message_auto_delete_time, r.location, r.for_import],
  [controls, controls, false, true, 60, null, false]));
test('TdObject ordinary result ID preserves controls while int64 remains raw', () => checkWire(
  C.createSendInlineQueryResultCommand(-1001, '9223372036854775807', controls, false),
  r => r.result_id, controls));
test('TdObject leaves raw signed int64 tokens, quoted strings, int53, booleans and nulls unchanged', async () => {
  for (const id of ['9007199254740993', '9223372036854775807', '-9223372036854775808']) {
    const command = C.createSendInlineQueryResultCommand(-9007199254740991, id, id, false);
    const json = await gatewayWire(serializer.serializeCommand(command));
    // Do not inspect int64 via JSON.parse: JS numbers would round these values.
    assert.ok(json.includes('"query_id":' + id + ','), 'exact unquoted int64 token');
    assert.ok(json.includes('"result_id":"' + id + '"'), 'ordinary string stays quoted');
    const wire = JSON.parse(json);
    assert.equal(wire.chat_id, -9007199254740991);
    assert.equal(wire.hide_via_bot, false);
    assert.deepEqual([wire.topic_id, wire.reply_to, wire.options], [null, null, null]);
  }
});

// Incoming decoding is a separate path: use actual getters/accessor, not JSON.parse
// as the implementation under test. The oracle compares exact JS code units.
const incomingTexts = ['ordinary', '\\n', '\n', '\\u0000', '\0', '\\u0041', '\\\\u0000',
  '\\r\\t', '\r\t', 'trailing\\', 'literal \\n versus actual\n',
  String.raw`C:\new\test\root\file`, 'quote" and brackets {[ ]} slash\\', controls,
  'Русский 中文 😀', '\ud800', '\udc00'];
for (const text of incomingTexts) {
  test(`incoming getString/cache/accessor ${JSON.stringify(text)}`, () => {
    const obj = TdObject.fromJSON(JSON.stringify({ text }));
    assert.equal(obj.getString('text'), text, 'first extraction');
    assert.equal(tdGetText(obj), text, 'production accessor and cached value');
    const builder = new TdObject();
    builder.setString('text', text);
    assert.equal(TdObject.fromJSON(builder.toJSON()).getString('text'), text, 'encoder/decoder round trip');
  });
  test(`incoming nested formatted text ${JSON.stringify(text)}`, () => {
    const obj = TdObject.fromJSON(JSON.stringify({ '@type': 'message', content: {
      '@type': 'messageText', text: { '@type': 'formattedText', text, entities: [] }
    } }));
    assert.equal(tdGetText(obj.getObject('content').getObject('text')), text);
  });
  test(`incoming object array ${JSON.stringify(text)}`, () => {
    const messages = TdObject.fromJSON(JSON.stringify({ messages: [
      { text, nested: { text: 'decoy' } }, { text: 'sentinel' }
    ] })).getArray('messages');
    assert.equal(messages.length, 2);
    assert.equal(tdGetText(messages[0]), text);
    assert.equal(tdGetText(messages[1]), 'sentinel');
  });
}
test('incoming primitive string array decodes once without changing exact int64 entries', () => {
  const encoded = incomingTexts.map(text => JSON.stringify(text));
  const json = '{"values":[' + encoded.join(',') + ',9223372036854775807,-9223372036854775808]}';
  assert.deepEqual(TdObject.fromJSON(json).getStringArray('values'),
    [...incomingTexts, '9223372036854775807', '-9223372036854775808']);
});
for (const [literal, expected] of [
  [String.raw`"\n"`, '\n'], [String.raw`"\\n"`, '\\n'],
  [String.raw`"\u0000"`, '\0'], [String.raw`"\\u0000"`, '\\u0000'],
  [String.raw`"\u005cn"`, '\\n'], [String.raw`"\b\f\/"`, '\b\f/'],
  [String.raw`"\ud83d\ude00"`, '😀']
]) {
  test(`incoming independent JSON token oracle ${literal}`, () => {
    assert.equal(JSON.parse(literal), expected, 'known-answer oracle');
    const raw = '{"text":' + literal + ',"id":9223372036854775807,"values":[' + literal + ']}';
    const obj = TdObject.fromJSON(raw);
    assert.equal(tdGetText(obj), expected);
    assert.deepEqual(obj.getStringArray('values'), [expected]);
    assert.equal(obj.getInt64String('id'), '9223372036854775807', 'no parse of the whole object');
  });
}
test('incoming decoder preserves permissive unknown escapes without new exceptions', () => {
  for (const text of [String.raw`\q`, String.raw`\uZZZZ`, String.raw`\u123`]) {
    // Intentionally invalid JSON; preserving legacy tolerance is not validating it.
    assert.equal(TdObject.fromJSON('{"text":"' + text + '"}').getString('text'), text);
  }
});

// Existing device-test bodies run here via a host assertion adapter, not a claimed device run.
let nativeBodiesThroughHost = 0;
load('../../ohosTest/ets/test/CommandSerializer.test.ets', {
  ...C, TdObject, ...serializer,
  describe: (_name, body) => body(),
  it: (name, _flags, body) => { nativeBodiesThroughHost++; test('existing Hypium: ' + name, body); },
  expect: value => ({
    assertEqual: expected => assert.strictEqual(value, expected),
    assertTrue: () => assert.strictEqual(value, true),
    assertFalse: () => assert.strictEqual(value, false)
  })
}).commandSerializerTest();
assert.ok(nativeBodiesThroughHost > 0, 'existing suite must register real bodies');

let complete = false;
(async () => {
  let passed = 0;
  let failed = 0;
  for (const { name, run } of tests) {
    try { await run(); passed++; }
    catch (error) { failed++; console.error('FAIL', name, error.message); }
  }
  assert.ok(!mutant || mutationEngaged);
  console.log(JSON.stringify({ passed, failed, nativeBodiesThroughHost,
    gatewayNativeSeamCalls: nativeCalls.length, mutant, mutationEngaged, sources }));
  complete = true;
  process.exitCode = failed ? 1 : 0;
})().catch(error => { complete = true; console.error('HARNESS_ERROR', error); process.exitCode = 2; });
process.on('beforeExit', () => { if (!complete) process.exitCode = 2; });
