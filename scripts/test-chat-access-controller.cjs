// Node >= 24 source witness. No SDK, network, native TDLib or account access.
// Executes the actual controller with a deferred, account-scoped use-case fake.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');

const root = path.resolve(__dirname, '..');
const relative = 'entry/src/main/ets/ui/pages/chat/ChatAccessController.ets';
const tests = [];
const test = (name, run) => tests.push({ name, run });
const turn = () => new Promise(resolve => setImmediate(resolve));
let ChatAccessController;
let Chat;

function channel(overrides = {}) {
  return { id: -10051, type: 'channel', supergroupId: 51,
    order: '0', archiveOrder: '0', canSendBasicMessages: true, ...overrides };
}

function access(overrides = {}) {
  return { groupId: 51, kind: 'supergroup', role: 'member', isMember: true,
    canPostMessages: false, canEditMessages: false, ...overrides };
}

function fixture(listener = () => {}) {
  const calls = [];
  const notices = [];
  const useCase = {
    load(kind, groupId) {
      assert.equal(this, useCase, 'load must retain its scoped use-case receiver');
      let resolve, reject;
      const promise = new Promise((ok, fail) => { resolve = ok; reject = fail; });
      calls.push({ kind, groupId, resolve, reject });
      return promise;
    }
  };
  const controller = new ChatAccessController(useCase, () => {
    notices.push(controller.isUnavailable());
    listener(controller);
  });
  return { controller, useCase, calls, notices };
}

test('idle retry is inert; repeated unknown observes hydrate exactly once without synchronous notify', async () => {
  const f = fixture();
  assert.equal(f.controller.isUnavailable(), false);
  f.controller.retry();
  assert.equal(f.calls.length, 0);
  for (let i = 0; i < 8; i++) f.controller.observe(channel(), access({ role: 'unknown' }));
  assert.equal(f.calls.length, 1);
  assert.equal(f.calls[0].kind, 'supergroup');
  assert.equal(f.calls[0].groupId, 51);
  assert.deepEqual(f.notices, []);
  f.controller.retry();
  assert.equal(f.calls.length, 1, 'retry during pending must not duplicate');
  f.calls[0].resolve();
  await turn();
  assert.deepEqual(f.notices, [false]);
  f.controller.observe(channel());
  f.controller.retry();
  assert.equal(f.calls.length, 1, 'a completed one-shot is not an automatic retry');
});

test('list positions and default permissions never suppress unknown hydration', async () => {
  for (const overrides of [
    { order: '9223372036854775807', canSendBasicMessages: true },
    { archiveOrder: '90000000', canSendBasicMessages: false },
    { order: '0', archiveOrder: '0', canSendBasicMessages: false }
  ]) {
    const f = fixture();
    f.controller.observe(channel(overrides));
    assert.equal(f.calls.length, 1);
    f.calls[0].reject(new Error('offline'));
    await turn();
    f.controller.observe(channel({ order: '123', archiveOrder: '456' }));
    assert.equal(f.calls.length, 1);
    assert.equal(f.controller.isUnavailable(), true);
  }
});

test('failure sticks through store updates; explicit retry clears failure and stays singleflight', async () => {
  const f = fixture();
  f.controller.observe(channel());
  f.calls[0].reject(new Error('offline'));
  await turn();
  assert.deepEqual(f.notices, [true]);
  for (let i = 0; i < 5; i++) f.controller.observe(channel());
  assert.equal(f.calls.length, 1);
  assert.equal(f.controller.isUnavailable(), true);
  assert.deepEqual(f.notices, [true]);
  f.controller.retry();
  f.controller.retry();
  f.controller.observe(channel());
  assert.equal(f.calls.length, 2);
  assert.deepEqual(f.notices, [true, false]);
  f.calls[1].reject(new Error('still offline'));
  await turn();
  assert.deepEqual(f.notices, [true, false, true]);
  f.controller.observe(channel());
  assert.equal(f.calls.length, 2);
  f.controller.retry();
  f.calls[2].resolve();
  await turn();
  assert.deepEqual(f.notices, [true, false, true, false, false]);
  assert.equal(f.controller.isUnavailable(), false);
});

test('successful settle notifies a page that reads matching access from store', async () => {
  let current;
  const f = fixture(controller => controller.observe(channel(), current));
  f.controller.observe(channel(), current);
  current = access({ role: 'administrator', canPostMessages: true });
  f.calls[0].resolve();
  await turn();
  assert.deepEqual(f.notices, [false]);
  assert.equal(f.calls.length, 1);
  assert.equal(f.controller.isUnavailable(), false);
});

