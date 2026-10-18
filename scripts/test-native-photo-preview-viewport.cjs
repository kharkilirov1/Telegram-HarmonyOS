// Run the actual native text helper AND its real footer call sites at the UI
// boundary. This models clipped fixture content, not an ArkUI renderer.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const argument = process.argv.find(arg => arg.startsWith('--source='));
const sourcePath = argument ? path.resolve(argument.slice(9)) :
  path.resolve(__dirname, '../entry/src/ohosTest/ets/test/PhotoSelectionPreview.test.ets');
const source = fs.readFileSync(sourcePath, 'utf8');
const end = source.indexOf('export default function photoSelectionPreviewTest()');
assert.ok(end > 0, 'read actual native helper prefix');
const code = stripTypeScriptTypes(source.slice(0, end).replace(/^import[\s\S]*?;\s*/gm, ''), { mode: 'transform' });

function fixture(text, id, options = {}) {
  let exposed = false, now = 0;
  const events = [];
  const row = { getBounds: async () => ({ left: 10, right: 90, top: 10, bottom: 30 }), getText: async () => options.wrongLabel ? 'stale fixture label' : text };
  const root = { getBounds: async () => ({ left: 0, right: 100, top: 0, bottom: 100 }), scrollSearch: async selector => {
    events.push(['scroll', selector.id]);
    assert.equal(selector.id, id, 'scroll to this footer by stable ID');
    if (options.scrollError) throw new Error('native scroll failed');
    if (options.missingFooter) return undefined;
    exposed = true;
    return row;
  } };
  const textExists = () => exposed && (!options.wrongLabel || options.decoyText);
  const driver = {
    findComponent: async selector => { now += 100; assert.equal(selector.id, id); return exposed ? row : undefined; },
    waitForComponent: async (selector, timeout) => {
      assert.ok(timeout > 0 && timeout <= 5000, 'one original 5s observation bound');
      if (selector.id === 'chat-test-fixture-scroll') return options.missingRoot ? undefined : root;
      assert.equal(selector.text, text);
      events.push(['wait-text', selector.text, exposed]);
      return textExists() ? row : undefined;
    },
    assertComponentExist: async selector => {
      if (selector.id) assert.equal(exposed && selector.id === id, true, 'native footer exists');
      else assert.equal(selector.text === text && textExists(), true, 'original native text assertion');
      events.push(['assert-exists', selector.id || selector.text]);
    }
  };
  const escaped = text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const call = source.match(new RegExp("await requireText\\(driver, '" + escaped + "'[^;]*\\);"));
  assert.ok(call, 'retain the real footer assertion call: ' + text);
  const run = new Function('ON', 'expect', 'console', 'PhotoSelectionPreviewFixture', 'Date', code +
    ';return async function(driver) {' + call[0] + '};')(
    { id: value => ({ id: value }), text: value => ({ text: value }) },
    actual => ({ assertEqual: expected => assert.equal(actual, expected) }), { info() {} },
    { session: { isSendingMessage: () => true }, view: { composer: { isSending: true } },
      viewportOwner: () => 1, assertViewportOwner: owner => assert.equal(owner, 1),
      positionInViewport: target => { assert.equal(target, id); events.push(['position', target]);
        if (options.scrollError) throw new Error('fixture positioning failed'); exposed = !options.missingFooter; }
    }, { now: () => now });
  return { run: () => run(driver), events };
}

