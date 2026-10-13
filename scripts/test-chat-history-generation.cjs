#!/usr/bin/env node
// Node >=24. Actual ETS use case, commands, DTO/parser, normalizer, message reducer
// and serial AppStore queue/scopes. Only TDLib transport, hilog and unrelated
// normalizer registrations are fixtures. No build, device, network or account.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const sources = new Map();
const hash = text => createHash('sha256').update(text).digest('hex');
function load(relative, deps = {}) {
  const source = fs.readFileSync(path.join(root, relative), 'utf8');
  sources.set(relative, hash(source));
  const names = [...source.matchAll(/^export\s+(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const code = source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s*\{[^}]*\};?\s*/gm, '').replace(/^export\s+/gm, '');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(code, { mode: 'transform' }) +
    `\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const errors = [];
const hilog = { info() {}, debug() {}, warn() {}, error(...args) { errors.push(args); } };
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
const messageHandlers = load('core/events/normalizers/MessageNormalizer.ets',
  { ...events, ...dto, ...td, ...accessors, hilog });
const normalizer = load('core/events/EventNormalizer.ets', { ...td, ...accessors, ...messageHandlers, hilog,
  registerAuthHandlers() {}, registerChatHandlers() {}, registerUserHandlers() {},
  registerFileHandlers() {}, registerAccentColorHandlers() {}, registerStoryHandlers() {} });
const { LoadChatHistoryUseCase: History, LoadChatHistoryParams: Params } = load(
  'domain/usecases/loadChatHistory.ets', { ...td, ...accessors, ...commands, ...appErrors, ...events, ...normalizer, hilog });
const tick = () => new Promise(resolve => setImmediate(resolve));
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
const response = (ids, chatId = 1) => td.TdObject.fromJSON(JSON.stringify({
  '@type': 'messages', total_count: ids.length,
  messages: ids.map(id => ({ '@type': 'message', id, chat_id: chatId, date: 1,
    sender_id: { '@type': 'messageSenderChat', chat_id: chatId },
    content: { '@type': 'messageText', text: { '@type': 'formattedText', text: String(id), entities: [] } } }))
}));
function fixture() {
  History.resetState();
  const initial = state.createInitialAppState();
  for (const id of [1, 2]) initial.chats.chats.set(id,
    Object.assign(new state.Chat(), { id, lastMessage: Object.assign(new state.ChatLastMessage(), { id: '2000' }) }));
  const store = new AppStore(messagesReducer, initial, false);
  const pending = [];
  const gateway = { send(command) {
    assert.equal(command.type, 'getChatHistory', 'this fixture must only request history');
    const d = deferred();
    pending.push({ command, ...d });
    return d.promise;
  } };
  return { store, pending, gateway, uc: new History(store.createScope(), gateway) };
}
function execute(f, direction = 'initial', fromMessageId = '0', chatId = 1, limit = 4) {
  const params = Object.assign(new Params(), { chatId, direction, fromMessageId, limit });
  return f.uc.execute(params);
}
function aroundUnread(f, chatId = 1) {
  return f.uc.execute(Object.assign(new Params(), {
    chatId, direction: 'initial', reason: 'aroundUnread', fromMessageId: '100', offset: -2, limit: 4
  }));
}
const ids = (f, chatId = 1) => [...(f.store.getState().messages.messages.get(chatId)?.keys() || [])].sort();
function snapshot(f, chatId = 1) {
  return { ids: ids(f, chatId), oldest: f.uc.getOldestMessageId(chatId), newest: f.uc.getNewestMessageId(chatId),
    older: f.uc.canLoadOlderMessages(chatId), newer: f.uc.canLoadNewerMessages(chatId),
    fetched: f.uc.hasHistoryBeenFetched(chatId), retry: f.uc.shouldRetry(chatId),
    loading: f.uc.isLoading(chatId), directions: ['initial', 'older', 'newer'].map(d => f.uc.isLoading(chatId, d)) };
}
async function seed(f, chatId = 1) {
  const count = f.pending.length;
  const p = execute(f, 'initial', '0', chatId);
  assert.equal(f.pending.length, count + 1);
  f.pending[count].resolve(response([970, 980, 990, 1000], chatId));
  assert.equal(await p, true);
}
async function jump(f, target = '100', chatId = 1) {
  const count = f.pending.length;
  const p = f.uc.loadAroundMessage(chatId, target, 4);
  await tick();
  assert.equal(f.pending.length, count + 1, 'jump must issue its own request despite an occupied initial bucket');
  assert.equal(f.pending[count].command.payload.fromMessageId, target);
  assert.equal(f.pending[count].command.payload.offset, -2);
  return { p, request: f.pending[count] };
}
const tests = [];
const test = (name, run) => tests.push({ name, run });

test('oracle: production parser/reducer and same-bucket deduplication', async () => {
  const f = fixture();
  const p = execute(f);
  assert.equal(await execute(f), false);
  assert.equal(f.pending.length, 1);
  f.pending[0].resolve(response([4, 3, 2, 1]));
  assert.equal(await p, true);
  assert.deepEqual(ids(f), ['1', '2', '3', '4']);
  assert.equal(f.store.getState().messages.messages.get(1).get('2').content.text, '2');
  assert.equal(f.uc.getOldestMessageId(1), '1');
  assert.equal(f.uc.getNewestMessageId(1), '4');
  assert.equal(await execute(f), false);
});

test('negative chat ID: real jump resets store before transport, without replacing execute', async () => {
  const f = fixture();
  const chatId = -100123;
  const original = f.store.getState();
  original.messages.messages.set(chatId, new Map([['91', Object.assign(new state.Message(), { id: '91', chatId })]]));
  let calls = 0;
  const uc = new History(f.store.createScope(), { send(command) {
    calls++;
    assert.equal(f.store.getState().messages.messages.has(chatId), false);
    assert.equal(uc.isLoading(chatId, 'initial'), true);
    assert.deepEqual(command.payload, Object.assign(new commands.GetChatHistoryPayload(), {
      chatId, fromMessageId: '950', offset: -20, limit: 40, onlyLocal: false
    }));
    return Promise.resolve(response([940, 950, 960], chatId));
  } });
  assert.equal(await uc.loadAroundMessage(chatId, '950', 40), true);
  assert.equal(calls, 1);
  assert.equal(original.messages.messages.has(chatId), true, 'reset/reducer preserve prior snapshot');
  assert.deepEqual(ids(f, chatId), ['940', '950', '960']);
});

test('jump during initial load issues target request; old finally keeps new loading', async () => {
  const f = fixture();
  const old = execute(f);
  const current = await jump(f);
  const before = snapshot(f);
  f.pending[0].resolve(response([1000, 999, 998, 997]));
  assert.equal(await old, false);
  assert.deepEqual(snapshot(f), before, 'stale initial cannot touch range, retry, edges or loading');
  current.request.resolve(response([110, 100, 90]));
  assert.equal(await current.p, true);
  assert.deepEqual(ids(f), ['100', '110', '90']);
});

for (const direction of ['older', 'newer']) {
  for (const empty of [false, true]) {
    test(`stale ${direction} ${empty ? 'empty' : 'nonempty'} response cannot alter new window`, async () => {
      const f = fixture();
      await seed(f);
      const old = execute(f, direction, '970');
      const oldRequest = f.pending.at(-1);
      const current = await jump(f);
      current.request.resolve(response([110, 100, 90]));
      await current.p;
      const before = snapshot(f);
      oldRequest.resolve(response(empty ? [] : [960, 950, 940]));
      assert.equal(await old, false, 'a superseded response is not a successful history load');
      assert.deepEqual(snapshot(f), before);
    });
  }
}

for (const reject of [false, true]) {
  test(`stale older ${reject ? 'failure' : 'success'} cannot release a new older reservation`, async () => {
    const f = fixture();
    const old = execute(f, 'older', '1000');
    const oldRequest = f.pending.at(-1);
    const current = await jump(f);
    current.request.resolve(response([110, 100, 90]));
    await current.p;
    const next = execute(f, 'older', '90');
    const nextRequest = f.pending.at(-1);
    const before = snapshot(f);
    if (reject) oldRequest.reject(new Error('superseded network failure'));
    else oldRequest.resolve(response([950, 940]));
    assert.equal(await old, false);
    assert.deepEqual(snapshot(f), before);
    nextRequest.resolve(response([90, 80, 70]));
    assert.equal(await next, true);
    assert.equal(f.uc.getOldestMessageId(1), '70');
    assert.equal(f.uc.isLoading(1), false);
  });
}

test('multiple jumps: newest intent wins, reversed completions do not restore old range', async () => {
  const f = fixture();
  const a = await jump(f, '100');
  const b = await jump(f, '500');
  const c = await jump(f, '900');
  b.request.reject(new Error('old jump failed'));
  assert.equal(await b.p, false);
  assert.equal(f.uc.isLoading(1, 'initial'), true);
  c.request.resolve(response([890, 900, 910]));
  assert.equal(await c.p, true);
  const before = snapshot(f);
  a.request.resolve(response([90, 100, 110]));
  assert.equal(await a.p, false);
  assert.deepEqual(snapshot(f), before);
});

test('same-turn jumps fence queued reset and reserve primary before notifying listeners', async () => {
  const f = fixture();
  let resets = 0;
  let listenerLoad;
  f.store.subscribe(() => { resets++; listenerLoad = execute(f); });
  const a = f.uc.loadAroundMessage(1, '100', 4);
  const b = f.uc.loadAroundMessage(1, '500', 4);
  await tick();
  assert.equal(await a, false);
  assert.equal(resets, 1, 'superseded queued reset must not reach reducer/listeners');
  assert.equal(await listenerLoad, false, 'reset listener must not steal the target primary slot');
  assert.equal(f.pending.length, 1);
  assert.equal(f.pending[0].command.payload.fromMessageId, '500');
  f.pending[0].resolve(response([490, 500, 510]));
  assert.equal(await b, true);
});

test('already queued old dispatch is rejected inside the actual serial AppStore queue', async () => {
  const f = fixture();
  const seen = [];
  f.store.subscribe(() => seen.push(ids(f)));
  const old = execute(f, 'older', '1000');
  const gate = deferred();
  // Hold the existing queue boundary, never replace dispatch/processEventBatch.
  f.store.pendingPromise = gate.promise;
  f.pending[0].resolve(response([950, 940]));
  await tick();
  const current = f.uc.loadAroundMessage(1, '100', 4);
  gate.resolve();
  await tick();
  assert.equal(await old, false);
  assert.deepEqual(seen, [[]], 'stale queued batch must not be transiently published before reset');
  assert.equal(f.pending.length, 2);
  f.pending[1].resolve(response([90, 100, 110]));
  assert.equal(await current, true);
});

test('initial top-up and deferred first batch both lose ownership on jump', async () => {
  const f = fixture();
  const old = execute(f, 'initial', '0', 1, 50);
  f.pending[0].resolve(response([1000, 990]));
  await tick();
  assert.equal(f.pending[1].command.payload.fromMessageId, '990', 'real controlled top-up path engaged');
  const topUp = f.pending[1];
  const current = await jump(f);
  current.request.resolve(response([110, 100, 90]));
  await current.p;
  const before = snapshot(f);
  topUp.resolve(response([990, 980]));
  assert.equal(await old, false);
  assert.deepEqual(snapshot(f), before);
  assert.equal(f.pending.length, 3, 'stale top-up loop must not request another page in the new window');
});

test('current initial top-up still fills and publishes its own range', async () => {
  const f = fixture();
  const p = execute(f, 'initial', '0', 1, 4);
  f.pending[0].resolve(response([1000, 990]));
  await tick();
  assert.deepEqual(ids(f), []);
  f.pending[1].resolve(response([990, 980, 970, 960]));
  assert.equal(await p, true);
  assert.deepEqual(ids(f), ['1000', '960', '970', '980', '990']);
  assert.equal(f.uc.isLoading(1), false);
});

test('late aroundUnread correction replaces successful default map and both cursors', async () => {
  const f = fixture();
  await seed(f);
  const p = aroundUnread(f);
  await tick();
  assert.equal(f.pending.length, 2);
  assert.equal(f.pending[1].command.payload.fromMessageId, '100');
  assert.equal(f.pending[1].command.payload.offset, -2);
  f.pending[1].resolve(response([110, 100, 90]));
  assert.equal(await p, true);
  assert.deepEqual(ids(f), ['100', '110', '90'], 'correction must not combine disjoint windows');
  assert.equal(f.uc.getOldestMessageId(1), '90');
  assert.equal(f.uc.getNewestMessageId(1), '110');
  assert.equal(f.uc.canLoadOlderMessages(1), true);
  assert.equal(f.uc.canLoadNewerMessages(1), true);
  assert.equal(f.pending.length, 2, 'aroundUnread is not eligible for default initial top-up');
});

for (const outcome of ['success', 'empty', 'failure']) {
  test(`aroundUnread correction retires outstanding older/newer ${outcome} and owns new buckets`, async () => {
    const f = fixture();
    await seed(f);
    const oldOlder = execute(f, 'older', '970');
    const oldNewer = execute(f, 'newer', '1000');
    const oldRequests = f.pending.slice(1);
    const p = aroundUnread(f);
    await tick();
    assert.equal(f.pending.length, 4);
    assert.equal(await aroundUnread(f), false, 'duplicate pending correction remains deduplicated');
    f.pending[3].resolve(response([110, 100, 90]));
    assert.equal(await p, true);
    const older = execute(f, 'older', '90');
    const newer = execute(f, 'newer', '110');
    assert.equal(f.pending.length, 6, 'new window must have fresh older and newer reservations');
    const before = snapshot(f);
    assert.deepEqual(before.ids, ['100', '110', '90']);
    assert.equal(before.oldest, '90');
    assert.equal(before.newest, '110');
    for (const request of oldRequests) {
      if (outcome === 'failure') request.reject(new Error('retired default page'));
      else request.resolve(response(outcome === 'empty' ? [] : [960, 1000, 1010]));
    }
    assert.deepEqual(await Promise.all([oldOlder, oldNewer]), [false, false]);
    assert.deepEqual(snapshot(f), before, 'old completions cannot change cursors, edges, cache or loading');
    f.pending[4].resolve(response([90, 80]));
    f.pending[5].resolve(response([110, 120]));
    assert.deepEqual(await Promise.all([older, newer]), [true, true]);
    assert.deepEqual(ids(f), ['100', '110', '120', '80', '90']);
    assert.equal(f.uc.getOldestMessageId(1), '80');
    assert.equal(f.uc.getNewestMessageId(1), '120');
    assert.equal(f.uc.isLoading(1), false);
  });
}

test('first aroundUnread preserves initial semantics and pending request deduplication', async () => {
  const f = fixture();
  // A live cached message is not a completed getChatHistory fallback window.
  await f.store.dispatchBatch(normalizer.getEventNormalizer().normalize(response([99])));
  const before = f.store.getState();
  const p = aroundUnread(f);
  assert.equal(f.pending.length, 1, 'first aroundUnread sends without an extra reset continuation');
  assert.equal(await aroundUnread(f), false);
  assert.equal(f.store.getState(), before, 'first aroundUnread must not clear a live cache');
  f.pending[0].resolve(response([90, 100, 110]));
  assert.equal(await p, true);
  assert.deepEqual(ids(f), ['100', '110', '90', '99']);
  assert.equal(f.pending.length, 1, 'short aroundUnread response is not topped up as default');
});

test('pending default still coalesces aroundUnread until the page retries its correction', async () => {
  const f = fixture();
  const first = execute(f);
  assert.equal(await aroundUnread(f), false);
  assert.equal(f.pending.length, 1);
  f.pending[0].resolve(response([970, 980, 990, 1000]));
  assert.equal(await first, true);
  const p = aroundUnread(f);
  await tick();
  f.pending[1].resolve(response([90, 100, 110]));
  assert.equal(await p, true);
  assert.deepEqual(ids(f), ['100', '110', '90']);
});

test('aroundUnread correction fences an older batch already waiting in the store queue', async () => {
  const f = fixture();
  await seed(f);
  const seen = [];
  f.store.subscribe(() => seen.push(ids(f)));
  const older = execute(f, 'older', '970');
  const gate = deferred();
  f.store.pendingPromise = gate.promise;
  f.pending[1].resolve(response([960, 950]));
  await tick();
  const p = aroundUnread(f);
  gate.resolve();
  await tick();
  assert.equal(await older, false);
  assert.deepEqual(seen, [[]], 'old queued batch cannot publish into the replacement window');
  f.pending[2].resolve(response([110, 100, 90]));
  assert.equal(await p, true);
  assert.deepEqual(ids(f), ['100', '110', '90']);
});

test('failed aroundUnread correction clears fetched cache and retries the same target', async () => {
  const f = fixture();
  await seed(f);
  const p = aroundUnread(f);
  await tick();
  f.pending[1].reject(new Error('correction failed'));
  await assert.rejects(p, error => error instanceof appErrors.AppError);
  assert.equal(f.uc.shouldRetry(1), true);
  assert.deepEqual(ids(f), []);
  assert.equal(f.uc.getNewestMessageId(1), '0');
  const retry = aroundUnread(f);
  await tick();
  f.pending[2].resolve(response([110, 100, 90]));
  assert.equal(await retry, true);
  assert.deepEqual(ids(f), ['100', '110', '90']);
});

for (const exhausted of [[], [990]]) {
  test(`initial preserves ${exhausted.length ? 'no-progress' : 'empty'} top-up exhaustion`, async () => {
    const f = fixture();
    const p = execute(f);
    f.pending[0].resolve(response([1000, 990]));
    await tick();
    assert.equal(f.pending[1].command.payload.fromMessageId, '990');
    f.pending[1].resolve(response(exhausted));
    assert.equal(await p, true);
    assert.equal(f.uc.canLoadOlderMessages(1), false, 'initial must not overwrite its top-up exhaustion');
    assert.equal(f.uc.canLoadNewerMessages(1), true);
    assert.equal(f.uc.getOldestMessageId(1), '990');
    assert.equal(f.uc.getNewestMessageId(1), '1000');
    assert.deepEqual(ids(f), ['1000', '990']);
    assert.equal(f.uc.isLoading(1), false);
    assert.equal(f.pending.length, 2);
  });
}

test('initial still publishes its batch and keeps older retryable after top-up failure', async () => {
  const f = fixture();
  const p = execute(f);
  f.pending[0].resolve(response([1000, 990]));
  await tick();
  f.pending[1].reject(new Error('top-up failed'));
  assert.equal(await p, true);
  assert.deepEqual(ids(f), ['1000', '990']);
  assert.equal(f.uc.canLoadOlderMessages(1), true);
  assert.equal(f.uc.isLoading(1), false);
});

test('failed jump clears old fetched cache, releases slot and can retry same target', async () => {
  const f = fixture();
  await seed(f);
  const a = await jump(f);
  assert.equal(f.uc.hasHistoryBeenFetched(1), false, 'fetched belongs to the replaced window');
  a.request.reject(new Error('current network failure'));
  await assert.rejects(a.p, error => error instanceof appErrors.AppError);
  assert.equal(f.uc.isLoading(1), false);
  assert.equal(f.uc.shouldRetry(1), true);
  const b = await jump(f);
  b.request.resolve(response([90, 100, 110]));
  assert.equal(await b.p, true);
  assert.equal(f.uc.shouldRetry(1), false);
});

test('empty jump is retryable without inherited fetched or pagination cache', async () => {
  const f = fixture();
  await seed(f);
  const a = await jump(f);
  a.request.resolve(response([]));
  await a.p;
  assert.equal(f.uc.shouldRetry(1), true);
  assert.equal(f.uc.hasHistoryBeenFetched(1), false);
  assert.equal(f.uc.isLoading(1), false);
  assert.equal(f.uc.getOldestMessageId(1), '0');
  const b = await jump(f);
  b.request.resolve(response([100]));
  assert.equal(await b.p, true);
});

test('same-window older/newer requests remain independent and deduplicated', async () => {
  const f = fixture();
  await seed(f);
  const older = execute(f, 'older', '970');
  const newer = execute(f, 'newer', '1000');
  assert.equal(await execute(f, 'older', '970'), false);
  f.pending[1].resolve(response([970, 960]));
  assert.equal(await older, true);
  assert.equal(f.uc.isLoading(1), true);
  f.pending[2].resolve(response([1000, 1010]));
  assert.equal(await newer, true);
  assert.equal(f.uc.isLoading(1), false);
  assert.equal(f.uc.getOldestMessageId(1), '960');
  assert.equal(f.uc.getNewestMessageId(1), '1010');
});

test('jump ownership is shared across usecase instances but isolated by chat', async () => {
  const f = fixture();
  const old = execute(f);
  const other = execute(f, 'initial', '0', 2);
  f.uc = new History(f.store.createScope(), f.gateway);
  const current = await jump(f);
  f.pending[1].resolve(response([1, 2, 3, 4], 2));
  assert.equal(await other, true);
  const otherWindow = snapshot(f, 2);
  f.pending[0].resolve(response([997, 998, 999, 1000]));
  assert.equal(await old, false);
  current.request.resolve(response([90, 100, 110]));
  await current.p;
  assert.deepEqual(snapshot(f, 2), otherWindow);
});

test('reset rejects old continuations and old-instance jumps without touching new runtime', async () => {
  const f = fixture();
  const oldUc = f.uc;
  const old = execute(f);
  History.resetState();
  f.uc = new History(f.store.createScope(), f.gateway);
  const current = execute(f);
  f.pending[1].resolve(response([7, 8, 9, 10]));
  await current;
  const before = snapshot(f);
  assert.equal(await oldUc.loadAroundMessage(1, '100', 4), false);
  assert.deepEqual(snapshot(f), before, 'old instance must not dispatch a reset before checking lifecycle');
  f.pending[0].resolve(response([997, 998, 999, 1000]));
  assert.equal(await old, false);
  assert.deepEqual(snapshot(f), before);
});

test('reset while request is pending cannot clear a fresh same-chat primary bucket', async () => {
  const f = fixture();
  const old = execute(f);
  History.resetState();
  f.uc = new History(f.store.createScope(), f.gateway);
  const current = execute(f);
  const before = snapshot(f);
  f.pending[0].reject(new Error('old runtime failed'));
  assert.equal(await old, false);
  assert.deepEqual(snapshot(f), before);
  f.pending[1].resolve(response([7, 8, 9, 10]));
  assert.equal(await current, true);
});

test('revoked store scope rejects response, static cursor writes and new jumps', async () => {
  const f = fixture();
  const old = execute(f);
  f.store.invalidateScopes();
  f.pending[0].resolve(response([997, 998, 999, 1000]));
  assert.equal(await old, false);
  assert.equal(await f.uc.loadAroundMessage(1, '100', 4), false);
  assert.equal(f.pending.length, 1);
  assert.deepEqual(ids(f), []);
  const fresh = new History(f.store.createScope(), f.gateway);
  assert.equal(fresh.getNewestMessageId(1), '0');
  assert.equal(fresh.hasHistoryBeenFetched(1), false);
});

test('invalid jump input cannot clear an existing timeline', async () => {
  const f = fixture();
  await seed(f);
  const before = snapshot(f);
  for (const [chatId, messageId] of [[0, '100'], [1, '0'], [1, '']]) {
    assert.equal(await f.uc.loadAroundMessage(chatId, messageId), false);
  }
  assert.deepEqual(snapshot(f), before);
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
      assert.deepEqual(errors.slice(startErrors), [], 'no swallowed parser/store errors');
      console.log(`PASS ${name}`);
    } catch (error) {
      failed++;
      console.log(`FAIL ${name}\n${error.stack}`);
    } finally { clearTimeout(timer); }
  }
  for (const [file, digest] of sources) assert.equal(hash(fs.readFileSync(path.join(root, file), 'utf8')), digest,
    `source changed during witness: ${file}`);
  console.log(`RESULT ${tests.length - failed}/${tests.length} passed; ${failed} failed; ${sources.size} production source hashes stable`);
  console.log('HISTORY_SHA256', sources.get('domain/usecases/loadChatHistory.ets'));
  process.exitCode = failed ? 1 : 0;
}
main().catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
