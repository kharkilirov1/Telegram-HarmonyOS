import { describe, it, expect } from '@ohos/hypium';
import { Chat } from '../../../main/ets/core/model/AppState';
import { createGroupAccessUpdatedEvent, createSupergroupSlowmodeUpdatedEvent } from '../../../main/ets/core/model/AppEvent';
import { GroupAccessDto, SupergroupSlowmodeDto, createSupergroupSlowmodeDtoFromTd } from '../../../main/ets/core/model/dto/GroupAccessDto';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { navigationUIState } from '../../../main/ets/core/model/UIStateModels';
import { ChatSlowmodeController, remainingSlowmodeSeconds, currentSlowmodeSeconds } from '../../../main/ets/ui/pages/chat/ChatSlowmodeController';
import { ChatAccessController } from '../../../main/ets/ui/pages/chat/ChatAccessController';
import { LoadChatAccessUseCase } from '../../../main/ets/domain/usecases/loadChatAccess';
import { SlowmodeFixture, expectSlowmodeInputPreserved } from './Slowmode.test';
import { settleWrites } from './WritePathErrors.test';

// These additive callbacks exercise new public metadata/timer APIs. The 17
// existing-entry callbacks in Slowmode.test are run unchanged against baseline.
export function slowmodeReceipt(expires: number = 10.5, anchor: number = 100000): SupergroupSlowmodeDto {
  const value = createSupergroupSlowmodeDtoFromTd(TdObject.fromJSON(
    '{"@type":"supergroupFullInfo","slow_mode_delay":30,"slow_mode_delay_expires_in":' + expires.toString() + '}'), 77, anchor);
  if (value === undefined) throw new Error('Valid slowmode fixture receipt missing');
  return value;
}
function chatOf(f: SlowmodeFixture): Chat {
  const chat = f.store.getState().chats.chats.get(42);
  if (chat === undefined) throw new Error('Fixture chat missing');
  return chat;
}
async function setEnabled(f: SlowmodeFixture, enabled?: boolean): Promise<void> {
  const access = new GroupAccessDto(); access.kind = 'supergroup'; access.groupId = 77;
  access.role = 'member'; access.isMember = true; access.isActive = true; access.isSlowModeEnabled = enabled;
  await f.store.dispatch(createGroupAccessUpdatedEvent(access));
}
function fullInfo(expires: number): TdObject {
  return TdObject.fromJSON('{"@type":"supergroupFullInfo","slow_mode_delay":30,"slow_mode_delay_expires_in":' +
    expires.toString() + ',"my_boost_count":0,"unrestrict_boost_count":0}');
}
export class SlowmodeHydration {
  fixture: SlowmodeFixture = new SlowmodeFixture();
  controller: ChatAccessController;
  notifications: number = 0;
  private unsubscribe: () => void;
  constructor() {
    this.controller = new ChatAccessController(new LoadChatAccessUseCase(this.fixture.store, this.fixture.gateway), (): void => {
      this.notifications++; this.observe();
    });
    this.unsubscribe = this.fixture.store.subscribe((): void => { this.observe(); });
  }
  observe(): void {
    const state = this.fixture.store.getState();
    this.controller.observe(chatOf(this.fixture), state.chats.supergroupAccess.get(77),
      state.chats.supergroupBoosts.get(77), state.chats.supergroupSlowmode.get(77));
  }
  dispose(): void { this.controller.dispose(); this.unsubscribe(); }
}

