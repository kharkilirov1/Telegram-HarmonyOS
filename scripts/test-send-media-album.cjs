#!/usr/bin/env node
// SDK-free execution of actual production classes and actual SDK suite callbacks.
// Explicit gateway/Hypium/hilog fixtures; no native transport, UI, file I/O or SDK.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '..');
const baselineAt = process.argv.indexOf('--baseline-root');
const productRoot = baselineAt >= 0 ? path.resolve(process.argv[baselineAt + 1]) : root;
const expectedRedAt = process.argv.indexOf('--expect-red-case');
const expectedRedCase = expectedRedAt >= 0 ? process.argv[expectedRedAt + 1] : undefined;
const snapshotAt = process.argv.indexOf('--usecase-source');
const usecaseSnapshot = snapshotAt >= 0 ? path.resolve(process.argv[snapshotAt + 1]) : undefined;
assert.ok(usecaseSnapshot === undefined || (expectedRedCase !== undefined && baselineAt < 0),
  'An actual usecase preimage may only be used by an explicit RED witness');
assert.ok(expectedRedCase === undefined || (expectedRedCase.length > 0 && baselineAt < 0));
const sources = new Map();
function read(relative, from = productRoot) {
  const file = path.join(from, relative), text = fs.readFileSync(file, 'utf8');
  sources.set(file, text); return text;
}
function load(relative, dependencies = {}) {
  const text = read(relative === 'entry/src/main/ets/domain/usecases/sendMediaAlbum.ets' && usecaseSnapshot !== undefined
    ? path.relative(productRoot, usecaseSnapshot) : relative);
  const names = [...text.matchAll(/^export\s+(?:class|function|const|enum)\s+(\w+)/gm)].map(match => match[1]);
  const code = text.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s+\{[^}]*\};?\s*/gm, '').replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(code, { mode: 'transform' });
  return new Function(...Object.keys(dependencies), js + '\nreturn {' + names.join(',') + '};')(...Object.values(dependencies));
}
const hilog = { info() {}, warn() {}, error() {}, debug() {} };
const C = load('entry/src/main/ets/core/model/AppCommand.ets');
const td = load('entry/src/main/ets/models/td/common/index.ets');
const serializer = load('entry/src/main/ets/infra/td/serialization/CommandSerializer.ets', { ...C, ...td, hilog });
const tests = [];
function test(name, fn) { tests.push({ name, fn }); }
if (baselineAt >= 0) {
  // A prospective typed request is input data only: execution remains the real
  // baseline serializer. No baseline/album implementation is copied or faked.
  const prospective = new C.AppCommand();
  prospective.type = 'sendMediaAlbum';
  prospective.payload = { chatId: -10071, localPaths: ['/data/first.jpg', '/data/second.jpg'], caption: 'caption', replyToMessageId: '88' };
  test('baseline RED: dispatch must map typed album to actual TDLib sendMessageAlbum', () => {
    assert.equal(serializer.serializeCommand(prospective).method, 'sendMessageAlbum');
  });
  test('baseline RED: wire must contain an ordered array of two inputMessagePhoto contents', () => {
    const serialized = serializer.serializeCommand(prospective);
    const wire = JSON.parse(serializer.buildTdlibRequestJson(serialized.method, serialized.params));
    assert.ok(Array.isArray(wire.input_message_contents), 'album contents must be an array');
    assert.deepEqual(wire.input_message_contents.map(content => content.photo.path), ['/data/first.jpg', '/data/second.jpg']);
  });
} else {
  const errors = load('entry/src/main/ets/core/model/AppError.ets');
  const album = load('entry/src/main/ets/domain/usecases/sendMediaAlbum.ets', { ...C, ...td, ...errors, hilog });
  const expect = value => ({
    assertEqual(expected) { assert.equal(value, expected); },
    assertTrue() { assert.equal(value, true); },
    assertFalse() { assert.equal(value, false); }
  });
  const text = read('entry/src/ohosTest/ets/test/SendMediaAlbum.test.ets', root);
  const js = stripTypeScriptTypes(text.replace(/^import[^\n]*\n/gm, '')
    .replace('export default function', 'function'), { mode: 'transform' });
  const dependencies = { ...C, ...td, ...errors, ...album, ...serializer, describe: (_name, fn) => fn(),
    it: (name, _flags, fn) => test(name, fn), expect };
  new Function(...Object.keys(dependencies), js + '\nreturn sendMediaAlbumTest;')(...Object.values(dependencies))();
  test('actual wire JSON preserves every path and caption byte rather than substring matches', () => {
    const paths = ['/data/用户 "first"\\photo.jpg', '/data/second\tphoto.jpg'];
    const caption = 'Caption\n"quotes"\\ and 🙂';
    const encoded = serializer.serializeCommand(C.createSendMediaAlbumCommand(-10071, paths, caption, '88'));
    const wire = JSON.parse(serializer.buildTdlibRequestJson(encoded.method, encoded.params));
    assert.equal(wire['@type'], 'sendMessageAlbum');
    assert.equal(wire.chat_id, -10071);
    assert.deepEqual(wire.input_message_contents.map(content => content.photo.path), paths);
    assert.deepEqual(wire.input_message_contents.map(content => content.caption.text), [caption, '']);
    assert.ok(wire.input_message_contents.every(content => content['@type'] === 'inputMessagePhoto' && content.show_caption_above_media === false));
    assert.deepEqual(wire.reply_to, { '@type': 'inputMessageReplyToMessage', message_id: 88 });
    assert.equal(wire.topic_id, null); assert.equal(wire.options, null);
  });
  test('non-Error postdispatch rejection remains unknown and dispatches only once', async () => {
    const commands = [], gateway = { send(command) { commands.push(command); return Promise.reject('native status'); } };
    const params = Object.assign(new album.SendMediaAlbumParams(), { chatId: -10071, localPaths: ['/data/one.jpg', '/data/two.jpg'] });
    await assert.rejects(new album.SendMediaAlbumUseCase(gateway).execute(params), error =>
      error instanceof errors.AppError && errors.isWriteOutcomeUnknown(error));
    assert.equal(commands.length, 1);
  });
  const invalidRuntimeInputs = [
    ['null input', () => null],
    ['undefined input', () => undefined],
    ['non-array paths', params => { params.localPaths = '/data/one.jpg'; return params; }],
    ['null path', params => { params.localPaths[1] = null; return params; }],
    ['non-string caption', params => { params.caption = 42; return params; }],
    ['non-string reply', params => { params.replyToMessageId = 88; return params; }]
  ];
  for (const [name, prepare] of invalidRuntimeInputs) {
    test('runtime validation rejects ' + name + ' without dispatch', async () => {
      const commands = [], gateway = { send(command) { commands.push(command); return Promise.resolve(new td.TdObject()); } };
      const params = Object.assign(new album.SendMediaAlbumParams(), { chatId: -10071, localPaths: ['/data/one.jpg', '/data/two.jpg'] });
      await assert.rejects(new album.SendMediaAlbumUseCase(gateway).execute(prepare(params)), error =>
        error instanceof album.SendMediaAlbumError && error.outcomeUnknown === false);
      assert.equal(commands.length, 0);
    });
  }
}
let completed = false;
process.once('beforeExit', () => {
  if (!completed) { console.error('HARNESS_ERROR: incomplete album test run'); process.exitCode = 1; }
});
(async () => {
  const results = [];
  const selected = expectedRedCase === undefined ? tests : tests.filter(test => test.name === expectedRedCase);
  if (expectedRedCase !== undefined) assert.equal(selected.length, 1, 'RED witness must name one actual registered callback');
  for (const { name, fn } of selected) {
    let failure;
    try { await fn(); } catch (error) { failure = error; }
    if (baselineAt >= 0 || expectedRedCase !== undefined) {
      assert.ok(failure instanceof assert.AssertionError, name + ': RED witness must fail a behavioral assertion');
      assert.doesNotMatch(String(failure), /HARNESS_ERROR|TypeError|ReferenceError|SyntaxError/);
      results.push({ name, expectedBaselineFailure: baselineAt >= 0,
        expectedRegressionFailure: expectedRedCase !== undefined, message: failure.message });
    } else {
      if (failure !== undefined) throw failure;
      results.push({ name, passed: true });
    }
  }
  for (const [file, text] of sources) assert.equal(fs.readFileSync(file, 'utf8'), text, 'source changed during probe: ' + file);
  completed = true;
  console.log(JSON.stringify({ suite: 'send-media-album', checks: results.length, passed: results.length, failed: 0,
    baselineRedWitness: baselineAt >= 0, regressionRedWitness: expectedRedCase !== undefined, results,
    sources: Object.fromEntries([...sources].map(([file, text]) => [path.relative(productRoot, file), createHash('sha256').update(text).digest('hex')])),
    scope: { actualProductionClasses: true, actualSDKCallbacks: baselineAt < 0,
      gatewayIsFixture: true, nativeNetworkSends: false, authenticatedFlows: false, deviceActions: false }
  }));
})().catch(error => { completed = true; console.error(error.stack || String(error)); process.exitCode = 1; });
