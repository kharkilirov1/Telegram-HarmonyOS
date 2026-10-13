// Node >= 24: execute current auth UI/controller methods, not copied implementations.
// ArkUI builders/decorators are excluded; storage/store/timers/gateway are inert fixtures.
// No renderer, native TDLib, account operations, or device actions are invoked.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '../entry/src/main/ets');
function load(relative, deps = {}, component) {
  let source = fs.readFileSync(path.join(root, relative), 'utf8');
  if (component) {
    const end = source.search(/^  (?:@Builder|build\(\))/m);
    assert.ok(end > 0, `builder boundary exists: ${relative}`);
    source = source.slice(0, end) + '\n}\n';
    source = source.replace(/^\s*@(Entry|ComponentV2)\s*$/gm, '')
      .replace(/@(Local|Event|Param)\s+/g, '').replace(/\bstruct\b/g, 'class');
  }
  const names = component ? [component] : [...source.matchAll(/^export\s+(?:class|function)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, ''),
    { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const hilog = { info() {}, warn() {}, error() {}, debug() {} };
const resource = name => ({ id: name });
const tick = () => new Promise(resolve => setImmediate(resolve));
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
function fixture(initial = 'waitCode') {
  const values = new Map(), writes = [], dispatched = [], listeners = new Set(), scopedListeners = new Set();
  const timers = new Map(), cancelled = [], logoutRequests = [], recoveryRequests = [];
  let time = 0, nextTimer = 1, scopedReads = 0;
  let state = { auth: { status: initial, error: '' } };
  const StorageKeys = new Proxy({}, { get: (_, key) => key });
  values.set('AUTH_STATUS', initial);
  values.set('CONNECTION_STATUS', 'ready');
  const AppStorage = {
    get: key => values.get(key),
    set(key, value) { writes.push([key, value]); values.set(key, value); return true; },
    setOrCreate(key, value) { this.set(key, value); }
  };
  const lifecycle = {
    getState: () => state,
    subscribe(fn) { listeners.add(fn); return () => listeners.delete(fn); },
    dispatch(event) { dispatched.push(event); return Promise.resolve(); }
  };
  const runtime = {
    getLifecycleStore: () => lifecycle,
    getStore() {
      scopedReads++;
      return { ...lifecycle, subscribe(fn) { scopedListeners.add(fn); return () => scopedListeners.delete(fn); } };
    },
    retryClientRecovery() { const request = deferred(); recoveryRequests.push(request); return request.promise; }
  };
  class NavPathStack {
    paths = ['account-A'];
    clears = 0;
    clear() { this.paths = []; this.clears++; }
  }
  const deps = {
    hilog, AppStorage, StorageKeys, NavPathStack, $r: resource,
    getAppCoreRuntime: () => runtime,
    createAuthStateChangedEvent: status => ({ type: 'authStateChanged', status }),
    LoginController: { getInstance: () => ({ logout() {
      const request = deferred(); logoutRequests.push(request); return request.promise;
    } }) },
    Date: { now: () => time },
    setTimeout(callback, delay) { const id = nextTimer++; timers.set(id, { callback, delay }); return id; },
    clearTimeout(id) { cancelled.push(id); timers.delete(id); }
  };
  const { LoginRouterPage } = load('ui/pages/login/LoginRouterPage.ets', deps, 'LoginRouterPage');
  const { LoginRouter } = load('ui/pages/login/LoginRouter.ets', deps, 'LoginRouter');
  return {
    page: new LoginRouterPage(), router: new LoginRouter(), values, writes, dispatched, listeners, scopedListeners,
    timers, cancelled, logoutRequests, recoveryRequests, NavPathStack, scopedReads: () => scopedReads,
    auth(status, error = '', notify = true) {
      const previous = state;
      state = { auth: { status, error } };
      values.set('AUTH_STATUS', status);
      if (notify) for (const fn of [...listeners, ...scopedListeners]) fn(state, previous);
    },
    now(value) { time = value; },
    fire() {
      const [id, timer] = [...timers][0] || [];
      assert.ok(timer, 'a transition is scheduled');
      timers.delete(id); timer.callback();
    }
  };
}
function captureChecks(page) {
  const checks = [];
  const schedule = page.scheduleTransitionCheck.bind(page);
  page.scheduleTransitionCheck = (fn, delay) => { checks.push(fn); schedule(fn, delay); };
  return checks;
}
const tests = [];
const test = (name, run) => tests.push([name, run]);
for (const status of ['loggingOut', 'closing', 'closed', 'waitPhoneNumber']) {
  test(`ready -> ${status}: hide main synchronously and clear both navigation stacks`, () => {
    const f = fixture('ready');
    f.page.aboutToAppear();
    const accountStack = new f.NavPathStack();
    f.values.set('pageStack', accountStack);
    f.auth(status);
    assert.equal(f.page.showMainUI, false);
    assert.deepEqual(accountStack.paths, []);
    assert.deepEqual(f.page.pageStack.paths, []);
    assert.equal(f.values.get('pageStack'), f.page.pageStack);
  });
}
test('root subscribes only to stable lifecycle store and uses live initial auth', () => {
  const f = fixture('ready');
  f.values.set('AUTH_STATUS', 'waitCode');
  f.page.aboutToAppear();
  assert.equal(f.page.showMainUI, true);
  assert.equal(f.listeners.size, 1);
  assert.equal(f.scopedReads(), 0);
});
test('stale AppStorage ready cannot authenticate startup', () => {
  const f = fixture('closed');
  f.values.set('AUTH_STATUS', 'ready');
  f.page.aboutToAppear();
  assert.equal(f.page.showMainUI, false);
});
test('connection reconnect is not auth loss and preserves navigation', () => {
  const f = fixture('ready');
  f.page.aboutToAppear();
  f.values.set('CONNECTION_STATUS', 'waitingForNetwork');
  f.auth('ready');
  assert.equal(f.page.showMainUI, true);
  assert.equal(f.page.pageStack.clears, 0);
});
test('auth loss cancels timer; captured A check cannot reopen after B ready', () => {
  const f = fixture();
  const checks = captureChecks(f.page);
  f.page.aboutToAppear();
  f.auth('ready');
  f.page.waitForDataAndTransition();
  const oldCheck = checks[0];
  f.auth('closed');
  assert.equal(f.timers.size, 0);
  f.auth('ready');
  f.page.waitForDataAndTransition();
  f.now(4000);
  oldCheck();
  assert.equal(f.page.showMainUI, false, 'generation, not merely ready, fences the old check');
  assert.equal(f.timers.size, 1, 'B transition remains alive');
  f.fire();
  assert.equal(f.page.showMainUI, true);
});
test('every transition check reads live auth, even without subscription delivery', () => {
  const f = fixture();
  f.page.aboutToAppear();
  f.auth('ready');
  f.page.waitForDataAndTransition();
  f.auth('closed', '', false);
  f.now(4000);
  f.fire();
  assert.equal(f.page.showMainUI, false);
  assert.equal(f.timers.size, 0);
});
test('delayed completion callback cannot schedule or reveal unauthenticated UI', () => {
  const f = fixture('closed');
  f.page.aboutToAppear();
  f.page.waitForDataAndTransition();
  assert.equal(f.timers.size, 0);
  assert.equal(f.page.showMainUI, false);
});
test('root unsubscribe and reappear fence old subscription and timers', () => {
  const f = fixture();
  f.page.aboutToAppear();
  assert.equal(f.listeners.size, 1);
  const oldListener = [...f.listeners][0];
  f.auth('ready');
  f.page.waitForDataAndTransition();
  const oldTimer = [...f.timers.values()][0].callback;
  f.page.aboutToDisappear();
  assert.equal(f.listeners.size, 0);
  assert.equal(f.timers.size, 0);
  f.page.aboutToAppear();
  assert.equal(f.listeners.size, 1);
  oldListener({ auth: { status: 'closed' } }, { auth: { status: 'ready' } });
  f.now(4000); oldTimer();
  assert.equal(f.page.showMainUI, true);
});
test('router reads lifecycle auth/error and detaches the same stable subscription', () => {
  const f = fixture('closed');
  f.router.aboutToAppear();
  f.auth('closed', 'private fixture recovery failure');
  assert.equal(f.router.authError, 'private fixture recovery failure');
  assert.equal(f.listeners.size, 1);
  assert.equal(f.scopedReads(), 0);
  const old = [...f.listeners][0];
  f.router.aboutToDisappear();
  assert.equal(f.listeners.size, 0);
  f.auth('waitCode'); old();
  assert.equal(f.router.authStatus, 'closed');
});
for (const fails of [false, true]) {
  test(`logout ${fails ? 'reject' : 'resolve'} never invents waitPhoneNumber`, async () => {
    const f = fixture();
    f.router.aboutToAppear();
    const result = f.router.forceBackToPhone('wrong_number_pressed');
    assert.equal(f.logoutRequests.length, 1);
    assert.equal(f.dispatched.length, 0, 'no optimistic auth dispatch');
    assert.equal(f.values.get('AUTH_STATUS'), 'waitCode');
    if (fails) f.logoutRequests[0].reject(new Error('private logout failure'));
    else f.logoutRequests[0].resolve();
    await result; await tick();
    assert.equal(f.router.authStatus, 'waitCode');
    assert.equal(f.values.get('AUTH_STATUS'), 'waitCode');
    assert.equal(f.dispatched.length, 0);
    assert.equal(f.writes.some(([key]) => key === 'AUTH_STATUS'), false);
    if (fails) assert.deepEqual(f.router.localError, resource('app.string.action_failed'));
  });
}
test('wrong-number logout is single-flight; only real state can open phone input', async () => {
  const f = fixture();
  f.router.aboutToAppear();
  const first = f.router.forceBackToPhone('wrong_number_pressed');
  f.router.forceBackToPhone('wrong_number_pressed');
  assert.equal(f.logoutRequests.length, 1);
  f.logoutRequests[0].resolve();
  await first; await tick();
  assert.equal(f.router.authStatus, 'waitCode');
  f.auth('loggingOut'); f.auth('closed'); f.auth('waitPhoneNumber');
  assert.equal(f.router.authStatus, 'waitPhoneNumber');
  assert.equal(f.dispatched.length, 0);
});
test('logout failure after page disappearance or new auth phase cannot overwrite local state', async () => {
  for (const disappear of [false, true]) {
    const f = fixture();
    f.router.aboutToAppear();
    const result = f.router.forceBackToPhone('wrong_number_pressed');
    if (disappear) f.router.aboutToDisappear();
    else { f.auth('closed'); f.auth('waitPhoneNumber'); }
    f.logoutRequests[0].reject(new Error('private obsolete failure'));
    await result; await tick();
    assert.equal(f.router.localError, undefined);
    assert.equal(f.dispatched.length, 0);
  }
});
test('manual recovery calls safe runtime once and reports only generic local failure', async () => {
  const f = fixture('closed');
  f.router.aboutToAppear();
  f.auth('closed', 'private recovery failure');
  const first = f.router.retryRecovery();
  f.router.retryRecovery();
  assert.equal(f.recoveryRequests.length, 1);
  assert.equal(f.logoutRequests.length, 0);
  f.recoveryRequests[0].reject(new Error('secret path/token'));
  await first;
  assert.deepEqual(f.router.localError, resource('app.string.action_failed'));
  assert.equal(f.router.recoveryInFlight, false);
  assert.equal(f.router.authStatus, 'closed');
  const next = f.router.retryRecovery();
  f.recoveryRequests[1].resolve();
  await next;
  assert.equal(f.router.authStatus, 'closed', 'retry completion is not auth confirmation');
  assert.equal(f.dispatched.length, 0);
});
test('manual recovery is refused outside terminal state', async () => {
  const f = fixture('ready');
  f.router.aboutToAppear();
  await f.router.retryRecovery();
  assert.equal(f.recoveryRequests.length, 0);
});
test('obsolete retry rejection cannot overwrite a new login phase', async () => {
  const f = fixture('closed');
  f.router.aboutToAppear();
  const result = f.router.retryRecovery();
  f.auth('waitPhoneNumber');
  f.recoveryRequests[0].reject(new Error('obsolete private retry failure'));
  await result;
  assert.equal(f.router.localError, undefined);
  assert.equal(f.router.authStatus, 'waitPhoneNumber');
});
test('closed with auto recovery pending stays spinner; only failure exposes manual retry', async () => {
  const f = fixture('closed');
  f.router.aboutToAppear();
  assert.equal(f.router.hasRecoveryFailure(), false);
  assert.equal(f.recoveryRequests.length, 0, 'rendering pending state must not request another recovery');
  f.auth('closed', 'private failure');
  assert.equal(f.router.hasRecoveryFailure(), true);
  const result = f.router.retryRecovery();
  assert.equal(f.router.hasRecoveryFailure(), false, 'manual recovery in progress is a spinner');
  f.recoveryRequests[0].reject(new Error('private retry failure'));
  await result;
  assert.equal(f.router.hasRecoveryFailure(), true);
  f.auth('waitPhoneNumber');
  assert.equal(f.router.hasRecoveryFailure(), false);
});
test('detached router callbacks cannot initiate logout or recovery', async () => {
  for (const status of ['waitCode', 'closed']) {
    const f = fixture(status);
    f.router.aboutToAppear();
    f.router.aboutToDisappear();
    const logout = f.router.forceBackToPhone('obsolete_callback');
    const recovery = f.router.retryRecovery();
    assert.equal(f.logoutRequests.length, 0);
    assert.equal(f.recoveryRequests.length, 0);
    await Promise.all([logout, recovery]);
  }
});
test('stale wrong-number callback cannot log out an authenticated or terminal session', async () => {
  for (const status of ['ready', 'loggingOut', 'closing', 'closed']) {
    const f = fixture(status);
    f.router.aboutToAppear();
    const result = f.router.forceBackToPhone('obsolete_wrong_number');
    assert.equal(f.logoutRequests.length, 0);
    await result;
  }
});
test('transition honors minimum wait; duplicate completion does not restart its clock', () => {
  const f = fixture();
  f.page.aboutToAppear();
  f.auth('ready');
  const originalId = [...f.timers.keys()][0];
  f.now(500);
  f.page.waitForDataAndTransition();
  assert.deepEqual([...f.timers.keys()], [originalId]);
  f.now(749); f.fire();
  assert.equal(f.page.showMainUI, false);
  f.now(750); f.fire();
  assert.equal(f.page.showMainUI, true);
  f.auth('closed');
  f.page.aboutToDisappear();
  f.page.waitForDataAndTransition();
  assert.equal(f.timers.size, 0);
});
test('closed error UI is resource-based and binds safe retry (source contract, not rendering)', () => {
  const source = fs.readFileSync(path.join(root, 'ui/pages/login/LoginRouter.ets'), 'utf8');
  assert.match(source, /this\.authStatus === 'closed'[\s\S]*this\.authError\.length/);
  assert.match(source.slice(source.indexOf('  build()')), /if \(this\.hasRecoveryFailure\(\)\)/,
    'the executed failure predicate is wired into the real builder');
  assert.match(source, /Text\(\$r\('app\.string\.action_failed'\)\)/);
  assert.match(source, /this\.retryRecovery\(\)/);
  assert.doesNotMatch(source, /Text\(this\.authError\)/);
  for (const locale of ['base', 'ru_RU']) {
    const strings = JSON.parse(fs.readFileSync(path.join(root, `../resources/${locale}/element/string.json`), 'utf8')).string;
    for (const key of ['action_failed', 'retry']) assert.ok(strings.some(item => item.name === key && item.value));
  }
});
function controllerFixture() {
  let reads = 0;
  const sent = [], requests = [];
  const adapters = [0, 1].map(id => ({ send(command) {
    sent.push({ id, command }); const request = deferred(); requests.push(request); return request.promise;
  } }));
  let active = 0;
  const creators = Object.fromEntries(['SetPhoneNumber', 'CheckAuthCode', 'CheckAuthPassword', 'RequestPasswordRecovery',
    'ResendAuthCode', 'Logout'].map(name => [`create${name}Command`, value => ({ type: name, value })]));
  const { LoginController } = load('ui/controllers/LoginController.ets', {
    hilog, ...creators, RequestQrCodeAuthCommand: class {},
    getTdGatewayAdapter: () => { reads++; return adapters[active]; }
  });
  return { LoginController, sent, requests, reads: () => reads, switch() { active = 1; } };
}
test('controller singleton does not capture an account adapter at construction', () => {
  const f = controllerFixture();
  assert.equal(f.LoginController.getInstance(), f.LoginController.getInstance());
  assert.equal(f.reads(), 0);
});
for (const [command, arg] of [['sendPhoneNumber', '+10000000000'], ['checkCode', '00000'], ['checkPassword', 'fixture'],
  ['requestPasswordRecovery'], ['requestQrLogin'], ['logout'], ['resendCode']]) {
  test(`controller ${command} captures current adapter once per command, not per singleton`, async () => {
    const f = controllerFixture();
    const controller = f.LoginController.getInstance();
    const before = f.reads();
    const a = controller[command](arg);
    f.switch();
    const b = controller[command](arg);
    assert.deepEqual(f.sent.map(item => item.id), [0, 1]);
    assert.equal(f.reads() - before, 2);
    for (const request of f.requests) request.resolve();
    await Promise.all([a, b]);
    assert.equal(f.sent.length, 2);
  });
}
test('controller logout rejects with original failure, never reports success', async () => {
  const f = controllerFixture();
  const result = f.LoginController.getInstance().logout();
  const error = new Error('fixture logout refused');
  f.requests[0].reject(error);
  await assert.rejects(result, e => e === error);
});
async function main() {
  let passed = 0;
  for (const [name, run] of tests) {
    try { await run(); passed++; console.log(`PASS ${name}`); }
    catch (error) { console.error(`FAIL ${name}\n${error.stack}`); }
  }
  console.log(`${passed}/${tests.length} PASS; ${tests.length - passed} FAIL (actual source, host fixtures only)`);
  if (passed !== tests.length) process.exitCode = 1;
}
let finished = false;
process.on('beforeExit', () => {
  if (!finished) { console.error('FAIL incomplete test run: unresolved fixture promise'); process.exitCode = 1; }
});
main().then(() => { finished = true; }).catch(error => {
  finished = true; console.error(error); process.exitCode = 1;
});
