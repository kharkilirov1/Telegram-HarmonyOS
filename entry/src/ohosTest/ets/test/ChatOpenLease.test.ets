import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand, OpenChatCommand, CloseChatCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { ChatOpenLease } from '../../../main/ets/domain/usecases/ChatOpenLease';
import { TdObject } from '../../../main/ets/models/TdTypes';

class DeferredLeaseResponse {
  promise: Promise<Object>;
  private resolveResponse?: (value: Object) => void;
  private rejectResponse?: (error: Error) => void;

  constructor() {
    this.promise = new Promise<Object>((resolve: (value: Object) => void, reject: (error: Error) => void): void => {
      this.resolveResponse = resolve;
      this.rejectResponse = reject;
    });
  }

  resolve(value: Object): void {
    if (this.resolveResponse) this.resolveResponse(value);
  }

  reject(message: string): void {
    if (this.rejectResponse) this.rejectResponse(new Error(message));
  }
}

function receivedOk(): TdObject {
  return TdObject.fromJSON('{"@type":"ok"}');
}

class FakeLeaseGateway implements TdGatewayPort {
  commands: AnyAppCommand[] = [];
  openReply: Promise<Object> = Promise.resolve(receivedOk());
  closeReply: Promise<Object> = Promise.resolve(receivedOk());
  throwOpen: boolean = false;
  throwClose: boolean = false;

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  send(command: AnyAppCommand): Promise<Object> {
    this.commands.push(command);
    if (command.type === 'openChat') {
      if (this.throwOpen) throw new Error('synchronous-open-failure');
      return this.openReply;
    }
    if (command.type === 'closeChat') {
      if (this.throwClose) throw new Error('synchronous-close-failure');
      return this.closeReply;
    }
    throw new Error('unexpected-command:' + command.type);
  }

  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void {
    return (): void => {};
  }

  getConnectionState(): 'connecting' | 'ready' | 'updating' | 'waitingForNetwork' {
    return 'ready';
  }

  destroy(): Promise<void> {
    return Promise.resolve();
  }
}

function canDispatch(): boolean {
  return true;
}

// Drain continuations without timers, TDLib, singleton mocks or live accounts.
// Final outcomes are awaited explicitly; this only observes still-pending work.
async function settleLeaseResponses(): Promise<void> {
  for (let i = 0; i < 12; i++) {
    await Promise.resolve();
  }
}

function expectOpenOnly(gateway: FakeLeaseGateway, chatId: number): void {
  expect(gateway.commands.length).assertEqual(1);
  const open = gateway.commands[0] as OpenChatCommand;
  expect(open.type).assertEqual('openChat');
  expect(open.payload.chatId).assertEqual(chatId);
}

function expectOpenClose(gateway: FakeLeaseGateway, chatId: number): void {
  expect(gateway.commands.length).assertEqual(2);
  const open = gateway.commands[0] as OpenChatCommand;
  const close = gateway.commands[1] as CloseChatCommand;
  expect(open.type).assertEqual('openChat');
  expect(open.payload.chatId).assertEqual(chatId);
  expect(close.type).assertEqual('closeChat');
  expect(close.payload.chatId).assertEqual(chatId);
}

