import { describe, it, expect } from '@ohos/hypium';
import { AppStore, getDefaultStore, resetDefaultStore } from '../../../main/ets/core/store/AppStore';
import {
  AppState, ReducerAction, Chat, Message, User, FileTransfer, PendingMessage,
  AccentColorDefinition, createInitialAppState
} from '../../../main/ets/core/model/AppState';
import { AnyAppEvent, MyUserResolvedEvent, UserUpdatedEvent } from '../../../main/ets/core/model/AppEvent';
import { authReducer } from '../../../main/ets/core/reducers/authReducer';
import { usersReducer } from '../../../main/ets/core/reducers/usersReducer';

function sessionReducer(state: AppState, action: ReducerAction): AppState {
  return usersReducer(authReducer(state, action), action);
}

function resolvedUser(userId: number): MyUserResolvedEvent {
  const event = new MyUserResolvedEvent();
  event.userId = userId;
  return event;
}

function accountEvents(userId: number): AnyAppEvent[] {
  const user = new UserUpdatedEvent();
  user.userId = userId;
  user.userData.id = userId;
  user.userData.firstName = `account-${userId}`;
  return [resolvedUser(userId), user];
}

function seededAccount(): AppState {
  const state = createInitialAppState();
  state.auth.status = 'ready';
  state.auth.userId = 101;
  state.auth.phoneNumber = 'account-A-fixture';
  const user = new User();
  user.id = 101;
  state.users.users.set(101, user);
  const chat = new Chat();
  chat.id = 7;
  chat.draftText = 'private draft A';
  state.chats.chats.set(7, chat);
  state.chats.orderedChatIds = [7];
  const message = new Message();
  message.id = '8';
  message.chatId = 7;
  message.senderId = 101;
  const messages = new Map<string, Message>();
  messages.set('8', message);
  state.messages.messages.set(7, messages);
  state.messages.associatedMessages.set(7, messages);
  state.messages.pendingMessages.set('pending-A', new PendingMessage());
  state.files.transfers.set(9, new FileTransfer());
  state.files.aliases.set('remote-A', [9]);
  state.accentColors.colors.set(10, new AccentColorDefinition());
  state.accentColors.availableAccentColorIds = [10];
  state.lastEvent = resolvedUser(101);
  return state;
}

function expectEmpty(state: AppState): void {
  expect(state.auth.userId).assertEqual(0);
  expect(state.auth.status).assertEqual('notInitialized');
  expect(state.auth.phoneNumber).assertEqual('');
  expect(state.auth.codeLength).assertEqual(5);
  expect(state.connection.status).assertEqual('connecting');
  expect(state.users.users.size).assertEqual(0);
  expect(state.chats.chats.size).assertEqual(0);
  expect(state.chats.orderedChatIds.length).assertEqual(0);
  expect(state.messages.messages.size).assertEqual(0);
  expect(state.messages.associatedMessages.size).assertEqual(0);
  expect(state.messages.pendingMessages.size).assertEqual(0);
  expect(state.files.transfers.size).assertEqual(0);
  expect(state.files.aliases.size).assertEqual(0);
  expect(state.accentColors.colors.size).assertEqual(0);
  expect(state.accentColors.availableAccentColorIds.length).assertEqual(0);
  expect(state.lastEvent === undefined).assertTrue();
  expect(state.version).assertEqual(1);
}