for (const [name, next] of [
  ['chat with the same group', channel({ id: -10052 })],
  ['group in the same chat', channel({ supergroupId: 52 })]
]) {
  for (const outcome of ['resolve', 'reject']) {
    test(`switch ${name} ignores late ${outcome}`, async () => {
      const f = fixture();
      f.controller.observe(channel());
      f.controller.observe(next);
      assert.equal(f.calls.length, 2);
      assert.equal(f.calls[1].groupId, next.supergroupId);
      assert.deepEqual(f.notices, []);
      f.calls[0][outcome](new Error('stale'));
      await turn();
      assert.deepEqual(f.notices, []);
      assert.equal(f.controller.isUnavailable(), false);
      f.calls[1].reject(new Error('current'));
      await turn();
      assert.deepEqual(f.notices, [true]);
    });
  }
}

test('A to B to A does not reuse an old callback generation', async () => {
  const f = fixture();
  f.controller.observe(channel());
  f.controller.observe(channel({ id: -10052, supergroupId: 52 }));
  f.controller.observe(channel());
  assert.equal(f.calls.length, 3);
  f.calls[0].reject(new Error('first A'));
  f.calls[1].resolve();
  await turn();
  assert.deepEqual(f.notices, []);
  f.calls[2].reject(new Error('current A'));
  await turn();
  assert.deepEqual(f.notices, [true]);
});

for (const role of ['creator', 'administrator', 'member', 'restricted', 'left', 'banned']) {
  test(`known ${role} suppresses hydration and supersedes pending/failure without notify`, async () => {
    const known = access({ role });
    const initial = fixture();
    initial.controller.observe(channel(), known);
    initial.controller.retry();
    assert.equal(initial.calls.length, 0);
    assert.deepEqual(initial.notices, []);
    for (const outcome of ['resolve', 'reject']) {
      const f = fixture();
      f.controller.observe(channel());
      f.controller.observe(channel(), known);
      f.controller.retry();
      f.calls[0][outcome](new Error('superseded'));
      await turn();
      assert.deepEqual(f.notices, []);
      assert.equal(f.controller.isUnavailable(), false);
      f.controller.observe(channel());
      assert.equal(f.calls.length, 1, 'known update must consume the one-shot for this identity');
    }
    const failed = fixture();
    failed.controller.observe(channel());
    failed.calls[0].reject(new Error('offline'));
    await turn();
    failed.controller.observe(channel(), known);
    failed.controller.retry();
    assert.equal(failed.controller.isUnavailable(), false);
    assert.deepEqual(failed.notices, [true]);
    assert.equal(failed.calls.length, 1);
  });
}

test('only matching kind and group identity count as known access', async () => {
  for (const value of [access({ groupId: 52 }), access({ kind: 'basicGroup' }), access({ role: 'unknown' })]) {
    const f = fixture();
    f.controller.observe(channel(), value);
    assert.equal(f.calls.length, 1);
    f.controller.observe(channel(), value);
    f.calls[0].reject(new Error('not superseded'));
    await turn();
    assert.deepEqual(f.notices, [true]);
    assert.equal(f.controller.isUnavailable(), true);
  }
});

test('private and secret peers do not hydrate; changing type supersedes callbacks', async () => {
  for (const type of ['private', 'secret']) {
    const f = fixture();
    f.controller.observe(channel({ type }));
    f.controller.retry();
    assert.equal(f.calls.length, 0);
    assert.equal(f.controller.isUnavailable(), false);
    f.controller.observe(channel());
    assert.equal(f.calls.length, 1);
    f.controller.observe(channel({ type }));
    f.calls[0].reject(new Error('stale broadcast'));
    await turn();
    assert.deepEqual(f.notices, []);
    assert.equal(f.controller.isUnavailable(), false);
    f.controller.observe(channel());
    assert.equal(f.calls.length, 2);
  }
});

test('ordinary supergroup now hydrates its own missing membership', () => {
  const f = fixture();
  f.controller.observe(channel({ type: 'supergroup' }));
  assert.equal(f.calls.length, 1);
  assert.deepEqual([f.calls[0].kind, f.calls[0].groupId], ['supergroup', 51]);
  f.controller.dispose();
  f.calls[0].resolve();
});

test('invalid group identities are unavailable without requests, notifications or retry loops', () => {
  for (const supergroupId of [0, -1, 0.5, NaN, Infinity, -Infinity, Number.MAX_SAFE_INTEGER + 1, undefined, null, '51']) {
    const f = fixture();
    for (let i = 0; i < 3; i++) {
      f.controller.observe(channel({ supergroupId }));
      assert.equal(f.controller.isUnavailable(), true, `groupId=${supergroupId}`);
      f.controller.retry();
    }
    assert.equal(f.calls.length, 0);
    assert.deepEqual(f.notices, []);
  }
});

