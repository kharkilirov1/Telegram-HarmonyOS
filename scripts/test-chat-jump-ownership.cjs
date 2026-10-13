#!/usr/bin/env node
// Node >=24. Actual page jump/scroll/fulfill/timer methods + actual history,
// commands, TdObject, normalizer, reducer and AppStore. No native/network/build.
// Only transport, viewport/scroll/flash sinks, timers and unrelated normalizers
// are fixtures. No production method is replaced with a copied implementation.
const { readChatSource } = require("./chat-screen-source.cjs");
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const sources = new Map();
const hash = text => createHash('sha256').update(text).digest('hex');
function read(relative) {
  const source = readChatSource(path.join(root, relative), 'utf8');
  sources.set(relative, hash(source));
  return source;
}
function load(relative, deps = {}) {
  const source = read(relative);
  const names = [...source.matchAll(/^export\s+(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const code = source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s*\{[^}]*\};?\s*/gm, '').replace(/^export\s+/gm, '');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(code, { mode: 'transform' }) +
    `\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
function method(source, name) {
  const matches = [...source.matchAll(new RegExp(`^  (?:(?:private|public|async)\\s+)*${name}\\(`, 'gm'))];
  assert.equal(matches.length, 1, `one complete production method: ${name}`);
  const start = matches[0].index, end = source.indexOf('\n  }', start);
  assert.ok(end > start, `class-level closing boundary: ${name}`);
  return source.slice(start, end + 4);
}
const errors = [], warnings = [];
const hilog = { info() {}, debug() {}, warn(...args) { warnings.push(args); }, error(...args) { errors.push(args); } };
const td = load('models/td/common/index.ets');
const accessors = load('core/utils/tdAccessors.ets', td);
const commands = load('core/model/AppCommand.ets');
const appErrors = load('core/model/AppError.ets');
const state = load('core/model/AppState.ets');
const dto = load('core/model/dto/MessageDto.ets', { ...td, ...accessors });
const events = load('core/model/AppEvent.ets', dto);
const clone = load('core/utils/stateClone.ets', state);
const reply = load('core/utils/replyMessageKey.ets');
const { messagesReducer } = load('core/reducers/messagesReducer.ets', { ...state, ...clone, ...reply });
const invariants = load('core/invariants/assertInvariants.ets', { ...state, ...accessors, hilog });
const { AppStore } = load('core/store/AppStore.ets', { ...state, ...invariants, hilog });
const handlers = load('core/events/normalizers/MessageNormalizer.ets', { ...events, ...dto, ...td, ...accessors, hilog });
const normalizer = load('core/events/EventNormalizer.ets', { ...td, ...accessors, ...handlers, hilog,
  registerAuthHandlers() {}, registerChatHandlers() {}, registerUserHandlers() {},
  registerFileHandlers() {}, registerAccentColorHandlers() {}, registerStoryHandlers() {} });
const { LoadChatHistoryUseCase: History } = load('domain/usecases/loadChatHistory.ets',
  { ...td, ...accessors, ...commands, ...appErrors, ...events, ...normalizer, hilog });
const timelineSource = read('ui/pages/chat/ChatTimelineVO.ets');
const predicateStart = timelineSource.indexOf('export function timelineEntryContainsMessageId(');
assert.ok(predicateStart >= 0);
const predicate = timelineSource.slice(predicateStart, timelineSource.indexOf('\n}', predicateStart) + 2);
const timelineEntryContainsMessageId = new Function(stripTypeScriptTypes(predicate.replace(/^export /, ''),
  { mode: 'transform' }) + '; return timelineEntryContainsMessageId;')();
const pagePath = 'ui/pages/chat/TgChatScreenPage.ets';
const pageSource = read(pagePath);
const jumpFields = require('./chat-screen-source.cjs').fieldInitializers(path.join(root, pagePath),
  ['pendingJumpMessageId', 'pendingJumpAttempts', 'jumpRequestToken']);
const pageCode = stripTypeScriptTypes('class Page {\n' + jumpFields + '\n' +
  ['scrollToMessageId', 'jumpToMessageId', 'fulfillPendingJump', 'scheduleLifecycleTask']
    .map(name => method(pageSource, name)).join('\n') + '\n}', { mode: 'transform' });
const tick = () => new Promise(resolve => setImmediate(resolve));
const response = ids => td.TdObject.fromJSON(JSON.stringify({ '@type': 'messages', total_count: ids.length,
  messages: ids.map(id => ({ '@type': 'message', id, chat_id: 1, date: 1,
    sender_id: { '@type': 'messageSenderChat', chat_id: 1 },
    content: { '@type': 'messageText', text: { '@type': 'formattedText', text: String(id), entities: [] } } })) }));
function fixture() {
  History.resetState();
  const initial = state.createInitialAppState();
  initial.chats.chats.set(1, Object.assign(new state.Chat(), { id: 1,
    lastMessage: Object.assign(new state.ChatLastMessage(), { id: '2000' }) }));
  const store = new AppStore(messagesReducer, initial, false);
  const pending = [], timers = [], flashes = [], scrolls = [];
  let entries = [], sharedMediaCompletions = 0;
  const history = new History(store.createScope(), { send(command) {
    assert.equal(command.type, 'getChatHistory');
    return new Promise((resolve, reject) => {
      const request = { command, settled: false,
        resolve(value) { request.settled = true; resolve(value); },
        reject(error) { request.settled = true; reject(error); } };
      pending.push(request);
    });
  } });
  const Page = new Function('hilog', 'DOMAIN', 'TAG', 'timelineEntryContainsMessageId', 'ScrollAlign', 'setTimeout',
    pageCode + '\nreturn Page;')(hilog, 0, 'ChatScreen', timelineEntryContainsMessageId, { CENTER: 'center' },
    (callback, delay) => { timers.push({ callback, delay }); return timers.length; });
  const page = Object.assign(new Page(), { loadChatHistoryUseCase: history, activeChatId: 1, pageLifecycleToken: 1,
    transientTimerIds: new Set(), blockAutoPaginationUntilUserScroll: false,
    dataSource: { totalCount: () => entries.length, getData: index => entries[index] },
    listScroller: { scrollToIndex: (...args) => scrolls.push(args) },
    flashSearchHit: id => flashes.push(id), fulfillPendingSharedMediaAction: () => { sharedMediaCompletions++; } });
  return { page, history, store, pending, timers, flashes, scrolls,
    mediaCompletions: () => sharedMediaCompletions,
    loaded(...ids) { entries = ids.map(id => ({ kind: 'message', message: { messageId: String(id), sourceMessageIds: [String(id)] } })); },
    syncTimeline() { this.loaded(...(store.getState().messages.messages.get(1)?.keys() || [])); },
    fire(index) { assert.equal(timers[index].delay, 16); timers[index].callback(); },
    async drain() { for (const request of pending) if (!request.settled) request.resolve(response([])); await tick(); }
  };
}
async function finish(f, target) {
  const current = f.pending.at(-1);
  assert.equal(current.command.payload.fromMessageId, target);
  current.resolve(response([Number(target) - 10, Number(target), Number(target) + 10]));
  await tick();
  assert.equal(f.page.pendingJumpMessageId, target, 'latest intent survives until viewport fulfillment');
  f.syncTimeline(); f.page.fulfillPendingJump(); f.fire(f.timers.length - 1);
  assert.deepEqual(f.flashes, [target], 'only latest target is highlighted');
  assert.equal(f.page.pendingJumpMessageId, '');
  assert.equal(f.mediaCompletions(), 1);
}
const tests = [];
const test = (name, run) => tests.push({ name, run });
for (const targets of [['100', '500'], ['100', '500', '100']]) {
  test(`same-turn ${targets.join('->')}: stale false cannot clear current intent`, async () => {
    const f = fixture();
    for (const target of targets) f.page.jumpToMessageId(target);
    await tick();
    assert.equal(f.pending.length, 1, 'real history generation suppresses obsolete requests');
    assert.equal(f.page.pendingJumpMessageId, targets.at(-1));
    await finish(f, targets.at(-1));
  });
  for (const reject of [false, true]) {
    test(`inflight ${targets.join('->')}: stale ${reject ? 'reject' : 'resolve'} cannot clear current intent`, async () => {
      const f = fixture();
      for (const target of targets) { f.page.jumpToMessageId(target); await tick(); }
      for (const request of f.pending.slice(0, -1)) {
        if (reject) request.reject(new Error('synthetic superseded transport failure'));
        else request.resolve(response([90, 100, 110]));
      }
      await tick();
      assert.equal(f.page.pendingJumpMessageId, targets.at(-1));
      await finish(f, targets.at(-1));
    });
  }
  test(`accepted rejection then ${targets.join('->')}: stale page catch is fenced`, async () => {
    const f = fixture(), startWarnings = warnings.length;
    f.page.jumpToMessageId(targets[0]); await tick();
    f.pending[0].reject(new Error('synthetic accepted current failure'));
    // History sees rejection while A is still current; B starts before page.catch.
    queueMicrotask(() => { for (const target of targets.slice(1)) f.page.jumpToMessageId(target); });
    await tick();
    assert.ok(warnings.slice(startWarnings).some(args => args[1] === 'LoadChatHistory' &&
      args[2].startsWith('History load failed')), 'real history error branch engaged before supersession');
    assert.equal(f.page.pendingJumpMessageId, targets.at(-1));
    assert.equal(warnings.slice(startWarnings).some(args => args[2].startsWith('Jump failed')), false,
      'stale page.catch cannot report failure for current intent');
    await finish(f, targets.at(-1));
  });
}
test('current success performs actual scroll/flash through delayed fulfillment', async () => {
  const f = fixture(); f.page.jumpToMessageId('500'); await tick();
  await finish(f, '500');
  assert.equal(f.scrolls.length, 1);
  assert.equal(f.scrolls[0][2], 'center');
});
for (const reject of [false, true]) {
  test(`current ${reject ? 'catch' : 'false then'} still clears its own pending intent`, async () => {
    const f = fixture(), startWarnings = warnings.length;
    f.page.jumpToMessageId('100'); await tick();
    if (reject) f.pending[0].reject(new Error('synthetic current failure'));
    else f.pending[0].resolve(undefined);
    await tick();
    assert.equal(f.page.pendingJumpMessageId, '');
    assert.equal(warnings.slice(startWarnings).some(args => args[2].startsWith('Jump failed')), reject);
  });
  test(`lifecycle change fences old ${reject ? 'catch' : 'false then'} independently of jump token`, async () => {
    const f = fixture(), startWarnings = warnings.length;
    f.page.jumpToMessageId('100'); await tick();
    f.page.pageLifecycleToken++;
    f.page.pendingJumpMessageId = 'next-lifecycle-target';
    if (reject) f.pending[0].reject(new Error('synthetic old page failure'));
    else f.pending[0].resolve(undefined);
    await tick();
    assert.equal(f.page.pendingJumpMessageId, 'next-lifecycle-target');
    assert.equal(warnings.slice(startWarnings).some(args => args[2].startsWith('Jump failed')), false);
  });
  test(`loaded B supersedes pending A history before late ${reject ? 'catch' : 'then'} and fulfillment`, async () => {
    const f = fixture(); f.page.jumpToMessageId('100'); await tick();
    f.page.fulfillPendingJump();
    f.loaded('500'); f.page.jumpToMessageId('500');
    await tick();
    assert.equal(f.pending.length, 2, 'loaded B must supersede outstanding A in real history too');
    assert.equal(f.pending.at(-1).command.payload.fromMessageId, '500');
    assert.equal(f.page.pendingJumpMessageId, '500');
    if (reject) f.pending[0].reject(new Error('synthetic old failure'));
    else f.pending[0].resolve(response([90, 100, 110]));
    await tick(); f.loaded('100', '500'); f.fire(0);
    assert.equal(f.timers.length, 1, 'old callback cannot schedule another fulfillment');
    assert.deepEqual(f.flashes, []);
    assert.equal(f.mediaCompletions(), 0);
    await finish(f, '500');
  });
}
test('A->B->A: old 16ms callback cannot fulfill a new same-ID intent', async () => {
  const f = fixture(); f.page.jumpToMessageId('100'); await tick();
  f.page.fulfillPendingJump();
  f.page.jumpToMessageId('500'); f.page.jumpToMessageId('100');
  // Fire synchronously before promise completions: isolate the timer guard.
  f.loaded('100'); f.fire(0);
  assert.equal(f.page.pendingJumpMessageId, '100');
  assert.deepEqual(f.flashes, [], 'same ID does not grant ownership to old timer');
  assert.equal(f.mediaCompletions(), 0);
  await tick();
  f.pending[0].resolve(response([100])); await tick();
  await finish(f, '100');
});
test('A->loaded B->A: fast-path jump also invalidates old same-ID timer', async () => {
  const f = fixture(); f.page.jumpToMessageId('100'); await tick();
  f.page.fulfillPendingJump(); f.loaded('500'); f.page.jumpToMessageId('500');
  f.loaded(); f.page.jumpToMessageId('100');
  f.loaded('100'); f.fire(0);
  assert.equal(f.page.pendingJumpMessageId, '100');
  assert.deepEqual(f.flashes, []);
  assert.equal(f.mediaCompletions(), 0);
  await tick();
  await f.drain();
});
test('loaded target with no pending jump keeps fast path and sends no history request', () => {
  const f = fixture(); f.loaded('500'); f.page.jumpToMessageId('500');
  assert.equal(f.pending.length, 0);
  assert.equal(f.page.pendingJumpMessageId, '');
  assert.deepEqual(f.flashes, ['500']);
});
for (const timing of ['reset-queued', 'inflight']) {
  test(`real loaded-B store survives superseded A ${timing} response`, async () => {
    const f = fixture();
    const seed = f.history.loadAroundMessage(1, '500', 4); await tick();
    f.pending[0].resolve(response([490, 500, 510])); await seed; f.syncTimeline();
    f.page.jumpToMessageId('100');
    if (timing === 'inflight') await tick();
    f.page.jumpToMessageId('500'); await tick();
    assert.equal(f.pending.at(-1).command.payload.fromMessageId, '500', 'actual history window ownership follows B');
    if (timing === 'inflight') {
      assert.equal(f.pending[1].command.payload.fromMessageId, '100');
      f.pending[1].resolve(response([90, 100, 110])); await tick();
    } else {
      assert.equal(f.pending.length, 2, 'queued A reset/send is retired before transport');
    }
    await finish(f, '500');
    assert.deepEqual([...f.store.getState().messages.messages.get(1).keys()].sort(), ['490', '500', '510'],
      'no stale A range can replace the loaded B target');
  });
}
test('lifecycle change fences delayed 16ms fulfillment via real lifecycle scheduler', async () => {
  const f = fixture(); f.page.jumpToMessageId('100'); await tick();
  f.page.fulfillPendingJump(); f.page.pageLifecycleToken++;
  f.page.pendingJumpMessageId = '100'; f.loaded('100'); f.fire(0);
  assert.equal(f.page.pendingJumpMessageId, '100');
  assert.deepEqual(f.flashes, []);
  assert.equal(f.mediaCompletions(), 0);
  await f.drain();
});
async function main() {
  let failed = 0;
  for (const { name, run } of tests) {
    const startErrors = errors.length;
    let timer;
    try {
      await Promise.race([run(), new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error('test did not settle within 1500ms')), 1500);
      })]);
      assert.deepEqual(errors.slice(startErrors), [], 'no swallowed production parser/store errors');
      console.log(`PASS ${name}`);
    } catch (error) { failed++; console.error(`FAIL ${name}\n${error.stack}`); }
    finally { clearTimeout(timer); }
  }
  for (const [file, digest] of sources) assert.equal(hash(readChatSource(path.join(root, file), 'utf8')), digest,
    `source changed during witness; wait for stable dependencies and rerun: ${file}`);
  console.log(`RESULT ${tests.length - failed}/${tests.length} passed; ${failed} failed; ${sources.size} production source hashes stable`);
  console.log('PAGE_SHA256', sources.get(pagePath));
  console.log('HISTORY_SHA256', sources.get('domain/usecases/loadChatHistory.ets'));
  process.exitCode = failed ? 1 : 0;
}
main().catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
