// Mounted production pages. Only transport/auth bootstrap are controlled.
// This fixture never initializes native TDLib, logs in, or delivers a message.
import { AppCoreRuntime, AppCoreRuntimeBindings } from '../../../../main/ets/app/bootstrap/AppCoreRuntime';
import { AppStore } from '../../../../main/ets/core/store/AppStore';
import { appReducer } from '../../../../main/ets/core/reducers/index';
import { AppState, User, Chat, createInitialAppState } from '../../../../main/ets/core/model/AppState';
import { AppError, AppErrorKind } from '../../../../main/ets/core/model/AppError';
import { AnyAppEvent } from '../../../../main/ets/core/model/AppEvent';
import { AnyAppCommand } from '../../../../main/ets/core/model/AppCommand';
import { TdGateway, GatewayStats, ClientRecoveryHooks } from '../../../../main/ets/infra/td/gateway/TdGateway';
import { TdGatewayPort } from '../../../../main/ets/domain/ports/TdGatewayPort';
import { TdObject } from '../../../../main/ets/models/TdTypes';
import { ProfileLoadContext } from '../../../../main/ets/domain/usecases/loadProfileInfo';
import { ProfileMembersRouteParams } from '../../../../main/ets/ui/pages/profile/TgProfileMembersPage';
import { ProfileRouteParams } from '../../../../main/ets/ui/pages/profile/TgProfilePage';
import { LoginRouterPage } from '../../../../main/ets/ui/pages/login/LoginRouterPage';
import { TgUiTokens } from '../../../../main/ets/ui/tg_ui/tokens/TgUiTokens';
import { ChatScreenRouteParams } from '../../../../main/ets/ui/pages/chat/ChatScreenRouteParams';
import { HandleNavShownPort, handleNavShown } from '../../../../main/ets/ui/pages/chat/ChatScreenViewEventHandlers';
import { PendingSharedMediaAction } from '../../../../main/ets/ui/pages/chat/PendingSharedMediaActionSignal';

export const STABILIZATION_STARTUP_ROUTE = 'StabilizationStartupRoute';