test('invalid chat identities never load; negative chat IDs and int53 group IDs are valid', () => {
  for (const id of [0, 0.5, NaN, Infinity, -Infinity, Number.MAX_SAFE_INTEGER + 1, undefined, null, '-10051']) {
    const f = fixture();
    f.controller.observe(channel({ id }));
    f.controller.retry();
    assert.equal(f.controller.isUnavailable(), true, `chatId=${id}`);
    assert.equal(f.calls.length, 0);
    assert.deepEqual(f.notices, []);
  }
  const f = fixture();
  f.controller.observe(channel({ id: -1001234567890, supergroupId: 4503599627370495 }));
  assert.equal(f.calls.length, 1);
  assert.equal(f.calls[0].groupId, 4503599627370495);
  assert.equal(f.controller.isUnavailable(), false);
});

test('invalid identity supersedes pending; correcting the identity starts a fresh one-shot', async () => {
  const f = fixture();
  f.controller.observe(channel());
  f.controller.observe(channel({ supergroupId: 0 }));
  f.calls[0].resolve();
  await turn();
  assert.equal(f.controller.isUnavailable(), true);
  assert.deepEqual(f.notices, []);
  f.controller.observe(channel());
  assert.equal(f.calls.length, 2);
  assert.equal(f.controller.isUnavailable(), false);
});

test('string-shaped invalid identity cannot alias a pending numeric identity or poison its correction', async () => {
  for (const bad of [{ supergroupId: '51' }, { id: '-10051' }]) {
    const f = fixture();
    f.controller.observe(channel());
    f.controller.observe(channel(bad));
    assert.equal(f.controller.isUnavailable(), true);
    f.calls[0].resolve();
    await turn();
    assert.equal(f.controller.isUnavailable(), true, 'late success cannot clear invalid identity');
    assert.deepEqual(f.notices, []);
    f.controller.observe(channel());
    assert.equal(f.calls.length, 2);
    assert.equal(f.calls[1].groupId, 51);
    const initiallyInvalid = fixture();
    initiallyInvalid.controller.observe(channel(bad));
    initiallyInvalid.controller.observe(channel());
    assert.equal(initiallyInvalid.calls.length, 1);
    assert.equal(initiallyInvalid.calls[0].groupId, 51, 'load must receive the corrected numeric group ID');
  }
});

test('empty header observe(new Chat()) cancels pending without permanently disposing the controller', async () => {
  for (const outcome of ['resolve', 'reject']) {
    const f = fixture();
    f.controller.observe(channel());
    f.controller.observe(new Chat());
    f.controller.retry();
    f.calls[0][outcome](new Error('old header'));
    await turn();
    assert.deepEqual(f.notices, []);
    assert.equal(f.controller.isUnavailable(), false);
    f.controller.observe(channel());
    assert.equal(f.calls.length, 2);
    f.calls[1].reject(new Error('new header'));
    await turn();
    assert.deepEqual(f.notices, [true]);
  }
});

test('a new identity does not inherit failure from the previous chat', async () => {
  const f = fixture();
  f.controller.observe(channel());
  f.calls[0].reject(new Error('A'));
  await turn();
  f.controller.observe(channel({ id: -10052, supergroupId: 52 }));
  assert.equal(f.controller.isUnavailable(), false);
  assert.equal(f.calls.length, 2);
  assert.deepEqual(f.notices, [true]);
});

for (const outcome of ['resolve', 'reject']) {
  test(`dispose ignores late ${outcome} and makes observe/retry inert`, async () => {
    const f = fixture();
    f.controller.observe(channel());
    f.controller.dispose();
    f.controller.dispose();
    f.controller.observe(channel({ id: -10052, supergroupId: 52 }));
    f.controller.retry();
    f.calls[0][outcome](new Error('disposed'));
    await turn();
    assert.deepEqual(f.notices, []);
    assert.equal(f.calls.length, 1);
    const idle = fixture();
    idle.controller.dispose();
    idle.controller.observe(channel());
    idle.controller.retry();
    assert.equal(idle.calls.length, 0);
  });
}

test('failure listener can reobserve and retry; retry listener cannot duplicate its own pending attempt', async () => {
  let didRetry = false;
  const f = fixture(controller => {
    controller.observe(channel());
    if (controller.isUnavailable() && !didRetry) {
      didRetry = true;
      controller.retry();
    } else if (!controller.isUnavailable()) {
      controller.retry();
    }
  });
  f.controller.observe(channel());
  f.calls[0].reject(new Error('first'));
  await turn();
  assert.deepEqual(f.notices, [true, false]);
  assert.equal(f.calls.length, 2);
  f.calls[1].reject(new Error('retry'));
  await turn();
  assert.deepEqual(f.notices, [true, false, true]);
  assert.equal(f.controller.isUnavailable(), true);
  assert.equal(f.calls.length, 2);
});

