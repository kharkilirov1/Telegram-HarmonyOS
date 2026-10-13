// Node >=24: execute the real controller AND page wiring, without ArkUI/TDLib.
// --baseline-page <file> runs the same behavior against the pre-extraction page.
const { readChatSource } = require("./chat-screen-source.cjs");
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');

const root = path.resolve(__dirname, '..');
const pagePath = 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets';
const controllerPath = 'entry/src/main/ets/ui/pages/chat/ChatStickerSearchController.ets';
const option = name => {
  const index = process.argv.indexOf(name);
  return index < 0 ? undefined : process.argv[index + 1];
};
const baseline = option('--baseline-page');
const mutant = option('--mutant');
let pageSource = readChatSource(baseline || path.join(root, pagePath), 'utf8');
let controllerSource = baseline ? '' : readChatSource(path.join(root, controllerPath), 'utf8');
assert.ok(!mutant || ['request-id', 'page-wiring'].includes(mutant), `unknown mutant: ${mutant}`);
assert.ok(!baseline || !mutant, 'baseline and mutant modes are separate');
if (mutant === 'request-id') {
  const guard = 'requestId === this.requestId && query === this.query';
  assert.equal(controllerSource.split(guard).length - 1, 1, 'mutation site must engage exactly once');
  controllerSource = controllerSource.replace(guard, 'query === this.query');
}
if (mutant === 'page-wiring') {
  const call = 'this.stickerSearchCtrl.handleSearchQueryChange(query, this);';
  assert.equal(pageSource.split(call).length - 1, 1, 'page wiring mutation must engage exactly once');
  pageSource = pageSource.replace(call, 'void query;');
}
const cellSource = readChatSource(path.join(root,
  'entry/src/main/ets/ui/tg_ui/atoms/TgComposerStickerPanel.ets'), 'utf8')
  .match(/^export class StickerCellVO \{[\s\S]*?^\}/m)[0];
function method(name) {
  const match = pageSource.match(new RegExp(`^  (?:private )?(?:async )?${name}\\([\\s\\S]*?^  \\}`, 'm'));
  assert.ok(match, `Missing real page method ${name}`);
  return match[0];
}
function compile(source, name, bindings) {
  const body = source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s+/gm, '').replace(/@Trace\s+/g, '');
  const js = stripTypeScriptTypes(body, { mode: 'transform', sourceUrl: name });
  return new Function(...Object.keys(bindings), `${js}\nreturn ${name};`)(...Object.values(bindings));
}
const turn = () => new Promise(resolve => setImmediate(resolve));
const tests = [];
const test = (name, run) => tests.push({ name, run });