export default function slowmodePolicyTest(): void {
  describe('SlowmodePolicy', () => {
    it('fractional relative expiry and its explicit receipt anchor survive parsing without boost fields', 0, () => {
      const slow = slowmodeReceipt(); expect(slow.groupId).assertEqual(77); expect(slow.delaySeconds).assertEqual(30);
      expect(slow.expiresInSeconds).assertEqual(10.5); expect(slow.receivedElapsedMs).assertEqual(100000);
    });
    it('the parser requires top-level numbers and the exact full-info type', 0, () => {
      const invalid: string[] = ['{"@type":"ok","slow_mode_delay":30,"slow_mode_delay_expires_in":10}',
        '{"@type":"supergroupFullInfo","nested":{"slow_mode_delay":30,"slow_mode_delay_expires_in":10}}',
        '{"@type":"supergroupFullInfo","slow_mode_delay":"30","slow_mode_delay_expires_in":10}',
        '{"@type":"supergroupFullInfo","slow_mode_delay":30,"slow_mode_delay_expires_in":"10"}',
        '{"@type":"supergroupFullInfo","slow_mode_delay":-1,"slow_mode_delay_expires_in":10}',
        '{"@type":"supergroupFullInfo","slow_mode_delay":30,"slow_mode_delay_expires_in":-1}'];
      for (const json of invalid) expect(createSupergroupSlowmodeDtoFromTd(TdObject.fromJSON(json), 77, 100000)).assertEqual(undefined);
    });
    it('invalid group and receipt clock never create a countdown', 0, () => {
      const response = fullInfo(10);
      for (const groupId of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 1]) {
        expect(createSupergroupSlowmodeDtoFromTd(response, groupId, 100000)).assertEqual(undefined);
      }
      for (const anchor of [-1, Number.NaN, Number.POSITIVE_INFINITY]) {
        expect(createSupergroupSlowmodeDtoFromTd(response, 77, anchor)).assertEqual(undefined);
      }
    });
    it('zero configured delay retires even a positive relative expiry', 0, () => {
      const receipt = createSupergroupSlowmodeDtoFromTd(TdObject.fromJSON(
        '{"@type":"supergroupFullInfo","slow_mode_delay":0,"slow_mode_delay_expires_in":10}'), 77, 100000);
      expect(receipt?.expiresInSeconds).assertEqual(0);
    });
    it('fractional expiry rounds upward until the exact boundary and never reanchors', 0, () => {
      const f = new SlowmodeFixture(); const slow = slowmodeReceipt(); const chat = chatOf(f);
      const access = f.store.getState().chats.supergroupAccess.get(77);
      expect(remainingSlowmodeSeconds(chat, access, undefined, slow, 100000)).assertEqual(11);
      expect(remainingSlowmodeSeconds(chat, access, undefined, slow, 100500)).assertEqual(10);
      expect(remainingSlowmodeSeconds(chat, access, undefined, slow, 110499)).assertEqual(1);
      expect(remainingSlowmodeSeconds(chat, access, undefined, slow, 110500)).assertEqual(0);
      expect(remainingSlowmodeSeconds(chat, access, undefined, slow, 999999)).assertEqual(0);
      expect(slow.receivedElapsedMs).assertEqual(100000);
    });
    it('a clock failure or backward reading does not silently grant a known countdown', 0, () => {
      const f = new SlowmodeFixture(); const slow = slowmodeReceipt(); const chat = chatOf(f);
      expect(remainingSlowmodeSeconds(chat, undefined, undefined, slow, Number.NaN)).assertEqual(11);
      expect(remainingSlowmodeSeconds(chat, undefined, undefined, slow, 99000)).assertEqual(11);
    });
    it('the reducer detaches producer receipts and leaves the original anchor through unrelated updates', 0, async () => {
      const f = new SlowmodeFixture(); const slow = slowmodeReceipt();
      await f.store.dispatch(createSupergroupSlowmodeUpdatedEvent(slow)); slow.expiresInSeconds = 300;
      await setEnabled(f, true);
      const stored = f.store.getState().chats.supergroupSlowmode.get(77);
      expect(stored?.expiresInSeconds).assertEqual(10.5); expect(stored?.receivedElapsedMs).assertEqual(100000);
      expectSlowmodeInputPreserved(f);
    });
    it('explicit disable retires only slowmode and a later enable cannot revive its receipt', 0, async () => {
      const f = new SlowmodeFixture(); await f.updateFullInfo();
      await setEnabled(f, false); expect(f.store.getState().chats.supergroupSlowmode.has(77)).assertEqual(false);
      expect(f.store.getState().chats.supergroupBoosts.has(77)).assertEqual(true);
      await setEnabled(f, true); expect(f.store.getState().chats.supergroupSlowmode.has(77)).assertEqual(false);
      await f.updateFullInfo('4'); expect(f.store.getState().chats.supergroupSlowmode.get(77)?.expiresInSeconds).assertEqual(4);
    });
    it('missing optional enabled bit preserves the known bit and never fabricates a receipt', 0, async () => {
      const f = new SlowmodeFixture(); await setEnabled(f, true); await setEnabled(f);
      expect(f.store.getState().chats.supergroupAccess.get(77)?.isSlowModeEnabled).assertEqual(true);
      expect(f.store.getState().chats.supergroupSlowmode.has(77)).assertEqual(false);
    });
    it('disabled groups reject stale full-info receipts without affecting composer input', 0, async () => {
      const f = new SlowmodeFixture(); await setEnabled(f, false); await f.updateFullInfo();
      expect(f.store.getState().chats.supergroupSlowmode.has(77)).assertEqual(false);
      expect(f.page.canSendNewMessages('text')).assertEqual(true); expectSlowmodeInputPreserved(f);
    });
    it('presentation ticks age the same cached receipt instead of restarting it on observe', 0, async () => {
      const f = new SlowmodeFixture(); let now = 100000; const owner = new ChatSlowmodeController((): number => now);
      await f.store.dispatch(createSupergroupSlowmodeUpdatedEvent(slowmodeReceipt()));
      try {
        owner.observe(f.page); expect(f.page.composerSlowmodeSeconds).assertEqual(11);
        now = 105000; owner.observe(f.page); expect(f.page.composerSlowmodeSeconds).assertEqual(6);
        now = 110500; owner.observe(f.page); expect(f.page.composerSlowmodeSeconds).assertEqual(0);
        expectSlowmodeInputPreserved(f);
      } finally { owner.dispose(); }
    });
    it('suspend and resume recompute elapsed sleep without modifying the draft or sending', 0, async () => {
      const f = new SlowmodeFixture(); let now = 100000; const owner = new ChatSlowmodeController((): number => now);
      await f.store.dispatch(createSupergroupSlowmodeUpdatedEvent(slowmodeReceipt()));
      try {
        owner.observe(f.page); owner.suspend(); now = 110500; owner.resume();
        expect(f.page.composerSlowmodeSeconds).assertEqual(0); expectSlowmodeInputPreserved(f);
      } finally { owner.dispose(); }
    });
    it('background pause and foreground resume keep the original receipt anchor', 0, async () => {
      const f = new SlowmodeFixture(); let now = 100000; const owner = new ChatSlowmodeController((): number => now);
      const previous = navigationUIState.applicationForeground;
      await f.store.dispatch(createSupergroupSlowmodeUpdatedEvent(slowmodeReceipt()));
      try {
        navigationUIState.applicationForeground = false; owner.observe(f.page); owner.pause();
        now = 107000; navigationUIState.applicationForeground = true; owner.resume();
        expect(f.page.composerSlowmodeSeconds).assertEqual(4);
        expect(f.store.getState().chats.supergroupSlowmode.get(77)?.receivedElapsedMs).assertEqual(100000);
        expectSlowmodeInputPreserved(f);
      } finally { owner.dispose(); navigationUIState.applicationForeground = previous; }
    });
    it('account revocation synchronously clears its countdown and cannot mutate replacement input', 0, async () => {
      const f = new SlowmodeFixture(); const owner = new ChatSlowmodeController((): number => 100000);
      await f.store.dispatch(createSupergroupSlowmodeUpdatedEvent(slowmodeReceipt()));
      try {
        owner.observe(f.page); expect(f.page.composerSlowmodeSeconds).assertEqual(11);
        f.store.invalidateScopes(); expect(f.page.composerSlowmodeSeconds).assertEqual(0);
        f.page.composerDraftText = 'replacement'; owner.resume();
        expect(f.page.composerDraftText).assertEqual('replacement'); expect(f.gateway.trace.length).assertEqual(0);
      } finally { owner.dispose(); }
    });
    it('route and lifecycle changes fence late timer cleanup from a newer visible value', 0, async () => {
      const f = new SlowmodeFixture(); const owner = new ChatSlowmodeController((): number => 100000);
      await f.store.dispatch(createSupergroupSlowmodeUpdatedEvent(slowmodeReceipt()));
      owner.observe(f.page); f.page.pageLifecycleToken++; f.page.activeChatId = 99; f.page.composerSlowmodeSeconds = 88;
      owner.dispose(); expect(f.page.composerSlowmodeSeconds).assertEqual(88); expectSlowmodeInputPreserved(f);
    });
    it('live role and boost transitions are reflected by the current countdown owner', 0, async () => {
      const f = new SlowmodeFixture(); const owner = new ChatSlowmodeController((): number => 100000);
      await f.store.dispatch(createSupergroupSlowmodeUpdatedEvent(slowmodeReceipt()));
      try {
        owner.observe(f.page); expect(f.page.composerSlowmodeSeconds).assertEqual(11);
        const admin = new GroupAccessDto(); admin.kind = 'supergroup'; admin.groupId = 77; admin.role = 'administrator'; admin.isMember = true;
        await f.store.dispatch(createGroupAccessUpdatedEvent(admin)); owner.observe(f.page);
        expect(f.page.composerSlowmodeSeconds).assertEqual(0);
        await setEnabled(f, true); owner.observe(f.page); expect(f.page.composerSlowmodeSeconds).assertEqual(11);
      } finally { owner.dispose(); }
    });
    it('fresh hydration uses the captured group and publishes authoritative relative expiry', 0, async () => {
      const h = new SlowmodeHydration(); const f = h.fixture;
      try {
        await setEnabled(f, true); h.observe(); await settleWrites();
        expect(f.gateway.requests.length).assertEqual(1); expect(f.gateway.requests[0].command.type).assertEqual('getSupergroupFullInfo');
        f.gateway.requests[0].resolve?.(fullInfo(4)); await settleWrites();
        expect(f.store.getState().chats.supergroupSlowmode.get(77)?.expiresInSeconds).assertEqual(4);
        expect(currentSlowmodeSeconds(f.store.getState(), 42)).assertEqual(4);
        expect(h.controller.isUnavailable()).assertEqual(false);
      } finally { h.dispose(); }
    });
    it('enabled ABA joins superseded read cleanup and fetches current metadata exactly once', 0, async () => {
      const h = new SlowmodeHydration(); const f = h.fixture;
      try {
        await setEnabled(f, true); h.observe(); await settleWrites(); expect(f.gateway.requests.length).assertEqual(1);
        await setEnabled(f, false); await setEnabled(f, true); h.observe(); await settleWrites();
        expect(f.gateway.requests.length).assertEqual(1);
        f.gateway.requests[0].resolve?.(fullInfo(30)); await settleWrites(); await settleWrites();
        expect(f.store.getState().chats.supergroupSlowmode.has(77)).assertEqual(false);
        expect(f.gateway.requests.length).assertEqual(2);
        f.gateway.requests[1].resolve?.(fullInfo(4)); await settleWrites();
        expect(f.store.getState().chats.supergroupSlowmode.get(77)?.expiresInSeconds).assertEqual(4);
        expect(h.controller.isUnavailable()).assertEqual(false);
      } finally { h.dispose(); }
    });
    it('a genuine network failure stays unavailable without auto-loop and permits an explicit retry', 0, async () => {
      const h = new SlowmodeHydration(); const f = h.fixture;
      try {
        await setEnabled(f, true); h.observe(); await settleWrites();
        f.gateway.requests[0].reject?.(new Error('controlled network failure')); await settleWrites();
        h.observe(); await settleWrites(); expect(f.gateway.requests.length).assertEqual(1);
        expect(h.controller.isUnavailable()).assertEqual(true); h.controller.retry(); await settleWrites();
        expect(f.gateway.requests.length).assertEqual(2); f.gateway.requests[1].resolve?.(fullInfo(2)); await settleWrites();
        expect(h.controller.isUnavailable()).assertEqual(false);
      } finally { h.dispose(); }
    });
    it('network rejection during enabled ABA is not misclassified as a superseded-read refresh', 0, async () => {
      const h = new SlowmodeHydration(); const f = h.fixture;
      try {
        await setEnabled(f, true); h.observe(); await settleWrites();
        await setEnabled(f, false); await setEnabled(f, true);
        f.gateway.requests[0].reject?.(new Error('controlled network failure')); await settleWrites(); await settleWrites();
        expect(f.gateway.requests.length).assertEqual(1); expect(h.controller.isUnavailable()).assertEqual(true);
      } finally { h.dispose(); }
    });
    it('disable during hydration ignores the late receipt and never refetches', 0, async () => {
      const h = new SlowmodeHydration(); const f = h.fixture;
      try {
        await setEnabled(f, true); h.observe(); await settleWrites(); await setEnabled(f, false);
        f.gateway.requests[0].resolve?.(fullInfo(30)); await settleWrites(); await settleWrites();
        expect(f.store.getState().chats.supergroupSlowmode.has(77)).assertEqual(false);
        expect(f.gateway.requests.length).assertEqual(1); expect(h.controller.isUnavailable()).assertEqual(false);
      } finally { h.dispose(); }
    });
    it('a live full-info update wins over a stale direct response without another request', 0, async () => {
      const h = new SlowmodeHydration(); const f = h.fixture;
      try {
        await setEnabled(f, true); h.observe(); await settleWrites(); await f.updateFullInfo('2');
        const live = f.store.getState().chats.supergroupSlowmode.get(77);
        f.gateway.requests[0].resolve?.(fullInfo(30)); await settleWrites();
        expect(f.store.getState().chats.supergroupSlowmode.get(77) === live).assertEqual(true);
        expect(f.gateway.requests.length).assertEqual(1); expect(h.controller.isUnavailable()).assertEqual(false);
      } finally { h.dispose(); }
    });
    it('account revocation during hydration cannot populate or refetch the newer account', 0, async () => {
      const h = new SlowmodeHydration(); const f = h.fixture;
      try {
        await setEnabled(f, true); h.observe(); await settleWrites(); f.store.invalidateScopes(); h.dispose();
        f.gateway.requests[0].resolve?.(fullInfo(30)); await settleWrites(); await settleWrites();
        expect(f.store.getState().chats.supergroupSlowmode.has(77)).assertEqual(false);
        expect(f.gateway.requests.length).assertEqual(1);
      } finally { h.dispose(); }
    });
  });
}