export class StabilizationRequest {
  command: AnyAppCommand;
  resolve?: (value: Object) => void;
  reject?: (error: AppError) => void;
  constructor(command: AnyAppCommand) { this.command = command; }
}
export class StabilizationControlledPort implements TdGatewayPort {
  readonly requests: StabilizationRequest[] = [];
  initialize(): Promise<void> { throw new Error('Fixture port forbids transport bootstrap'); }
  send(command: AnyAppCommand): Promise<Object> {
    if (command.type !== 'getSupergroupMembers' && command.type !== 'searchChatMembers' && command.type !== 'getUserFullInfo' && command.type !== 'getSupergroupFullInfo') {
      throw new Error('Fixture forbids command=' + command.type);
    }
    const request = new StabilizationRequest(command); this.requests.push(request);
    console.info('[StabilizationNative] controlledCommand=' + command.type + ' request=' + this.requests.length.toString() + ' commandJson=' + JSON.stringify(command));
    return new Promise<Object>((resolve, reject) => { request.resolve = resolve; request.reject = reject; });
  }
  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void { return (): void => {}; }
  getConnectionState(): 'ready' { return 'ready'; }
  destroy(): Promise<void> { return Promise.resolve(); }
}
class StartupControlledGateway implements TdGateway {
  initializeCalls: number = 0;
  destroyCalls: number = 0;
  sendCalls: number = 0;
  private state: 'idle' | 'initializing' | 'ready' | 'destroying' = 'idle';
  private generation: number = 0;
  private listeners: Set<(update: TdObject) => void> = new Set();
  private resolveInitialize?: () => void;
  private rejectInitialize?: (error: AppError) => void;
  private resolveDestroy?: () => void;
  private rejectDestroy?: (error: AppError) => void;
  holdRetirement: boolean = false;
  initialize(): Promise<void> {
    this.initializeCalls++; this.state = 'initializing';
    console.info('[StabilizationNative] controlledInitialize=' + this.initializeCalls.toString());
    console.info('[StabilizationNative] controlledInitializeStack=' + (new Error('controlled-initialize-origin').stack ?? 'unavailable'));
    return new Promise<void>((resolve, reject) => { this.resolveInitialize = resolve; this.rejectInitialize = reject; });
  }
  rejectStartup(): void { this.rejectInitialize?.(new AppError(AppErrorKind.NETWORK, 'Controlled startup rejection')); }
  resolveStartup(): void {
    this.state = 'ready'; this.resolveInitialize?.();
    this.emit(TdObject.fromJSON('{"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitPhoneNumber"}}'));
  }
  destroy(): Promise<void> {
    this.destroyCalls++; this.state = 'destroying';
    console.info('[StabilizationNative] controlledDestroy=' + this.destroyCalls.toString());
    if (!this.holdRetirement) { this.state = 'idle'; this.generation++; return Promise.resolve(); }
    return new Promise<void>((resolve, reject) => { this.resolveDestroy = resolve; this.rejectDestroy = reject; });
  }
  settleRetirement(success: boolean): void {
    if (success) { this.state = 'idle'; this.generation++; this.resolveDestroy?.(); }
    else this.rejectDestroy?.(new AppError(AppErrorKind.NETWORK, 'Controlled retirement rejection'));
  }
  send(_method: string, _params?: TdObject): Promise<TdObject> { this.sendCalls++; throw new Error('Native transport is forbidden'); }
  sendWithRetry(_method: string, _params?: TdObject, _maxRetries?: number, _baseDelayMs?: number): Promise<TdObject> {
    this.sendCalls++; throw new Error('Native transport retry is forbidden');
  }
  subscribeUpdates(handler: (update: TdObject) => void): () => void { this.listeners.add(handler); return (): void => { this.listeners.delete(handler); }; }
  private emit(update: TdObject): void { this.listeners.forEach((handler) => handler(update)); }
  setClientRecoveryHooks(_hooks?: ClientRecoveryHooks): void {}
  getClientGeneration(): number { return this.generation; }
  retryClosedClient(): Promise<void> { throw new Error('Fixture does not invoke Closed recovery'); }
  getState(): 'idle' | 'initializing' | 'ready' | 'destroying' { return this.state; }
  getGatewayStats(): GatewayStats { return { state: this.state, pendingRequests: 0, timeouts: 0 }; }
  isReady(): boolean { return this.state === 'ready'; }
  isDrainCongested(): boolean { return false; }
}
class StartupControlledBindings implements AppCoreRuntimeBindings {
  gateway: StartupControlledGateway;
  adapter: StabilizationControlledPort;
  authStarts: number = 0;
  constructor(gateway: StartupControlledGateway, adapter: StabilizationControlledPort) { this.gateway = gateway; this.adapter = adapter; }
  startAuthSideEffect(_store: AppStore): void { this.authStarts++; }
  stopAuthSideEffect(): void {}
  handleRawUpdate(_rawJson: string): void { throw new Error('Fixture forbids native raw update delivery'); }
}
class StabilizationStartupSession {
  readonly gateway: StartupControlledGateway;
  readonly port: StabilizationControlledPort;
  readonly runtime: AppCoreRuntime;
  readonly retirementStarted: Promise<void>;
  private resolveRetirementStarted?: () => void;
  private retirementTask?: Promise<void>;
  private startupTask: Promise<void>;
  private startupFailure: boolean = false;
  constructor(holdRetirement: boolean) {
    this.gateway = new StartupControlledGateway(); this.gateway.holdRetirement = holdRetirement;
    this.port = new StabilizationControlledPort();
    this.runtime = new AppCoreRuntime(new StartupControlledBindings(this.gateway, this.port));
    // Installed before navigation/Back. Awaiting this can never silently await
    // undefined while native disappearance is still queued.
    this.retirementStarted = new Promise<void>((resolve) => { this.resolveRetirementStarted = resolve; });
    this.startupTask = this.runtime.initialize().catch((_error: Error): void => { this.startupFailure = true; });
  }
  async initialStartupSettled(): Promise<void> {
    await this.startupTask;
    if (!this.startupFailure) throw new Error('Expected controlled initial startup rejection did not occur');
  }
  retire(): void {
    if (this.retirementTask !== undefined) return;
    this.retirementTask = this.runtime.retire();
    this.resolveRetirementStarted?.();
  }
  async waitRetired(): Promise<void> {
    await this.retirementStarted;
    const task = this.retirementTask;
    if (task === undefined) throw new Error('Owned native retirement callback did not install its task');
    await task;
  }
}
// Only a local STACK witness destination. It invokes the production consumer,
// but does not mount a full chat client or acquire a ChatOpenLease/transport.
class StabilizationSearchStackHost implements HandleNavShownPort {
  activeChatId: number;
  accountStore: AppStore;
  routeContext: ChatScreenRouteParams;
  opens: number = 0;
  private renderSearch: () => void;
  constructor(route: ChatScreenRouteParams, renderSearch: () => void) {
    this.activeChatId = route.chatId; this.accountStore = route.accountStore;
    this.routeContext = route; this.renderSearch = renderSearch;
  }
  showOwnedChatRoute(): boolean { return this.routeContext.isCurrentAccount(this.accountStore); }
  openSearch(): void { this.opens++; this.renderSearch(); }
  beginSharedMediaAction(_action: PendingSharedMediaAction): void {}
  jumpToMessageId(_messageId: string): void {}
}
export class StabilizationUiRouteIdentity {
  readonly name: string;
  readonly param?: Object;
  constructor(name: string, param?: Object) { this.name = name; this.param = param; }
}