function fixture(source = controllerSource) {
  let now = 0, sequence = 0;
  const timers = new Map(), history = new Map(), requests = [], downloads = [], warnings = [], uris = [];
  const bindings = {
    setTimeout(fn, delay) {
      const id = sequence++;
      const timer = { fn, at: now + delay };
      timers.set(id, timer); history.set(id, timer);
      return id;
    },
    clearTimeout(id) { timers.delete(id); },
    fileUri: { getUriFromPath(p) { uris.push(p); return 'file://' + p; } },
    hilog: { warn(...args) { warnings.push(args); } }
  };
  function useCase() {
    const owner = {
      searchRegularStickers(query, languages) {
        assert.equal(this, owner, 'search must use the captured use-case receiver');
        return new Promise((resolve, reject) => requests.push({ owner, query, languages, resolve, reject }));
      },
      downloadStickerFile(id) {
        assert.equal(this, owner, 'download must use the captured use-case receiver');
        return new Promise((resolve, reject) => downloads.push({ owner, id, resolve, reject }));
      }
    };
    return owner;
  }
  const names = ['resetStickerSearchState', 'handleStickerSearchQueryChange', 'toStickerCellVO'];
  if (baseline) names.push('fetchStickerSearchFiles');
  else names.push('getLifecycleToken', 'getStickerSearchUseCase', 'isStickerSearchPanelActive',
    'getStickerSearchLanguageCodes', 'toStickerSearchCell', 'setStickerSearchItems',
    'setStickerSearchLoading');
  const StickerCellVO = compile(cellSource, 'StickerCellVO', {});
  const constant = baseline ? pageSource.match(/^const STICKER_SEARCH_DEBOUNCE_MS[^\n]+/m)[0] : '';
  const Page = process.argv.includes('--actual-delegates') ? require('./chat-screen-source.cjs').compileExports(
    require('./chat-screen-source.cjs').sourceGraph(path.join(root, pagePath)),
    { ...bindings, StickerCellVO, DOMAIN: 0x0021, TAG: 'PageTest' }, undefined,
    mutant === 'page-wiring' ? { handleStickerSearchQueryChange: method('handleStickerSearchQueryChange') } : {}).Session :
    compile(`${constant}\nclass Page {\n${names.map(method).join('\n')}\n}`, 'Page',
    { ...bindings, StickerCellVO, DOMAIN: 0x0021, TAG: 'PageTest' });
  const page = new Page();
  Object.assign(page, {
    pageLifecycleToken: 1, stickerPanelUseCase: useCase(), showComposerStickerPanel: true,
    activeStickerTabId: 'recent', stickerSearchItems: [], stickerSearchLoading: false,
    emojiSearchLanguageCodes: () => ['ru', 'en']
  });
  if (baseline) Object.assign(page, {
    stickerSearchQuery: '', stickerSearchRequestId: 0, stickerSearchDebounceTimerId: -1
  });
  else {
    const Controller = compile(source, 'ChatStickerSearchController', bindings);
    page.stickerSearchCtrl = new Controller();
  }
  function advance(ms) {
    now += ms;
    for (const [id, timer] of [...timers]) {
      if (timer.at <= now) { timers.delete(id); timer.fn(); }
    }
  }
  return { page, requests, downloads, warnings, uris, timers, useCase, advance,
    query: q => page.handleStickerSearchQueryChange(q), reset: () => page.resetStickerSearchState(),
    queued: id => history.get(id).fn() };
}
function entry(overrides = {}) {
  return { stickerId: '42', remoteFileId: 'remote42', fileId: 21, thumbFileId: 11,
    localPath: '', thumbPath: '', emoji: 'cat', isAnimated: false, isVideo: false,
    width: 512, height: 512, ...overrides };
}
async function results(f, entries = [entry()]) {
  f.query('cats'); f.advance(250);
  assert.equal(f.requests.length, 1);
  f.requests[0].resolve(entries); await turn();
}

test('trim, 250ms trailing debounce, language forwarding and immediate presentation reset', async () => {
  const f = fixture();
  f.page.stickerSearchItems = [entry()]; f.query('  ca  ');
  assert.deepEqual(f.page.stickerSearchItems, []); assert.equal(f.page.stickerSearchLoading, true);
  f.advance(249); assert.equal(f.requests.length, 0);
  f.query('  cats  '); f.advance(249); assert.equal(f.requests.length, 0);
  f.advance(1); assert.equal(f.requests.length, 1);
  assert.equal(f.requests[0].query, 'cats'); assert.deepEqual(f.requests[0].languages, ['ru', 'en']);
  f.requests[0].resolve([]); await turn();
  assert.deepEqual(f.page.stickerSearchItems, []); assert.equal(f.page.stickerSearchLoading, false);
});