// Exercise the actual initial readiness helper with serialized, controllable
// SDK promises. A local deadline is an observation threshold, not cancellation.
const readinessMutation = process.argv.find(arg => arg.startsWith('--readiness-mutant='))?.slice(19);
let readinessCode = code;
function readinessReplace(from, to) {
  assert.equal(readinessCode.split(from).length - 1, 1, 'readiness mutation must engage exactly once');
  readinessCode = readinessCode.replace(from, to);
}
if (readinessMutation) {
  const query = "const scrolls = await driver.findComponents(ON.id('chat-test-fixture-scroll'));";
  const mutations = {
    'orphan-race': () => readinessReplace(query,
      "const scrolls = await Promise.race([driver.findComponents(ON.id('chat-test-fixture-scroll')), new Promise((resolve, reject) => setTimeout(() => reject(new Error('mutant deadline')), 10000))]);"),
    'late-top-query': () => readinessReplace('checkDeadline();\n        if (currentTestAbility)', 'if (currentTestAbility)'),
    'late-mounted-pass': () => readinessReplace(query + '\n            checkDeadline();', query),
    'empty-scroll-pass': () => readinessReplace('scrolls.length > 0', 'scrolls.length >= 0'),
    'wrong-module-pass': () => readinessReplace(" || ability.context.currentHapModuleInfo.name !== $r('app.color.background_primary').moduleName", ''),
    'swallow-driver-error': () => readinessReplace(query, query.replace(');', ').catch(() => []);')),
    'extend-budget': () => readinessReplace('const deadline = Date.now() + 10000;', 'const deadline = Date.now() + 20000;'),
    'zero-yield': () => readinessReplace('setTimeout(()=>resolve(), 100);', 'setTimeout(()=>resolve(), 0);')
  };
  assert(mutations[readinessMutation], 'known readiness mutation'); mutations[readinessMutation]();
}

function readinessFixture(options = {}) {
  let now = 0, timerId = 0, busy = 0, topCalls = 0, scrollCalls = 0, outcome;
  const timers = new Map(), pending = new Map(), events = [];
  const top = (options.top || []).slice(), scroll = (options.scroll || []).slice();
  const owned = { context: { abilityInfo: { name: 'TestAbility' }, currentHapModuleInfo: { name: 'entry' } } };
  const sentinel = Object.assign(new Error('original SDK failure'), { code: 17000002 });
  const early = Object.assign(new Error('ability not ready'), { code: 16000100 });
  const flush = async () => { for (let i = 0; i < 24; i++) await Promise.resolve(); };
  async function request(method, action, fallback) {
    assert.equal(busy, 0, 'readiness SDK calls must never overlap'); busy++;
    events.push({ event: method + '-enter', now });
    try {
      if (action.hold) await new Promise(resolve => pending.set(method, resolve));
      now += action.elapsed || 0;
      if (action.error) throw action.error === 'early' ? early : sentinel;
      return Object.hasOwn(action, 'value') ? action.value : fallback;
    } finally { busy--; events.push({ event: method + '-settled', now }); }
  }
  const driver = { findComponents: selector => {
    assert.equal(selector.id, 'chat-test-fixture-scroll', 'retain the actual mounted Scroll selector');
    scrollCalls++; return request('findComponents', scroll.shift() || {}, []);
  } };
  const fakeSetTimeout = (callback, delay) => {
    assert(delay > 0, 'readiness must yield a positive timer turn');
    const id = ++timerId; timers.set(id, { callback, due: now + delay }); return id;
  };
  const helper = new Function('abilityDelegatorRegistry', '$r', 'ON', 'Date', 'setTimeout', 'clearTimeout',
    readinessCode + ';return testAbilityReady;')(
    { getAbilityDelegator: () => ({ getCurrentTopAbility: () => {
      topCalls++; return request('getTopAbility', top.shift() || {}, owned);
    } }) }, () => ({ moduleName: 'entry' }), { id: id => ({ id }) }, { now: () => now },
    fakeSetTimeout, id => timers.delete(id));
  const promise = helper(driver).then(() => { outcome = { status: 'fulfilled' }; events.push({ event: 'helper-fulfilled', now, busy }); },
    error => { outcome = { status: 'rejected', error }; events.push({ event: 'helper-rejected', now, busy }); });
  const advance = async to => {
    assert(to >= now); now = to;
    for (const [id, timer] of [...timers]) if (timer.due <= now) { timers.delete(id); timer.callback(); }
    await flush();
  };
  return { owned, sentinel, promise, flush, advance, events,
    state: () => ({ now, busy, topCalls, scrollCalls, outcome, pending: pending.size, timers: timers.size }),
    release: async method => { const resolve = pending.get(method); assert(resolve); pending.delete(method); resolve(); await flush(); },
    nextDriver: () => assert.equal(busy, 0, 'next Driver cannot enter while the previous native request is pending'),
    drain: async () => {
      now = Math.max(now, 300000);
      for (const [method, resolve] of pending) { pending.delete(method); resolve(); }
      await flush(); await advance(now + 1000);
      assert.equal(busy, 0, 'host cleanup drains controlled requests');
    }
  };
}

