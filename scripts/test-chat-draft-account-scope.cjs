// Node >=24. Draft integration through the SAME actual page/route/lease/store/
// adapter fixture as the lifecycle suite. Importing that suite runs no tests.
// UI/media, timer clock, native transport and empty-response normalization are
// explicit boundaries. No builds, devices, network or real account.
const assert = require('node:assert/strict');
const { AsyncLocalStorage } = require('node:async_hooks');
const { createFixtureHarness } = require('./test-chat-lifecycle-account-scope.cjs');
const mutant = process.argv.find(arg => arg.startsWith('--mutant='))?.slice(9);
assert.ok(!mutant || mutant === 'account-scope');
const results = [], asynchronousErrors = [], harnessErrors = [];
const context = new AsyncLocalStorage();
let completed = false, harness, planned = 0;
for (const kind of ['unhandledRejection', 'uncaughtException']) process.on(kind, error => {
  asynchronousErrors.push({ test: context.getStore(), kind, error: error?.stack ?? String(error) });
  process.exitCode = 1;
});
async function main() {
  harness = await createFixtureHarness({ draftMutant: Boolean(mutant) });
  const { C, ok } = harness;
  async function fixture(chatId = 7) {
    const f = await harness.fixture(chatId);
    f.p.composerDraftText = 'account A draft'; f.p.replyToMessageId = '0';
    f.store.getState().chats.chats.get(chatId).draftText = '';
    f.store.getState().chats.chats.get(chatId).draftReplyToMessageId = '0';
    f.store.getState().chats.chats.get(chatId).draftCustomEmojiEntities = [];
    f.drafts = () => f.requests.filter(r => r.method === 'setChatDraft');
    return f;
  }
const tick = () => new Promise(resolve => setImmediate(resolve));
const tests = [];
const test = (name, run) => tests.push({ name, run });
function sent(f, chatId = f.p.routeChatId) {
  assert.equal(f.drafts().length, 1, 'actual draft transport must engage exactly once');
  assert.equal(f.drafts()[0].payload.chatId, chatId);
  return f.drafts()[0];
}
for (const id of [7, -100123]) test(`current scope persists draft for chat ${id}`, async () => {
  const f = await fixture(id); f.p.persistDraft(id);
  assert.equal(sent(f, id).payload.text, 'account A draft');
});
for (const revoke of [true, false]) test(`account A/global B blocks draft (scope revoked=${revoke})`, async () => {
  const f = await fixture(); f.switchAccount(revoke); f.p.persistDraft(7);
  assert.equal(f.drafts().length, 0, 'A draft must never reach B gateway');
});
for (const reset of ['invalidateScopes', 'resetState', 'resetStateQueued']) test(`${reset} fences the same runtime scope`, async () => {
  const f = await fixture(); const pending = f.store[reset]();
  f.p.persistDraft(7); await pending;
  assert.equal(f.drafts().length, 0, 'stale scoped store must not fall back to root/global state');
});
for (const boundary of ['missing-owner', 'missing-chat', 'wrong-chat', 'zero-chat', 'runtime-reset', 'edit']) {
  test(`${boundary}: no draft dispatch`, async () => {
    const f = await fixture(); let id = 7;
    if (boundary === 'missing-owner') f.p.accountStore = undefined;
    if (boundary === 'missing-chat') f.store.getState().chats.chats.delete(7);
    if (boundary === 'wrong-chat') id = 8;
    if (boundary === 'zero-chat') id = 0;
    if (boundary === 'runtime-reset') f.runtimeError = true;
    if (boundary === 'edit') f.p.isEditingMessage = true;
    f.p.persistDraft(id); assert.equal(f.drafts().length, 0);
  });
}
for (const boundary of ['lifecycle', 'account', 'owner', 'route', 'draft', 'reply', 'edit']) {
  test(`context changes during gateway acquisition: ${boundary} blocks old snapshot`, async () => {
    const f = await fixture();
    f.onGatewayGet = () => {
      if (boundary === 'lifecycle') f.p.pageLifecycleToken++;
      if (boundary === 'account') f.switchAccount();
      if (boundary === 'owner') f.p.accountStore = f.runtimeStore.createScope();
      if (boundary === 'route') f.p.routeChatId = f.p.activeChatId = 8;
      if (boundary === 'draft') f.p.composerDraftText = 'new draft';
      if (boundary === 'reply') f.p.replyToMessageId = '99';
      if (boundary === 'edit') f.p.isEditingMessage = true;
    };
    f.p.persistDraft(7); assert.equal(f.drafts().length, 0);
  });
}
test('actual Back -> disappear persists old chat after global navigation clear and lifecycle increment', async () => {
  const f = await fixture(-100123); f.p.scheduleDraftDebounce(); f.p.handleBackPress();
  sent(f, -100123);
  assert.equal(f.navigation.activeChatId, 0);
  assert.equal(f.p.pageLifecycleToken, 2);
  assert.equal(f.p.routeActivated, false);
  assert.equal(f.p.accountStore, undefined);
  assert.equal(f.timers.size, 0);
  f.p.persistDraft(-100123); assert.equal(f.drafts().length, 1, 'disposed page cannot save again');
});
test('old page close preserves its draft while global navigation already points to another chat', async () => {
  const f = await fixture(); f.navigation.activeChatId = 8; f.p.aboutToDisappear(); sent(f, 7);
});
test('route-owned close remains valid with cleared local activeChatId', async () => {
  const f = await fixture(); f.p.activeChatId = 0; f.p.aboutToDisappear(); sent(f, 7);
});
test('immutable route lease retains ownership despite cleared mutable route id', async () => {
  const f = await fixture(); f.p.routeChatId = 0; f.p.aboutToDisappear(); sent(f, 7);
});
test('actual close after account reset sends no draft to B', async () => {
  const f = await fixture(); f.switchAccount(); f.p.aboutToDisappear(); assert.equal(f.drafts().length, 0);
});
for (const boundary of ['none', 'lifecycle', 'account', 'edit']) test(`actual debounce callback: ${boundary}`, async () => {
  const f = await fixture(); f.p.scheduleDraftDebounce();
  const callback = f.timers.get(f.p.draftDebounceTimerId); assert.equal(typeof callback, 'function');
  if (boundary === 'lifecycle') f.p.pageLifecycleToken++;
  if (boundary === 'account') f.switchAccount();
  if (boundary === 'edit') f.p.isEditingMessage = true;
  callback();
  if (boundary === 'none') sent(f); else assert.equal(f.drafts().length, 0);
});
test('unchanged draft/reply/entities is a no-op; changed reply still saves', async () => {
  const f = await fixture(), chat = f.store.getState().chats.chats.get(7);
  chat.draftText = f.p.composerDraftText; f.p.persistDraft(7); assert.equal(f.drafts().length, 0);
  f.p.replyToMessageId = '99'; f.p.persistDraft(7); assert.equal(sent(f).payload.replyToMessageId, '99');
});
test('explicit empty clear is retained; empty-to-empty reply difference is a no-op', async () => {
  const f = await fixture(), chat = f.store.getState().chats.chats.get(7);
  chat.draftText = 'stored'; f.p.composerDraftText = '  '; f.p.persistDraft(7);
  assert.equal(sent(f).payload.text, '');
  chat.draftText = ''; f.p.replyToMessageId = '99'; f.p.persistDraft(7); assert.equal(f.drafts().length, 1);
});
test('captured trimmed draft/reply/emoji do not alias later composer edits', async () => {
  const f = await fixture(); f.defer = true;
  f.p.composerDraftText = '  😀 text  '; f.p.replyToMessageId = '99';
  f.p.customEmojiDraftEntities = [new C.CustomEmojiTextEntity(2, 2, '777')];
  f.p.persistDraft(7); const request = sent(f);
  f.p.composerDraftText = 'new draft'; f.p.replyToMessageId = '100'; f.p.customEmojiDraftEntities[0].customEmojiId = '888';
  assert.equal(request.payload.text, '😀 text'); assert.equal(request.payload.replyToMessageId, '99');
  assert.deepEqual(request.payload.customEmojiEntities.map(e => [e.offset, e.length, e.customEmojiId]), [[0, 2, '777']]);
  request.resolve(ok()); await tick(); assert.equal(f.p.composerDraftText, 'new draft');
});

  planned = tests.length;
  for (const { name, run } of tests) {
    const result = { name, passed: false }; results.push(result);
    try { await context.run(name, async () => { await run(); await tick(); await tick(); }); result.passed = true; }
    catch (error) { result.error = error.stack ?? String(error); }
  }
  completed = true;
}
process.once('beforeExit', () => {
  if (!completed) harnessErrors.push('incomplete draft test run');
  for (const failure of asynchronousErrors) {
    const result = results.find(r => r.name === failure.test);
    if (result) { result.passed = false; result.error = [result.error, failure.kind + ': ' + failure.error].filter(Boolean).join('\n'); }
    else harnessErrors.push(failure.kind + ': ' + failure.error);
  }
  const sourceStable = harness?.loadedSourceStable() === true;
  if (!sourceStable) harnessErrors.push('loaded source changed during draft run');
  for (const result of results) {
    if (result.passed) console.log('PASS', result.name);
    else console.error('FAIL', result.name, result.error);
  }
  for (const error of harnessErrors) console.error('HARNESS_ERROR', error);
  const passed = results.filter(r => r.passed).length, failed = results.length - passed;
  const exitCode = harnessErrors.length ? 2 : failed ? 1 : 0;
  console.log(JSON.stringify({ suite: 'chat-draft-account-scope', total: planned, executed: results.length,
    passed, failed, mutant, mutations: harness?.mutations, sourceStable,
    unhandledFailures: asynchronousErrors.length, harnessErrors, exitCode,
    extractedMethods: harness?.methods, methodHashes: harness?.methodHashes,
    executedMethodHashes: harness?.executedMethodHashes, sources: harness?.sources,
    failures: results.filter(r => !r.passed) }));
  process.exitCode = exitCode;
});
main().catch(error => { harnessErrors.push(error.stack ?? String(error)); completed = true; });
