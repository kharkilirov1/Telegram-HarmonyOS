import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { AppError, AppErrorKind, classifyTdlibError, ERR_TDLIB_INIT_TIMEOUT,
  ERR_TDLIB_CLIENT_DESTROYED } from '../../../main/ets/core/model/AppError';
import { AppState, Chat, ChatLastMessage, createInitialAppState } from '../../../main/ets/core/model/AppState';
import { appReducer } from '../../../main/ets/core/reducers/index';
import { AppStore } from '../../../main/ets/core/store/AppStore';
import { TdGatewayPort, GatewayError, GatewayErrorCode } from '../../../main/ets/domain/ports/TdGatewayPort';
import { LoadChatsUseCase } from '../../../main/ets/domain/usecases/loadChats';
import { LoadChatHistoryUseCase, LoadChatHistoryParams } from '../../../main/ets/domain/usecases/loadChatHistory';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { ChatScreenRouteParams } from '../../../main/ets/ui/pages/chat/ChatScreenRouteParams';
import { ChatTimelineDataSource } from '../../../main/ets/ui/pages/chat/ChatTimelineDataSource';
import { ChatInitialHistoryCoordinatorPort, requestHistoryWithRetry, buildInitialHistoryParams,
  captureInitialHistorySnapshot, shouldRetryHistoryLoad, scheduleHistoryLoad } from '../../../main/ets/ui/pages/chat/ChatInitialHistoryCoordinator';