async function checkNativePhotoReadiness() {
  const results = [];
  async function check(name, options, verify) {
    const f = readinessFixture(options);
    try { await f.flush(); await verify(f); results.push({ name, pass: true }); }
    finally { await f.drain(); }
  }
  const rejected = f => { const s = f.state(); assert.equal(s.outcome?.status, 'rejected'); assert.equal(s.busy, 0); f.nextDriver(); return s.outcome.error; };
  const timeout = f => assert.match(rejected(f).message, /readiness timeout.*10000 ms/);
  const success = f => { assert.equal(f.state().outcome?.status, 'fulfilled'); assert.equal(f.state().busy, 0); f.nextDriver(); };
  await check('real current TestAbility and mounted Scroll complete before deadline', { scroll: [{ value: [{}] }] }, async f => {
    success(f); assert.equal(f.state().topCalls, 1); assert.equal(f.state().scrollCalls, 1);
  });
  await check('deadline cannot return while findComponents is pending; late empty reply fails after drain', { scroll: [{ hold: true }] }, async f => {
    assert.equal(f.state().busy, 1); await f.advance(10000);
    assert.equal(f.state().outcome, undefined, 'deadline must not orphan the pending native query');
    assert.throws(f.nextDriver, { code: 'ERR_ASSERTION' });
    await f.advance(15000); await f.release('findComponents'); timeout(f);
    assert.equal(f.state().scrollCalls, 1); assert.equal(f.state().topCalls, 1);
  });
  await check('late mounted Scroll is a timeout rather than a PASS', { scroll: [{ hold: true, value: [{}] }] }, async f => {
    await f.advance(10000); assert.equal(f.state().outcome, undefined);
    await f.release('findComponents'); timeout(f); assert.equal(f.state().scrollCalls, 1);
  });
  await check('late findComponents rejection retains the original error object', { scroll: [{ hold: true, error: true }] }, async f => {
    await f.advance(12000); assert.equal(f.state().outcome, undefined);
    await f.release('findComponents'); assert.equal(rejected(f), f.sentinel);
  });
  await check('late top-ability completion cannot launch a new lookup after the deadline', { top: [{ hold: true }], scroll: [{ value: [{}] }] }, async f => {
    await f.advance(10000); assert.equal(f.state().outcome, undefined); assert.equal(f.state().scrollCalls, 0);
    await f.release('getTopAbility'); timeout(f); assert.equal(f.state().scrollCalls, 0);
  });
  await check('late recoverable top-ability error times out without retry', { top: [{ hold: true, error: 'early' }] }, async f => {
    await f.advance(10000); assert.equal(f.state().outcome, undefined);
    await f.release('getTopAbility'); timeout(f); assert.equal(f.state().topCalls, 1); assert.equal(f.state().scrollCalls, 0);
  });
  await check('late unexpected top-ability error preserves the original error message', { top: [{ hold: true, error: true }] }, async f => {
    await f.advance(10000); assert.equal(f.state().outcome, undefined); await f.release('getTopAbility');
    assert.equal(rejected(f).message, 'Cannot obtain native TestAbility: original SDK failure'); assert.equal(f.state().scrollCalls, 0);
  });
  await check('permanently pending SDK call retains the helper barrier beyond the aggregate runner budget', { scroll: [{ hold: true, value: [{}] }] }, async f => {
    await f.advance(240001); assert.equal(f.state().outcome, undefined);
    assert.equal(f.state().busy, 1); assert.equal(f.state().scrollCalls, 1); assert.equal(f.state().topCalls, 1);
    assert.throws(f.nextDriver, { code: 'ERR_ASSERTION' });
    // Release only in host cleanup; the helper never grants completion above.
  });
  await check('the exact10000ms boundary cannot accept a mounted Scroll', { scroll: [{ elapsed: 10000, value: [{}] }] }, async f => timeout(f));
  await check('a mount at9999ms remains valid', { scroll: [{ elapsed: 9999, value: [{}] }] }, async f => success(f));
  await check('empty Scroll never satisfies mount readiness', {}, async f => { await f.advance(10000); timeout(f); assert.equal(f.state().scrollCalls, 1); });
  await check('undefined Scroll never satisfies mount readiness', { scroll: [{ value: undefined }] }, async f => { await f.advance(10000); timeout(f); });
  await check('null Scroll never satisfies mount readiness', { scroll: [{ value: null }] }, async f => { await f.advance(10000); timeout(f); });
  await check('a settled Driver error propagates without outstanding query', { scroll: [{ error: true }] }, async f => { assert.equal(rejected(f), f.sentinel); });
  for (const [name, value] of [
    ['wrong ability', { context: { abilityInfo: { name: 'EntryAbility' }, currentHapModuleInfo: { name: 'entry' } } }],
    ['wrong module', { context: { abilityInfo: { name: 'TestAbility' }, currentHapModuleInfo: { name: 'entry_test' } } }],
    ['missing ability', undefined], ['missing context', {}]
  ]) await check(name + ' cannot authorize a native mount lookup', { top: [{ value }], scroll: [{ value: [{}] }] }, async f => {
    assert.equal(f.state().scrollCalls, 0); await f.advance(10000); timeout(f); assert.equal(f.state().scrollCalls, 0);
  });
  await check('only expected16000100 startup failure retries after a positive turn', { top: [{ error: 'early' }], scroll: [{ value: [{}] }] }, async f => {
    assert.equal(f.state().outcome, undefined); assert.equal(f.state().scrollCalls, 0);
    await f.advance(100); success(f); assert.equal(f.state().topCalls, 2);
  });
  await check('early missing Scroll retries serially without changing the deadline', { scroll: [{ value: [] }, { value: [{}] }] }, async f => {
    assert.equal(f.state().outcome, undefined); await f.advance(100); success(f); assert.equal(f.state().scrollCalls, 2);
  });
  await check('positive yield crossing the threshold cannot start another SDK request', { scroll: [{ elapsed: 9999 }] }, async f => {
    await f.advance(10099); timeout(f); assert.equal(f.state().topCalls, 1); assert.equal(f.state().scrollCalls, 1);
  });
  return { passed: results.length, results };
}


