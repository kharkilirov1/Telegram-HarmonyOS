// Node >= 24 source witness. No SDK, network, native TDLib or account access.
// Executes the checked-in .ets suite and controller; no copied controller logic.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const sources = {};
let injectAssertionFailure = false;

function expect(actual) {
  if (injectAssertionFailure) {
    injectAssertionFailure = false;
    assert.fail('injected test assertion');
  }
  return {
    assertTrue: () => assert.equal(actual, true),
    assertFalse: () => assert.equal(actual, false),
    assertEqual: expected => assert.equal(actual, expected)
  };
}

function load(relative, deps = {}, names) {
  let source = fs.readFileSync(path.join(root, relative), 'utf8');
  sources[relative] = createHash('sha256').update(source).digest('hex');
  names ??= [...source.matchAll(/^export\s+(?:class|function|const|enum)\s+(\w+)/gm)].map(match => match[1]);
  source = source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+(?:default\s+)?/gm, '');
  const js = stripTypeScriptTypes(source, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}

// Explicit host-only boundary, not a Hypium implementation: support only this
// suite's own send/dispatch methods and when(any).afterAction, and fail closed.
// Production controller methods and the native test bodies remain untouched.
const ArgumentMatchers = { any: Symbol('host-any') };
const hostMocks = new WeakMap();
class HostMockKit {
  mocks = [];
  mockFunc(target, original) {
    assert.equal(typeof original, 'function');
    assert.equal(hostMocks.has(original), false, 'Already mocked');
    const keys = Object.keys(target).filter(key => target[key] === original);
    assert.equal(keys.length, 1, 'Expected one own boundary method');
    const entry = { target, key: keys[0], original, action: undefined };
    const mock = function (...args) {
      assert.equal(args.length, 1, 'Only one boundary argument is supported');
      assert.equal(typeof entry.action, 'function', 'Unconfigured host mock');
      return entry.action.apply(this, args);
    };
    entry.mock = mock;
    hostMocks.set(mock, entry);
    this.mocks.push(entry);
    target[entry.key] = mock;
    return mock;
  }
  ignoreMock(target, key) {
    const index = this.mocks.findIndex(entry => entry.target === target && entry.key === key);
    assert.notEqual(index, -1, 'Unknown host mock');
    const entry = this.mocks[index];
    assert.equal(target[key], entry.mock, 'Boundary changed outside this mock');
    target[key] = entry.original;
    hostMocks.delete(entry.mock);
    this.mocks.splice(index, 1);
  }
}
function when(mock) {
  const entry = hostMocks.get(mock);
  assert.ok(entry, 'Expected an active host mock');
  return (...matchers) => {
    assert.deepEqual(matchers, [ArgumentMatchers.any], 'Only one any matcher is supported');
    return { afterAction(action) {
      assert.equal(typeof action, 'function');
      entry.action = action;
    } };
  };
}

function verifyHostMockBoundary() {
  const target = { send() { throw new Error('original boundary'); } };
  const original = target.send;
  const mocker = new HostMockKit();
  const mock = mocker.mockFunc(target, original);
  try {
    assert.equal(target.send, mock);
    assert.throws(() => target.send({}), /Unconfigured host mock/);
    assert.throws(() => when(mock)('unsupported'), /Only one any matcher/);
    const argument = {};
    const result = Promise.resolve('boundary-result');
    let calls = 0;
    when(mock)(ArgumentMatchers.any).afterAction(function (value) {
      calls++;
      assert.equal(this, target);
      assert.equal(value, argument);
      return result;
    });
    assert.equal(target.send(argument), result, 'Mock must forward the actual action result');
    assert.equal(calls, 1, 'Mock must execute the actual action exactly once');
  } finally {
    mocker.ignoreMock(target, 'send');
  }
  assert.equal(target.send, original, 'Mock must restore the original function identity');
  assert.throws(() => when(mock), /Expected an active host mock/);
  assert.throws(() => target.send({}), /original boundary/);
  console.log('PASS host_mock_boundary_forwarding_and_restore');
}

async function main() {
  verifyHostMockBoundary();
  const mainRoot = 'entry/src/main/ets/';
  const hilog = { info() {}, warn() {}, error() {}, debug() {} };
  const commands = load(mainRoot + 'core/model/AppCommand.ets');
  const dto = load(mainRoot + 'core/model/dto/MessageDto.ets');
  const events = load(mainRoot + 'core/model/AppEvent.ets', dto);
  const { TdObject } = load(mainRoot + 'models/td/common/index.ets');
  const timeline = load(mainRoot + 'ui/pages/chat/ChatTimelineVO.ets', {
    TgMessageSendStatus: { None: 'none' }
  });
  const gateway = { send() { throw new Error('Unmocked gateway.send'); } };
  const store = { dispatch() { throw new Error('Unmocked store.dispatch'); } };
  const originalSend = gateway.send;
  const originalDispatch = store.dispatch;
  const boundaries = {
    getTdGatewayAdapter: () => gateway,
    getAppCoreRuntime: () => ({ getStore: () => store })
  };
  const controller = load(mainRoot + 'ui/pages/chat/ChatMediaDownloadController.ets', {
    ...commands, ...events, ...boundaries, hilog
  });
  const tests = [];
  const before = [], after = [];
  const suite = load('entry/src/ohosTest/ets/test/ChatMediaDownloadController.test.ets', {
    ...controller, ...boundaries, ...events, ...timeline, TdObject,
    MockKit: HostMockKit, when, ArgumentMatchers,
    describe: (_name, run) => run(),
    beforeEach: run => before.push(run),
    afterEach: run => after.push(run),
    it: (name, _flags, run) => tests.push({ name, run }),
    expect
  }, ['chatMediaDownloadControllerTest']);
  suite.chatMediaDownloadControllerTest();
  assert.ok(tests.length > 0, 'No focused tests registered');
  let passed = 0, failed = 0;
  for (const test of tests) {
    try {
      for (const setup of before) await setup();
      await test.run();
      console.log('PASS', test.name);
      passed++;
    } catch (error) {
      if (error.code !== 'ERR_ASSERTION') throw error;
      console.log('FAIL', test.name, error.message);
      failed++;
    } finally {
      for (const cleanup of after) await cleanup();
      assert.equal(gateway.send, originalSend, 'send mock must be restored');
      assert.equal(store.dispatch, originalDispatch, 'dispatch mock must be restored');
    }
  }
  // Hypium does not guarantee afterEach on a thrown test assertion. Exercise
  // that path without the host runner's emergency finally cleanup.
  try {
    for (const setup of before) await setup();
    injectAssertionFailure = true;
    try {
      await tests[0].run();
      throw new Error('Failure injection did not engage');
    } catch (error) {
      if (error.code !== 'ERR_ASSERTION' || error.message !== 'injected test assertion') throw error;
    }
    assert.equal(injectAssertionFailure, false, 'Assertion fault must engage');
    assert.equal(gateway.send, originalSend, 'send must be restored even when afterEach is skipped');
    assert.equal(store.dispatch, originalDispatch, 'dispatch must be restored even when afterEach is skipped');
    console.log('PASS cleanup_survives_assertion_failure');
    passed++;
  } catch (error) {
    if (error.code !== 'ERR_ASSERTION') throw error;
    console.log('FAIL cleanup_survives_assertion_failure', error.message);
    failed++;
  } finally {
    injectAssertionFailure = false;
    for (const cleanup of after) await cleanup();
  }
  console.log(JSON.stringify({ passed, failed, sources }));
  process.exitCode = failed > 0 ? 1 : 0;
}

require('./host-test-completion.cjs').guardSuite(main()).catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