for (const action of ['known', 'switch', 'dispose']) {
  test(`retry listener ${action} supersedes ownership before another request is dispatched`, async () => {
    let armed = false;
    const f = fixture(controller => {
      if (!armed) return;
      if (action === 'known') controller.observe(channel(), access());
      if (action === 'switch') controller.observe(channel({ id: -10052, supergroupId: 52 }));
      if (action === 'dispose') controller.dispose();
    });
    f.controller.observe(channel());
    f.calls[0].reject(new Error('first'));
    await turn();
    armed = true;
    f.controller.retry();
    assert.equal(f.calls.length, action === 'switch' ? 2 : 1);
    assert.deepEqual(f.notices, [true, false]);
    if (action === 'switch') {
      assert.equal(f.calls[1].groupId, 52, 'retry must not leak a request for the old group');
      armed = false;
      f.calls[1].reject(new Error('new chat'));
      await turn();
      assert.deepEqual(f.notices, [true, false, true]);
    }
  });
}

test('a synchronous use-case throw settles asynchronously and can be explicitly retried', async () => {
  const f = fixture();
  f.useCase.load = () => { throw new Error('revoked capability'); };
  assert.doesNotThrow(() => f.controller.observe(channel()));
  assert.deepEqual(f.notices, []);
  await turn();
  assert.deepEqual(f.notices, [true]);
  f.controller.observe(channel());
  await turn();
  assert.deepEqual(f.notices, [true]);
  f.controller.retry();
  assert.deepEqual(f.notices, [true, false]);
  await turn();
  assert.deepEqual(f.notices, [true, false, true]);
});

test('synchronous use-case reentry cannot rehydrate the same identity or revive known access', async () => {
  const f = fixture();
  const originalLoad = f.useCase.load;
  f.useCase.load = function(kind, groupId) {
    const result = originalLoad.call(this, kind, groupId);
    f.controller.observe(channel());
    f.controller.retry();
    f.controller.observe(channel(), access());
    return result;
  };
  f.controller.observe(channel());
  assert.equal(f.calls.length, 1);
  f.calls[0].reject(new Error('already superseded'));
  await turn();
  assert.deepEqual(f.notices, []);
  assert.equal(f.controller.isUnavailable(), false);
});

test('controllers use only their constructor-scoped use case, including retry after disposal of another scope', async () => {
  const a = fixture(), b = fixture();
  a.controller.observe(channel());
  b.controller.observe(channel());
  assert.equal(a.calls.length, 1);
  assert.equal(b.calls.length, 1);
  a.controller.dispose();
  a.calls[0].reject(new Error('old account'));
  b.calls[0].reject(new Error('new account'));
  await turn();
  b.controller.retry();
  assert.equal(a.calls.length, 1);
  assert.equal(b.calls.length, 2);
  assert.deepEqual(a.notices, []);
  assert.deepEqual(b.notices, [true, false]);
});

async function main() {
  assert.ok(fs.existsSync(path.join(root, relative)), 'ChatAccessController source must exist');
  const source = fs.readFileSync(path.join(root, relative), 'utf8');
  const body = source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(body, { mode: 'transform', sourceUrl: relative });
  ChatAccessController = new Function(`${js}\nreturn ChatAccessController;`)();
  const modelPath = 'entry/src/main/ets/core/model/AppState.ets';
  const modelSource = fs.readFileSync(path.join(root, modelPath), 'utf8');
  // Read the real empty-header defaults, without initializing AppState/runtime.
  const chatSource = modelSource.match(/^export class Chat \{[\s\S]*?^\}/m);
  assert.ok(chatSource, 'Chat model source must exist');
  Chat = new Function(`${stripTypeScriptTypes(chatSource[0].replace(/^export /, ''),
    { mode: 'transform', sourceUrl: modelPath })}\nreturn Chat;`)();
  let passed = 0, failed = 0;
  for (const { name, run } of tests) {
    if (process.argv[2] && !name.includes(process.argv[2])) continue;
    try {
      await run();
      console.log('PASS', name);
      passed++;
    } catch (error) {
      if (error.code !== 'ERR_ASSERTION') throw error;
      console.log('FAIL', name, error.message);
      failed++;
    }
  }
  assert.ok(passed + failed > 0, 'No focused tests selected');
  console.log(JSON.stringify({ passed, failed, sources: {
    [relative]: createHash('sha256').update(source).digest('hex'),
    [modelPath + '#Chat']: createHash('sha256').update(chatSource[0]).digest('hex')
  } }));
  process.exitCode = failed > 0 ? 1 : 0;
}

main().catch(error => {
  console.error(error.code === 'ERR_ASSERTION' ? 'FAIL' : 'HARNESS_ERROR', error);
  process.exitCode = error.code === 'ERR_ASSERTION' ? 1 : 2;
});