test('short query and reset cancel even timer zero; missing use case and inactive panel stay idle', () => {
  for (const value of ['', '  ', ' x ']) {
    const f = fixture(); f.query('cats'); f.query(value); f.advance(250);
    assert.equal(f.requests.length, 0); assert.equal(f.page.stickerSearchLoading, false);
  }
  const f = fixture(); f.query('cats'); f.reset(); f.advance(250);
  assert.equal(f.requests.length, 0); assert.equal(f.timers.size, 0);
  assert.equal(f.page.stickerSearchLoading, false); assert.deepEqual(f.page.stickerSearchItems, []);
  for (const change of [p => p.stickerPanelUseCase = undefined,
    p => p.showComposerStickerPanel = false, p => p.activeStickerTabId = 'gifs']) {
    const f = fixture(); change(f.page); f.query('cats'); f.advance(250);
    assert.equal(f.requests.length, 0); assert.equal(f.timers.size, 0);
    assert.equal(f.page.stickerSearchLoading, false);
  }
});

test('cancelled queued timer cannot clear the newer timer or dispatch after reset', () => {
  const f = fixture(); f.query('cats'); f.query('dogs');
  f.queued(0); f.reset();
  assert.equal(f.timers.size, 0, 'reset must cancel the actual current timer');
  f.queued(1); assert.equal(f.requests.length, 0);
});

test('request identity rejects same-query A-B-A success and failure without clearing current loading', async () => {
  for (const outcome of ['resolve', 'reject']) {
    const f = fixture();
    for (const q of ['cats', 'dogs', 'cats']) { f.query(q); f.advance(250); }
    f.requests[0][outcome](outcome === 'resolve' ? [entry()] : new Error('old'));
    f.requests[1][outcome](outcome === 'resolve' ? [entry()] : new Error('old'));
    await turn();
    assert.equal(f.page.stickerSearchLoading, true); assert.deepEqual(f.page.stickerSearchItems, []);
    assert.equal(f.downloads.length, 0); assert.equal(f.warnings.length, 0);
    f.requests[2].resolve([]); await turn(); assert.equal(f.page.stickerSearchLoading, false);
  }
});

const invalidations = [
  ['reset', f => f.reset()], ['new query', f => f.query('dogs')],
  ['lifecycle', f => f.page.pageLifecycleToken++],
  ['hidden panel', f => f.page.showComposerStickerPanel = false],
  ['GIF tab', f => f.page.activeStickerTabId = 'gifs'],
  ['use-case replacement', f => f.page.stickerPanelUseCase = f.useCase()]
];
for (const [name, invalidate] of invalidations) {
  test(`pre-dispatch fence: ${name}`, () => {
    const f = fixture(); f.query('cats'); invalidate(f); f.advance(250);
    assert.equal(f.requests.length, name === 'new query' ? 1 : 0);
    if (name === 'new query') assert.equal(f.requests[0].query, 'dogs');
  });
  for (const outcome of ['resolve', 'reject']) {
    test(`late search ${outcome}: ${name}`, async () => {
      const f = fixture(); f.query('cats'); f.advance(250); invalidate(f);
      const items = f.page.stickerSearchItems, loading = f.page.stickerSearchLoading;
      f.requests[0][outcome](outcome === 'resolve' ? [entry()] : new Error('stale'));
      await turn();
      assert.equal(f.page.stickerSearchItems, items); assert.equal(f.page.stickerSearchLoading, loading);
      assert.equal(f.downloads.length, 0); assert.equal(f.warnings.length, 0);
    });
  }
  for (const stage of ['thumbnail', 'full file']) {
    test(`late preview ${stage}: ${name}`, async () => {
      const f = fixture(); await results(f, [entry(), entry({ stickerId: '43', thumbFileId: 12 })]);
      const cell = f.page.stickerSearchItems[0];
      if (stage === 'full file') { f.downloads[0].resolve('/thumb'); await turn(); }
      const index = f.downloads.length - 1;
      assert.equal(f.downloads[index].id, stage === 'thumbnail' ? 11 : 21);
      const thumb = cell.thumbPathUri, uri = cell.pathUri, conversions = f.uris.length;
      invalidate(f); f.downloads[index].resolve('/late'); await turn();
      assert.equal(cell.thumbPathUri, thumb, 'late thumbnail must not mutate the published VO');
      assert.equal(cell.pathUri, uri, 'late full file must not mutate the published VO');
      assert.equal(f.downloads.length, index + 1, 'stale continuation must not download the next file');
      assert.equal(f.uris.length, conversions, 'stale paths must not even reach URI conversion');
    });
  }
}