// Passive identity witness only. It never changes navigation or account state.
export class StabilizationUiOwnership {
  readonly stack: NavPathStack;
  readonly routes: StabilizationUiRouteIdentity[];
  readonly runtimeOwner?: AppCoreRuntime;
  readonly storeOwner?: AppStore;
  constructor(stack: NavPathStack, routes: StabilizationUiRouteIdentity[], runtimeOwner?: AppCoreRuntime, storeOwner?: AppStore) {
    this.stack = stack; this.routes = routes; this.runtimeOwner = runtimeOwner; this.storeOwner = storeOwner;
  }
}

export class StabilizationNativeFixture {
  private static stack?: NavPathStack;
  private static startup?: AppCoreRuntime;
  private static startupSessions: Map<AppCoreRuntime, StabilizationStartupSession> = new Map();
  private static rootStore?: AppStore;
  private static profilePort?: StabilizationControlledPort;
  private static searchMode: 'normal' | 'wrongAccount' | 'missing' = 'normal';
  private static searchTarget?: ChatScreenRouteParams;
  private static searchHosts: Map<number, StabilizationSearchStackHost> = new Map();
  static bindNavigation(stack: NavPathStack): void { StabilizationNativeFixture.stack = stack; }
  static navigationDepth(): number { return StabilizationNativeFixture.stack?.size() ?? -1; }
  static navigationBound(): boolean { return StabilizationNativeFixture.stack !== undefined; }
  static captureUiOwnership(expectedDepth: number): StabilizationUiOwnership {
    const stack = StabilizationNativeFixture.stack;
    if (stack === undefined || stack.size() !== expectedDepth) throw new Error('UI ownership capture lost expected navigation');
    const names = stack.getAllPathName();
    const routes: StabilizationUiRouteIdentity[] = [];
    for (let index = 0; index < names.length; index++) {
      const param: Object | undefined = stack.getParamByIndex(index) as Object | undefined;
      routes.push(new StabilizationUiRouteIdentity(names[index], param));
    }
    return new StabilizationUiOwnership(stack, routes, StabilizationNativeFixture.startup, StabilizationNativeFixture.rootStore);
  }
  static isUiOwnershipPopped(owner: StabilizationUiOwnership): boolean {
    const stack = StabilizationNativeFixture.stack;
    if (stack === undefined || stack !== owner.stack || owner.routes.length === 0 || stack.size() !== owner.routes.length - 1) return false;
    if (StabilizationNativeFixture.startup !== owner.runtimeOwner || StabilizationNativeFixture.rootStore !== owner.storeOwner) return false;
    const names = stack.getAllPathName();
    if (names.length !== owner.routes.length - 1) return false;
    for (let index = 0; index < names.length; index++) {
      if (names[index] !== owner.routes[index].name || stack.getParamByIndex(index) !== owner.routes[index].param) return false;
    }
    return true;
  }
  static isUiOwnershipCurrent(owner: StabilizationUiOwnership): boolean {
    const stack = StabilizationNativeFixture.stack;
    if (stack === undefined || stack !== owner.stack || stack.size() !== owner.routes.length ||
      StabilizationNativeFixture.startup !== owner.runtimeOwner || StabilizationNativeFixture.rootStore !== owner.storeOwner) return false;
    const names = stack.getAllPathName();
    if (names.length !== owner.routes.length) return false;
    for (let index = 0; index < names.length; index++) {
      if (names[index] !== owner.routes[index].name || stack.getParamByIndex(index) !== owner.routes[index].param) return false;
    }
    return true;
  }
  static async prepareStartup(holdRetirement: boolean = false): Promise<void> {
    const previous = StabilizationNativeFixture.startup;
    if (previous !== undefined) await StabilizationNativeFixture.waitRetired(previous);
    const session = new StabilizationStartupSession(holdRetirement);
    StabilizationNativeFixture.startupSessions.set(session.runtime, session);
    StabilizationNativeFixture.startup = session.runtime;
    await new Promise<void>((resolve) => { setTimeout(() => resolve(), 0); });
  }
  static runtime(): AppCoreRuntime {
    const runtime = StabilizationNativeFixture.startup;
    if (runtime === undefined) throw new Error('Startup fixture not prepared');
    return runtime;
  }
  private static startupSession(owner: AppCoreRuntime): StabilizationStartupSession {
    const session = StabilizationNativeFixture.startupSessions.get(owner);
    if (session === undefined) throw new Error('Owned startup fixture session absent');
    return session;
  }
  static failStartup(): void { StabilizationNativeFixture.startupSession(StabilizationNativeFixture.runtime()).gateway.rejectStartup(); }
  static completeStartup(): void { StabilizationNativeFixture.startupSession(StabilizationNativeFixture.runtime()).gateway.resolveStartup(); }
  static async initialStartupSettled(): Promise<void> {
    await StabilizationNativeFixture.startupSession(StabilizationNativeFixture.runtime()).initialStartupSettled();
  }
  static initializeCalls(): number { return StabilizationNativeFixture.startupSession(StabilizationNativeFixture.runtime()).gateway.initializeCalls; }
  static destroyCalls(): number { return StabilizationNativeFixture.startupSession(StabilizationNativeFixture.runtime()).gateway.destroyCalls; }
  static settleRetirement(success: boolean): void { StabilizationNativeFixture.startupSession(StabilizationNativeFixture.runtime()).gateway.settleRetirement(success); }
  static forbidTransportProof(): void {
    const session = StabilizationNativeFixture.startupSession(StabilizationNativeFixture.runtime());
    if (session.gateway.sendCalls !== 0 || session.port.requests.length !== 0) {
      throw new Error('Startup fixture crossed its forbidden transport boundary');
    }
  }
  static onStartupDisappear(owner: AppCoreRuntime): void {
    StabilizationNativeFixture.startupSession(owner).retire();
  }
  static waitRetirementStarted(owner: AppCoreRuntime): Promise<void> {
    return StabilizationNativeFixture.startupSession(owner).retirementStarted;
  }
  static async waitRetired(owner: AppCoreRuntime = StabilizationNativeFixture.runtime()): Promise<void> {
    await StabilizationNativeFixture.startupSession(owner).waitRetired();
  }
  static prepareProfiles(): void {
    const state: AppState = createInitialAppState(); state.auth.userId = 123;
    const chat = new Chat(); chat.id = -42; chat.title = 'Controlled members'; chat.type = 'supergroup'; chat.supergroupId = 77;
    state.chats.chats.set(chat.id, chat);
    for (let id = 1000; id < 1120; id++) { const user = new User(); user.id = id; user.firstName = 'Member ' + id.toString(); state.users.users.set(id, user); }
    const alice = new User(); alice.id = 7; alice.firstName = 'Current Alice'; alice.bio = 'Cached bio'; state.users.users.set(7, alice);
    StabilizationNativeFixture.rootStore = new AppStore(appReducer, state, false);
    StabilizationNativeFixture.profilePort = new StabilizationControlledPort();
  }
  static store(): AppStore {
    const store = StabilizationNativeFixture.rootStore;
    if (store === undefined) throw new Error('Profile fixture not prepared'); return store;
  }
  static port(): StabilizationControlledPort {
    const port = StabilizationNativeFixture.profilePort;
    if (port === undefined) throw new Error('Profile gateway not prepared'); return port;
  }
  static context(): ProfileLoadContext { return new ProfileLoadContext(StabilizationNativeFixture.store(), StabilizationNativeFixture.port()); }
  static membersParams(context?: ProfileLoadContext): ProfileMembersRouteParams {
    return new ProfileMembersRouteParams(-42, 77, 'all', 120, context ?? StabilizationNativeFixture.context());
  }
  static profileParams(context?: ProfileLoadContext): ProfileRouteParams { return new ProfileRouteParams(0, 7, context ?? StabilizationNativeFixture.context()); }
  static requestCount(): number { return StabilizationNativeFixture.port().requests.length; }
  static failProfileRequest(index: number): void {
    StabilizationNativeFixture.port().requests[index].reject?.(new AppError(AppErrorKind.NETWORK, 'Controlled unavailable', '', 503, true));
  }
  static replyMembers(index: number, firstId: number, count: number, total: number = 120): void {
    const members: string[] = [];
    for (let i = 0; i < count; i++) members.push('{"@type":"chatMember","member_id":{"@type":"messageSenderUser","user_id":' +
      (firstId + i).toString() + '},"status":{"@type":"chatMemberStatusMember"}}');
    StabilizationNativeFixture.port().requests[index].resolve?.(TdObject.fromJSON('{"@type":"chatMembers","total_count":' +
      total.toString() + ',"members":[' + members.join(',') + ']}'));
  }
  static replyBio(index: number, text: string): void {
    StabilizationNativeFixture.port().requests[index].resolve?.(TdObject.fromJSON('{"@type":"userFullInfo","bio":{"@type":"formattedText","text":' + JSON.stringify(text) + ',"entities":[]}}'));
  }
  static revokeAccount(): void { StabilizationNativeFixture.store().invalidateScopes(); }
  static pushMembers(context?: ProfileLoadContext): void { StabilizationNativeFixture.stack?.pushPathByName('TgProfileMembersPage', StabilizationNativeFixture.membersParams(context)); }
  static pushProfile(context?: ProfileLoadContext): void { StabilizationNativeFixture.stack?.pushPathByName('TgProfilePage', StabilizationNativeFixture.profileParams(context)); }
  static prepareSearchStack(mode: 'normal' | 'wrongAccount' | 'missing'): void {
    StabilizationNativeFixture.prepareProfiles(); StabilizationNativeFixture.searchMode = mode;
    StabilizationNativeFixture.searchTarget = undefined; StabilizationNativeFixture.searchHosts.clear();
  }
  static pushSearchStack(): void {
    const stack = StabilizationNativeFixture.stack;
    if (stack === undefined || stack.size() !== 0) throw new Error('Search stack requires actual empty root');
    const store = StabilizationNativeFixture.store(); const port = StabilizationNativeFixture.port();
    const first = new ChatScreenRouteParams(-41, 'Controlled stack Chat A', store, port);
    const otherOwner = StabilizationNativeFixture.searchMode === 'wrongAccount' ? new AppStore(appReducer, createInitialAppState(), false) : store;
    const secondId = StabilizationNativeFixture.searchMode === 'missing' ? -43 : -42;
    const second = new ChatScreenRouteParams(secondId, 'Controlled stack Chat B', otherOwner, port);
    StabilizationNativeFixture.searchTarget = second;
    stack.pushPath({ name: 'TgChatScreenPage', param: first }, false);
    stack.pushPath({ name: 'TgChatScreenPage', param: second }, false);
    const params = new ProfileRouteParams(-42, 0, StabilizationNativeFixture.context());
    stack.pushPath({ name: 'TgProfilePage', param: params }, false);
  }
  static bindSearchHost(route: ChatScreenRouteParams, renderSearch: () => void): StabilizationSearchStackHost {
    const host = new StabilizationSearchStackHost(route, renderSearch);
    StabilizationNativeFixture.searchHosts.set(route.navigationToken, host); return host;
  }
  static searchOpenCalls(): number {
    let count = 0; StabilizationNativeFixture.searchHosts.forEach((host) => { count += host.opens; }); return count;
  }
  static returnedSearchTargetIsCurrent(): boolean {
    const stack = StabilizationNativeFixture.stack; const target = StabilizationNativeFixture.searchTarget;
    if (stack === undefined || target === undefined || stack.size() !== 2) return false;
    const top = stack.getParamByIndex(1) as Object;
    return top === target && top instanceof ChatScreenRouteParams && top.chatId === -42 &&
      top.accountStore === StabilizationNativeFixture.store() && top.isCurrentAccount(StabilizationNativeFixture.store()) &&
      stack.getAllPathName()[1] === 'TgChatScreenPage';
  }
}

