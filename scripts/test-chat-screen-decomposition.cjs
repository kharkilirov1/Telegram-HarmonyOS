#!/usr/bin/env node
// Actual production imports, delegates, reactive aliases and render callbacks.
// All behavioral children use actual exported functions behind actual Session
// delegates. Native UI delivery, transport and platform objects remain fixtures.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { spawnSync } = require('node:child_process');
const { createHash } = require('node:crypto');
const defaultSource = require('./chat-screen-source.cjs');
// The CLI and mutation probes run the same gate with an explicit source loader.
function run({ sourceLoader = defaultSource, projectRoot = path.resolve(__dirname, '..'),
  staticOnly = process.argv.includes('--static-only'), report = true } = {}) {
const source = sourceLoader;
const root = path.resolve(projectRoot);
const pageFile = path.join(root, 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets');
const graph = source.sourceGraph(pageFile);
const results = [];
function check(name, run) {
  run(); results.push(name);
}
const models = { chrome: 'ChatChromeState', composer: 'ChatComposerState', panels: 'ChatPanelsState',
  timeline: 'ChatTimelineViewState', media: 'ChatMediaViewState', pinnedSearch: 'ChatPinnedSearchState' };
const at = name => {
  const found = [...graph.files].find(([file]) => path.basename(file) === name + '.ets');
  assert.ok(found, `actual imported owner ${name}`); return found[1];
};
const controllerBridges = {
  goToOlderSearchResult: ['searchCtrl', 'goToOlderResult', 'ChatSearchController'],
  goToNewerSearchResult: ['searchCtrl', 'goToNewerResult', 'ChatSearchController'],
  openChannelShare: ['messageActionsCtrl', 'openForwardTargetPickerForEntry', 'ChatMessageActionsController']
};
// These inputs trigger observed presentation dependencies; the Session API
// deliberately takes only the preceding operational arguments.
const presentationInputs = {
  messageActionItems: ['forwardState'], messageActionsPopupHeight: ['forwardState'],
  isMediaDownloadPending: ['downloadRevision'], isMediaDownloadFailed: ['downloadRevision'],
  effectiveAlbumPhotoDownloading: ['downloadRevision'], effectiveAlbumPhotoDownloadFailed: ['downloadRevision']
};
function verifyBindingPayloads(candidateGraph) {
  const code = [...candidateGraph.files].find(([file]) => path.basename(file) === 'ChatScreenViewBindings.ets')[1];
  const js = stripTypeScriptTypes(code.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export /gm, ''), { mode: 'transform' });
  const Bindings = new Function(js + '\nreturn ChatScreenViewBindings;')();
  const calls = [], returned = Symbol('Session return value'), session = {};
  const capture = target => (...args) => { calls.push({ target, args }); return returned; };
  for (const name of candidateGraph.delegates.keys()) session[name] = capture('session.' + name);
  for (const [field, method] of Object.values(controllerBridges)) {
    session[field] ??= {}; session[field][method] = capture(field + '.' + method);
  }
  const bindings = new Bindings(session);
  const names = new Set([...candidateGraph.files].filter(([file]) => /^TgChat/.test(path.basename(file)))
    .flatMap(([, text]) => [...text.matchAll(/this\.bindings\.(\w+)\(/g)].map(match => match[1])));
  for (const name of names) {
    const signature = code.match(new RegExp(`^  ${name}\\(([^)]*)\\): (.*?) \\{`, 'm'));
    assert.ok(signature, `actual ViewBindings signature: ${name}`);
    const parameters = signature[1].trim() ? signature[1].split(',').map(item => item.trim().match(/^(\w+)\??\s*:/)?.[1]) : [];
    assert.ok(parameters.every(Boolean), `named ViewBindings inputs: ${name}`);
    const bridge = controllerBridges[name];
    const expectedNames = bridge ? (name === 'openChannelShare' ? ['entry'] : []) : candidateGraph.delegates.get(name).arguments;
    assert.deepEqual(parameters, [...expectedNames, ...(presentationInputs[name] || [])],
      `ViewBindings input contract: ${name}`);
    const payloads = parameters.map((parameter, index) => Object.freeze({ name, parameter, index }));
    const expectedArgs = payloads.slice(0, expectedNames.length);
    const target = bridge ? bridge[0] + '.' + bridge[1] : 'session.' + name;
    if (bridge) expectedArgs.push(session);
    calls.length = 0;
    const result = bindings[name](...payloads);
    assert.equal(calls.length, 1, `ViewBindings forwards exactly once: ${name}`);
    assert.equal(calls[0].target, target, `ViewBindings target: ${name}`);
    assert.equal(calls[0].args.length, expectedArgs.length, `ViewBindings payload arity: ${name}`);
    for (let index = 0; index < expectedArgs.length; index++) {
      assert.strictEqual(calls[0].args[index], expectedArgs[index], `ViewBindings payload order/identity: ${name} argument ${index}`);
    }
    if (signature[2] !== 'void') assert.strictEqual(result, returned, `ViewBindings return value: ${name}`);
  }
  return names.size;
}
let bindingPayloadChecks = 0;
check('all original methods and UI events are bound to actual exported functions', () => {
  assert.equal(graph.delegates.size, 287);
  assert.match(graph.page, /new ChatScreenSession\(\s*this\.view/);
  assert.match(graph.page, /this\.session\.aboutToAppear\(\)/);
  assert.match(graph.page, /this\.session\.aboutToDisappear\(\)/);
  for (const name of ['handleNavReady', 'handleNavShown', 'handleNavBackPressed']) {
    assert.ok(graph.delegates.has(name));
    assert.ok(graph.page.includes(`this.session.${name}(`), `page invokes ${name}`);
  }
});
check('bounded composition has no retained page implementations', () => {
  assert.ok(graph.page.split('\n').length <= 700);
  for (const [file, text] of graph.files) {
    assert.ok(text.split('\n').length <= 500, `bounded actual owner ${path.basename(file)}`);
    for (const item of source.imports(text)) assert.doesNotMatch(item.specifier, /chat-screen-source|\/scripts\/|\.cjs$/,
      'production owners must not import test source helpers');
  }
  for (const name of ['persistDraft', 'handleSendMessage', 'rebuildTimeline', 'bindChatRoute', 'jumpToMessageId']) {
    assert.doesNotMatch(graph.page, new RegExp(`^  (?:private )?${name}\\(`, 'm'));
  }
});
check('all 114 reactive fields have one backing model and bidirectional Context aliases', () => {
  const aggregate = at('ChatScreenViewState'), context = at('ChatScreenContext');
  const fields = [];
  const bindings = { $r: id => ({ id }), NavPathStack: class {} };
  for (const [slice, model] of Object.entries(models)) {
    const code = at(model);
    assert.match(code, /@ObservedV2/);
    assert.match(aggregate, new RegExp(`readonly ${slice}: ${model} = new ${model}\\(\\)`));
    for (const match of code.matchAll(/@Trace (\w+):/g)) fields.push({ slice, name: match[1] });
    for (const match of code.matchAll(/= ([A-Z]\w+)\.([A-Za-z]\w*)/g)) {
      bindings[match[1]] ??= {}; bindings[match[1]][match[2]] = match[1] + '.' + match[2];
    }
    const js = stripTypeScriptTypes(code.replace(/^import[\s\S]*?;\s*/gm, '').replace(/@ObservedV2\s*|@Trace\s*|^export /gm, ''), { mode: 'transform' });
    bindings[model] = new Function(...Object.keys(bindings), js + `\nreturn ${model};`)(...Object.values(bindings));
  }
  assert.equal(fields.length, 114);
  assert.equal(new Set(fields.map(field => field.name)).size, 114);
  const aggregateJs = stripTypeScriptTypes(aggregate.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export /gm, ''), { mode: 'transform' });
  const View = new Function(...Object.keys(bindings), aggregateJs + '\nreturn ChatScreenViewState;')(...Object.values(bindings));
  const contextJs = stripTypeScriptTypes(context.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export /gm, ''), { mode: 'transform' });
  const Context = new Function(contextJs + '\nreturn ChatScreenContext;')();
  const host = Object.create(Context.prototype); host.view = new View();
  for (const { slice, name } of fields) {
    assert.match(context, new RegExp(`get ${name}\\(\\)[^\\n]*return this\\.view\\.${slice}\\.${name};`));
    assert.match(context, new RegExp(`set ${name}\\([^\\n]*\\{[^}]*this\\.view\\.${slice}\\.${name} = value;`));
    const first = Symbol(name), second = Symbol(name + 'view');
    host[name] = first; assert.equal(host.view[slice][name], first, `${name} write reaches observed state`);
    host.view[slice][name] = second; assert.equal(host[name], second, `${name} read follows observed state`);
  }
});
check('each child is called from an imported rendered owner', () => {
  for (const child of ['TgChatTimelineViewport', 'TgChatTimelineRow', 'TgChatComposerDock', 'TgChatKeyboardPanels',
    'TgChatMessageActionsPopup', 'TgChatPinnedOverlay', 'TgChatMediaOverlay']) {
    const owner = [...graph.files].find(([file, text]) => path.basename(file) !== child + '.ets' &&
      source.imports(text).some(item => item.binding.includes(child)) && text.includes(child + '('));
    assert.ok(owner, `rendered import chain for ${child}`);
  }
  const bindingSource = at('ChatScreenViewBindings');
  for (const [file, text] of graph.files) {
    if (!/^TgChat/.test(path.basename(file))) continue;
    for (const match of text.matchAll(/this\.bindings\.(\w+)\(/g)) {
      const name = match[1];
      if (controllerBridges[name]) {
        const [field, method, controller] = controllerBridges[name];
        assert.match(bindingSource, new RegExp(`^  ${name}\\([^\\n]+this\\.session\\.${field}\\.${method}\\([^\\n]*this\\.session\\)`, 'm'));
        assert.match(at('ChatScreenContext'), new RegExp(`${field}: ${controller} = new ${controller}\\(\\)`));
        const code = source.raw(path.join(path.dirname(pageFile), controller + '.ets'));
        assert.match(code, new RegExp(`^  (?:private )?${method}\\(`, 'm'));
      } else {
        assert.ok(graph.delegates.has(name), `render callback has Session delegate: ${name}`);
        assert.match(bindingSource, new RegExp(`^  ${name}\\([^\\n]+this\\.session\\.${name}\\(`, 'm'));
      }
    }
  }
  bindingPayloadChecks = verifyBindingPayloads(graph);
  assert.match(at('TgChatTimelineViewport'), /LazyForEach\([\s\S]*entry\.key/);
  assert.match(at('TgChatTimelineRow'), /\.enabled\(item\.enabled\)|TgChatMessageActionsPopup\(/);
  assert.match(at('TgChatMessageActionsPopup'), /\.enabled\(item\.enabled\)/);
});
check('swapped new UI event delegate arguments are rejected without changing production files', () => {
  let engaged = 0;
  assert.throws(() => source.sourceGraph(pageFile, { transform(text, file) {
    if (path.basename(file) !== 'ChatScreenSession.ets') return text;
    const changed = text.replace('delegateHandleTimelineScrollIndex(this, start, end)', 'delegateHandleTimelineScrollIndex(this, end, start)');
    if (changed !== text) engaged++; return changed;
  } }), /Session must forward every argument in order: handleTimelineScrollIndex/);
  assert.equal(engaged, 1);
});
check('lost composer text payload is rejected by actual ViewBindings execution', () => {
  let engaged = 0;
  const mutant = source.sourceGraph(pageFile, { transform(text, file) {
    if (path.basename(file) !== 'ChatScreenViewBindings.ets') return text;
    const changed = text.replace('this.session.handleComposerTextChange(value)', "this.session.handleComposerTextChange('')");
    if (changed !== text) engaged++; return changed;
  } });
  assert.equal(engaged, 1);
  assert.throws(() => verifyBindingPayloads(mutant), /ViewBindings payload order\/identity: handleComposerTextChange argument 0/);
});
check('disconnected Session delegation is rejected without changing production files', () => {
  let engaged = 0;
  assert.throws(() => source.sourceGraph(pageFile, { transform(text, file) {
    if (path.basename(file) !== 'ChatScreenSession.ets') return text;
    const changed = text.replace(/(isRouteContextCurrent\([^\n]*\{)[^\n]*\}/, '$1 return true; }');
    if (changed !== text) engaged++; return changed;
  } }), /Session must delegate|actual delegate call/);
  assert.equal(engaged, 1);
});
function cacheRuntime(mutant = false) {
  const code = stripTypeScriptTypes(at('ChatScrollPositionCache').replace(/^export /gm, ''), { mode: 'transform' });
  const Cache = new Function(code + '\nreturn ChatScrollPositionCache;')();
  let mutations = 0;
  const { Session } = source.compileExports(graph, { ChatScrollPositionCache: Cache,
    hilog: { info() {} }, ScrollAlign: { START: 'start' } }, text => {
    if (!mutant || !text.includes('ChatScrollPositionCache.positions.get(chatId)')) return text;
    assert.equal(text.split('ChatScrollPositionCache.positions.get(chatId)').length - 1, 1);
    mutations++;
    return text.replace('ChatScrollPositionCache.positions.get(chatId)', 'new Map<number, string>().get(chatId)');
  });
  assert.equal(mutations, mutant ? 1 : 0);
  const entries = [{ key: 'first' }, { key: 'saved' }, { key: 'last' }];
  const dataSource = { totalCount: () => entries.length, getData: index => entries[index],
    findIndexByKey: key => entries.findIndex(entry => entry.key === key) };
  const first = Object.assign(new Session(), { currentScrollChatId: 7, lastVisibleStartIndex: 1, dataSource });
  first.saveScrollPosition(); assert.equal(Cache.positions.get(7), 'saved');
  const scheduled = [], scrolls = [], rechecks = [], unlocks = [];
  const second = Object.assign(new Session(), { activeChatId: 7, dataSource, unreadRestoreIndex: -1,
    awaitingInitialTimeline: true, guardProgrammaticScroll() {},
    armAutoPaginationUnlock: (...args) => unlocks.push(args),
    scheduleLifecycleTask: (delay, task) => scheduled.push({ delay, task }),
    schedulePaginationRecheck: delay => rechecks.push(delay),
    listScroller: { scrollToIndex: (...args) => scrolls.push(args) } });
  second.computeInitialIndex(entries.length);
  assert.equal(second.listInitialIndex, 1, 'a new Session reads the actual shared cache');
  second.restoreScrollPosition(); assert.equal(second.awaitingInitialTimeline, false);
  assert.equal(scheduled.length, 1); assert.equal(scheduled[0].delay, 16);
  scheduled[0].task(); assert.deepEqual(scrolls, [[1, false, 'start']]);
  assert.deepEqual(unlocks, [[1, 'initialRestore']]); assert.equal(rechecks.length, 1);
  second.activeChatId = 8; second.computeInitialIndex(entries.length);
  assert.equal(second.listInitialIndex, 2, 'another chat falls back to its own bottom');
}
check('actual shared cache and Session save/compute/restore delegates preserve scroll restoration', () => cacheRuntime());
check('disconnecting the actual shared cache read fails restoration behavior', () => {
  assert.throws(() => cacheRuntime(true), /a new Session reads the actual shared cache/);
});
function child(name, script, flags = [], negative = false) {
  const result = spawnSync(process.execPath, ['--disable-warning=ExperimentalWarning', path.join(__dirname, script), '--actual-delegates', ...flags],
    { cwd: root, encoding: 'utf8', windowsHide: true, maxBuffer: 16 * 1024 * 1024 });
  assert.ifError(result.error);
  const output = result.stdout + result.stderr;
  if (negative) {
    assert.equal(result.status, 1, `${name} must fail a behavioral assertion\n${output.slice(-1200)}`);
    assert.doesNotMatch(output, /HARNESS_ERROR|TypeError|ReferenceError|SyntaxError/);
  } else assert.equal(result.status, 0, `${name}\n${output.slice(-2000)}`);
  results.push(name);
}
if (!staticOnly) {
  child('actual Session lifecycle/route/account/draft behavior', 'test-chat-lifecycle-account-scope.cjs');
  child('actual Session text/media send completion behavior', 'test-send-cleanup-ownership.cjs');
  child('actual Session sticker search request and callback behavior', 'test-chat-sticker-search-controller.cjs');
  child('actual Session window/search teardown and stale callback behavior', 'test-ui-window-search-lifecycle.cjs');
  for (const mutant of ['close-owner', 'restore-owner', 'navigation-owner', 'reappear-owner'])
    child('negative ' + mutant, 'test-chat-lifecycle-account-scope.cjs', ['--mutant=' + mutant], true);
  child('negative disconnected search delegate', 'test-chat-sticker-search-controller.cjs', ['--mutant', 'page-wiring', '--case', 'trim'], true);
  child('negative stale search callback', 'test-ui-window-search-lifecycle.cjs', ['--mutant=search-generation'], true);
  child('negative missing search teardown', 'test-ui-window-search-lifecycle.cjs', ['--mutant=search-dispose'], true);
  child('negative send operation retirement', 'test-send-cleanup-ownership.cjs', ['--mutant-session-send'], true);
}
check('all actually read production sources remain byte-for-byte unchanged', () => {
  for (const [file, text] of graph.files) assert.equal(source.raw(file), text, file);
});
const summary = { suite: 'chat-screen-decomposition', checks: results.length, passed: results.length,
  failed: 0, actualDelegates: graph.delegates.size, actualOwners: graph.files.size,
  bindingPayloadChecks,
  sources: Object.fromEntries([...graph.files].map(([file, text]) => [path.relative(root, file), createHash('sha256').update(text).digest('hex')])),
  exclusions: ['ArkUI native rendering/delivery', 'SDK object initialization', 'TDLib native transport', 'device visual acceptance'] };
if (report) console.log(JSON.stringify(summary));
return summary;
}
module.exports = { run };
if (require.main === module) run();
