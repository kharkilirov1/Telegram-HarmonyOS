// Node >=24; execute the real AppStore, state, auth reducer and invariants.
// Only hilog is a host sink. No SDK/build/device, polling, network or account actions.
// Frozen prediction: absent API is RED; epoch callbacks run before invalidation returns,
// once per subscription, after revocation; cancellation/reentry/throws cannot leak into B.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const sources = {};
const hash = source => createHash('sha256').update(source).digest('hex');
function read(relative) {
  const source = fs.readFileSync(path.join(root, relative), 'utf8');
  sources[relative] = hash(source);
  return source;
}
function evaluate(source, relative, deps = {}) {
  const names = [...source.matchAll(/^export\s+(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, ''),
    { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const load = (relative, deps) => evaluate(read(relative), relative, deps);
const A = load('core/model/AppState.ets');
const E = load('core/model/AppEvent.ets');
const clone = load('core/utils/stateClone.ets', A);
const { authReducer } = load('core/reducers/authReducer.ets', { ...A, ...clone });
const td = load('models/td/common/index.ets');
const accessors = load('core/utils/tdAccessors.ets', td);
const storePath = 'core/store/AppStore.ets';
const actualSource = read(storePath);
function fixture(source) {
  const errors = [];
  const hilog = { info() {}, debug() {}, warn() {}, error(...args) { errors.push(args.at(-1)); } };
  const invariants = load('core/invariants/assertInvariants.ets', { ...A, ...accessors, hilog });
  const { AppStore } = evaluate(source, storePath, { ...A, ...invariants, hilog });
  const initial = A.createInitialAppState();
  initial.auth.userId = 101;
  const store = new AppStore(authReducer, initial, false);
  return { store, AppStore, hilog, errors, expectedErrors: [], event: E.createMyUserResolvedEvent };
}
const tests = [
  ['root registration captures current epoch synchronously and only once', async f => {
    const seen = [];
    const unsubscribe = f.store.subscribeScopeInvalidation(() => seen.push('invalidated'));
    assert.equal(typeof unsubscribe, 'function');
    assert.deepEqual(seen, []);
    await f.store.dispatch(f.event(102));
    assert.deepEqual(seen, [], 'ordinary dispatch is not invalidation');
    f.store.invalidateScopes();
    assert.deepEqual(seen, ['invalidated'], 'must run before return, not a microtask');
    f.store.invalidateScopes();
    unsubscribe(); unsubscribe();
    assert.deepEqual(seen, ['invalidated']);
  }],
  ['scope and descendant are revoked before callback without clearing root state', f => {
    const scope = f.store.createScope(), child = scope.createScope();
    const state = f.store.getState(), seen = [];
    let stateCalls = 0;
    f.store.subscribe(() => stateCalls++);
    scope.subscribeScopeInvalidation(() => seen.push([scope.isScopeCurrent(), child.isScopeCurrent()]));
    child.subscribeScopeInvalidation(() => seen.push([child.getState().auth.userId, f.store.getState() === state]));
    f.store.invalidateScopes();
    assert.deepEqual(seen, [[false, false], [0, true]]);
    assert.equal(f.store.getState(), state);
    assert.equal(stateCalls, 0);
    assert.equal(f.store.isScopeCurrent(), true);
  }],
  ['valid scoped invalidation delegates once to the root', f => {
    const scope = f.store.createScope(), calls = [];
    f.store.subscribeScopeInvalidation(() => calls.push('root'));
    scope.subscribeScopeInvalidation(() => calls.push('scope'));
    scope.invalidateScopes();
    assert.deepEqual(calls, ['root', 'scope']);
    scope.invalidateScopes();
    assert.deepEqual(calls, ['root', 'scope']);
  }],
  ['unsubscribe is idempotent before and after notification', f => {
    let calls = 0;
    const off = f.store.subscribeScopeInvalidation(() => calls++);
    off(); off(); f.store.invalidateScopes(); off();
    assert.equal(calls, 0);
    const offNext = f.store.subscribeScopeInvalidation(() => calls++);
    f.store.invalidateScopes(); offNext(); offNext(); f.store.invalidateScopes();
    assert.equal(calls, 1);
  }],
  ['earlier callback cancels later callback in the same snapshot', f => {
    const calls = [];
    let offLater;
    f.store.subscribeScopeInvalidation(() => { calls.push('first'); offLater(); offLater(); });
    offLater = f.store.subscribeScopeInvalidation(() => calls.push('canceled'));
    f.store.subscribeScopeInvalidation(() => calls.push('last'));
    f.store.invalidateScopes();
    assert.deepEqual(calls, ['first', 'last']);
  }],
  ['same listener has independent registration and cancellation handles', f => {
    let calls = 0;
    const listener = () => calls++;
    const off = f.store.subscribeScopeInvalidation(listener);
    f.store.subscribeScopeInvalidation(listener);
    f.store.createScope().subscribeScopeInvalidation(listener);
    off(); f.store.invalidateScopes();
    assert.equal(calls, 2);
  }],
  ['stale registration notifies inline and cannot capture account B', f => {
    const stale = f.store.createScope();
    f.store.invalidateScopes();
    const current = f.store.createScope(), calls = [];
    current.subscribeScopeInvalidation(() => calls.push('B'));
    for (const view of [stale, stale.createScope()]) {
      const off = view.subscribeScopeInvalidation(() => calls.push('stale'));
      assert.equal(calls.at(-1), 'stale', 'stale registration must notify before returning');
      off(); off();
    }
    assert.deepEqual(calls, ['stale', 'stale']);
    stale.invalidateScopes();
    assert.equal(current.isScopeCurrent(), true);
    assert.deepEqual(calls, ['stale', 'stale']);
    f.store.invalidateScopes();
    assert.deepEqual(calls, ['stale', 'stale', 'B']);
  }],
  ['new root and scoped observers during callback belong to new epoch', f => {
    const calls = [];
    let current;
    f.store.subscribeScopeInvalidation(() => {
      calls.push('A'); current = f.store.createScope();
      f.store.subscribeScopeInvalidation(() => calls.push('B-root'));
      current.subscribeScopeInvalidation(() => calls.push('B-scope'));
    });
    f.store.invalidateScopes();
    assert.deepEqual(calls, ['A']);
    assert.equal(current.isScopeCurrent(), true);
    f.store.invalidateScopes();
    assert.deepEqual(calls, ['A', 'B-root', 'B-scope']);
    f.store.invalidateScopes();
    assert.equal(calls.length, 3);
  }],
  ['stale callback may register root observer without capturing stale observer in B', f => {
    const stale = f.store.createScope(); f.store.invalidateScopes();
    const calls = [];
    stale.subscribeScopeInvalidation(() => {
      calls.push('stale'); f.store.subscribeScopeInvalidation(() => calls.push('B'));
    });
    assert.deepEqual(calls, ['stale']);
    f.store.invalidateScopes(); f.store.invalidateScopes();
    assert.deepEqual(calls, ['stale', 'B']);
  }],
  ['callback exceptions are isolated and throwing callbacks stay one-shot', f => {
    const calls = [];
    f.expectedErrors.push('Error: expected invalidation throw');
    f.store.subscribeScopeInvalidation(() => { calls.push('throw'); throw new Error('expected invalidation throw'); });
    f.store.subscribeScopeInvalidation(() => calls.push('healthy'));
    assert.doesNotThrow(() => f.store.invalidateScopes());
    assert.deepEqual(calls, ['throw', 'healthy']);
    f.store.invalidateScopes();
    assert.deepEqual(calls, ['throw', 'healthy']);
  }],
  ['stale callback exceptions are isolated synchronously', f => {
    const stale = f.store.createScope(); f.store.invalidateScopes();
    f.expectedErrors.push('Error: expected stale throw');
    let calls = 0;
    const off = stale.subscribeScopeInvalidation(() => { calls++; throw new Error('expected stale throw'); });
    assert.equal(calls, 1); off(); off(); f.store.invalidateScopes();
    assert.equal(calls, 1);
  }],
  ['error formatting and logging failures cannot interrupt revocation', f => {
    const calls = [];
    f.store.subscribeScopeInvalidation(() => { throw { toString() { throw new Error('format failure'); } }; });
    f.store.subscribeScopeInvalidation(() => calls.push('healthy'));
    assert.doesNotThrow(() => f.store.invalidateScopes());
    assert.deepEqual(calls, ['healthy']);
    const stale = f.store.createScope(); f.store.invalidateScopes();
    f.hilog.error = () => { throw new Error('sink failure'); };
    assert.doesNotThrow(() => stale.subscribeScopeInvalidation(() => { throw new Error('callback failure'); }));
    f.store.subscribeScopeInvalidation(() => { throw new Error('callback failure'); });
    f.store.subscribeScopeInvalidation(() => calls.push('healthy-again'));
    assert.doesNotThrow(() => f.store.invalidateScopes());
    assert.deepEqual(calls, ['healthy', 'healthy-again']);
  }],
  ['recursive invalidation delivers pending observers once before inner return', f => {
    const calls = [];
    let firstCalls = 0;
    f.store.subscribeScopeInvalidation(() => {
      calls.push('A-first');
      if (++firstCalls > 1) return; // Bound a broken consume-after-call implementation.
      f.store.subscribeScopeInvalidation(() => {
        calls.push('B'); f.store.subscribeScopeInvalidation(() => calls.push('C'));
      });
      f.store.invalidateScopes();
      calls.push('inner-return');
    });
    f.store.subscribeScopeInvalidation(() => calls.push('A-later'));
    f.store.invalidateScopes();
    assert.deepEqual(calls, ['A-first', 'A-later', 'B', 'inner-return']);
    f.store.invalidateScopes();
    assert.deepEqual(calls, ['A-first', 'A-later', 'B', 'inner-return', 'C']);
  }],
  ['recursive invalidation respects cancellation of pending old observer', f => {
    const calls = []; let offLater, entered = false;
    f.store.subscribeScopeInvalidation(() => {
      calls.push('A'); if (entered) return; entered = true;
      offLater(); f.store.invalidateScopes();
    });
    offLater = f.store.subscribeScopeInvalidation(() => calls.push('canceled'));
    f.store.invalidateScopes();
    assert.deepEqual(calls, ['A']);
  }],
  ['reentrant invalidation through the revoked scope remains a no-op', f => {
    const stale = f.store.createScope(), calls = [];
    stale.subscribeScopeInvalidation(() => {
      calls.push('A'); f.store.subscribeScopeInvalidation(() => calls.push('B'));
      stale.invalidateScopes();
    });
    f.store.invalidateScopes(); assert.deepEqual(calls, ['A']);
    f.store.invalidateScopes(); assert.deepEqual(calls, ['A', 'B']);
  }],
  ['self unsubscribe and next-epoch cancellation are harmless', f => {
    let off, calls = 0;
    off = f.store.subscribeScopeInvalidation(() => {
      calls++; off(); off();
      const offNext = f.store.subscribeScopeInvalidation(() => calls++);
      offNext(); offNext();
    });
    f.store.invalidateScopes(); f.store.invalidateScopes();
    assert.equal(calls, 1);
  }],
  ['independent roots cannot invalidate or cancel one another', f => {
    const other = new f.AppStore(authReducer, undefined, false), calls = [];
    f.store.subscribeScopeInvalidation(() => calls.push('one'));
    other.subscribeScopeInvalidation(() => calls.push('two'));
    f.store.invalidateScopes(); assert.deepEqual(calls, ['one']);
    other.invalidateScopes(); assert.deepEqual(calls, ['one', 'two']);
  }],
  ['invalidate preserves root subscriptions and removes old scoped subscriptions', async f => {
    let rootCalls = 0, oldCalls = 0, newCalls = 0;
    const old = f.store.createScope();
    f.store.subscribe(() => rootCalls++); old.subscribe(() => oldCalls++);
    f.store.subscribeScopeInvalidation(() => f.store.createScope().subscribe(() => newCalls++));
    f.store.invalidateScopes();
    assert.deepEqual([rootCalls, oldCalls, newCalls], [0, 0, 0]);
    await f.store.dispatch(f.event(202));
    assert.deepEqual([rootCalls, oldCalls, newCalls], [1, 0, 1]);
  }],
  ['revocation drops queued A events but preserves callback-enqueued B events', async f => {
    const old = f.store.createScope(), seen = [], notifications = [];
    f.store.subscribe(state => notifications.push(state.auth.userId));
    const pending = old.dispatchBatch([f.event(301), f.event(302)]);
    let current, accepted;
    f.store.subscribeScopeInvalidation(() => {
      seen.push(old.isScopeCurrent()); current = f.store.createScope();
      accepted = current.dispatch(f.event(401));
    });
    f.store.invalidateScopes();
    assert.deepEqual(seen, [false]);
    await pending; await accepted;
    assert.equal(current.getState().auth.userId, 401);
    assert.deepEqual(notifications, [401]);
    await old.dispatch(f.event(999));
    assert.deepEqual(notifications, [401]);
  }],
  ['sync reset invalidates before state clear and notifies state listeners normally', f => {
    const calls = [];
    f.store.subscribe(state => calls.push(['state', state.auth.userId]));
    f.store.subscribeScopeInvalidation(() => calls.push(['invalidate', f.store.getState().auth.userId]));
    f.store.resetState();
    assert.deepEqual(calls, [['invalidate', 101], ['state', 0]]);
  }],
  ['queued reset invalidates inline but clears on existing queue only once', async f => {
    const calls = [];
    f.store.subscribe(state => calls.push(['state', state.auth.userId]));
    const pending = f.store.dispatch(f.event(202));
    f.store.subscribeScopeInvalidation(() => calls.push(['invalidate', f.store.getState().auth.userId]));
    const reset = f.store.resetStateQueued();
    assert.deepEqual(calls, [['invalidate', 101]]);
    const current = f.store.createScope();
    current.subscribeScopeInvalidation(() => calls.push(['B', 0]));
    await pending; await reset;
    assert.deepEqual(calls, [['invalidate', 101], ['state', 0]]);
    assert.equal(current.isScopeCurrent(), true);
    f.store.invalidateScopes();
    assert.deepEqual(calls.at(-1), ['B', 0]);
  }],
  ['stale resets neither clear B state nor notify B observers', async f => {
    const stale = f.store.createScope(); f.store.invalidateScopes();
    let calls = 0; f.store.subscribeScopeInvalidation(() => calls++);
    await f.store.dispatch(f.event(202));
    stale.resetState(); await stale.resetStateQueued();
    assert.equal(f.store.getState().auth.userId, 202); assert.equal(calls, 0);
    f.store.invalidateScopes(); assert.equal(calls, 1);
  }],
  ['invalidation during state notification stops the old notification snapshot', async f => {
    const old = f.store.createScope(), calls = [];
    f.store.subscribe(() => { calls.push('state-first'); f.store.invalidateScopes(); });
    f.store.subscribe(() => calls.push('state-later'));
    old.subscribe(() => calls.push('old-state'));
    old.subscribeScopeInvalidation(() => calls.push('invalidated'));
    await f.store.dispatch(f.event(202));
    assert.deepEqual(calls, ['state-first', 'invalidated']);
  }]
];
async function runSuite(source = actualSource, verbose = true) {
  const failures = [];
  for (const [name, run] of tests) {
    const f = fixture(source);
    try {
      await run(f);
      assert.deepEqual(f.errors, f.expectedErrors, 'unexpected swallowed callback/reducer assertions');
      if (verbose) console.log('PASS', name);
    } catch (error) {
      failures.push({ name, error: error.stack });
      if (verbose) console.log('FAIL', name, error.stack);
    }
  }
  return { passed: tests.length - failures.length, failed: failures.length, failures };
}
function replaceOnce(source, before, after) {
  assert.equal(source.split(before).length - 1, 1, `mutation must engage exactly once: ${before}`);
  return source.replace(before, after);
}
async function negativeControls() {
  const consume = 'if (!this.scopeInvalidationListeners.delete(listener)) continue;';
  const stale = 'if (!this.isScopeCurrent()) {\n      observer();\n      return (): void => {};\n    }';
  const mutations = [
    ['no-notification', source => replaceOnce(source, '\n      listener();\n    }\n  }\n\n  /** One-shot',
      '\n      // deliberately dropped\n    }\n  }\n\n  /** One-shot')],
    ['async-notification', source => replaceOnce(source, '\n      listener();\n    }\n  }\n\n  /** One-shot',
      '\n      Promise.resolve().then(listener);\n    }\n  }\n\n  /** One-shot')],
    ['generation-after-notification', source => replaceOnce(replaceOnce(source, '    this.generation++;\n', ''),
      '      listener();\n    }\n  }', '      listener();\n    }\n    this.generation++;\n  }')],
    ['cancel-ignored', source => replaceOnce(source, consume, 'this.scopeInvalidationListeners.delete(listener);')],
    ['consume-after-call', source => replaceOnce(source, `${consume}\n      listener();`,
      'if (!this.scopeInvalidationListeners.has(listener)) continue;\n      listener();\n      this.scopeInvalidationListeners.delete(listener);')],
    ['live-set-iteration', source => replaceOnce(source,
      'const snapshot: (() => void)[] = Array.from(this.scopeInvalidationListeners);',
      'const snapshot = this.scopeInvalidationListeners;')],
    ['clear-new-epoch', source => replaceOnce(source,
      '      listener();\n    }\n  }', '      listener();\n    }\n    this.scopeInvalidationListeners.clear();\n  }')],
    ['stale-captures-B', source => replaceOnce(source, stale, '')],
    ['stale-notification-deferred', source => replaceOnce(source, stale, stale.replace('observer();', 'Promise.resolve().then(observer);'))],
    ['unsubscribe-noop', source => replaceOnce(source, '      root.scopeInvalidationListeners.delete(observer);', '')],
    ['exceptions-escape', source => replaceOnce(source,
      '        listener();\n      } catch (error) {', '        listener();\n      } catch (error) {\n        throw error;')],
    ['stale-invalidate-delegates', source => replaceOnce(source,
      'if (this.isScopeCurrent()) this.scopeRoot.invalidateScopes();', 'this.scopeRoot.invalidateScopes();')],
    ['generation-never-revoked', source => replaceOnce(source, '    this.generation++;', '    // no revocation')]
  ];
  const results = [];
  for (const [name, mutate] of mutations) {
    const source = mutate(actualSource.replace(/\r\n/g, '\n'));
    assert.notEqual(hash(source), hash(actualSource.replace(/\r\n/g, '\n')), `${name} must change source`);
    // Syntax/loader errors are harness failures, not evidence of a caught regression.
    const result = await runSuite(source, false);
    assert.ok(result.failed > 0, `${name} escaped the behavioral checks`);
    results.push({ name, failed: result.failed, firstFailure: result.failures[0].name });
    console.log('REJECTED', name, `${result.failed}/${tests.length}`, result.failures[0].name);
  }
  return results;
}
async function main() {
  const result = await runSuite();
  console.log(JSON.stringify({ ...result, sources }));
  process.exitCode = result.failed ? 1 : 0;
  if (!result.failed && process.argv.includes('--negative-controls')) {
    const controls = await negativeControls();
    console.log(JSON.stringify({ rejected: controls.length, controls, sources }));
  }
}
module.exports = { runSuite, actualSource, hash };
if (require.main === module) require('./host-test-completion.cjs').guardSuite(main()).catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