test('real page mapping and sequential previews preserve cached/static/animated/video policy', async () => {
  const f = fixture(); await results(f, [
    entry({ stickerId: 'cached', localPath: '/cached', thumbPath: '/cached-thumb' }),
    entry(), entry({ stickerId: 'animated', isAnimated: true, fileId: 22, thumbFileId: 12 }),
    entry({ stickerId: 'video', isVideo: true, fileId: 23, thumbFileId: 13 }),
    entry({ stickerId: 'no-files', fileId: 0, thumbFileId: 0 })
  ]);
  assert.equal(f.page.stickerSearchLoading, false);
  const cells = f.page.stickerSearchItems;
  assert.equal(cells[0].pathUri, 'file:///cached'); assert.equal(cells[0].thumbPathUri, 'file:///cached-thumb');
  assert.equal(cells[1].remoteFileId, 'remote42'); assert.equal(cells[1].width, 512);
  for (const [index, id, p] of [[0, 11, '/thumb'], [1, 21, '/full'], [2, 12, ''], [3, 13, '/video-thumb']]) {
    assert.equal(f.downloads.length, index + 1); assert.equal(f.downloads[index].id, id);
    assert.equal(f.downloads[index].owner, f.requests[0].owner);
    f.downloads[index].resolve(p); await turn();
  }
  assert.equal(f.downloads.length, 4); assert.equal(cells[1].previewUri(), 'file:///full');
  assert.equal(cells[2].previewUri(), ''); assert.equal(cells[3].previewUri(), 'file:///video-thumb');
});

test('current search failure settles loading, warns once and permits retry', async () => {
  const f = fixture(); f.query('cats'); f.advance(250);
  f.requests[0].reject(new Error('offline')); await turn();
  assert.equal(f.page.stickerSearchLoading, false); assert.equal(f.warnings.length, 1);
  assert.deepEqual(f.page.stickerSearchItems, []);
  f.query('cats'); f.advance(250); f.requests[1].resolve([]); await turn();
  assert.equal(f.page.stickerSearchLoading, false); assert.equal(f.requests.length, 2);
});

test('preview rejection is handled without dropping results or reviving stale loading', async () => {
  for (const stale of [false, true]) {
    const f = fixture(); await results(f);
    const items = f.page.stickerSearchItems;
    if (stale) f.query('dogs');
    f.downloads[0].reject(new Error('download failed')); await turn();
    assert.equal(f.page.stickerSearchLoading, stale);
    assert.equal(f.warnings.length, stale ? 0 : 1);
    if (!stale) assert.equal(f.page.stickerSearchItems, items);
    assert.equal(f.downloads.length, 1);
  }
});

async function main() {
  const selected = tests.filter(t => !option('--case') || t.name.includes(option('--case')));
  assert.ok(selected.length > 0, 'No behavioral tests selected');
  let failed = 0;
  for (const { name, run } of selected) {
    try { await run(); console.log('PASS', name); }
    catch (error) {
      if (error.code !== 'ERR_ASSERTION') throw error;
      failed++; console.log('FAIL', name, error.message);
    }
  }
  console.log(JSON.stringify({ tests: selected.length, passed: selected.length - failed, failed,
    baseline: !!baseline, mutant: mutant || null,
    pageHash: createHash('sha256').update(pageSource).digest('hex'),
    controllerHash: createHash('sha256').update(controllerSource).digest('hex') }));
  process.exitCode = failed ? 1 : 0;
}
require('./host-test-completion.cjs').guardSuite(main()).catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
