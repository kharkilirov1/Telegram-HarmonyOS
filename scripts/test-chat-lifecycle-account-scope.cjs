#!/usr/bin/env node
// Node >=24. Wave18 lifecycle/route integration witness; run from any directory.
// Complete actual page methods + real AppStore scopes + generation-fenced
// TdGatewayAdapter. No production edits, builds, device, network or real account.
// Runtime lookup, native transport/serialization, reply presentation, navigation
// stack, timers and unrelated UI/media teardown are explicit fixture boundaries.
// Also exports the exact fixture for the draft suite; importing never runs tests.
// --mutant=close-owner|restore-owner|navigation-owner|reappear-owner: negative controls.
// Wave18: --mutant=absent-snapshot|settled-no-correction|coalesced-capture.
// --known-gap=reappear: historical CLI alias for the focused reappear regressions
// (also in the normal suite); expects PASS now, never masks a known failure.
const { readChatSource } = require("./chat-screen-source.cjs");
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const { AsyncLocalStorage } = require('node:async_hooks');
const root = path.resolve(__dirname, '../entry/src/main/ets');
// Slow-mode imports execute real production code; only the SDK uptime service is a fixture.
const slowmodeFixtureDeps = (() => {
  const etsRoot = path.resolve(__dirname, '../entry/src/main/ets');
  function module(file, deps = {}) {
    const source = fs.readFileSync(path.join(etsRoot, file), 'utf8');
    const names = [...source.matchAll(/^export\s+(?:class|function)\s+(\w+)/gm)].map(match => match[1]);
    const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, ''), { mode: 'transform' });
    return new Function(...Object.keys(deps), js + `; return {${names.join(',')}};`)(...Object.values(deps));
  }
  const clock = module('core/utils/SlowmodeClock.ets', { systemDateTime: { TimeType: { STARTUP: 0 }, getUptime: () => 0 } });
  return { ...clock, ...module('ui/pages/chat/ChatSlowmodeController.ets', {
    ...clock, navigationUIState: { applicationForeground: true }
  }) };
})();
Object.assign(globalThis, slowmodeFixtureDeps);

const pageFile = 'ui/pages/chat/TgChatScreenPage.ets';
const sources = {};
const snapshots = new Map();
const methodHashes = {};
const executedMethodHashes = {};
const executedMethodSources = {};
const standalone = require.main === module;
const mutant = standalone ? process.argv.find(arg => arg.startsWith('--mutant='))?.slice(9) ?? null : null;
const knownGap = standalone ? process.argv.find(arg => arg.startsWith('--known-gap='))?.slice(12) ?? null : null;
const reappearWitnesses = [];
const mutationSites = [];
const expectedMutationSites = { 'close-owner': 1, 'restore-owner': 4, 'navigation-owner': 1,
  'reappear-owner': 1, 'absent-snapshot': 1, 'settled-no-correction': 2, 'coalesced-capture': 2 };
const methods = ['aboutToAppear', 'bindChatRoute', 'activateChatRoute', 'isRouteContextCurrent',
  'showOwnedChatRoute', 'startOwnedChatData', 'createChatRouteParams', 'getChatRouteToken', 'getActiveChatId', 'hasActiveChatState',
  'maybeMarkChatRead', 'showChatOpenFailure', 'scheduleHistoryLoad', 'requestHistoryWithRetry',
  'shouldRetryHistoryLoad', 'captureInitialHistorySnapshot', 'buildInitialHistoryParams', 'shouldReactToStoreChange', 'syncOwnedChatContext', 'resolveOwnedChatTitle',
  'aboutToDisappear', 'handleBackPress', 'ownsNavigationContext', 'clearOwnedChatContext',
  'restoreDraftFromChat', 'persistDraft', 'scheduleDraftDebounce', 'normalizedDraftCustomEmojiEntities',
  'setSendingMessage', 'setCustomEmojiEntities', 'setDraftText', 'setDraftSelection',
  'startReply', 'setReplyMode', 'clearReplyMode', 'clearEditMode', 'clearForwardMode', 'setForwardMode',
  'applyPendingForwardTransferIfNeeded'];