@ComponentV2
export struct StabilizationSearchStackChatView {
  @Local private title: string = 'Controlled stack destination';
  @Local private searchOpened: boolean = false;
  private host?: StabilizationSearchStackHost;
  build() {
    NavDestination() {
      Column({ space: 12 }) {
        Text('Controlled STACK witness only - no full chat client').fontSize(14)
        Text(this.title).id('stabilization-stack-chat')
        Text(this.searchOpened ? 'Controlled destination search consumed once' : 'Controlled destination search closed')
          .id('stabilization-stack-search-state')
      }.width('100%').height('100%').backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext): void => {
      const route = context.pathInfo.param as Object;
      if (!(route instanceof ChatScreenRouteParams)) throw new Error('Actual owned ChatScreenRouteParams required');
      this.title = route.chatTitle;
      this.host = StabilizationNativeFixture.bindSearchHost(route, (): void => { this.searchOpened = true; });
    })
    .onShown((): void => {
      if (this.host !== undefined) handleNavShown(this.host);
    })
  }
}

@ComponentV2
export struct StabilizationStartupFixtureView {
  @Require @Param runtimeOwner: AppCoreRuntime;
  private capturedRuntime?: AppCoreRuntime;
  aboutToAppear(): void { if (this.capturedRuntime === undefined) this.capturedRuntime = this.runtimeOwner; }
  private ownedRuntime(): AppCoreRuntime {
    if (this.capturedRuntime === undefined) this.capturedRuntime = this.runtimeOwner;
    return this.capturedRuntime;
  }
  private retireOwnedRuntime(): void {
    const owner = this.capturedRuntime;
    if (owner !== undefined) StabilizationNativeFixture.onStartupDisappear(owner);
  }
  aboutToDisappear(): void { this.retireOwnedRuntime(); }
  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        LoginRouterPage({ runtimeProvider: (): AppCoreRuntime => this.ownedRuntime() })
        Text('Controlled transport - local startup test').fontSize(11).fontColor(TgUiTokens.COLOR_TEXT_PREVIEW).id('stabilization-startup-ready')
      }.width('100%').height('100%')
    }
    .hideTitleBar(true)
    .onHidden((reason: VisibilityChangeReason): void => {
      // A system IME window can background the app without removing this route.
      if (reason === VisibilityChangeReason.TRANSITION) this.retireOwnedRuntime();
    })
  }
}
