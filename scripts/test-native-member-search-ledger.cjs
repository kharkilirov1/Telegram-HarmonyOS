// Execute the real registered native member-search callback and its ledger helpers.
// Only SDK interactions/controlled transport are modeled; production UI is not claimed tested here.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const option = key => process.argv.find(a => a.startsWith(key + '='))?.slice(key.length + 1);
const sourcePath = option('--source') ? path.resolve(option('--source')) :
  path.resolve(__dirname, '../entry/src/ohosTest/ets/test/StabilizationNative.test.ets');
let source = fs.readFileSync(sourcePath, 'utf8').replace(/\r\n/g, '\n');
const mutant = option('--mutant');
if (mutant) {
  const mutations = {
    'skip-intermediate-replies': ['staleIds.push(staleId); segment.reply(request, staleId);', 'staleIds.push(staleId);'],
    'skip-intermediate-assertions': ["      for (const staleId of staleIds) await absentText(driver, 'Member ' + staleId.toString());", ''],
    'skip-old-assertions': ["      await absentText(driver, 'Member 1000');", ''],
    'skip-late-assertion': ["await absentText(driver, 'Member 1110'); closeRequests.assertNoNewRequests();", 'closeRequests.assertNoNewRequests();'],
    'accept-duplicate-terminal': ["        if (terminal !== undefined) throw new Error('Native members duplicate terminal query=' + query);", '']
  };
  assert(mutations[mutant], 'known mutation');
  const [before, after] = mutations[mutant];
  const expected = mutant === 'skip-old-assertions' ? 2 : 1;
  assert.equal(source.split(before).length - 1, expected, 'mutation must activate at every intended location');
  source = source.split(before).join(after);
}
const code = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace('export default function stabilizationNativeTest()', 'function stabilizationNativeTest()'), { mode: 'transform' });
const caseName = 'actual member search revokes old result and Back fences late replacement';
function create(options = {}) {
  let now = 0, depth = 0, text = '', selected, port, currentRequest;
  let visible = new Set(), lateDuplicateSent = false;
  const replies = [], interactions = [];
  const command = query => query === '' ?
    { type: 'getSupergroupMembers', payload: { supergroupId: 77, offset: 0, limit: 100, filterKind: 'all' } } :
    { type: 'searchChatMembers', payload: { chatId: -42, query, limit: 200, filterKind: 'all' } };
  const emit = query => {
    const request = { command: command(query) };
    if (options.wrongScope && query === 'new') request.command.payload.chatId = -43;
    port.requests.push(request); currentRequest = request;
    return request;
  };
  const fixture = {
    prepareProfiles: () => { port = { requests: [] }; },
    requestCount: () => port.requests.length, port: () => port, navigationDepth: () => depth,
    replyMembers: (index, firstId, count) => {
      const request = port.requests[index];
      assert(request, 'reply must target an existing request');
      assert(!replies.some(r => r.request === request), 'reply must occur only once');
      replies.push({ request, index, firstId, count, depth });
      const badOld = options.renderStaleOld && firstId === 1000 && count === 1;
      const badIntermediate = options.renderStaleIntermediate && firstId >= 1010 && firstId < 1100;
      const badLate = options.renderLateClose && firstId === 1110;
      if (depth === 1 && badIntermediate) {
        for (let i = 0; i < count; i++) visible.add('Member ' + (firstId + i));
      } else if ((depth === 1 && (request === currentRequest || badOld)) || badLate)
        visible = new Set(Array.from({ length: count }, (_, i) => 'Member ' + (firstId + i)));
    }
  };
  const driver = { delayMs: async ms => { now += ms; }, waitForIdle: async () => true };
  const harness = {
    rootReady: async () => assert.equal(depth, 0),
    open: async () => { depth = 1; emit(''); },
    component: async (_driver, id) => ({ id }),
    clickOwnedComponent: async (_driver, target) => {
      interactions.push(target.id);
      if (target.id === 'tg_chat_top_bar_search_close') {
        text = ''; visible.clear(); emit('');
        if (options.duplicateClose) emit('');
      }
    },
    controlledInputAfterFocus: async () => ({ id: 'input' }),
    inputOwnedText: async (_driver, _target, value) => {
      text = value; visible.clear();
      const queries = value === 'old' ? options.oldQueries ?? ['old'] : options.newQueries ?? ['', 'ne', 'new'];
      for (const query of queries) emit(query);
      if (options.duplicateNew && value === 'new') emit('new');
      if (options.duplicateOld && value === 'old') emit('old');
      if (options.changePort && value === 'new') port = { requests: port.requests.slice() };
      if (options.changeRequestIdentity && value === 'new') port.requests[1] = { command: port.requests[1].command };
    },
    ownedText: async () => text,
    ownedWaitForComponent: async (_driver, selector) => {
      const found = visible.has(selector.text);
      if (found && options.lateDuplicateNew && !lateDuplicateSent) { lateDuplicateSent = true; emit('new'); }
      return found ? { text: selector.text } : undefined;
    },
    dismissKnownImeFirstUse: async () => false,
    absentText: async (_driver, value) => assert(!visible.has(value), 'unexpected stale UI row ' + value),
    screenshot: async () => {},
    back: async () => { assert.equal(depth, 1); depth = 0; visible.clear(); if (options.requestAfterBack) emit(''); }
  };
  const overrides = Object.keys(harness).map(name => name + ' = harness.' + name + ';').join('\n');
  const expect = value => ({ assertTrue: () => assert.equal(value, true), assertFalse: () => assert.equal(value, false), assertEqual: expected => assert.equal(value, expected) });
  new Function('abilityDelegatorRegistry', 'describe', 'it', 'Driver', 'ON', 'StabilizationNativeFixture', 'TG_CHAT_SEARCH_INPUT_ID', 'expect', 'Date', 'console', 'harness',
    code + '\n' + overrides + '\nstabilizationNativeTest();')(
    { getArguments: () => ({ parameters: {}, bundleName: 'test.fixture' }) }, (_name, callback) => callback(),
    (name, _flag, callback) => { if (name === caseName) selected = callback; },
    { create: () => driver }, { text: text => ({ text }) }, fixture, 'input', expect, { now: () => now }, { info: () => {} }, harness);
  assert(selected, 'select actual registered member-search callback');
  return { run: () => selected(), replies, interactions, requests: () => port.requests, elapsed: () => now };
}
const tests = [];
const test = (name, run) => tests.push({ name, run });
test('actual callback correlates old then empty/ne/new, answers all stale requests and one late close', async () => {
  const f = create(); await assert.doesNotReject(f.run());
  assert.equal(f.replies.length, f.requests().length, 'every controlled request must be explicitly settled');
  assert.equal(f.replies.find(r => r.firstId === 1100).request.command.payload.query, 'new');
  assert.equal(f.replies.find(r => r.firstId === 1000 && r.count === 1).request.command.payload.query, 'old');
  const late = f.replies.find(r => r.firstId === 1110); assert.equal(late.depth, 0); assert.equal(late.request.command.type, 'getSupergroupMembers');
  assert.equal(f.interactions.filter(id => id === 'tg_chat_top_bar_search_close').length, 1);
});
test('actual callback settles every deletion/typing prefix from both native input calls', async () => {
  const f = create({ oldQueries: ['o', 'ol', 'old'], newQueries: ['ol', 'o', '', 'n', 'ne', 'new'] });
  await assert.doesNotReject(f.run());
  assert.equal(f.replies.length, f.requests().length);
  const sentinels = f.replies.filter(r => r.firstId >= 1010 && r.firstId < 1100);
  assert.equal(sentinels.length, 7); assert.equal(new Set(sentinels.map(r => r.firstId)).size, 7);
});
test('atomic input path also retains all semantic assertions', async () => {
  const f = create({ newQueries: ['new'] }); await assert.doesNotReject(f.run()); assert.equal(f.replies.length, 4);
});
test('intermediate query order or repetition is not treated as a terminal duplicate', async () => {
  const f = create({ newQueries: ['ne', '', 'n', '', 'ne', 'new'] });
  await assert.doesNotReject(f.run()); assert.equal(f.replies.length, f.requests().length);
});
for (const [name, options, reason] of [
  ['duplicate final new query', { duplicateNew: true }, /duplicate terminal query/],
  ['duplicate final old query', { duplicateOld: true }, /duplicate terminal query/],
  ['duplicate final new query after sealing', { lateDuplicateNew: true }, /unexpected request after terminal query/],
  ['unrelated query', { newQueries: ['', 'nw', 'new'] }, /unexpected input query/],
  ['wrong chat scope', { wrongScope: true }, /scope\/payload/],
  ['port owner change', { changePort: true }, /port owner changed/],
  ['captured request identity change', { changeRequestIdentity: true }, /request identity changed/],
  ['missing final new query', { newQueries: ['', 'ne'] }, /timed out: exact new query request/],
  ['duplicate close reload', { duplicateClose: true }, /duplicate terminal query/],
  ['request after Back', { requestAfterBack: true }, /unexpected request after terminal query/],
  ['old reply rendered after replacement', { renderStaleOld: true }, /unexpected stale UI row Member 1000/],
  ['intermediate reply rendered over final new result', { renderStaleIntermediate: true }, /unexpected stale UI row Member 101/],
  ['late close reply rendered after Back', { renderLateClose: true }, /unexpected stale UI row Member 1110/]
]) test(name + ' remains a native callback failure', async () => {
  const f = create(options); await assert.rejects(f.run(), reason);
});
let suiteComplete = false;
const watchdog = setTimeout(() => {
  if (!suiteComplete) { console.error('Native member-search ledger suite did not finish within 3s'); process.exitCode = 1; }
}, 3000);
(async () => {
  const results = [];
  for (const { name, run } of tests) {
    try { await run(); results.push({ name, pass: true }); }
    catch (error) { results.push({ name, pass: false, code: error.code, message: error.message }); }
  }
  const receipt = { sourcePath, mutant, passed: results.filter(r => r.pass).length, total: results.length, results };
  console.log(JSON.stringify(receipt, null, 2));
  if (option('--receipt')) fs.writeFileSync(path.resolve(option('--receipt')), JSON.stringify(receipt, null, 2) + '\n');
  process.exitCode = process.exitCode || (receipt.passed === receipt.total ? 0 : 1);
})().catch(error => { console.error(error); process.exitCode = 1; })
  .finally(() => { suiteComplete = true; clearTimeout(watchdog); });
