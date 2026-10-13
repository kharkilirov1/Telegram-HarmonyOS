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
  let exposed = false;
  const events = [];
  const row = { getText: async () => options.wrongLabel ? 'stale fixture label' : text };
  const root = { scrollSearch: async selector => {
    events.push(['scroll', selector.id]);
    assert.equal(selector.id, id, 'scroll to this footer by stable ID');
    if (options.scrollError) throw new Error('native scroll failed');
    if (options.missingFooter) return undefined;
    exposed = true;
    return row;
  } };
  const textExists = () => exposed && (!options.wrongLabel || options.decoyText);
  const driver = {
    waitForComponent: async (selector, timeout) => {
      assert.equal(timeout, 5000, 'keep the original wait bound');
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
  const run = new Function('ON', 'expect', 'console', 'PhotoSelectionPreviewFixture', code +
    ';return async function(driver) {' + call[0] + '};')(
    { id: value => ({ id: value }), text: value => ({ text: value }) },
    actual => ({ assertEqual: expected => assert.equal(actual, expected) }), { info() {} },
    { session: { isSendingMessage: () => true }, view: { composer: { isSending: true } } });
  return { run: () => run(driver), events };
}

require('./host-test-completion.cjs').guardSuite((async () => {
  const cases = [
    ['preview busy:true', 'photo-preview-fixture-busy-state'],
    ['preview busy:false', 'photo-preview-fixture-busy-state'],
    ['preview photos:0', 'photo-preview-fixture-count']
  ];
  const results = [];
  for (const [text, id] of cases) {
    const f = fixture(text, id);
    await f.run();
    assert.deepEqual(f.events, [['scroll', id], ['assert-exists', id],
      ['wait-text', text, true], ['assert-exists', text]], 'expose footer before original exact text wait');
    for (const [label, options, expected] of [
      ['missing-root', { missingRoot: true }, /Scroll is not mounted/],
      ['missing-footer', { missingFooter: true }, /Missing native preview component/],
      ['wrong-label', { wrongLabel: true }, /Missing native preview text/],
      ['wrong-label-with-decoy', { wrongLabel: true, decoyText: true }, { code: 'ERR_ASSERTION' }],
      ['native-scroll-failure', { scrollError: true }, /native scroll failed/]
    ]) {
      await assert.rejects(fixture(text, id, options).run(), expected, label + ': ' + text);
    }
    results.push({ text, id, positive: true, negativeCases: 5 });
  }
  console.log(JSON.stringify({ passed: true, sourcePath, results }));
})()).catch(error => { console.error(error); process.exitCode = 1; });