require('./host-test-completion.cjs').guardSuite((async () => {
  const readiness = await checkNativePhotoReadiness();
  const cases = [
    ['preview busy:true', 'photo-preview-fixture-busy-state'],
    ['preview busy:false', 'photo-preview-fixture-busy-state'],
    ['preview photos:0', 'photo-preview-fixture-count']
  ];
  const results = [];
  for (const [text, id] of cases) {
    const f = fixture(text, id);
    await f.run();
    assert.deepEqual(f.events, [['position', id], ['assert-exists', id],
      ['wait-text', text, true], ['assert-exists', text]], 'expose footer before original exact text wait');
    for (const [label, options, expected] of [
      ['missing-root', { missingRoot: true }, /Scroll is not mounted/],
      ['missing-footer', { missingFooter: true }, /Native photo viewport deadline/],
      ['wrong-label', { wrongLabel: true }, /Missing native preview text/],
      ['wrong-label-with-decoy', { wrongLabel: true, decoyText: true }, { code: 'ERR_ASSERTION' }],
      ['fixture-positioning-failure', { scrollError: true }, /fixture positioning failed/]
    ]) {
      await assert.rejects(fixture(text, id, options).run(), expected, label + ': ' + text);
    }
    results.push({ text, id, positive: true, negativeCases: 5 });
  }
  console.log(JSON.stringify({ passed: true, sourcePath, readiness, results }));
})()).catch(error => { console.error(error); process.exitCode = 1; });