export default function appStoreSessionTest() {
  describe('AppStoreSession', () => {
    it('root keeps serial order, batch notification count and empty batch barrier', 0, async () => {
      const root = new AppStore(sessionReducer);
      const seen: number[] = [];
      root.subscribe((state: AppState) => { seen.push(state.auth.userId); });
      const one = root.dispatch(resolvedUser(1));
      const singleBatch = root.dispatchBatch([resolvedUser(2)]);
      const batch = root.dispatchBatch([resolvedUser(3), resolvedUser(4)]);
      await root.dispatchBatch([]);
      await Promise.all([one, singleBatch, batch]);
      expect(seen.join(',')).assertEqual('1,2,4');
      expect(root.select((state: AppState) => state.auth.userId)).assertEqual(4);
    });

    it('wave1 dequeue guards preserve false, current and unguarded dispatch paths', 0, async () => {
      const root = new AppStore(sessionReducer);
      let active = true;
      const guard = (): boolean => active;
      let calls = 0;
      root.subscribe(() => { calls++; });
      const one = root.dispatch(resolvedUser(1), guard);
      const singleBatch = root.dispatchBatch([resolvedUser(2)], guard);
      const batch = root.dispatchBatch([resolvedUser(3), resolvedUser(4)], guard);
      active = false;
      await Promise.all([one, singleBatch, batch]);
      expect(root.getState().auth.userId).assertEqual(0);
      expect(calls).assertEqual(0);
      await root.dispatch(resolvedUser(5));
      active = true;
      await root.dispatchBatch([resolvedUser(6), resolvedUser(7)], guard);
      expect(root.getState().auth.userId).assertEqual(7);
      expect(calls).assertEqual(2);
    });

    it('synchronous reset drops already queued root singleton and batch events', 0, async () => {
      const root = new AppStore(sessionReducer, seededAccount(), false);
      const seen: number[] = [];
      root.subscribe((state: AppState) => { seen.push(state.auth.userId); });
      const one = root.dispatch(resolvedUser(101));
      const singleBatch = root.dispatchBatch([resolvedUser(102)]);
      const batch = root.dispatchBatch([resolvedUser(103), resolvedUser(104)]);
      root.resetState();
      expectEmpty(root.getState());
      await Promise.all([one, singleBatch, batch]);
      expectEmpty(root.getState());
      expect(seen.join(',')).assertEqual('0');
      await root.dispatch(resolvedUser(202));
      expect(root.getState().auth.userId).assertEqual(202);
    });

    it('queued reset invalidates immediately, drops old work and preserves root subscriptions', 0, async () => {
      const root = new AppStore(sessionReducer, seededAccount(), false);
      const identity = root;
      const old = root.createScope();
      const seen: number[] = [];
      root.subscribe((state: AppState) => { seen.push(state.auth.userId); });
      const one = root.dispatch(resolvedUser(111));
      const singleBatch = root.dispatchBatch([resolvedUser(112)]);
      const batch = root.dispatchBatch([resolvedUser(113), resolvedUser(114)]);
      const scoped = old.dispatchBatch(accountEvents(115));
      const reset = root.resetStateQueued();
      expectEmpty(old.getState());
      expect(root.getState().auth.userId).assertEqual(101);
      await Promise.all([one, singleBatch, batch, scoped, reset]);
      expect(root === identity).assertTrue();
      expectEmpty(root.getState());
      expect(seen.join(',')).assertEqual('0');
      await root.createScope().dispatchBatch(accountEvents(202));
      expect(seen.join(',')).assertEqual('0,202');
      expect(root.getState().users.users.has(101)).assertFalse();
      expect(root.getState().users.users.has(202)).assertTrue();
    });

    it('late async A dispatch after B is ready cannot overwrite B', 0, async () => {
      const root = new AppStore(sessionReducer);
      const old = root.createScope();
      await old.dispatchBatch(accountEvents(101));
      let release: () => void = (): void => {};
      const gate = new Promise<void>((resolve) => { release = resolve; });
      const late = gate.then(async () => {
        await old.dispatch(resolvedUser(101));
        await old.dispatchBatch(accountEvents(101));
      });
      await root.resetStateQueued();
      const current = root.createScope();
      await current.dispatchBatch(accountEvents(202));
      release();
      await late;
      expect(current.getState().auth.userId).assertEqual(202);
      expect(current.getState().users.users.has(101)).assertFalse();
      expect(current.getState().users.users.has(202)).assertTrue();
    });

    it('stale reads and selectors return detached empty state rather than B', 0, async () => {
      const root = new AppStore(sessionReducer, seededAccount(), false);
      const old = root.createScope();
      await root.resetStateQueued();
      const current = root.createScope();
      await current.dispatchBatch(accountEvents(202));
      expect(current.select((state: AppState) => state.auth.userId)).assertEqual(202);
      expectEmpty(old.getState());
      expectEmpty(old.select((state: AppState) => state));
      const detached = old.getState();
      detached.auth.userId = 999;
      detached.users.users.set(999, new User());
      expectEmpty(old.getState());
      expect(current.getState().auth.userId).assertEqual(202);
      expect(current.getState().users.users.has(999)).assertFalse();
    });

    it('old subscriptions and subscriptions added while stale never observe B', 0, async () => {
      const root = new AppStore(sessionReducer);
      const old = root.createScope();
      const oldSeen: number[] = [];
      const stop = old.subscribe((state: AppState) => { oldSeen.push(state.auth.userId); });
      await old.dispatch(resolvedUser(101));
      await root.resetStateQueued();
      let staleCalls = 0;
      const stopStale = old.subscribe(() => { staleCalls++; });
      const current = root.createScope();
      const currentSeen: number[] = [];
      const stopCurrent = current.subscribe((state: AppState) => { currentSeen.push(state.auth.userId); });
      await current.dispatch(resolvedUser(202));
      stop();
      stopStale();
      stopCurrent();
      await current.dispatch(resolvedUser(203));
      expect(oldSeen.join(',')).assertEqual('101');
      expect(staleCalls).assertEqual(0);
      expect(currentSeen.join(',')).assertEqual('202');
    });

    it('nested scopes preserve their captured generation and cannot resurrect A', 0, async () => {
      const root = new AppStore(sessionReducer);
      const old = root.createScope();
      const nested = old.createScope();
      await nested.dispatch(resolvedUser(101));
      expect(old.getState().auth.userId).assertEqual(101);
      await root.resetStateQueued();
      const current = root.createScope();
      await current.createScope().dispatch(resolvedUser(202));
      const resurrected = old.createScope().createScope();
      await nested.dispatch(resolvedUser(111));
      await resurrected.dispatchBatch(accountEvents(112));
      expectEmpty(resurrected.getState());
      expect(current.getState().auth.userId).assertEqual(202);
    });

    it('stale resets, invalidation and reducer replacement cannot wipe or disable B', 0, async () => {
      const root = new AppStore(sessionReducer);
      const old = root.createScope();
      await root.resetStateQueued();
      const current = root.createScope();
      await current.dispatchBatch(accountEvents(202));
      old.replaceReducer((state: AppState) => state);
      old.resetState();
      await old.resetStateQueued();
      old.invalidateScopes();
      expect(current.getState().auth.userId).assertEqual(202);
      await current.dispatch(resolvedUser(203));
      expect(root.getState().auth.userId).assertEqual(203);
    });

    it('new scopes created before queued clear remain valid after that clear', 0, async () => {
      const root = new AppStore(sessionReducer);
      const old = root.createScope();
      const reset = root.resetStateQueued();
      const current = root.createScope();
      const write = current.dispatchBatch(accountEvents(202));
      await Promise.all([reset, write]);
      expectEmpty(old.getState());
      expect(current.getState().auth.userId).assertEqual(202);
      await current.dispatch(resolvedUser(203));
      expect(root.getState().auth.userId).assertEqual(203);
    });

    it('multiple queued resets serialize and only the newest account work survives', 0, async () => {
      const root = new AppStore(sessionReducer);
      const seen: number[] = [];
      root.subscribe((state: AppState) => { seen.push(state.auth.userId); });
      const firstReset = root.resetStateQueued();
      const middle = root.createScope();
      const middleWrite = middle.dispatchBatch(accountEvents(101));
      const secondReset = root.resetStateQueued();
      const newest = root.createScope();
      const newestWrite = newest.dispatchBatch(accountEvents(202));
      await Promise.all([firstReset, middleWrite, secondReset, newestWrite]);
      expect(seen.join(',')).assertEqual('0,0,202');
      expectEmpty(middle.getState());
      expect(newest.getState().auth.userId).assertEqual(202);
      expect(newest.getState().users.users.has(101)).assertFalse();
    });

    it('current scoped queued reset invalidates itself and peer scopes synchronously', 0, async () => {
      const root = new AppStore(sessionReducer, seededAccount(), false);
      const current = root.createScope();
      const peer = root.createScope();
      const reset = current.resetStateQueued();
      expectEmpty(current.getState());
      expectEmpty(peer.getState());
      const next = root.createScope();
      await Promise.all([reset, current.dispatch(resolvedUser(111)), next.dispatch(resolvedUser(202))]);
      await peer.resetStateQueued();
      expect(next.getState().auth.userId).assertEqual(202);
    });

    it('current scoped synchronous reset invalidates queued writes and peer scopes', 0, async () => {
      const root = new AppStore(sessionReducer, seededAccount(), false);
      const current = root.createScope();
      const peer = root.createScope();
      const queued = peer.dispatchBatch(accountEvents(111));
      current.resetState();
      expectEmpty(root.getState());
      expectEmpty(current.getState());
      expectEmpty(peer.getState());
      const next = root.createScope();
      await Promise.all([queued, next.dispatch(resolvedUser(202))]);
      expect(root.getState().auth.userId).assertEqual(202);
    });

    it('explicit invalidation preserves lifecycle state but drops queued events and scoped listeners', 0, async () => {
      const root = new AppStore(sessionReducer, seededAccount(), false);
      const current = root.createScope();
      let calls = 0;
      current.subscribe(() => { calls++; });
      const queued = root.dispatchBatch(accountEvents(111));
      current.invalidateScopes();
      expectEmpty(current.getState());
      expect(root.getState().auth.userId).assertEqual(101);
      await queued;
      expect(root.getState().auth.userId).assertEqual(101);
      await root.dispatch(resolvedUser(202));
      expect(calls).assertEqual(0);
    });

    it('current scoped guards and reducer replacement delegate to the same root queue', 0, async () => {
      const root = new AppStore(sessionReducer);
      const current = root.createScope();
      await current.dispatch(resolvedUser(101), (): boolean => false);
      await current.dispatchBatch(accountEvents(102), (): boolean => false);
      expect(root.getState().auth.userId).assertEqual(0);
      current.replaceReducer((state: AppState, action: ReducerAction): AppState => {
        return authReducer(state, resolvedUser(303));
      });
      await current.dispatch(resolvedUser(202));
      expect(root.getState().auth.userId).assertEqual(303);
      root.replaceReducer(sessionReducer);
      await current.dispatch(resolvedUser(404));
      expect(current.getState().auth.userId).assertEqual(404);
    });

    it('reentrant reset during notification never delivers the old state after clear', 0, async () => {
      const root = new AppStore(sessionReducer);
      const seen: number[] = [];
      root.subscribe((state: AppState) => {
        if (state.auth.userId === 101) root.resetState();
      });
      root.subscribe((state: AppState) => { seen.push(state.auth.userId); });
      await root.dispatch(resolvedUser(101));
      expect(seen.join(',')).assertEqual('0');
      expectEmpty(root.getState());
    });

    it('invalidation inside a dequeue guard cannot admit singleton or batch events', 0, async () => {
      const root = new AppStore(sessionReducer);
      const guard = (): boolean => { root.invalidateScopes(); return true; };
      await root.dispatch(resolvedUser(101), guard);
      await root.dispatchBatch(accountEvents(102), guard);
      expectEmpty(root.getState());
      await root.dispatch(resolvedUser(202));
      expect(root.getState().auth.userId).assertEqual(202);
    });

    it('default singleton identity and listeners survive reset without changing defaults', 0, async () => {
      resetDefaultStore();
      try {
        const root = getDefaultStore(sessionReducer);
        let calls = 0;
        const stop = root.subscribe(() => { calls++; });
        await root.dispatch(resolvedUser(101));
        root.resetState();
        expect(getDefaultStore(sessionReducer) === root).assertTrue();
        expectEmpty(root.getState());
        await root.dispatch(resolvedUser(202));
        expect(calls).assertEqual(3);
        stop();
        await root.dispatch(resolvedUser(203));
        expect(calls).assertEqual(3);
      } finally {
        resetDefaultStore();
      }
    });
  });
}