// "ok" establishes logical ownership only, not a native open_count increment.
export default function chatOpenLeaseTest() {
  describe('ChatOpenLease', () => {
    it('accepts nonzero safe integer IDs including negative IDs and safe boundaries', 0, async (): Promise<void> => {
      const ids: number[] = [73, -1001234567890, Number.MAX_SAFE_INTEGER, Number.MIN_SAFE_INTEGER];
      for (const chatId of ids) {
        const gateway = new FakeLeaseGateway();
        const lease = new ChatOpenLease(chatId, gateway);
        expect(lease.isOpen()).assertEqual(false);
        expect(lease.isReleased()).assertEqual(false);
        expect(await lease.ensureOpen(canDispatch)).assertEqual(true);
        expect(lease.isOpen()).assertEqual(true);
        expectOpenOnly(gateway, chatId);
        await lease.release();
        expectOpenClose(gateway, chatId);
        expect(lease.isOpen()).assertEqual(false);
        expect(lease.isReleased()).assertEqual(true);
      }
    });

    it('never dispatches invalid IDs or retries them', 0, async (): Promise<void> => {
      const ids: number[] = [0, -0, NaN, Infinity, -Infinity, 1.5, -0.5,
        Number.MAX_SAFE_INTEGER + 1, Number.MIN_SAFE_INTEGER - 1];
      for (const chatId of ids) {
        const gateway = new FakeLeaseGateway();
        const lease = new ChatOpenLease(chatId, gateway);
        expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
        expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
        expect(lease.isOpen()).assertEqual(false);
        await lease.release();
        expect(gateway.commands.length).assertEqual(0);
        expect(lease.isReleased()).assertEqual(true);
      }
    });

    it('checks dispatch before sending and shares one pending and successful result', 0, async (): Promise<void> => {
      const gateway = new FakeLeaseGateway();
      const ack = new DeferredLeaseResponse();
      gateway.openReply = ack.promise;
      const lease = new ChatOpenLease(73, gateway);
      let checks: number = 0;
      let ignoredChecks: number = 0;
      const first = lease.ensureOpen((): boolean => {
        if (checks === 0) expect(gateway.commands.length).assertEqual(0);
        checks += 1;
        return true;
      });
      const second = lease.ensureOpen((): boolean => {
        ignoredChecks += 1;
        return false;
      });
      await settleLeaseResponses();
      expect(checks > 0).assertEqual(true);
      expectOpenOnly(gateway, 73);
      expect(lease.isOpen()).assertEqual(false);
      ack.resolve(receivedOk());
      expect(await first).assertEqual(true);
      expect(await second).assertEqual(true);
      expect(await lease.ensureOpen((): boolean => {
        ignoredChecks += 1;
        return false;
      })).assertEqual(true);
      expect(ignoredChecks).assertEqual(0);
      expectOpenOnly(gateway, 73);
      await lease.release();
      expectOpenClose(gateway, 73);
    });

    it('caches preflight false even when a later caller permits dispatch', 0, async (): Promise<void> => {
      const gateway = new FakeLeaseGateway();
      const lease = new ChatOpenLease(73, gateway);
      expect(await lease.ensureOpen((): boolean => false)).assertEqual(false);
      expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
      expect(lease.isOpen()).assertEqual(false);
      await lease.release();
      expect(gateway.commands.length).assertEqual(0);
    });

    it('contains a throwing preflight and caches failure without sending', 0, async (): Promise<void> => {
      const gateway = new FakeLeaseGateway();
      const lease = new ChatOpenLease(73, gateway);
      expect(await lease.ensureOpen((): boolean => {
        throw new Error('preflight-failure');
      })).assertEqual(false);
      expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
      await lease.release();
      expect(lease.isOpen()).assertEqual(false);
      expect(gateway.commands.length).assertEqual(0);
    });

    it('contains a rejected acquisition and never retries or closes it', 0, async (): Promise<void> => {
      const gateway = new FakeLeaseGateway();
      const ack = new DeferredLeaseResponse();
      gateway.openReply = ack.promise;
      const lease = new ChatOpenLease(73, gateway);
      const opening = lease.ensureOpen(canDispatch);
      await settleLeaseResponses();
      ack.reject('open-rejected');
      expect(await opening).assertEqual(false);
      gateway.openReply = Promise.resolve(receivedOk());
      expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
      expect(lease.isOpen()).assertEqual(false);
      await lease.release();
      await lease.release();
      expectOpenOnly(gateway, 73);
    });

    it('contains a synchronous send failure without retry or close', 0, async (): Promise<void> => {
      const gateway = new FakeLeaseGateway();
      gateway.throwOpen = true;
      const lease = new ChatOpenLease(73, gateway);
      expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
      gateway.throwOpen = false;
      expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
      await lease.release();
      expect(lease.isOpen()).assertEqual(false);
      expectOpenOnly(gateway, 73);
    });

    it('rejects non-received non-top-level malformed and wrong-type results without ownership', 0,
      async (): Promise<void> => {
        const outbound = TdObject.empty();
        outbound.setString('@type', 'ok');
        const overwrittenError = TdObject.fromJSON('{"@type":"error","code":400}');
        overwrittenError.setString('@type', 'ok');
        const results: Object[] = [
          JSON.parse('{"@type":"ok"}') as Object,
          JSON.parse('null') as Object,
          new Error('ok'),
          outbound,
          overwrittenError,
          TdObject.empty(),
          TdObject.fromJSON('{"@type":"error","code":400,"message":"denied"}'),
          TdObject.fromJSON('{"@type":"chat","id":73}'),
          TdObject.fromJSON('{"nested":{"@type":"ok"}}'),
          TdObject.fromJSON('{"nested":{"@type":"ok"},"@type":"error"}'),
          TdObject.fromJSON('[{"@type":"ok"}]'),
          TdObject.fromJSON('{"@type":"ok"'),
          TdObject.fromJSON('{"@type":true}'),
          TdObject.fromJSON('{"@type":1}'),
          TdObject.fromJSON('{"@type":null}'),
          TdObject.fromJSON('{"@type":"OK"}'),
          TdObject.fromJSON('null')
        ];
        for (const response of results) {
          const gateway = new FakeLeaseGateway();
          gateway.openReply = Promise.resolve(response);
          const lease = new ChatOpenLease(73, gateway);
          expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
          expect(lease.isOpen()).assertEqual(false);
          gateway.openReply = Promise.resolve(receivedOk());
          expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
          await lease.release();
          await lease.release();
          expectOpenOnly(gateway, 73);
        }
      });

    it('accepts a received top-level ok even when nested type precedes it', 0, async (): Promise<void> => {
      const gateway = new FakeLeaseGateway();
      gateway.openReply = Promise.resolve(TdObject.fromJSON('{"nested":{"@type":"error"},"@type":"ok"}'));
      const lease = new ChatOpenLease(73, gateway);
      expect(await lease.ensureOpen(canDispatch)).assertEqual(true);
      expect(lease.isOpen()).assertEqual(true);
      await lease.release();
      expectOpenClose(gateway, 73);
    });

    it('pre-release synchronously invalidates an unused lease and prevents dispatch', 0, async (): Promise<void> => {
      const gateway = new FakeLeaseGateway();
      const lease = new ChatOpenLease(73, gateway);
      let checks: number = 0;
      const released = lease.release();
      expect(lease.isReleased()).assertEqual(true);
      expect(lease.isOpen()).assertEqual(false);
      expect(await lease.ensureOpen((): boolean => {
        checks += 1;
        return true;
      })).assertEqual(false);
      await released;
      await lease.release();
      expect(checks).assertEqual(0);
      expect(gateway.commands.length).assertEqual(0);
    });

    it('same-turn release after ensure prevents the reserved acquisition from dispatching', 0,
      async (): Promise<void> => {
        const gateway = new FakeLeaseGateway();
        const lease = new ChatOpenLease(73, gateway);
        let checks: number = 0;
        const opening = lease.ensureOpen((): boolean => {
          checks += 1;
          return true;
        });
        const first = lease.release();
        const second = lease.release();
        expect(lease.isReleased()).assertEqual(true);
        expect(lease.isOpen()).assertEqual(false);
        expect(await opening).assertEqual(false);
        await first;
        await second;
        expect(checks).assertEqual(0);
        expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
        expect(gateway.commands.length).assertEqual(0);
      });

    it('release clears open synchronously and all releases wait for one pending close', 0, async (): Promise<void> => {
      const gateway = new FakeLeaseGateway();
      const closeAck = new DeferredLeaseResponse();
      gateway.closeReply = closeAck.promise;
      const lease = new ChatOpenLease(73, gateway);
      expect(await lease.ensureOpen(canDispatch)).assertEqual(true);
      let firstDone: boolean = false;
      let secondDone: boolean = false;
      const first = lease.release();
      expect(lease.isReleased()).assertEqual(true);
      expect(lease.isOpen()).assertEqual(false);
      const firstObserved = first.then((): void => { firstDone = true; });
      const secondObserved = lease.release().then((): void => { secondDone = true; });
      await settleLeaseResponses();
      expectOpenClose(gateway, 73);
      expect(firstDone).assertEqual(false);
      expect(secondDone).assertEqual(false);
      expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
      closeAck.resolve(receivedOk());
      await firstObserved;
      await secondObserved;
      expect(firstDone).assertEqual(true);
      expect(secondDone).assertEqual(true);
      await lease.release();
      expectOpenClose(gateway, 73);
    });

    it('double release during acquisition waits for its ack then closes once without a circular await', 0,
      async (): Promise<void> => {
        const gateway = new FakeLeaseGateway();
        const ack = new DeferredLeaseResponse();
        const closeAck = new DeferredLeaseResponse();
        gateway.openReply = ack.promise;
        gateway.closeReply = closeAck.promise;
        const lease = new ChatOpenLease(73, gateway);
        const opening = lease.ensureOpen(canDispatch);
        await settleLeaseResponses();
        let firstDone: boolean = false;
        let secondDone: boolean = false;
        const first = lease.release();
        expect(lease.isReleased()).assertEqual(true);
        expect(lease.isOpen()).assertEqual(false);
        const firstObserved = first.then((): void => { firstDone = true; });
        const secondObserved = lease.release().then((): void => { secondDone = true; });
        await settleLeaseResponses();
        expectOpenOnly(gateway, 73);
        expect(firstDone).assertEqual(false);
        expect(secondDone).assertEqual(false);
        ack.resolve(receivedOk());
        await settleLeaseResponses();
        expectOpenClose(gateway, 73);
        expect(lease.isOpen()).assertEqual(false);
        expect(firstDone).assertEqual(false);
        expect(secondDone).assertEqual(false);
        closeAck.resolve(receivedOk());
        expect(await opening).assertEqual(false);
        await firstObserved;
        await secondObserved;
        expect(firstDone).assertEqual(true);
        expect(secondDone).assertEqual(true);
        expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
        await lease.release();
        expectOpenClose(gateway, 73);
      });

    it('release waits for a rejected pending acquisition but sends no close', 0, async (): Promise<void> => {
      const gateway = new FakeLeaseGateway();
      const ack = new DeferredLeaseResponse();
      gateway.openReply = ack.promise;
      const lease = new ChatOpenLease(73, gateway);
      const opening = lease.ensureOpen(canDispatch);
      await settleLeaseResponses();
      let releaseDone: boolean = false;
      const released = lease.release().then((): void => { releaseDone = true; });
      await settleLeaseResponses();
      expect(releaseDone).assertEqual(false);
      expectOpenOnly(gateway, 73);
      ack.reject('pending-open-rejected');
      expect(await opening).assertEqual(false);
      await released;
      expect(releaseDone).assertEqual(true);
      expect(lease.isReleased()).assertEqual(true);
      expect(lease.isOpen()).assertEqual(false);
      await lease.release();
      expectOpenOnly(gateway, 73);
    });

    it('release does not close an unknown pending acquisition result', 0, async (): Promise<void> => {
      const gateway = new FakeLeaseGateway();
      const ack = new DeferredLeaseResponse();
      gateway.openReply = ack.promise;
      const lease = new ChatOpenLease(73, gateway);
      const opening = lease.ensureOpen(canDispatch);
      await settleLeaseResponses();
      const first = lease.release();
      const second = lease.release();
      ack.resolve(JSON.parse('{"@type":"ok"}') as Object);
      expect(await opening).assertEqual(false);
      await first;
      await second;
      expect(lease.isOpen()).assertEqual(false);
      expect(lease.isReleased()).assertEqual(true);
      expectOpenOnly(gateway, 73);
    });

    it('scope invalidated while pending auto-releases the ack before ensure resolves false', 0,
      async (): Promise<void> => {
        const gateway = new FakeLeaseGateway();
        const ack = new DeferredLeaseResponse();
        const closeAck = new DeferredLeaseResponse();
        gateway.openReply = ack.promise;
        gateway.closeReply = closeAck.promise;
        const lease = new ChatOpenLease(73, gateway);
        let active: boolean = true;
        let ensureDone: boolean = false;
        const opening = lease.ensureOpen((): boolean => active);
        const observed = opening.then((result: boolean): boolean => {
          ensureDone = true;
          return result;
        });
        await settleLeaseResponses();
        expectOpenOnly(gateway, 73);
        active = false;
        ack.resolve(receivedOk());
        await settleLeaseResponses();
        expectOpenClose(gateway, 73);
        expect(lease.isReleased()).assertEqual(true);
        expect(lease.isOpen()).assertEqual(false);
        expect(ensureDone).assertEqual(false);
        closeAck.resolve(receivedOk());
        expect(await observed).assertEqual(false);
        expect(ensureDone).assertEqual(true);
        active = true;
        expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
        await lease.release();
        expectOpenClose(gateway, 73);
      });

    it('throwing post-ack scope check auto-releases ownership before resolving false', 0,
      async (): Promise<void> => {
        const gateway = new FakeLeaseGateway();
        const ack = new DeferredLeaseResponse();
        const closeAck = new DeferredLeaseResponse();
        gateway.openReply = ack.promise;
        gateway.closeReply = closeAck.promise;
        const lease = new ChatOpenLease(73, gateway);
        let invalidate: boolean = false;
        let ensureDone: boolean = false;
        const opening = lease.ensureOpen((): boolean => {
          if (invalidate) throw new Error('scope-check-failed');
          return true;
        }).then((result: boolean): boolean => {
          ensureDone = true;
          return result;
        });
        await settleLeaseResponses();
        expectOpenOnly(gateway, 73);
        invalidate = true;
        ack.resolve(receivedOk());
        await settleLeaseResponses();
        expectOpenClose(gateway, 73);
        expect(lease.isReleased()).assertEqual(true);
        expect(lease.isOpen()).assertEqual(false);
        expect(ensureDone).assertEqual(false);
        closeAck.resolve(receivedOk());
        expect(await opening).assertEqual(false);
        await lease.release();
        expectOpenClose(gateway, 73);
      });

    it('external double release can join automatic post-ack cleanup without a cycle', 0,
      async (): Promise<void> => {
        const gateway = new FakeLeaseGateway();
        const ack = new DeferredLeaseResponse();
        const closeAck = new DeferredLeaseResponse();
        gateway.openReply = ack.promise;
        gateway.closeReply = closeAck.promise;
        const lease = new ChatOpenLease(73, gateway);
        let active: boolean = true;
        const opening = lease.ensureOpen((): boolean => active);
        await settleLeaseResponses();
        active = false;
        ack.resolve(receivedOk());
        await settleLeaseResponses();
        expectOpenClose(gateway, 73);
        const first = lease.release();
        const second = lease.release();
        expect(lease.isReleased()).assertEqual(true);
        expect(lease.isOpen()).assertEqual(false);
        closeAck.resolve(receivedOk());
        expect(await opening).assertEqual(false);
        await first;
        await second;
        expectOpenClose(gateway, 73);
      });

    it('keeps pending acquisition and close bound to each captured gateway', 0, async (): Promise<void> => {
      const oldGateway = new FakeLeaseGateway();
      const newGateway = new FakeLeaseGateway();
      const oldAck = new DeferredLeaseResponse();
      const newAck = new DeferredLeaseResponse();
      oldGateway.openReply = oldAck.promise;
      newGateway.openReply = newAck.promise;
      const oldLease = new ChatOpenLease(73, oldGateway);
      const newLease = new ChatOpenLease(-74, newGateway);
      const oldOpening = oldLease.ensureOpen(canDispatch);
      const newOpening = newLease.ensureOpen(canDispatch);
      await settleLeaseResponses();
      let oldReleaseDone: boolean = false;
      const oldReleased = oldLease.release().then((): void => { oldReleaseDone = true; });
      newAck.resolve(receivedOk());
      expect(await newOpening).assertEqual(true);
      expect(oldReleaseDone).assertEqual(false);
      expectOpenOnly(oldGateway, 73);
      expectOpenOnly(newGateway, -74);
      oldAck.resolve(receivedOk());
      expect(await oldOpening).assertEqual(false);
      await oldReleased;
      expect(oldReleaseDone).assertEqual(true);
      expectOpenClose(oldGateway, 73);
      expectOpenOnly(newGateway, -74);
      expect(newLease.isOpen()).assertEqual(true);
      expect(newLease.isReleased()).assertEqual(false);
      await newLease.release();
      expectOpenClose(newGateway, -74);
    });

    it('best-effort release absorbs rejected close without reopening or retrying', 0, async (): Promise<void> => {
      const gateway = new FakeLeaseGateway();
      const closeAck = new DeferredLeaseResponse();
      gateway.closeReply = closeAck.promise;
      const lease = new ChatOpenLease(73, gateway);
      expect(await lease.ensureOpen(canDispatch)).assertEqual(true);
      const first = lease.release();
      const second = lease.release();
      await settleLeaseResponses();
      expectOpenClose(gateway, 73);
      closeAck.reject('close-rejected');
      await first;
      await second;
      expect(lease.isOpen()).assertEqual(false);
      expect(lease.isReleased()).assertEqual(true);
      expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
      await lease.release();
      expectOpenClose(gateway, 73);
    });

    it('best-effort release absorbs synchronous close failure without retrying', 0, async (): Promise<void> => {
      const gateway = new FakeLeaseGateway();
      gateway.throwClose = true;
      const lease = new ChatOpenLease(73, gateway);
      expect(await lease.ensureOpen(canDispatch)).assertEqual(true);
      await lease.release();
      gateway.throwClose = false;
      await lease.release();
      expect(lease.isOpen()).assertEqual(false);
      expect(lease.isReleased()).assertEqual(true);
      expect(await lease.ensureOpen(canDispatch)).assertEqual(false);
      expectOpenClose(gateway, 73);
    });

    it('best-effort release tolerates non-ok close results without additional closes', 0,
      async (): Promise<void> => {
        const results: Object[] = [TdObject.fromJSON('{"@type":"error","code":400}'),
          JSON.parse('null') as Object, new Error('close-response'), TdObject.empty()];
        for (const response of results) {
          const gateway = new FakeLeaseGateway();
          gateway.closeReply = Promise.resolve(response);
          const lease = new ChatOpenLease(73, gateway);
          expect(await lease.ensureOpen(canDispatch)).assertEqual(true);
          await lease.release();
          await lease.release();
          expect(lease.isReleased()).assertEqual(true);
          expect(lease.isOpen()).assertEqual(false);
          expectOpenClose(gateway, 73);
        }
      });

    it('automatic cleanup still resolves false when its best-effort close rejects', 0, async (): Promise<void> => {
      const gateway = new FakeLeaseGateway();
      const ack = new DeferredLeaseResponse();
      const closeAck = new DeferredLeaseResponse();
      gateway.openReply = ack.promise;
      gateway.closeReply = closeAck.promise;
      const lease = new ChatOpenLease(73, gateway);
      let active: boolean = true;
      const opening = lease.ensureOpen((): boolean => active);
      await settleLeaseResponses();
      active = false;
      ack.resolve(receivedOk());
      await settleLeaseResponses();
      expectOpenClose(gateway, 73);
      closeAck.reject('automatic-close-rejected');
      expect(await opening).assertEqual(false);
      expect(lease.isReleased()).assertEqual(true);
      expect(lease.isOpen()).assertEqual(false);
      await lease.release();
      expectOpenClose(gateway, 73);
    });
  });
}