const hash = source => createHash('sha256').update(source).digest('hex');
function read(relative) {
  if (!snapshots.has(relative)) {
    const source = readChatSource(path.join(root, relative), 'utf8');
    snapshots.set(relative, source);
    sources[relative] = hash(source);
  }
  return snapshots.get(relative);
}
function load(relative, deps = {}) {
  const source = read(relative);
  const names = [...source.matchAll(/^export\s+(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  // Import stripping is the isolation boundary: native runtime modules never load.
  const code = source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(code, { mode: 'transform' }) +
    `\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
function extractMethod(source, name) {
  const matches = [...source.matchAll(new RegExp(
    `^  (?:(?:private|public|protected|async)\\s+)*${name}\\(`, 'gm'))];
  assert.equal(matches.length, 1, `exactly one actual full page method required: ${name}`);
  // Same class-level closing indentation as the draft suite. The entire method,
  // including nested blocks/catches, is retained; Node's TS parser validates it.
  const start = matches[0].index;
  const end = source.indexOf('\n  }', start);
  assert.ok(end > start, `full page method has no closing delimiter: ${name}`);
  const fullMethod = source.slice(start, end + 4);
  methodHashes[name] = hash(fullMethod);
  return fullMethod;
}
function mutateMethod(name, source) {
  function replaceExactly(from, to, label, count = 1) {
    assert.equal(source.split(from).length - 1, count, `mutant anchor count must engage: ${label}`);
    const before = source;
    source = source.replaceAll(from, to);
    assert.notEqual(source, before, `mutant must change the executed method: ${label}`);
    for (let i = 0; i < count; i++) mutationSites.push(`${name}:${label}${count > 1 ? `:${i + 1}` : ''}`);
  }
  if (mutant === 'close-owner' && name === 'aboutToDisappear') {
    replaceExactly('if (route !== undefined) void route.openLease.release();',
      `getTdGatewayAdapter().send(createCloseChatCommand(closingChatId))
          .catch((_: Error) => {});`, 'legacy-global-dispatch');
  }
  if (mutant === 'restore-owner' && name === 'restoreDraftFromChat') {
    replaceExactly('owner === undefined || chatId === 0', 'chatId === 0', 'missing-owner-guard');
    replaceExactly('if (runtime.getStore() !== owner) return;', 'if (false) return;', 'initial-owner-guard');
    replaceExactly('const state = owner.getState();', 'const state = runtime.getStore().getState();', 'legacy-global-state');
    replaceExactly('getAppCoreRuntime() !== runtime || runtime.getStore() !== owner ||',
      'false || false ||', 'prewrite-owner-guard');
  }
  if (mutant === 'navigation-owner' && name === 'ownsNavigationContext') {
    // One exact whole-method replacement, bypassing BOTH clear and visibility
    // callers of this actual guard. No test expectation or fixture is mutated.
    replaceExactly(source, '  private ownsNavigationContext(): boolean { return true; }', 'guard-always-true');
  }
  if (mutant === 'reappear-owner' && name === 'isRouteContextCurrent') {
    replaceExactly('!route.openLease.isReleased()', 'true', 'released-route-reentry');
  }
  if (mutant === 'absent-snapshot' && name === 'captureInitialHistorySnapshot') {
    replaceExactly('if (route.entryUnreadCount === undefined && chat === undefined) return;',
      '// Mutant: freeze a default snapshot while first chat is still unknown.', 'unknown-as-zero');
  }
  if (mutant === 'settled-no-correction' && name === 'requestHistoryWithRetry') {
    // Both completion branches lose the pending correction. Ordinary retry logic
    // stays intact, so a failure must demonstrate the missing correction path.
    replaceExactly("if (this.initialHistoryFallbackRequested && this.initialHistoryParams?.reason === 'aroundUnread') {\n" +
      '          this.scheduleHistoryLoad(chatId, 0);\n          return;\n        }',
      '// Mutant: no correction handoff after default settles.', 'lost-completion-correction', 2);
  }
  if (mutant === 'coalesced-capture' && name === 'activateChatRoute') {
    replaceExactly('this.captureInitialHistorySnapshot(_newState);',
      '// Mutant: defer first-state capture until the coalesced rebuild.', 'remove-raw-capture');
    replaceExactly('const currentState = store.getState();\n              this.rebuildTimeline(currentState);',
      'const currentState = store.getState();\n              this.captureInitialHistorySnapshot(currentState);\n' +
      '              this.rebuildTimeline(currentState);', 'capture-coalesced-state');
  }
  executedMethodHashes[name] = hash(source);
  executedMethodSources[name] = source;
  return source;
}
// Search/window teardown behavior is covered by test-ui-window-search-lifecycle.cjs.
const uiMethods = ['clearSearchFlash', 'closeMessageActions', 'resetBotMenuState', 'resetEmojiSearchState',
  'resetStickerSearchState', 'resetGifSearchState', 'resetPinnedMessageState', 'saveScrollPosition',
  'clearTransientTimers', 'clearPendingMediaDownloads', 'resetPaginationState',
  'teardownMediaPlaybackController', 'setPinnedMessagesListVisible',
  'computeSafeInsets', 'setupMediaPlaybackController', 'refreshChatInputPanel',
  'rebuildTimeline', 'loadPinnedMessage', 'bindWindowSizeListener'];
// Unrelated composer/access factories are binding spies. History/read factories
// below call through to real use cases, and open/close always use the real lease.
const factoryGatewayIndex = {
  createLoadChatAccessUseCase: 1, createSendMessageUseCase: 0, createSendMediaMessageUseCase: 0,
  createEditMessageUseCase: 0, createDeleteMessagesUseCase: 0, createForwardMessagesUseCase: 0,
  createSetChatMuteUseCase: 0, createJoinChatUseCase: 0,
  createSearchChatMessagesUseCase: 0, createPinChatMessageUseCase: 0, createStickerPanelUseCase: 0,
  createLoadChatHistoryUseCase: 1, createLoadRepliedMessageUseCase: 1, createMarkChatReadUseCase: 1
};
const storageNames = ['CHAT_SCREEN_VISIBLE', 'ACTIVE_CHAT_ID', 'ACTIVE_CHAT_TITLE', 'CHAT_NAV_LOCK_UNTIL'];
const tests = [];
const results = [];
const fixtureRuns = [];
const asynchronousErrors = [];
const harnessErrors = [];
const context = new AsyncLocalStorage();
let completed = false;
const test = (name, run) => tests.push({ name, run });
const tick = () => new Promise(resolve => setImmediate(resolve));
function registerAsyncFailure(kind, error) {
  asynchronousErrors.push({ test: context.getStore() ?? null, kind,
    error: error?.stack ?? String(error) });
  process.exitCode = 1;
}
if (standalone) {
  process.on('unhandledRejection', error => registerAsyncFailure('unhandledRejection', error));
  process.on('uncaughtException', error => registerAsyncFailure('uncaughtException', error));
}

async function main({ fixturesOnly = false, draftMutant = false,
  actualDelegates = process.argv.includes('--actual-delegates') } = {}) {
  assert.ok(Number(process.versions.node.split('.')[0]) >= 24, 'Node >=24 required');
  assert.ok(mutant === null || Object.hasOwn(expectedMutationSites, mutant),
    `unknown mutant: ${mutant}`);
  assert.ok(knownGap === null || knownGap === 'reappear', `unknown known-gap probe: ${knownGap}`);
  assert.ok(!mutant || !knownGap, 'mutants and known-gap probes are separate runs');
  const C = load('core/model/AppCommand.ets');
  const A = load('core/model/AppState.ets');
  const td = load('models/td/common/index.ets');
  const accessors = load('core/utils/tdAccessors.ets', td);
  const { ChatOpenLease } = load('domain/usecases/ChatOpenLease.ets', { ...C, ...td });
  const { ChatScreenRouteParams } = load('ui/pages/chat/ChatScreenRouteParams.ets', { ChatOpenLease });
  const ok = () => td.TdObject.fromJSON('{"@type":"ok"}');
  const errors = load('core/model/AppError.ets');
  const port = load('domain/ports/TdGatewayPort.ets', errors);
  const emoji = load('ui/tg_ui/utils/TgCustomEmojiDraftPolicy.ets', C);
  const silentLog = { info() {}, debug() {}, warn() {}, error() {} };
  const { AppStore } = load('core/store/AppStore.ets', { ...A, hilog: silentLog });
  const pageSource = read(pageFile).replaceAll('\r\n', '\n');
  const constants = Object.fromEntries(['CHAT_NAV_TRANSITION_LOCK_MS', 'HISTORY_INITIAL_DELAY_MS',
    'HISTORY_RETRY_BASE_DELAY_MS', 'HISTORY_MAX_RETRY_ATTEMPTS'].map(name => {
    const match = new RegExp(`^const ${name} = (\\d+);$`, 'm').exec(pageSource);
    assert.ok(match, `actual numeric page constant required: ${name}`);
    return [name, Number(match[1])];
  }));
  let pageJs = stripTypeScriptTypes(
    `class PageProbe {
  slowmodeController = new globalThis.ChatSlowmodeController();
  composerSlowmodeSeconds = 0;\n${methods.map(name => mutateMethod(name, extractMethod(pageSource, name))).join('\n')}\n}`,
    { mode: 'transform' });
  assert.equal(mutationSites.length, mutant ? expectedMutationSites[mutant] : 0,
    'all and only selected mutation sites must engage');
  if (draftMutant) {
    const original = extractMethod(pageSource, 'persistDraft');
    const anchor = 'runtime.getStore() !== owner';
    assert.equal(original.split(anchor).length - 1, 2, 'both draft ownership sites engage');
    const mutated = original.replaceAll(anchor, 'false');
    pageJs = stripTypeScriptTypes(`class PageProbe {
  slowmodeController = new globalThis.ChatSlowmodeController();
  composerSlowmodeSeconds = 0;\n${methods.map(name =>
      name === 'persistDraft' ? mutated : extractMethod(pageSource, name)).join('\n')}\n}`, { mode: 'transform' });
    executedMethodHashes.persistDraft = hash(mutated);
  }

  async function fixture(chatId = 7, options = {}) {
    function accountState(label) {
      const state = A.createInitialAppState();
      for (const id of new Set([7, 8, chatId])) {
        state.chats.chats.set(id, Object.assign(new A.Chat(), { id,
          title: `${label} chat`, type: 'private', peerUserId: 55,
          unreadCount: options.unreadCount ?? 0, lastReadInboxMessageId: '100',
          draftText: `${label} 😀 draft`, draftReplyToMessageId: label === 'A' ? '101' : '202',
          draftCustomEmojiEntities: [new C.CustomEmojiTextEntity(2, 2, label === 'A' ? '777' : '888')] }));
        state.messages.messages.set(id, new Map([
          [label === 'A' ? '101' : '202', { id: label === 'A' ? '101' : '202', timestamp: 1,
            fixtureAuthor: `${label} author`, fixturePreview: `${label} reply` }]
        ]));
      }
      return state;
    }
    const store = new AppStore(options.reducer ?? (s => s), accountState('A'), false);
    const f = { store, runtimeStore: store.createScope(), generation: 1, requests: [],
      logs: [], replyCalls: [], presentationReads: [], storeReads: [], timers: new Map(), timerDelays: new Map(),
      storage: new Map(), runtimeError: false, nativeError: false, pops: 0,
      events: [], bindingEntries: [], factoryCalls: [], hookHits: [], gatewayGets: 0,
      heldMethods: new Set(options.heldMethods ?? []), historyCalls: [], pages: [], stackParams: [] };
    fixtureRuns.push({ test: context.getStore(), fixture: f });
    function hook(name) {
      const callback = f[name]; f[name] = undefined;
      if (callback) { f.hookHits.push(name); callback(); }
    }
    function observeReads(scope, label) {
      const getState = scope.getState.bind(scope);
      // Call-through spy; never substitutes/reimplements scope validity logic.
      scope.getState = () => {
        f.storeReads.push(label); const state = getState();
        if (label === 'A') hook('onOwnerState');
        return state;
      };
    }
    observeReads(f.runtimeStore, 'A');
    const hilog = Object.fromEntries(['info', 'debug', 'warn', 'error'].map(level =>
      [level, (...args) => f.logs.push([level, ...args])]));
    const native = { getClientGeneration: () => f.generation, isReady: () => true,
      send(method, payload) {
        assert.ok(['openChat', 'closeChat', 'getUser', 'getChatHistory', 'viewMessages', 'setChatDraft'].includes(method),
          `unexpected fixture transport method: ${method}`);
        const request = { method, payload, generation: f.generation };
        f.requests.push(request);
        if (f.defer || f.heldMethods.has(method)) return new Promise((resolve, reject) => Object.assign(request, { resolve, reject }));
        if (f.nativeError) return Promise.reject(new Error('fixture transport rejected'));
        return Promise.resolve(method === 'getChatHistory'
          ? (f.historyResponse ?? td.TdObject.fromJSON('{"@type":"messages","messages":[]}'))
          : method === 'getUser' ? td.TdObject.fromJSON(`{"@type":"user","id":${payload.userId}}`) : ok());
      } };
    const adapters = load('infra/td/adapter/TdGatewayAdapter.ets', { ...errors, ...port, hilog,
      getTdGateway: () => native,
      serializeCommand: command => ({ method: command.type, params: command.payload }) });
    // Same real adapter captured by production aboutToAppear, BEFORE a switch.
    // Never replace this page capability with a getter for the current account.
    f.originalAdapter = adapters.getTdGatewayAdapter();
    f.runtime = { getStore: () => {
      const captured = f.runtimeStore; hook('onRuntimeStore'); return captured;
    } };
    f.navigation = { activeChatId: chatId, activeChatTitle: 'A chat', activeChatOwnerToken: 0,
      chatScreenVisible: true, chatNavLockUntil: 0 };
    f.chatState = { activeChatId: chatId, activeChatTitle: 'A chat' };
    f.publishNavigation = (id, title, lock = 0, token = 0) => {
      Object.assign(f.navigation, { activeChatId: id, activeChatTitle: title, activeChatOwnerToken: token,
        chatScreenVisible: true, chatNavLockUntil: lock });
      Object.assign(f.chatState, { activeChatId: id, activeChatTitle: title });
      for (const [key, value] of Object.entries({ ACTIVE_CHAT_ID: id, ACTIVE_CHAT_TITLE: title,
        CHAT_SCREEN_VISIBLE: true, CHAT_NAV_LOCK_UNTIL: lock })) f.storage.set(key, value);
    };
    f.publishNavigation(chatId, 'A chat');
    let timerId = 0;
    // Real history/read use cases; empty-response normalization is explicit and
    // cannot fabricate any chat/message update or satisfy a transport assertion.
    const history = load('domain/usecases/loadChatHistory.ets', { ...C, ...td, ...accessors, ...errors, hilog,
      ChatMessagesResetEvent: load('core/model/AppEvent.ets').ChatMessagesResetEvent,
      getEventNormalizer: () => options.eventNormalizer ?? ({ normalize: () => [] }) });
    const markRead = load('domain/usecases/markChatRead.ets', { ...C, ...accessors, ...errors, hilog });
    const factories = Object.fromEntries(Object.keys(factoryGatewayIndex).map(name => [name, (...args) => {
      const call = { name, args }; f.factoryCalls.push(call);
      if (name === 'createLoadChatHistoryUseCase') {
        const actual = history.createLoadChatHistoryUseCase(...args);
        const execute = actual.execute.bind(actual);
        actual.execute = params => { f.historyCalls.push({ ...params }); return execute(params); };
        return actual;
      }
      if (name === 'createMarkChatReadUseCase') return markRead.createMarkChatReadUseCase(...args);
      return call;
    }]));
    const moduleDeps = { ...C, ...errors, ...emoji, ...factories, ...td, ChatScreenRouteParams,
      LoadChatHistoryParams: history.LoadChatHistoryParams,
      hilog, DOMAIN: 0x21, TAG: 'TgChatScreenPage', ...constants,
      localized: (_id, fallback) => fallback, $r: id => ({ id }),
      getAppCoreRuntime: () => {
        if (f.runtimeError) throw new Error('fixture runtime resetting');
        const captured = f.runtime; hook('onRuntimeGet'); return captured;
      },
      getTdGatewayAdapter: () => {
        f.gatewayGets++; const captured = adapters.getTdGatewayAdapter(); hook('onGatewayGet'); return captured;
      },
      ChatAccessController: class { dispose() {} },
      PendingChatUnreadSnapshot: { consume: () => undefined },
      setTimeout: (callback, delay) => { f.timers.set(++timerId, callback); f.timerDelays.set(timerId, delay); return timerId; },
      clearTimeout: id => { f.timerDelays.delete(id); f.timers.delete(id); }, navigationUIState: f.navigation, chatUIState: f.chatState,
      StorageKeys: Object.fromEntries(storageNames.map(k => [k, k])),
      AppStorage: { get: key => f.storage.get(key), set: (key, value) => f.storage.set(key, value) },
      removeWindowSizeListener() {},
      resolveSenderName: (message, state) => {
        f.presentationReads.push({ kind: 'author', state }); return message.fixtureAuthor;
      },
      resolveReplyPreview: (messages, id) => {
        f.presentationReads.push({ kind: 'preview', id }); return messages.get(id)?.fixturePreview ?? '';
      } };
    // Extracted page methods keep real module scope: non-delegate owner helpers are
    // injected from their actual modules instead of being silently absent.
    const topBarPresentation = load('ui/pages/chat/ChatTopBarPresentation.ets', {
      ...A, fileUri: { getUriFromPath: () => '' },
      localized: moduleDeps.localized, localizedPlural: (_id, _count, fallback) => fallback,
      $r: moduleDeps.$r,
      TgChatTopBarSubtitleMode: { Secondary: 'secondary', Online: 'online', Typing: 'typing', Activity: 'activity' },
      TgChatTopBarTrailingAction: { None: 'none', Search: 'search', Avatar: 'avatar' }
    });
    const sourceBoundary = require('./chat-screen-source.cjs');
    const ownerHelpers = sourceBoundary.helperBindings(
      sourceBoundary.sourceGraph(path.join(root, pageFile)),
      { ...moduleDeps, typingActivityRemainingMs: topBarPresentation.typingActivityRemainingMs });
    const deps = { ...moduleDeps, ...ownerHelpers };
    f.transfer = load('ui/pages/chat/PendingForwardTransfer.ets').pendingForwardTransfer;
    const actions = load('ui/pages/chat/ChatMessageActionsController.ets', {
      hilog, localized: deps.localized, $r: deps.$r, pendingForwardTransfer: f.transfer });
    const Page = actualDelegates ? require('./chat-screen-source.cjs').compileExports(
      require('./chat-screen-source.cjs').sourceGraph(path.join(root, pageFile)), deps, undefined,
      Object.fromEntries(Object.entries(executedMethodSources).filter(([name, source]) => hash(source) !== methodHashes[name]))).Session :
      new Function(...Object.keys(deps), pageJs + '\nreturn PageProbe;')(...Object.values(deps));
    f.newPage = () => {
      const p = Object.assign(new Page(), Object.fromEntries(uiMethods.map(name => [name, () => f.events.push(name)])), {
    slowmodeController: new slowmodeFixtureDeps.ChatSlowmodeController(), composerSlowmodeSeconds: 0,
      accountStore: undefined, chatGateway: undefined, routeContext: undefined,
      routeActivated: false, routeDataStarted: false,
      initialHistoryParams: undefined, initialHistoryFallbackRequested: false,
      activeChatId: 0, routeChatId: 0, activeChatTitle: '', routeChatTitle: '',
      pageLifecycleToken: 0, composerDraftText: '', customEmojiDraftEntities: [], replyToMessageId: '0',
      replyToAuthor: '', replyToPreview: '', composerSelectionStart: 0, composerSelectionEnd: 0,
      composerCaretRequestRevision: 0, expectedProgrammaticCustomEmojiText: '',
      isEditingMessage: false, isForwardingMessages: false, forwardingMessageIds: [],
      forwardSourceChatId: 0, forwardTitle: '', forwardPreview: '',
      isClosing: false, pinnedMessagesListVisible: false, draftDebounceTimerId: -1,
      historyFallbackTimerId: -1, rebuildTimerId: -1, paginationRecheckTimerId: -1,
      sendingMessageOperation: 0, pinnedMessageRequestId: 0,
      voiceRecordingCtrl: { dispose() {} }, searchCtrl: { clearPendingTimer() {} },
      mediaDownloadCtrl: { setChangeListener() {} }, replyHydrationCoordinator: { reset() {} },
      messageActionsCtrl: new actions.ChatMessageActionsController()
    });
    const startReply = p.messageActionsCtrl.startReply.bind(p.messageActionsCtrl);
    p.messageActionsCtrl.startReply = (messageId, author, preview, isQuote, host) => {
      f.replyCalls.push({ messageId, author, preview, isQuote });
      return startReply(messageId, author, preview, isQuote, host);
    };
    for (const name of ['syncOwnedChatContext', 'restoreDraftFromChat']) {
      const actual = p[name].bind(p);
      p[name] = (...args) => {
        f.bindingEntries.push({ name, store: p.accountStore, gateway: p.chatGateway,
          routeOwner: p.routeAccountStore });
        return actual(...args);
      };
    }
      p.bindNavigationStack = () => f.stack;
      p.getChatUIContext = () => ({ getPromptAction: () => ({ showToast: data => f.events.push(data.message) }) });
      f.pages.push(p); return p;
    };
    f.stack = { size: () => f.stackParams.length, getParamByIndex: i => f.stackParams[i],
      pop: () => {
        f.pops++;
        if (f.onPop) return f.onPop();
        const route = f.stackParams.pop();
        f.pages.find(p => p.routeContext === route)?.aboutToDisappear();
      } };
    f.newRoute = (id = chatId, title = 'A chat') => new ChatScreenRouteParams(id, title, f.runtimeStore, adapters.getTdGatewayAdapter());
    f.p = f.newPage(); f.route = f.newRoute();
    f.stackParams.push(f.route);
    f.fireHistory = async (p = f.p) => {
      const id = p.historyFallbackTimerId, callback = f.timers.get(id);
      assert.equal(typeof callback, 'function', 'real scheduleHistoryLoad must install its timer');
      f.timers.delete(id); f.timerDelays.delete(id); callback(); await tick(); await tick();
    };
    f.fireRebuild = async (p = f.p) => {
      const id = p.rebuildTimerId, callback = f.timers.get(id);
      assert.equal(typeof callback, 'function', 'actual store subscription must queue the rebuild');
      f.timers.delete(id); f.timerDelays.delete(id); callback(); await tick(); await tick();
    };
    f.opens = () => f.requests.filter(r => r.method === 'openChat');
    f.closes = () => f.requests.filter(r => r.method === 'closeChat');
    f.switchAccount = (revoke = true) => {
      if (revoke) store.resetState();
      f.runtimeStore = new AppStore(s => s, accountState('B'), false).createScope();
      observeReads(f.runtimeStore, 'B');
      f.generation++;
      f.publishNavigation(chatId, 'B chat', 12345);
    };
    if (options.bind !== false) {
      await firstAppear(f);
      assert.equal(f.p.routeActivated, true, 'actual bind/activation completed');
      assert.equal(f.route.openLease.isOpen(), true, 'real TdObject Ok acknowledged by actual lease');
      // Restore tests start from an empty editable UI, not a prebound fake owner.
      f.p.composerDraftText = ''; f.p.customEmojiDraftEntities = []; f.p.replyToMessageId = '0';
      f.p.replyToAuthor = ''; f.p.replyToPreview = ''; f.p.composerCaretRequestRevision = 0;
      f.replyCalls.length = 0; f.presentationReads.length = 0; f.storeReads.length = 0;
      f.startupRequests = f.requests.splice(0);
    }
    return f;
  }
  function draftSnapshot(f) {
    return { text: f.p.composerDraftText, entities: f.p.customEmojiDraftEntities.map(e => [e.offset, e.length, e.customEmojiId]),
      reply: [f.p.replyToMessageId, f.p.replyToAuthor, f.p.replyToPreview],
      modes: [f.p.isEditingMessage, f.p.isForwardingMessages, [...f.p.forwardingMessageIds],
        f.p.forwardSourceChatId, f.p.forwardTitle, f.p.forwardPreview],
      selection: [f.p.composerSelectionStart, f.p.composerSelectionEnd, f.p.composerCaretRequestRevision],
      expectedEmoji: f.p.expectedProgrammaticCustomEmojiText };
  }
  function navigationSnapshot(f) {
    return { navigation: { ...f.navigation }, chatState: { ...f.chatState }, storage: [...f.storage] };
  }
  function assertClosedOnce(f, chatId) {
    assert.equal(f.closes().length, 1, 'actual closeChat transport must engage exactly once');
    assert.deepEqual(f.closes().map(r => [r.payload.chatId, r.generation]), [[chatId, 1]]);
  }
  function assertNoRestore(f, before) {
    assert.deepEqual(draftSnapshot(f), before, 'unowned restore must not import draft/reply/entities or change selection');
    assert.equal(f.replyCalls.length, 0, 'unowned restore must not enter reply controller');
    assert.equal(f.presentationReads.length, 0, 'unowned restore must not resolve reply metadata');
    assert.equal(f.storeReads.includes('B'), false, 'old A page must not even read B state');
  }
  async function firstAppear(f) {
    f.p.aboutToAppear();
    assert.equal(f.p.accountStore, undefined, 'route-less appear cannot bind globals');
    f.p.bindChatRoute(f.route);
    f.p.showOwnedChatRoute();
    await tick(); await tick();
    assert.equal(f.logs.some(log => /Chat route activation failed|Owned chat initialization failed/.test(String(log))), false,
      'complete activation must not hide an exception behind a best-effort catch');
  }

  if (fixturesOnly) return { fixture, C, A, ok, sources, methods, methodHashes, executedMethodHashes,
    mutations: draftMutant ? 2 : 0, loadedSourceStable: () => Object.keys(sources).every(relative =>
      hash(readChatSource(path.join(root, relative), 'utf8')) === sources[relative]) };

  async function lateChatFixture(options = {}) {
    const dto = load('core/model/dto/ChatDto.ets', { ...C, ...accessors, hilog: silentLog });
    const messageDto = load('core/model/dto/MessageDto.ets', { ...td, ...accessors });
    const events = load('core/model/AppEvent.ets', { ...dto, ...messageDto });
    const clone = load('core/utils/stateClone.ets', { ...A, ...C });
    const { chatsReducer } = load('core/reducers/chatsReducer.ets', {
      ...A, ...events, ...clone, ...accessors, DtoChatType: dto.ChatType });
    const messages = load('core/events/normalizers/MessageNormalizer.ets', {
      ...events, ...messageDto, ...td, ...accessors, hilog: silentLog });
    // Actual messages normalizer makes completed history genuinely cached. Other
    // registration domains are not involved; first-chat/read events enter directly.
    const normalizer = load('core/events/EventNormalizer.ets', { ...td, ...accessors, ...messages,
      hilog: silentLog, ...Object.fromEntries(['Auth', 'Chat', 'User', 'File', 'AccentColor', 'Story']
        .map(name => [`register${name}Handlers`, () => {}])) }).getEventNormalizer();
    const f = await fixture(7, { bind: false, heldMethods: ['openChat', 'viewMessages', ...(options.holdHistory ? ['getChatHistory'] : [])],
      reducer: chatsReducer, eventNormalizer: normalizer });
    f.id = -929;
    f.firstState = async (unreadCount = 3, boundary = '303') => {
      const event = Object.assign(new events.NewChatEvent(), { chatId: f.id,
        chatData: Object.assign(new dto.ChatDto(), { id: f.id, title: 'late first state', unreadCount,
          lastReadInboxMessageId: boundary, lastMessage: Object.assign(new dto.ChatLastMessage(), { id: '909' }) }) });
      await f.runtimeStore.dispatch(event);
      return event;
    };
    f.readState = async (unreadCount = 0, boundary = '909') => {
      await f.runtimeStore.dispatch(Object.assign(new events.ChatReadInboxEvent(), {
        chatId: f.id, unreadCount, lastReadInboxMessageId: boundary }));
    };
    if (options.cachedUnread !== undefined) await f.firstState(options.cachedUnread, options.boundary ?? '303');
    f.targetRoute = f.newRoute(f.id, 'late first state');
    f.page = f.newPage(); f.stackParams.push(f.targetRoute);
    f.page.aboutToAppear(); f.page.bindChatRoute(f.targetRoute); assert.equal(f.page.showOwnedChatRoute(), true);
    await tick();
    f.resolveOpen = async () => { f.opens()[0].resolve(ok()); await tick(); await tick(); };
    // Twelve real message DTOs avoid the independent short-page top-up path.
    f.historyResponse = td.TdObject.fromJSON(JSON.stringify({ '@type': 'messages', total_count: 12,
      messages: Array.from({ length: 12 }, (_, i) => ({ '@type': 'message', id: 910 + i, chat_id: f.id, date: 1,
        sender_id: { '@type': 'messageSenderChat', chat_id: f.id },
        content: { '@type': 'messageText', text: { '@type': 'formattedText', text: 'history fixture', entities: [] } } })) }));
    f.historyRequests = () => f.requests.filter(r => r.method === 'getChatHistory');
    f.assertHistory = expected => {
      assert.deepEqual(f.historyCalls.map(p => [p.fromMessageId, p.offset, p.limit, p.reason]), expected);
      assert.deepEqual(f.historyRequests().map(r => [r.payload.fromMessageId, r.payload.offset, r.payload.limit]),
        expected.map(p => p.slice(0, 3)));
    };
    return f;
  }

  test('actual bind captures immutable owner and gateway before sync/restore', async () => {
    const f = await fixture(7, { bind: false }); await firstAppear(f);
    assert.deepEqual(f.bindingEntries.slice(0, 2).map(e => e.name), ['syncOwnedChatContext', 'restoreDraftFromChat']);
    for (const entry of f.bindingEntries) {
      assert.equal(entry.store, f.runtimeStore);
      assert.equal(entry.gateway, f.originalAdapter);
      assert.equal(entry.routeOwner, f.runtimeStore);
    }
    assert.equal(f.gatewayGets, 0, 'bind uses captured route gateway, never a global getter');
    assert.equal(f.factoryCalls.length, Object.keys(factoryGatewayIndex).length);
    for (const { name, args } of f.factoryCalls) {
      const index = factoryGatewayIndex[name];
      assert.equal(args[index], f.originalAdapter, name);
      if (index === 1) assert.equal(args[0], f.runtimeStore, name);
    }
    assert.equal(f.p.composerDraftText, 'A 😀 draft');
    assert.deepEqual(draftSnapshot(f).reply, ['101', 'A author', 'A reply']);
    assert.equal(f.route.openLease.isOpen(), true);
    assert.equal(f.opens().length, 1);
    assert.equal(f.events.filter(e => e === 'bindWindowSizeListener').length, 1);
    assert.equal(f.logs.some(log => String(log).includes('activation failed')), false);
  });
  for (const boundary of ['account-switch', 'scope-invalidation', 'runtime-error']) {
    test(`first bind rejects ${boundary} before any owned effects`, async () => {
      const f = await fixture(7, { bind: false });
      if (boundary === 'account-switch') f.switchAccount(false);
      if (boundary === 'scope-invalidation') f.store.invalidateScopes();
      if (boundary === 'runtime-error') f.runtimeError = true;
      const before = navigationSnapshot(f);
      f.p.aboutToAppear(); f.p.bindChatRoute(f.route); await tick();
      assert.equal(f.p.routeContext, undefined);
      assert.equal(f.p.accountStore, undefined);
      assert.equal(f.p.chatGateway, undefined);
      assert.equal(f.bindingEntries.length, 0);
      assert.equal(f.factoryCalls.length, 0); assert.equal(f.requests.length, 0);
      assert.deepEqual(navigationSnapshot(f), before);
    });
  }
  for (const mode of ['edit', 'forward']) for (const text of ['', 'unsent buffer']) {
    test(`${mode} mode with ${text ? 'nonempty' : 'empty'} buffer is preserved by restore`, async () => {
      const f = await fixture(); f.p.composerDraftText = text;
      f.p.isEditingMessage = mode === 'edit'; f.p.isForwardingMessages = mode === 'forward';
      if (mode === 'forward') Object.assign(f.p, { forwardingMessageIds: ['909'], forwardSourceChatId: 8,
        forwardTitle: 'forward title', forwardPreview: 'forward preview' });
      const before = draftSnapshot(f); f.p.restoreDraftFromChat(); assertNoRestore(f, before);
      assert.equal(f.storeReads.length, 0, 'mode guard must run before even reading draft state');
    });
  }
  for (const getter of ['onRuntimeGet', 'onRuntimeStore', 'onOwnerState']) {
    test(`restore refuses account switch during ${getter}`, async () => {
      const f = await fixture(), before = draftSnapshot(f);
      f[getter] = () => f.switchAccount(false);
      f.p.restoreDraftFromChat();
      assert.deepEqual(f.hookHits, [getter], 'injected boundary must actually engage');
      assertNoRestore(f, before);
    });
  }
  test('same-account restore reads page chat, not a different global navigation chat', async () => {
    const f = await fixture(); f.store.getState().chats.chats.get(8).draftText = 'other chat draft';
    f.publishNavigation(8, 'new A chat', 23456); const before = navigationSnapshot(f);
    f.p.restoreDraftFromChat();
    assert.equal(f.p.composerDraftText, 'A 😀 draft');
    assert.deepEqual(draftSnapshot(f).reply, ['101', 'A author', 'A reply']);
    assert.deepEqual(navigationSnapshot(f), before);
  });
  test('retired captured client blocks actual disappearance despite same current account scope', async () => {
    const f = await fixture(); f.generation++;
    // Avoid draft-save acquisition so this witnesses close capability fencing.
    f.p.composerDraftText = 'A 😀 draft'; f.p.replyToMessageId = '101';
    f.p.customEmojiDraftEntities = f.store.getState().chats.chats.get(7).draftCustomEmojiEntities.slice();
    f.p.aboutToDisappear(); await tick(); await tick();
    assert.equal(f.closes().length, 0, 'old captured adapter cannot reach current-generation transport');
    assert.equal(f.gatewayGets, 0, 'teardown must not reacquire a current global gateway');
    assert.equal(f.p.chatGateway, undefined, 'disposed capability released');
  });
  test('missing mutable gateway does not erase immutable lease or reacquire global close adapter', async () => {
    const f = await fixture(); f.p.chatGateway = undefined; f.p.aboutToDisappear(); await tick();
    assertClosedOnce(f, 7);
  });
  test('same valid account with deleted chat still allows Back', async () => {
    const f = await fixture(); f.store.getState().chats.chats.delete(7); f.p.handleBackPress(); await tick();
    assert.equal(f.pops, 1, 'cache deletion must not trap the user on the page');
    assert.equal(f.navigation.activeChatId, 0); assert.equal(f.navigation.chatScreenVisible, false);
    assert.equal(f.p.accountStore, undefined);
    assert.ok(f.closes().length <= 1, 'best-effort close is allowed, never duplicated');
    assert.ok(f.closes().every(r => r.generation === 1 && r.payload.chatId === 7));
  });
  for (const boundary of ['no-owner', 'revoked', 'runtime-error']) {
    test(`${boundary}: Back preserves navigation and never pops`, async () => {
      const f = await fixture(7, { bind: boundary !== 'no-owner' });
      if (boundary === 'revoked') f.store.invalidateScopes();
      if (boundary === 'runtime-error') f.runtimeError = true;
      const before = navigationSnapshot(f); f.p.handleBackPress(); await tick();
      assert.equal(f.pops, 0); assert.deepEqual(navigationSnapshot(f), before); assert.equal(f.closes().length, 0);
    });
  }
  test('runtime lookup failure leaves restore untouched', async () => {
    const f = await fixture(), before = draftSnapshot(f); f.runtimeError = true;
    f.p.restoreDraftFromChat(); assertNoRestore(f, before);
  });

  // Required initial RED cases: expectations are invariant, not known-bad xfails.
  for (const revoke of [true, false]) {
    test(`RED close: account A/global B revoke=${revoke}`, async () => {
      const f = await fixture(); f.switchAccount(revoke); f.p.aboutToDisappear(); await tick();
      assert.equal(f.closes().filter(r => r.generation === 2).length, 0, 'A closeChat must never reach B transport');
    });
    test(`RED restore: account A/global B revoke=${revoke}`, async () => {
      const f = await fixture(); f.switchAccount(revoke); const before = draftSnapshot(f);
      f.p.restoreDraftFromChat(); assertNoRestore(f, before);
    });
  }
  test('same owner restores valid draft, entities, selection and reply', async () => {
    const f = await fixture(), chat = f.store.getState().chats.chats.get(7);
    f.p.restoreDraftFromChat();
    assert.equal(f.p.composerDraftText, 'A 😀 draft');
    assert.deepEqual(draftSnapshot(f).entities, [[2, 2, '777']]);
    assert.notEqual(f.p.customEmojiDraftEntities, chat.draftCustomEmojiEntities, 'actual setter must copy array');
    assert.deepEqual(draftSnapshot(f).selection, [chat.draftText.length, chat.draftText.length, 1]);
    assert.equal(f.p.expectedProgrammaticCustomEmojiText, chat.draftText);
    assert.deepEqual(draftSnapshot(f).reply, ['101', 'A author', 'A reply']);
    assert.deepEqual(f.replyCalls, [{ messageId: '101', author: 'A author', preview: 'A reply', isQuote: false }]);
    assert.ok(f.storeReads.includes('A'), 'real owning scope lookup engaged');
    assert.equal(f.requests.length, 0, 'restore is local-only');
  });
  for (const route of ['disappear', 'Back']) test(`normal ${route} closes owned chat and clears navigation`, async () => {
    const f = await fixture(-100123);
    if (route === 'Back') f.p.handleBackPress(); else f.p.aboutToDisappear();
    await tick();
    assertClosedOnce(f, -100123);
    assert.equal(f.pops, route === 'Back' ? 1 : 0);
    assert.equal(f.p.accountStore, undefined);
    assert.equal(f.p.routeActivated, false);
    assert.equal(f.navigation.activeChatId, 0);
    assert.equal(f.navigation.chatScreenVisible, false);
    assert.equal(f.chatState.activeChatId, 0);
    assert.equal(f.storage.get('CHAT_SCREEN_VISIBLE'), false);
    assert.equal(f.storage.get('ACTIVE_CHAT_ID'), 0);
  });
  test('duplicate disappearance closes exactly once', async () => {
    const f = await fixture(); f.p.aboutToDisappear(); await tick(); f.p.aboutToDisappear(); await tick(); assertClosedOnce(f, 7);
  });
  test('no opened route never sends closeChat despite local chat ids', async () => {
    const f = await fixture(7, { bind: false }); f.p.activeChatId = f.p.routeChatId = 7; f.p.aboutToDisappear(); await tick(); assert.equal(f.closes().length, 0);
  });
  for (const boundary of ['no-owner', 'revoked', 'reset']) {
    test(`${boundary}: acknowledged lease releases only its captured client`, async () => {
      const f = await fixture();
      if (boundary === 'no-owner') f.p.accountStore = undefined;
      if (boundary === 'revoked') f.store.invalidateScopes();
      if (boundary === 'reset') f.store.resetState();
      f.p.aboutToDisappear(); await tick(); assertClosedOnce(f, 7);
      assert.equal(f.gatewayGets, 0, 'revocation cannot reacquire a replacement client');
    });
    test(`${boundary}: restore is inert`, async () => {
      const f = await fixture();
      if (boundary === 'no-owner') f.p.accountStore = undefined;
      if (boundary === 'revoked') f.store.invalidateScopes();
      if (boundary === 'reset') f.store.resetState();
      const before = draftSnapshot(f); f.p.restoreDraftFromChat(); assertNoRestore(f, before);
    });
  }
  for (const boundary of ['zero-chat', 'missing-chat', 'existing-input']) test(`${boundary}: restore is inert`, async () => {
    const f = await fixture();
    if (boundary === 'zero-chat') f.p.activeChatId = 0;
    if (boundary === 'missing-chat') f.store.getState().chats.chats.delete(7);
    if (boundary === 'existing-input') f.p.setDraftText('new typing');
    const before = draftSnapshot(f); f.p.restoreDraftFromChat(); assertNoRestore(f, before);
  });
  for (const revoke of [true, false]) test(`RED navigation: old A disappear preserves B same-chat state revoke=${revoke}`, async () => {
    const f = await fixture(); f.switchAccount(revoke); const before = navigationSnapshot(f);
    f.p.aboutToDisappear(); await tick(); assert.deepEqual(navigationSnapshot(f), before, 'old A must not clear B navigation or visibility');
  });
  test('RED navigation: old page preserves distinct new chat in same account', async () => {
    const f = await fixture(); f.publishNavigation(8, 'new A chat', 23456); const before = navigationSnapshot(f);
    f.p.aboutToDisappear(); await tick();
    assertClosedOnce(f, 7);
    assert.deepEqual(navigationSnapshot(f), before, 'closing 7 must not erase current chat 8 or its visibility');
  });
  test('fixture: real captured adapter rejects a later generation before native send', async () => {
    const f = await fixture(); f.switchAccount(false);
    await assert.rejects(f.originalAdapter.send(C.createCloseChatCommand(7)), /session has ended/);
    assert.equal(f.requests.length, 0);
  });
  test('best-effort close rejection is handled, not an unhandled test failure', async () => {
    const f = await fixture(); f.nativeError = true; f.p.aboutToDisappear(); await tick(); await tick(); assertClosedOnce(f, 7);
  });

  test('reappear: released route is terminal even in the same valid account', async () => {
    const f = await fixture(7, { bind: false }); await firstAppear(f);
    const owner = f.p.routeAccountStore, count = f.factoryCalls.length;
    f.p.aboutToDisappear(); await tick(); assertClosedOnce(f, 7);
    f.p.aboutToAppear(); f.p.bindChatRoute(f.route); assert.equal(f.p.showOwnedChatRoute(), false);
    await tick();
    assert.equal(f.p.accountStore, undefined); assert.equal(f.p.routeAccountStore, owner);
    assert.equal(f.factoryCalls.length, count);
    assert.equal(f.opens().length, 1, 'released lease cannot reacquire');
    assert.equal(f.events.filter(e => e === 'bindWindowSizeListener').length, 1);
  });
  for (const disappear of [false, true]) for (const revoke of [false, true]) {
    test(`reappear: A -> B rejects retained component disappear=${disappear} revoke=${revoke}`, async () => {
      const f = await fixture(7, { bind: false }), retainedText = 'A retained reappear draft'; await firstAppear(f);
      const owner = f.p.routeAccountStore;
      assert.equal(owner, f.runtimeStore, 'actual first appear bound original A');
      assert.equal(f.events.filter(e => e === 'bindWindowSizeListener').length, 1);
      f.p.setCustomEmojiEntities([]); f.p.setReplyMode('0', '', '', false); f.p.setDraftText(retainedText);
      if (disappear) {
        f.p.aboutToDisappear(); await tick(); assertClosedOnce(f, 7);
        assert.equal(f.p.accountStore, undefined); assert.equal(f.p.routeAccountStore, owner);
      }
      const beforeBinding = f.bindingEntries.length, beforeFactories = f.factoryCalls.length;
      const beforeGatewayGets = f.gatewayGets;
      f.switchAccount(revoke); const beforeNavigation = navigationSnapshot(f);
      f.p.aboutToAppear();
      f.p.persistDraft(7);
      const leaked = f.requests.filter(r => r.method === 'setChatDraft' &&
        r.generation === 2 && r.payload.text === retainedText);
      reappearWitnesses.push({ disappear, revoke,
        reboundToB: f.p.accountStore === f.runtimeStore,
        retainedText: f.p.composerDraftText,
        completedAppearCount: f.events.filter(e => e === 'bindWindowSizeListener').length,
        appearErrors: f.logs.filter(log => String(log).includes('aboutToAppear failed')),
        leakedDrafts: leaked.map(r => ({ method: r.method, generation: r.generation, payload: r.payload }))
      });
      f.p.unsubscribe?.();
      assert.equal(leaked.length, 0, 'same-component rebind must not publish the retained A draft into B');
      assert.equal(f.p.routeAccountStore, owner, 'persistent owner is not rebound');
      assert.equal(f.bindingEntries.length, beforeBinding, 'reject before sync/restore');
      assert.equal(f.factoryCalls.length, beforeFactories, 'reject before use-case construction');
      assert.equal(f.gatewayGets, beforeGatewayGets, 'reject before acquiring another client');
      assert.deepEqual(navigationSnapshot(f), beforeNavigation);
    });
  }
  for (const disappear of [false, true]) test(`reappear: invalidated same view is rejected disappear=${disappear}`, async () => {
    const f = await fixture(7, { bind: false }); await firstAppear(f); const owner = f.p.routeAccountStore;
    if (disappear) f.p.aboutToDisappear(); await tick();
    f.store.invalidateScopes();
    assert.equal(f.runtimeStore, owner, 'runtime still returns the identical, now revoked view');
    const before = navigationSnapshot(f), bindings = f.bindingEntries.length, gateways = f.gatewayGets;
    f.p.aboutToAppear();
    assert.equal(f.p.routeAccountStore, owner);
    assert.equal(f.bindingEntries.length, bindings); assert.equal(f.gatewayGets, gateways);
    assert.deepEqual(navigationSnapshot(f), before);
    assert.equal(f.events.filter(e => e === 'bindWindowSizeListener').length, 1);
    f.p.unsubscribe?.();
  });
  test('source baseline: route-less appear must not import global account or draft', async () => {
    const f = await fixture(7, { bind: false }); f.p.aboutToAppear(); await tick();
    assert.equal(f.p.accountStore, undefined, 'aboutToAppear alone is not route authorization');
    assert.equal(f.p.composerDraftText, '');
    assert.equal(f.factoryCalls.length, 0);
    assert.equal(f.requests.length, 0);
  });
  test('source baseline: old same-chat page must not clear a newer navigation owner', async () => {
    const f = await fixture();
    const replacement = f.newRoute(); f.stackParams.push(replacement);
    const next = f.newPage(); next.bindChatRoute(replacement); next.showOwnedChatRoute(); await tick();
    const before = navigationSnapshot(f);
    f.p.aboutToDisappear(); await tick();
    assert.deepEqual(navigationSnapshot(f), before, 'chatId equality is not route ownership');
  });
  test('pending open -> disappear -> late TdObject Ok closes exactly once without peer/history/read', async () => {
    const f = await fixture(7, { bind: false, heldMethods: ['openChat'], unreadCount: 4 });
    await firstAppear(f);
    assert.equal(f.opens().length, 1); assert.equal(f.route.openLease.isOpen(), false);
    f.p.maybeMarkChatRead(f.store.getState());
    f.p.aboutToDisappear(); f.p.aboutToDisappear();
    assert.equal(f.closes().length, 0);
    const released = f.route.openLease.release();
    f.opens()[0].resolve(ok()); await released; await tick();
    assertClosedOnce(f, 7);
    assert.equal(f.route.openLease.isReleased(), true);
    assert.equal(f.requests.some(r => ['getUser', 'getChatHistory', 'viewMessages'].includes(r.method)), false);
    assert.equal(f.timers.size, 0);
  });
  test('duplicate onReady/onShown/appear reuse a single pending and acknowledged open', async () => {
    const f = await fixture(7, { bind: false, heldMethods: ['openChat'] });
    await firstAppear(f);
    for (let i = 0; i < 3; i++) {
      f.p.bindChatRoute(f.route); f.p.aboutToAppear(); assert.equal(f.p.showOwnedChatRoute(), true);
    }
    assert.equal(f.opens().length, 1);
    f.opens()[0].resolve(ok()); await tick();
    f.p.bindChatRoute(f.route); f.p.showOwnedChatRoute(); await tick();
    assert.equal(f.opens().length, 1);
    assert.equal(f.events.filter(e => e === 'bindWindowSizeListener').length, 1);
    await f.fireHistory(); assert.equal(f.historyCalls.length, 1);
    f.p.aboutToDisappear(); await f.route.openLease.release(); assertClosedOnce(f, 7);
  });
  for (const revoke of [false, true]) test(`delayed A route first onReady after B is inert revoke=${revoke}`, async () => {
    const f = await fixture(7, { bind: false }); const route = f.route;
    f.switchAccount(revoke); const before = navigationSnapshot(f);
    f.p.aboutToAppear(); f.p.bindChatRoute(route); assert.equal(f.p.showOwnedChatRoute(), false);
    f.p.aboutToDisappear(); await tick();
    assert.equal(f.p.accountStore, undefined); assert.equal(f.p.routeContext, undefined);
    assert.equal(f.p.composerDraftText, ''); assert.equal(f.factoryCalls.length, 0);
    assert.equal(f.requests.length, 0); assert.equal(f.storeReads.includes('B'), false);
    assert.deepEqual(navigationSnapshot(f), before);
  });
  test('background onReady initializes local route but never claims newer hidden globals', async () => {
    const f = await fixture(7, { bind: false });
    const next = f.newRoute(8, 'foreground'); f.stackParams.push(next);
    f.publishNavigation(8, 'foreground', 4321, next.navigationToken);
    f.navigation.chatScreenVisible = false; f.storage.set('CHAT_SCREEN_VISIBLE', false);
    const before = navigationSnapshot(f);
    f.p.bindChatRoute(f.route); assert.equal(f.p.showOwnedChatRoute(), false); await tick();
    assert.equal(f.p.activeChatId, 7); assert.equal(f.p.routeActivated, true);
    assert.equal(f.route.openLease.isOpen(), true);
    assert.deepEqual(navigationSnapshot(f), before);
  });
  test('same-account same-chat overlap: stale onShown and Back are inert; current Back restores underlying owner', async () => {
    const f = await fixture(); const older = f.p;
    const route = f.newRoute(), next = f.newPage(); f.stackParams.push(route);
    next.bindChatRoute(route); next.showOwnedChatRoute(); await tick();
    assert.notEqual(route.navigationToken, f.route.navigationToken);
    const before = navigationSnapshot(f);
    assert.equal(older.showOwnedChatRoute(), false); older.handleBackPress();
    assert.equal(f.pops, 0); assert.deepEqual(navigationSnapshot(f), before);
    next.handleBackPress(); await route.openLease.release();
    assert.equal(f.pops, 1); assert.equal(route.openLease.isReleased(), true);
    assert.equal(f.route.openLease.isOpen(), true);
    assert.equal(older.showOwnedChatRoute(), true);
    assert.equal(f.navigation.activeChatOwnerToken, f.route.navigationToken);
    assert.equal(f.opens().length, 1, 'only replacement page opened after baseline');
    older.aboutToDisappear(); await f.route.openLease.release();
    assert.equal(f.closes().length, 2, 'each acknowledged route releases once');
  });
  for (const boundary of ['none', 'replacement', 'account']) test(`Back failed-pop rollback owns only its cleared slot: ${boundary}`, async () => {
    const f = await fixture(); const before = navigationSnapshot(f); let replacementState;
    f.onPop = () => {
      if (boundary === 'replacement') {
        const route = f.newRoute(), next = f.newPage(); f.stackParams.push(route);
        next.bindChatRoute(route); next.showOwnedChatRoute(); replacementState = navigationSnapshot(f);
      }
      if (boundary === 'account') { f.switchAccount(false); replacementState = navigationSnapshot(f); }
      throw new Error('fixture failed pop');
    };
    f.p.handleBackPress(); await tick();
    assert.equal(f.pops, 1); assert.equal(f.p.isClosing, false);
    assert.deepEqual(navigationSnapshot(f), replacementState ?? before);
    assert.equal(f.closes().length, 0);
  });
  for (const boundary of ['invalidateScopes', 'resetState', 'resetStateQueued', 'account', 'generation', 'lifecycle', 'history']) {
    test(`pending-open context forecast prevents peer/history/read: ${boundary}`, async () => {
      const f = await fixture(7, { bind: false, heldMethods: ['openChat'], unreadCount: 3 });
      await firstAppear(f);
      if (['invalidateScopes', 'resetState', 'resetStateQueued'].includes(boundary)) await f.store[boundary]();
      if (boundary === 'account') f.switchAccount(false);
      if (boundary === 'generation') f.generation++;
      if (boundary === 'lifecycle') f.p.pageLifecycleToken++;
      if (boundary === 'history') f.p.loadChatHistoryUseCase = undefined;
      f.opens()[0].resolve(ok()); await tick(); await tick();
      assert.equal(f.requests.some(r => ['getUser', 'getChatHistory', 'viewMessages'].includes(r.method)), false);
      assert.equal(f.p.historyFallbackTimerId, -1);
      f.p.aboutToDisappear(); await f.route.openLease.release();
      assert.equal(f.closes().length, ['account', 'generation'].includes(boundary) ? 0 : 1);
    });
  }
  for (const boundary of ['invalidateScopes', 'resetState', 'resetStateQueued', 'account']) {
    test(`scheduled-history context forecast suppresses retired route: ${boundary}`, async () => {
      const f = await fixture();
      const timer = f.timers.get(f.p.historyFallbackTimerId);
      assert.equal(typeof timer, 'function');
      if (boundary === 'account') f.switchAccount(false); else await f.store[boundary]();
      timer(); await tick(); await tick();
      assert.equal(f.requests.some(r => r.method === 'getChatHistory'), false);
    });
  }
  test('peer hydration precedes initial history; captured unread survives early mark-read state change', async () => {
    const f = await fixture(7, { bind: false, heldMethods: ['openChat', 'getUser'], unreadCount: 5 });
    await firstAppear(f);
    assert.deepEqual(f.requests.map(r => r.method), ['openChat']);
    f.p.maybeMarkChatRead(f.store.getState()); assert.equal(f.requests.length, 1);
    f.opens()[0].resolve(ok()); await tick();
    assert.deepEqual(f.requests.map(r => r.method), ['openChat', 'getUser']);
    assert.equal(f.requests[1].payload.userId, 55);
    assert.equal(f.p.historyFallbackTimerId, -1);
    f.requests[1].resolve(td.TdObject.fromJSON('{"@type":"user","id":55}')); await tick();
    assert.deepEqual(f.requests.map(r => r.method), ['openChat', 'getUser', 'viewMessages']);
    assert.equal(f.p.stickyLastReadMessageId, '100');
    const chat = f.store.getState().chats.chats.get(7);
    chat.unreadCount = 0; chat.lastReadInboxMessageId = '999';
    await f.fireHistory();
    assert.equal(f.historyCalls.length, 1);
    assert.deepEqual(f.historyCalls.map(p => [p.chatId, p.fromMessageId, p.offset, p.limit, p.direction, p.reason]),
      [[7, '100', -10, 60, 'initial', 'aroundUnread']]);
    assert.equal(f.requests.at(-1).method, 'getChatHistory');
    assert.equal(f.requests.at(-1).payload.fromMessageId, '100');
  });
  test('default initial history uses latest 50 even with a cached message window', async () => {
    const f = await fixture(); await f.fireHistory();
    assert.deepEqual(f.historyCalls.map(p => [p.fromMessageId, p.offset, p.limit, p.reason]), [['0', 0, 50, 'default']]);
    assert.equal(f.requests.filter(r => r.method === 'getChatHistory').length, 1);
  });
  for (const boundary of ['not-shown', 'hidden', 'new-owner', 'released', 'account']) {
    test(`mark-read requires acknowledged open and visible current navigation owner: ${boundary}`, async () => {
      const f = await fixture(); const chat = f.store.getState().chats.chats.get(7); chat.unreadCount = 2;
      if (boundary === 'not-shown') f.navigation.activeChatOwnerToken = 0;
      if (boundary === 'hidden') f.navigation.chatScreenVisible = false;
      if (boundary === 'new-owner') f.navigation.activeChatOwnerToken = f.newRoute().navigationToken;
      if (boundary === 'released') await f.route.openLease.release();
      if (boundary === 'account') f.switchAccount(false);
      f.p.maybeMarkChatRead(f.store.getState()); await tick();
      assert.equal(f.requests.some(r => r.method === 'viewMessages'), false);
    });
  }
  test('created chat missing at route creation binds and uses first owned unread snapshot when cache arrives', async () => {
    const f = await fixture(7, { bind: false, heldMethods: ['openChat'] });
    const id = -909, route = f.p.createChatRouteParams(id, 'created');
    assert.equal(route, undefined, 'unbound source cannot manufacture a route');
    f.p.bindChatRoute(f.route); f.p.showOwnedChatRoute(); await tick();
    const created = f.p.createChatRouteParams(id, 'created');
    assert.ok(created instanceof ChatScreenRouteParams); assert.ok(created.openLease instanceof ChatOpenLease);
    assert.equal(created.accountStore, f.runtimeStore); assert.equal(created.gateway, f.originalAdapter);
    assert.equal(created.entryUnreadCount, undefined);
    const next = f.newPage(); f.stackParams.push(created); next.aboutToAppear(); next.bindChatRoute(created);
    assert.equal(next.showOwnedChatRoute(), true); await tick();
    assert.equal(next.routeActivated, true); assert.equal(next.activeChatId, id);
    f.store.getState().chats.chats.set(id, Object.assign(new A.Chat(), { id, title: 'created', unreadCount: 3,
      lastReadInboxMessageId: '303' }));
    f.opens().find(r => r.payload.chatId === id).resolve(ok()); await tick();
    assert.equal(next.stickyLastReadMessageId, '303');
    await f.fireHistory(next);
    assert.ok(f.historyCalls.some(p => p.chatId === id && p.fromMessageId === '303' && p.limit === 60 && p.offset === -10));
    f.opens().find(r => r.payload.chatId === 7).resolve(ok()); await tick();
  });
  test('onReady/onShown source wiring calls the actual tested methods', async () => {
    const graph = require('./chat-screen-source.cjs').sourceGraph(path.join(root, pageFile));
    assert.match(graph.page, /\.onReady\([\s\S]*?this\.session\.handleNavReady\(context\)/);
    assert.match(graph.page, /\.onShown\([\s\S]*?this\.session\.handleNavShown\(\)/);
    const owner = [...graph.files.values()].find(source => /export function handleNavReady\(/.test(source));
    assert.ok(owner, 'actual imported navigation event owner');
    assert.match(owner, /host\.bindChatRoute\(context\.pathInfo\.param/);
    assert.match(owner, /host\.showOwnedChatRoute\(\)/);
  });
  for (const [scenario, cached, boundary] of [
    ['missing-cache fallback survives read-inbox reducer', false, '303'],
    ['missing-cache zero boundary stays safe default', false, '0'],
    ['cached route snapshot retains around-unread parity', true, '303']
  ]) test(`open -> viewMessages -> history: ${scenario}`, async () => {
    const events = load('core/model/AppEvent.ets');
    const clone = load('core/utils/stateClone.ets', { ...A, ...C });
    const { chatsReducer } = load('core/reducers/chatsReducer.ets', { ...A, ...events, ...clone, ...accessors });
    const f = await fixture(7, { bind: false, heldMethods: ['openChat', 'viewMessages'], reducer: chatsReducer });
    const id = -919;
    const chat = Object.assign(new A.Chat(), { id, title: 'created unread', unreadCount: 3,
      lastReadInboxMessageId: boundary,
      lastMessage: Object.assign(new A.ChatLastMessage(), { id: '909' }) });
    if (cached) f.store.getState().chats.chats.set(id, chat);
    const route = f.newRoute(id, chat.title), page = f.newPage();
    assert.equal(route.entryUnreadCount, cached ? 3 : undefined);
    assert.equal(route.entryLastReadInboxMessageId, cached ? boundary : undefined);
    f.stackParams.push(route); page.aboutToAppear(); page.bindChatRoute(route);
    assert.equal(page.showOwnedChatRoute(), true); await tick();
    assert.deepEqual(f.requests.map(r => r.method), ['openChat']);
    if (!cached) f.store.getState().chats.chats.set(id, chat);
    f.opens()[0].resolve(ok()); await tick();
    assert.equal(route.openLease.isOpen(), true);
    assert.deepEqual(f.requests.map(r => r.method), ['openChat', 'viewMessages']);
    assert.equal(f.requests[1].payload.chatId, id);
    assert.deepEqual(f.requests[1].payload.messageIds, ['909']);
    // Deliver a real read-inbox event through the real store/reducer after the
    // actual read command but BEFORE firing the page's delayed history timer.
    const readInbox = Object.assign(new events.ChatReadInboxEvent(), { chatId: id,
      unreadCount: 0, lastReadInboxMessageId: '909' });
    await f.runtimeStore.dispatch(readInbox);
    const updated = f.runtimeStore.getState().chats.chats.get(id);
    assert.notEqual(updated, chat, 'actual immutable reducer must engage');
    assert.equal(updated.unreadCount, 0); assert.equal(updated.lastReadInboxMessageId, '909');
    assert.equal(chat.unreadCount, 3, 'pre-read snapshot is not mutated');
    f.requests[1].resolve(ok()); await tick();
    await f.fireHistory(page);
    assert.deepEqual(f.requests.map(r => r.method), ['openChat', 'viewMessages', 'getChatHistory']);
    assert.equal(f.historyCalls.length, 1);
    const expected = boundary === '0' ? ['0', 0, 50, 'default'] : ['303', -10, 60, 'aroundUnread'];
    const params = f.historyCalls[0], command = f.requests[2].payload;
    assert.deepEqual([params.fromMessageId, params.offset, params.limit, params.reason], expected);
    assert.deepEqual([command.fromMessageId, command.offset, command.limit], expected.slice(0, 3));
  });
  test('actual positive route token consumes its forward transfer once through page/controller', async () => {
    const f = await fixture(7, { bind: false });
    assert.ok(f.route.navigationToken > 0); assert.equal(f.p.getChatRouteToken(), 0);
    f.transfer.arm(7, 8, ['1048576'], 'author', 'preview', f.route.navigationToken);
    await firstAppear(f);
    assert.equal(f.p.getChatRouteToken(), f.route.navigationToken);
    assert.equal(f.p.isForwardingMessages, true);
    assert.deepEqual(f.p.forwardingMessageIds, ['1048576']);
    assert.equal(f.p.forwardSourceChatId, 8);
    assert.equal(f.transfer.hasPendingFor(7, f.route.navigationToken), false);
    f.p.clearForwardMode(); f.p.applyPendingForwardTransferIfNeeded();
    assert.equal(f.p.isForwardingMessages, false, 'actual transfer is one-shot');
    f.p.aboutToDisappear(); await f.route.openLease.release(); assert.equal(f.p.getChatRouteToken(), 0);
  });
  test('Wave18 RED: first owned chat after Ok before history preserves unread boundary', async () => {
    // Canonical form of wave17-evidence.json openFindings.lateFirstOwnedChat.
    // Unlike the original probe, first chat and read updates enter the actual reducer.
    const dto = load('core/model/dto/ChatDto.ets', { ...C, ...accessors, hilog: silentLog });
    const events = load('core/model/AppEvent.ets', dto);
    const clone = load('core/utils/stateClone.ets', { ...A, ...C });
    const { chatsReducer } = load('core/reducers/chatsReducer.ets', {
      ...A, ...events, ...clone, ...accessors, DtoChatType: dto.ChatType });
    const f = await fixture(7, { bind: false, heldMethods: ['openChat', 'viewMessages'], reducer: chatsReducer });
    const id = -919, route = f.newRoute(id, 'late'), page = f.newPage();
    f.stackParams.push(route); page.aboutToAppear(); page.bindChatRoute(route); page.showOwnedChatRoute();
    await tick(); f.opens()[0].resolve(ok()); await tick();
    assert.equal(route.entryUnreadCount, undefined);
    assert.equal(f.runtimeStore.getState().chats.chats.has(id), false);
    assert.deepEqual(f.requests.map(r => r.method), ['openChat']);
    const firstChat = Object.assign(new events.NewChatEvent(), { chatId: id,
      chatData: Object.assign(new dto.ChatDto(), { id, title: 'late', unreadCount: 3,
        lastReadInboxMessageId: '303', lastMessage: Object.assign(new dto.ChatLastMessage(), { id: '909' }) }) });
    await f.runtimeStore.dispatch(firstChat);
    assert.equal(f.runtimeStore.getState().chats.chats.get(id).unreadCount, 3, 'actual first-chat reducer engaged');
    const rebuildId = page.rebuildTimerId, rebuild = f.timers.get(rebuildId);
    assert.equal(typeof rebuild, 'function', 'real subscription queued its rebuild');
    f.timers.delete(rebuildId); rebuild(); await tick();
    assert.deepEqual(f.requests.map(r => r.method), ['openChat', 'viewMessages']);
    await f.runtimeStore.dispatch(Object.assign(new events.ChatReadInboxEvent(), {
      chatId: id, unreadCount: 0, lastReadInboxMessageId: '909' }));
    assert.equal(f.runtimeStore.getState().chats.chats.get(id).unreadCount, 0);
    f.requests[1].resolve(ok()); await tick();
    await f.fireHistory(page);
    assert.deepEqual(f.requests.map(r => r.method), ['openChat', 'viewMessages', 'getChatHistory']);
    assert.deepEqual(f.historyCalls.map(p => [p.fromMessageId, p.offset, p.limit, p.reason]),
      [['303', -10, 60, 'aroundUnread']]);
  });
  test('same-chat replacement cannot consume an older positive-token forward transfer', async () => {
    const f = await fixture(); const nextRoute = f.newRoute(), next = f.newPage();
    f.transfer.arm(7, 8, ['1048576'], 'author', 'preview', f.route.navigationToken);
    f.stackParams.push(nextRoute); next.bindChatRoute(nextRoute); next.showOwnedChatRoute(); await tick();
    assert.equal(next.isForwardingMessages, false);
    assert.equal(f.transfer.hasPendingFor(7, f.route.navigationToken), true);
    assert.notEqual(next.getChatRouteToken(), f.p.getChatRouteToken());
    f.p.applyPendingForwardTransferIfNeeded();
    assert.equal(f.p.isForwardingMessages, true);
    assert.equal(f.transfer.hasPendingFor(7, f.route.navigationToken), false);
  });
  test('new B same-chat bind cannot consume an armed A forward transfer', async () => {
    const f = await fixture(7, { bind: false });
    f.transfer.arm(7, 8, ['1048576'], 'A author', 'A preview', f.route.navigationToken);
    f.switchAccount(false);
    const nextRoute = f.newRoute(7, 'B chat'), next = f.newPage(); f.stackParams.push(nextRoute);
    next.aboutToAppear(); next.bindChatRoute(nextRoute); next.showOwnedChatRoute(); await tick();
    assert.equal(next.routeActivated, true); assert.equal(next.accountStore, f.runtimeStore);
    assert.equal(next.isForwardingMessages, false);
    assert.equal(f.transfer.hasPendingFor(7, f.route.navigationToken), true);
    f.p.bindChatRoute(f.route); f.p.applyPendingForwardTransferIfNeeded();
    assert.equal(f.p.getChatRouteToken(), 0); assert.equal(f.p.isForwardingMessages, false);
  });
  test('Wave18: unknown first chat is not confirmed zero unread after Ok', async () => {
    const f = await lateChatFixture(); await f.resolveOpen();
    assert.equal(f.targetRoute.entryUnreadCount, undefined);
    assert.equal(f.page.initialHistoryParams, undefined, 'no first state means no frozen unread snapshot');
    assert.equal(f.requests.some(r => r.method === 'viewMessages'), false);
  });
  for (const timing of ['before-Ok', 'after-Ok-before-history']) test(`Wave18: first positive state survives coalesced read update ${timing}`, async () => {
    const f = await lateChatFixture();
    if (timing === 'after-Ok-before-history') await f.resolveOpen();
    await f.firstState();
    const rebuildId = f.page.rebuildTimerId;
    await f.readState();
    assert.equal(f.page.rebuildTimerId, rebuildId, 'two actual reducer events coalesced into one rebuild');
    assert.equal(f.runtimeStore.getState().chats.chats.get(f.id).unreadCount, 0);
    if (timing === 'before-Ok') await f.resolveOpen();
    await f.fireRebuild(f.page); await f.fireHistory(f.page);
    f.assertHistory([['303', -10, 60, 'aroundUnread']]);
    assert.equal(f.requests.some(r => r.method === 'viewMessages'), false, 'server already read; never fabricate a new unread grant');
  });
  for (const cachedUnread of [0, 3]) test(`Wave18: cached snapshot survives changed state before Ok unread=${cachedUnread}`, async () => {
    const f = await lateChatFixture({ cachedUnread });
    await f.firstState(8, '606'); await f.resolveOpen(); await f.fireRebuild(f.page); await f.fireHistory(f.page);
    f.assertHistory(cachedUnread ? [['303', -10, 60, 'aroundUnread']] : [['0', 0, 50, 'default']]);
  });
  for (const phase of ['pending', 'completed-cached', 'rejected']) {
    test(`Wave18: one correction after first state with default ${phase}`, async () => {
      const f = await lateChatFixture({ holdHistory: phase !== 'completed-cached' });
      await f.resolveOpen(); await f.fireHistory(f.page);
      f.assertHistory([['0', 0, 50, 'default']]);
      if (phase === 'completed-cached') {
        assert.equal(f.page.loadChatHistoryUseCase.hasHistoryBeenFetched(f.id), true, 'actual normalized history populated cache');
      } else assert.equal(f.page.loadChatHistoryUseCase.isLoading(f.id, 'initial'), true);
      const defaultRequest = f.historyRequests()[0];
      await f.firstState(); await f.fireRebuild(f.page);
      if (phase !== 'completed-cached') {
        if (f.timers.has(f.page.historyFallbackTimerId)) await f.fireHistory(f.page);
        assert.equal(f.historyRequests().length, 1, 'no parallel initial bucket or duplicate default');
        f.heldMethods.delete('getChatHistory');
        if (phase === 'rejected') defaultRequest.reject(new Error('fixture default history rejected'));
        else defaultRequest.resolve(f.historyResponse);
        await tick(); await tick();
      }
      await f.fireHistory(f.page);
      f.assertHistory([['0', 0, 50, 'default'], ['303', -10, 60, 'aroundUnread']]);
      assert.equal(f.page.loadChatHistoryUseCase.hasHistoryBeenFetched(f.id), true);
      for (let i = 0; i < 3; i++) await f.firstState();
      await f.fireRebuild(f.page);
      assert.equal(f.historyRequests().length, 2, 'duplicate updates must not repeat default or correction');
      assert.equal(f.timers.has(f.page.historyFallbackTimerId), false, 'no unbounded correction/retry timer');
    });
  }
  test('Wave18: default cached before state still preserves first boundary before mark-read reducer clears it', async () => {
    const f = await lateChatFixture(); await f.resolveOpen(); await f.fireHistory(f.page);
    assert.equal(f.page.loadChatHistoryUseCase.hasHistoryBeenFetched(f.id), true);
    await f.firstState(); await f.fireRebuild(f.page);
    assert.deepEqual(f.requests.map(r => r.method), ['openChat', 'getChatHistory', 'viewMessages']);
    await f.readState(); f.requests.find(r => r.method === 'viewMessages').resolve(ok()); await tick();
    await f.fireHistory(f.page);
    f.assertHistory([['0', 0, 50, 'default'], ['303', -10, 60, 'aroundUnread']]);
    assert.equal(f.runtimeStore.getState().chats.chats.get(f.id).unreadCount, 0);
  });
  for (const unreadCount of [0, 3]) test(`Wave18: invalid zero boundary never requests around-unread unread=${unreadCount}`, async () => {
    const f = await lateChatFixture(); await f.resolveOpen(); await f.firstState(unreadCount, '0');
    await f.fireRebuild(f.page); await f.fireHistory(f.page);
    f.assertHistory([['0', 0, 50, 'default']]);
    await f.firstState(unreadCount, '0'); await f.fireRebuild(f.page);
    assert.equal(f.historyRequests().length, 1); assert.equal(f.timers.has(f.page.historyFallbackTimerId), false);
  });
  test('Wave18: first confirmed zero unread after default needs no correction', async () => {
    const f = await lateChatFixture(); await f.resolveOpen(); await f.fireHistory(f.page);
    await f.firstState(0, '303'); await f.fireRebuild(f.page);
    f.assertHistory([['0', 0, 50, 'default']]);
    assert.equal(f.timers.has(f.page.historyFallbackTimerId), false);
    assert.equal(f.requests.some(r => r.method === 'viewMessages'), false);
  });
  test('Wave18: no first state permits one bounded delayed default and no read/retry loop', async () => {
    const f = await lateChatFixture(); await f.resolveOpen();
    assert.equal(f.historyRequests().length, 0, 'fallback is not synchronous');
    const delay = f.timerDelays.get(f.page.historyFallbackTimerId);
    assert.equal(delay, constants.HISTORY_INITIAL_DELAY_MS); assert.ok(Number.isFinite(delay) && delay > 0);
    await f.fireHistory(f.page);
    for (let i = 0; i < 5; i++) { await f.readState(); await tick(); }
    f.assertHistory([['0', 0, 50, 'default']]);
    assert.equal(f.timers.has(f.page.historyFallbackTimerId), false);
    assert.equal(f.requests.some(r => r.method === 'viewMessages'), false);
  });
  for (const boundary of ['invalidateScopes', 'resetState', 'resetStateQueued', 'account', 'disappear']) {
    test(`Wave18: revoked pending default cannot schedule first-state correction ${boundary}`, async () => {
      const f = await lateChatFixture({ holdHistory: true }); await f.resolveOpen(); await f.fireHistory(f.page);
      await f.firstState();
      if (boundary === 'account') f.switchAccount(false);
      else if (boundary === 'disappear') f.page.aboutToDisappear();
      else await f.store[boundary]();
      f.historyRequests()[0].resolve(f.historyResponse); await tick(); await tick();
      // Execute already-queued UI/timer callbacks, even after their owner retired.
      for (const [id, callback] of [...f.timers]) { f.timers.delete(id); callback(); await tick(); }
      assert.equal(f.historyRequests().length, 1);
      assert.equal(f.requests.some(r => r.method === 'viewMessages'), false);
    });
  }
  test('Wave18: capture/correction does not reset existing user scroll state', async () => {
    const f = await lateChatFixture(); await f.resolveOpen(); await f.fireHistory(f.page);
    Object.assign(f.page, { needsScrollRestore: false, hasRestoredUnreadBoundary: true,
      lastVisibleStartIndex: 42, lastVisibleEndIndex: 49 });
    await f.firstState(); await f.fireRebuild(f.page);
    assert.deepEqual([f.page.needsScrollRestore, f.page.hasRestoredUnreadBoundary,
      f.page.lastVisibleStartIndex, f.page.lastVisibleEndIndex], [false, true, 42, 49]);
    // Rendering itself is outside this fixture; these are actual page-owned flags.
  });
  if (knownGap === 'reappear') tests.splice(0, tests.length, ...tests.filter(t => t.name.startsWith('reappear:')));

  for (const { name, run } of tests) {
    const result = { name, passed: false };
    results.push(result);
    try {
      await context.run(name, async () => {
        await run(); await tick(); await tick();
        for (const { fixture: f } of fixtureRuns.filter(entry => entry.test === name)) {
          assert.equal(f.logs.some(log => /Chat route activation failed|Owned chat initialization failed|Timeline rebuild failed/.test(String(log))), false,
            'no swallowed lifecycle exception after complete actual page execution');
        }
      });
      result.passed = true;
    } catch (error) { result.error = error.stack ?? String(error); }
  }
  completed = true;
}

// Emit the FINAL summary at idle, not before detached rejections can be seen.
// A dangling awaited promise that lets Node exit is a HARNESS_ERROR, never PASS.
if (standalone) process.once('beforeExit', () => {
  if (!completed) harnessErrors.push('incomplete lifecycle test run');
  for (const failure of asynchronousErrors) {
    const result = results.find(r => r.name === failure.test);
    if (result) {
      result.passed = false;
      result.error = [result.error, `${failure.kind}: ${failure.error}`].filter(Boolean).join('\n');
    } else harnessErrors.push(`${failure.kind}: ${failure.error}`);
  }
  const changedSources = Object.keys(sources).filter(relative => {
    try { return hash(readChatSource(path.join(root, relative), 'utf8')) !== sources[relative]; }
    catch (_) { return true; }
  });
  if (changedSources.length) harnessErrors.push(`source changed during run: ${changedSources.join(', ')}`);
  for (const result of results) {
    if (result.passed) console.log('PASS', result.name);
    else console.error('FAIL', result.name, result.error);
  }
  for (const error of harnessErrors) console.error('HARNESS_ERROR', error);
  const passed = results.filter(r => r.passed).length;
  const failed = results.length - passed;
  const exitCode = harnessErrors.length ? 2 : failed ? 1 : 0;
  console.log(JSON.stringify({ suite: knownGap ? 'chat-lifecycle-account-scope-reappear' : 'chat-lifecycle-account-scope',
    node: process.version, knownGap, reappearWitnesses,
    mutant, mutations: mutationSites.length, mutationSites,
    total: tests.length, executed: results.length, passed, failed, exitCode,
    unhandledFailures: asynchronousErrors.length, harnessErrors, extractedMethods: methods,
    methodHashes, executedMethodHashes, sources, sourceStable: changedSources.length === 0,
    coverageExclusions: ['ArkUI native lifecycle delivery/rendering', 'TDLib native open_count', 'empty-history response normalization', 'UI/media rendering'],
    harnessHash: hash(readChatSource(__filename, 'utf8')),
    failures: results.filter(r => !r.passed).map(r => ({ name: r.name, error: r.error })) }));
  process.exitCode = exitCode;
});
if (standalone) main().catch(error => { harnessErrors.push(error.stack ?? String(error)); completed = true; });
module.exports = { createFixtureHarness: options => main({ ...options, fixturesOnly: true }) };