// Real errors, read use cases, AppStore/reducers, route/scope/lease and retry
// coordinator. Only transport and the observable scheduling boundary are fixtures.
// No app bootstrap, native gateway, account action, UI or network request.
class PendingRead {
  readonly command: AnyAppCommand;
  readonly promise: Promise<Object>;
  private resolve?: (value: Object) => void;
  private reject?: (error: AppError | Error) => void;
  constructor(command: AnyAppCommand) {
    this.command = command;
    this.promise = new Promise<Object>((resolve, reject) => { this.resolve = resolve; this.reject = reject; });
  }
  succeed(): void {
    const resolve = this.resolve;
    if (resolve === undefined) throw new Error('Missing synthetic resolution');
    resolve(TdObject.fromJSON('{"@type":"messages","messages":[],"total_count":0}'));
  }
  fail(error: AppError | Error): void {
    const reject = this.reject;
    if (reject === undefined) throw new Error('Missing synthetic rejection');
    reject(error);
  }
}
class ReadGateway implements TdGatewayPort {
  readonly requests: PendingRead[] = [];
  async initialize(): Promise<void> { throw new Error('Native initialization is forbidden'); }
  send(command: AnyAppCommand): Promise<Object> {
    if (command.type === 'openChat' || command.type === 'closeChat') {
      return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}'));
    }
    if (command.type !== 'loadChats' && command.type !== 'getChatHistory') {
      throw new Error('Unexpected read capability: ' + command.type);
    }
    const pending = new PendingRead(command); this.requests.push(pending); return pending.promise;
  }
  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void { return (): void => {}; }
  getConnectionState(): 'connecting' | 'ready' | 'updating' | 'waitingForNetwork' { return 'ready'; }
  async destroy(): Promise<void> {}
}
function seedChat(state: AppState, unread: boolean = false): void {
  const chat = new Chat(); chat.id = 42; chat.unreadCount = unread ? 2 : 0;
  chat.lastReadInboxMessageId = '100'; chat.lastMessage = new ChatLastMessage(); chat.lastMessage.id = '200';
  state.chats.chats.set(42, chat);
}
async function settleReads(): Promise<void> {
  await new Promise<void>((resolve) => { setTimeout(() => resolve(), 0); });
}
async function rejected<T>(promise: Promise<T>): Promise<AppError> {
  try { await promise; } catch (error) {
    expect(error instanceof AppError).assertTrue(); return error as AppError;
  }
  throw new Error('Expected a typed rejection');
}
async function inertHistory(promise: Promise<boolean>): Promise<void> {
  let threw = false; let value = true;
  try { value = await promise; } catch (_) { threw = true; }
  expect(threw).assertFalse(); expect(value).assertFalse();
}
function metadata(actual: AppError, original: AppError): void {
  expect(actual.kind).assertEqual(original.kind);
  expect(actual.tdlibCode).assertEqual(original.tdlibCode);
  expect(actual.retryable).assertEqual(original.retryable);
  expect(actual.technicalMessage).assertEqual(original.technicalMessage);
}
class ReadFixture {
  readonly gateway: ReadGateway = new ReadGateway();
  readonly store: AppStore;
  readonly history: LoadChatHistoryUseCase;
  readonly chats: LoadChatsUseCase;
  constructor(seed: boolean = true) {
    LoadChatHistoryUseCase.resetState();
    const state = createInitialAppState(); if (seed) seedChat(state);
    this.store = new AppStore(appReducer, state, false);
    this.history = new LoadChatHistoryUseCase(this.store.createScope(), this.gateway);
    this.chats = new LoadChatsUseCase(this.store.createScope(), this.gateway);
  }
  params(): LoadChatHistoryParams { const p = new LoadChatHistoryParams(); p.chatId = 42; return p; }
  async startChats(): Promise<Promise<void>[]> {
    // Keep the promise in an array so this helper does not await the pending read.
    const pending = this.chats.execute(); await settleReads();
    expect(this.gateway.requests.length).assertEqual(1);
    expect(this.store.getState().chats.isLoading).assertTrue(); return [pending];
  }
}
class RetryFixture extends ReadFixture implements ChatInitialHistoryCoordinatorPort {
  accountStore: AppStore;
  activeChatId: number = 42;
  awaitingInitialTimeline: boolean = true;
  dataSource: ChatTimelineDataSource = new ChatTimelineDataSource();
  historyFallbackTimerId: number = -1;
  initialHistoryFallbackRequested: boolean = false;
  initialHistoryParams?: LoadChatHistoryParams;
  loadChatHistoryUseCase?: LoadChatHistoryUseCase;
  pageLifecycleToken: number = 1;
  routeActivated: boolean = true;
  routeContext?: ChatScreenRouteParams;
  stickyLastReadMessageId: string = '';
  readonly attempts: number[] = [];
  useRealTimer: boolean = false;
  constructor(correction: boolean = false) {
    super(!correction); this.accountStore = this.store; this.loadChatHistoryUseCase = this.history;
    this.routeContext = new ChatScreenRouteParams(42, 'Synthetic read route', this.store, this.gateway);
  }
  isRouteContextCurrent(route: ChatScreenRouteParams): boolean {
    return this.routeContext === route && this.routeActivated && route.isCurrentAccount(this.store) &&
      !route.openLease.isReleased();
  }
  buildInitialHistoryParams(id: number, state?: AppState): LoadChatHistoryParams {
    return buildInitialHistoryParams(this, id, state);
  }
  captureInitialHistorySnapshot(state: AppState, correction: boolean = true): void {
    captureInitialHistorySnapshot(this, state, correction);
  }
  shouldRetryHistoryLoad(id: number): boolean { return shouldRetryHistoryLoad(this, id); }
  requestHistoryWithRetry(id: number, attempt: number): void { requestHistoryWithRetry(this, id, attempt); }
  scheduleHistoryLoad(id: number, attempt: number): void {
    this.attempts.push(attempt); if (this.useRealTimer) scheduleHistoryLoad(this, id, attempt);
  }
  async startWithoutSnapshot(): Promise<void> {
    this.useRealTimer = true;
    const route = this.routeContext; if (route === undefined) throw new Error('Missing synthetic route');
    expect(await route.openLease.ensureOpen((): boolean => this.isRouteContextCurrent(route))).assertTrue();
    this.requestHistoryWithRetry(42, 0); expect(this.gateway.requests.length).assertEqual(1);
    expect(this.initialHistoryParams === undefined).assertTrue(); expect(this.initialHistoryFallbackRequested).assertTrue();
  }
  lateSnapshot(): void { seedChat(this.store.getState(), true); this.captureInitialHistorySnapshot(this.store.getState()); }
  disposeTimer(): void {
    if (this.historyFallbackTimerId >= 0) clearTimeout(this.historyFallbackTimerId);
    this.historyFallbackTimerId = -1;
  }
  async start(correction: boolean): Promise<void> {
    const route = this.routeContext; if (route === undefined) throw new Error('Missing synthetic route');
    expect(await route.openLease.ensureOpen((): boolean => this.isRouteContextCurrent(route))).assertTrue();
    this.requestHistoryWithRetry(42, 0); expect(this.gateway.requests.length).assertEqual(1);
    if (correction) {
      seedChat(this.store.getState(), true); this.captureInitialHistorySnapshot(this.store.getState(), false);
      expect(this.initialHistoryFallbackRequested).assertTrue();
      expect(this.initialHistoryParams?.reason).assertEqual('aroundUnread');
    } else expect(this.initialHistoryParams?.reason).assertEqual('default');
  }
}
class ClassifiedReadCase {
  readonly name: string; readonly code: number; readonly detail: string;
  constructor(name: string, code: number, detail: string) { this.name = name; this.code = code; this.detail = detail; }
}
function retryCause(name: string): AppError | Error {
  if (name === 'auth-retryable') return new AppError(AppErrorKind.AUTH, 'Synthetic auth', 'auth detail', 401, true);
  if (name === 'rate-limit') return classifyTdlibError(429, 'FLOOD_WAIT_37');
  if (name === 'nonretryable-network') return new AppError(AppErrorKind.NETWORK, 'Terminal transport', 'terminal detail', 0, false);
  if (name === 'invalid-command') return new GatewayError(GatewayErrorCode.INVALID_COMMAND, 'Invalid read');
  if (name === 'network') return classifyTdlibError(503, 'Synthetic service unavailable');
  if (name === 'warming') return new GatewayError(GatewayErrorCode.NOT_INITIALIZED, 'Gateway not initialized');
  if (name === 'expired') { const error = new GatewayError(GatewayErrorCode.NOT_INITIALIZED, 'Session ended'); error.retryable = false; return error; }
  if (name === 'legacy') return new Error('Synthetic legacy failure');
  throw new Error('Unknown retry fixture');
}
export default function gatewayErrorPropagationTest(): void {
  describe('GatewayErrorPropagation', () => {
    const classified: ClassifiedReadCase[] = [
      new ClassifiedReadCase('401 authentication', 401, 'SESSION_EXPIRED'),
      new ClassifiedReadCase('403 forbidden', 403, 'CHAT_ACCESS_DENIED'),
      new ClassifiedReadCase('400 request', 400, 'CHAT_NOT_FOUND'),
      new ClassifiedReadCase('429 flood', 429, 'FLOOD_WAIT_37'),
      new ClassifiedReadCase('503 network', 503, 'Synthetic backend unavailable'),
      new ClassifiedReadCase('initialization timeout', 0, ERR_TDLIB_INIT_TIMEOUT + ': synthetic detail'),
      new ClassifiedReadCase('destroyed client', 0, ERR_TDLIB_CLIENT_DESTROYED + ': synthetic detail')
    ];
    classified.forEach((item: ClassifiedReadCase) => {
      it('loadChats preserves metadata and technical detail: ' + item.name, 0, async () => {
        const f = new ReadFixture(); const original = classifyTdlibError(item.code, item.detail);
        const pending = (await f.startChats())[0]; f.gateway.requests[0].fail(original);
        metadata(await rejected(pending), original);
        expect(f.store.getState().chats.isLoading).assertFalse(); expect(f.store.getState().chats.hasMore).assertTrue();
      });
      it('history preserves the same typed error and releases its bucket: ' + item.name, 0, async () => {
        const f = new ReadFixture(); const original = classifyTdlibError(item.code, item.detail);
        const pending = f.history.execute(f.params()); expect(f.history.isLoading(42, 'initial')).assertTrue();
        f.gateway.requests[0].fail(original); const observed = await rejected(pending);
        expect(observed === original).assertTrue(); metadata(observed, original);
        expect(f.history.isLoading(42)).assertFalse(); expect(f.history.hasHistoryBeenFetched(42)).assertFalse();
      });
    });
    it('invalid commands are UNKNOWN and nonretryable while warming remains retryable NETWORK', 0, () => {
      const invalid = new GatewayError(GatewayErrorCode.INVALID_COMMAND, 'Bad read', 'synthetic command');
      expect(invalid.kind).assertEqual(AppErrorKind.UNKNOWN); expect(invalid.retryable).assertFalse();
      expect(invalid.technicalMessage).assertEqual('synthetic command');
      const warming = new GatewayError(GatewayErrorCode.NOT_INITIALIZED, 'Not ready');
      expect(warming.kind).assertEqual(AppErrorKind.NETWORK); expect(warming.retryable).assertTrue();
    });
    it('loadChats 404 exhausts the list and releases loading without throwing or further dispatch', 0, async () => {
      const f = new ReadFixture(); const pending = (await f.startChats())[0];
      f.gateway.requests[0].fail(classifyTdlibError(404, 'No more chats')); await pending;
      expect(f.store.getState().chats.hasMore).assertFalse(); expect(f.store.getState().chats.isLoading).assertFalse();
      await f.chats.execute(); expect(f.gateway.requests.length).assertEqual(1);
    });
    it('untyped legacy read errors keep the existing NETWORK retry fallback', 0, async () => {
      const f = new ReadFixture(); const pending = f.history.execute(f.params());
      f.gateway.requests[0].fail(new Error('Legacy history detail')); const history = await rejected(pending);
      expect(history.kind).assertEqual(AppErrorKind.NETWORK); expect(history.retryable).assertTrue();
      expect(history.technicalMessage).assertEqual('Error: Legacy history detail');
      const chatsPending = f.chats.execute(); await settleReads();
      f.gateway.requests[1].fail(new Error('Legacy chats detail')); const chats = await rejected(chatsPending);
      expect(chats.kind).assertEqual(AppErrorKind.NETWORK); expect(chats.retryable).assertTrue();
      expect(chats.technicalMessage).assertEqual('Legacy chats detail');
    });
    it('a current rejected history bucket can accept a subsequent successful request', 0, async () => {
      const f = new ReadFixture(); const first = f.history.execute(f.params());
      f.gateway.requests[0].fail(classifyTdlibError(429, 'FLOOD_WAIT_37')); await rejected(first);
      expect(f.history.isLoading(42)).assertFalse(); const second = f.history.execute(f.params());
      expect(f.gateway.requests.length).assertEqual(2); expect(f.history.isLoading(42)).assertTrue();
      f.gateway.requests[1].succeed(); await second; expect(f.history.isLoading(42)).assertFalse();
    });
    ['success', 'error'].forEach((outcome: string) => {
      it('retired history ' + outcome + ' is inert and cannot release a fresh same-chat bucket', 0, async () => {
        const f = new ReadFixture(); const old = f.history.execute(f.params());
        LoadChatHistoryUseCase.resetState(); const fresh = new LoadChatHistoryUseCase(f.store.createScope(), f.gateway);
        const current = fresh.execute(f.params()); expect(fresh.isLoading(42)).assertTrue();
        if (outcome === 'success') f.gateway.requests[0].succeed();
        else f.gateway.requests[0].fail(classifyTdlibError(401, 'Retired account error'));
        await inertHistory(old); expect(fresh.isLoading(42)).assertTrue();
        expect(fresh.hasHistoryBeenFetched(42)).assertFalse();
        f.gateway.requests[1].succeed(); await current; expect(fresh.isLoading(42)).assertFalse();
      });
    });
    it('revoking only the real AppStore scope suppresses a pending typed history error', 0, async () => {
      const f = new ReadFixture(); const pending = f.history.execute(f.params()); const before = f.store.getState();
      f.store.invalidateScopes(); f.gateway.requests[0].fail(classifyTdlibError(401, 'Retired scope auth'));
      await inertHistory(pending); expect(f.store.getState() === before).assertTrue();
    });
    it('cancelled loadChats suppresses obsolete typed rejection without further store changes', 0, async () => {
      const f = new ReadFixture(); const pending = (await f.startChats())[0]; f.chats.cancel();
      const before = f.store.getState(); f.gateway.requests[0].fail(classifyTdlibError(401, 'Obsolete auth'));
      await pending; expect(f.store.getState() === before).assertTrue(); expect(f.store.getState().chats.isLoading).assertTrue();
    });
    ['ordinary', 'aroundUnread'].forEach((branch: string) => {
      ['auth-retryable', 'rate-limit', 'nonretryable-network', 'invalid-command', 'expired', 'network', 'warming', 'legacy']
        .forEach((cause: string) => {
          it(branch + ' rejected retry decision: ' + cause, 0, async () => {
            const correction = branch === 'aroundUnread'; const f = new RetryFixture(correction); await f.start(correction);
            f.gateway.requests[0].fail(retryCause(cause)); await settleReads();
            const retry = cause === 'network' || cause === 'warming' || cause === 'legacy';
            expect(f.attempts.length).assertEqual(retry ? 1 : 0);
            if (retry) expect(f.attempts[0]).assertEqual(correction ? 0 : 1);
            expect(f.history.isLoading(42)).assertFalse(); expect(f.gateway.requests.length).assertEqual(1);
          });
        });
    });
    ['scope', 'route', 'lifecycle', 'usecase'].forEach((owner: string) => {
      it('current NETWORK error cannot schedule after ' + owner + ' retirement', 0, async () => {
        const f = new RetryFixture(); await f.start(false);
        if (owner === 'scope') f.store.invalidateScopes();
        else if (owner === 'route') f.routeContext = new ChatScreenRouteParams(42, 'Replacement', f.store, f.gateway);
        else if (owner === 'lifecycle') f.pageLifecycleToken++;
        else f.loadChatHistoryUseCase = new LoadChatHistoryUseCase(f.store.createScope(), f.gateway);
        f.gateway.requests[0].fail(classifyTdlibError(503, 'Synthetic obsolete network')); await settleReads();
        expect(f.attempts.length).assertEqual(0); expect(f.gateway.requests.length).assertEqual(1);
      });
    });
    [401, 429].forEach((code: number) => {
      ['before', 'after'].forEach((timing: string) => {
        it('terminal ' + code.toString() + ' consumes late correction ' + timing + ' rejection and cancels its real timer', 0, async () => {
          const f = new RetryFixture(true);
          try {
            await f.startWithoutSnapshot();
            if (timing === 'before') { f.lateSnapshot(); expect(f.historyFallbackTimerId >= 0).assertTrue(); }
            f.gateway.requests[0].fail(classifyTdlibError(code, code === 401 ? 'SESSION_EXPIRED' : 'FLOOD_WAIT_37'));
            await settleReads();
            expect(f.initialHistoryFallbackRequested).assertFalse(); expect(f.historyFallbackTimerId).assertEqual(-1);
            if (timing === 'after') { f.lateSnapshot(); expect(f.historyFallbackTimerId).assertEqual(-1); }
            expect(f.gateway.requests.length).assertEqual(1);
          } finally { f.disposeTimer(); }
        });
      });
      it('obsolete ' + code.toString() + ' callback preserves replacement route correction timer', 0, async () => {
        const f = new RetryFixture(true);
        try {
          await f.startWithoutSnapshot(); f.lateSnapshot();
          f.routeContext = new ChatScreenRouteParams(42, 'Replacement timer owner', f.store, f.gateway);
          const route = f.routeContext;
          expect(await route.openLease.ensureOpen((): boolean => f.isRouteContextCurrent(route))).assertTrue();
          f.initialHistoryParams = undefined; f.initialHistoryFallbackRequested = true; f.lateSnapshot();
          const currentTimer = f.historyFallbackTimerId; expect(currentTimer >= 0).assertTrue();
          f.gateway.requests[0].fail(classifyTdlibError(code, code === 401 ? 'SESSION_EXPIRED' : 'FLOOD_WAIT_37'));
          await settleReads();
          expect(f.historyFallbackTimerId).assertEqual(currentTimer); expect(f.initialHistoryFallbackRequested).assertTrue();
          expect(f.gateway.requests.length).assertEqual(1);
        } finally { f.disposeTimer(); }
      });
    });
    ['success', 'network'].forEach((outcome: string) => {
      ['before', 'after'].forEach((timing: string) => {
        it(outcome + ' retains a real late correction timer ' + timing + ' completion', 0, async () => {
          const f = new RetryFixture(true);
          try {
            await f.startWithoutSnapshot(); if (timing === 'before') f.lateSnapshot();
            if (outcome === 'success') f.gateway.requests[0].succeed();
            else f.gateway.requests[0].fail(classifyTdlibError(503, 'Synthetic retryable network'));
            await settleReads(); if (timing === 'after') f.lateSnapshot();
            expect(f.initialHistoryFallbackRequested).assertTrue(); expect(f.historyFallbackTimerId >= 0).assertTrue();
            expect(f.initialHistoryParams?.reason).assertEqual('aroundUnread'); expect(f.gateway.requests.length).assertEqual(1);
          } finally { f.disposeTimer(); }
        });
      });
    });
    [401, 429].forEach((code: number) => {
      ['pending', 'completed'].forEach((state: string) => {
        it('obsolete ' + code.toString() + ' rejection preserves newer same-route ' + state + ' correction owner', 0, async () => {
          const f = new RetryFixture(true);
          try {
            await f.startWithoutSnapshot();
            f.gateway.requests[0].fail(classifyTdlibError(code, code === 401 ? 'SESSION_EXPIRED' : 'FLOOD_WAIT_37'));
            let newerTimer = -1;
            // Actual Domain releases its bucket in the first rejection microtask.
            // Start a new operation before the old coordinator .then().catch().
            await Promise.resolve().then((): void => {
              f.requestHistoryWithRetry(42, 0); expect(f.gateway.requests.length).assertEqual(2);
              f.lateSnapshot(); newerTimer = f.historyFallbackTimerId;
              if (state === 'completed') f.gateway.requests[1].succeed();
            });
            await settleReads(); expect(newerTimer >= 0).assertTrue();
            expect(f.initialHistoryFallbackRequested).assertTrue(); expect(f.historyFallbackTimerId >= 0).assertTrue();
            expect(f.history.isLoading(42)).assertEqual(state === 'pending');
            if (state === 'pending') {
              expect(f.historyFallbackTimerId).assertEqual(newerTimer);
              f.gateway.requests[1].succeed(); await settleReads();
            }
            // A completed current request retains around-unread correction (0),
            // rather than falling through to ordinary retry (1 / 450ms).
            expect(f.attempts[f.attempts.length - 1]).assertEqual(0); expect(f.gateway.requests.length).assertEqual(2);
          } finally { f.disposeTimer(); }
        });
      });
    });
    it('obsolete success cannot replace a newer same-route pending correction timer', 0, async () => {
      const f = new RetryFixture(true);
      try {
        await f.startWithoutSnapshot(); f.gateway.requests[0].succeed(); let newerTimer = -1;
        await Promise.resolve().then((): void => {
          f.requestHistoryWithRetry(42, 0); expect(f.gateway.requests.length).assertEqual(2);
          f.lateSnapshot(); newerTimer = f.historyFallbackTimerId;
        });
        await settleReads(); expect(newerTimer >= 0).assertTrue();
        expect(f.historyFallbackTimerId).assertEqual(newerTimer); expect(f.history.isLoading(42)).assertTrue();
        f.gateway.requests[1].succeed(); await settleReads(); expect(f.attempts[f.attempts.length - 1]).assertEqual(0);
      } finally { f.disposeTimer(); }
    });
    ['success', 'error'].forEach((outcome: string) => {
      it('Domain reset retires an old ' + outcome + ' continuation even with the same host usecase and route', 0, async () => {
        const f = new RetryFixture(true);
        try {
          await f.startWithoutSnapshot(); f.lateSnapshot(); f.disposeTimer(); f.attempts.length = 0;
          LoadChatHistoryUseCase.resetState();
          const fresh = new LoadChatHistoryUseCase(f.store.createScope(), f.gateway);
          const current = fresh.execute(f.params()); expect(f.gateway.requests.length).assertEqual(2);
          // Preserve the old host/use-case reference so only Domain request
          // ownership can reject its continuation, not the outer route guards.
          if (outcome === 'success') f.gateway.requests[0].succeed();
          else f.gateway.requests[0].fail(classifyTdlibError(401, 'Reset old typed rejection'));
          await settleReads(); expect(f.attempts.length).assertEqual(0); expect(f.historyFallbackTimerId).assertEqual(-1);
          expect(fresh.isLoading(42)).assertTrue(); f.gateway.requests[1].succeed(); await current;
          expect(fresh.isLoading(42)).assertFalse();
        } finally { f.disposeTimer(); }
      });
    });
    it('an execution skipped by a retired Domain instance cannot schedule a correction without a new reservation', 0, async () => {
      const f = new RetryFixture(true);
      try {
        await f.startWithoutSnapshot(); f.gateway.requests[0].succeed(); await settleReads();
        f.lateSnapshot(); f.disposeTimer(); f.attempts.length = 0; LoadChatHistoryUseCase.resetState();
        f.requestHistoryWithRetry(42, 0); await settleReads();
        expect(f.gateway.requests.length).assertEqual(1); expect(f.attempts.length).assertEqual(0);
        expect(f.historyFallbackTimerId).assertEqual(-1);
      } finally { f.disposeTimer(); }
    });
  });
}
