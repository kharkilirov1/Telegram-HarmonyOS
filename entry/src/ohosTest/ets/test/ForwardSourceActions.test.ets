import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { ForwardMessagesUseCase, ForwardMessagesEligibilityError } from '../../../main/ets/domain/usecases/forwardMessages';
import { serializeCommand, buildTdlibRequestJson } from '../../../main/ets/infra/td/serialization/CommandSerializer';
import { ChatForwardSourceController } from '../../../main/ets/ui/pages/chat/ChatForwardSourceController';

// Same TDLib MessageId.h fixtures as ForwardEligibility: server_id << 20,
// local type bits = 2. Arithmetic must preserve the maximum server int53 ID.
const SOURCE_CHAT_ID = -12;
const SERVER_ID = '1048576';
const SECOND_SERVER_ID = '2097152';
const LOCAL_ID = '1048578';
const MAX_SERVER_ID = '2251799812636672';

function sourceProperties(forward: boolean, copy: boolean, secret: boolean): TdObject {
  return TdObject.fromJSON(`{"@type":"messageProperties","can_be_forwarded":${forward},` +
    `"can_be_copied":${copy},"can_be_copied_to_secret_chat":${secret}}`);
}

class DeferredSourceResponse {
  promise: Promise<TdObject>;
  private resolveResponse?: (value: TdObject) => void;
  private rejectResponse?: (error: Error) => void;

  constructor() {
    this.promise = new Promise<TdObject>((resolve, reject) => {
      this.resolveResponse = resolve;
      this.rejectResponse = reject;
    });
  }

  resolve(value: TdObject): void {
    if (this.resolveResponse === undefined) throw new Error('Missing deferred resolver');
    this.resolveResponse(value);
  }

  reject(): void {
    if (this.rejectResponse === undefined) throw new Error('Missing deferred rejection');
    this.rejectResponse(new Error('Source properties unavailable'));
  }
}

// Real use case/controller, fake port only. No adapter, network or sends.
// Reserve each reply before awaiting it so superseding requests cannot steal
// an older request's fixture. Missing/unexpected commands always fail closed.
class SourceActionsGateway implements TdGatewayPort {
  commands: AnyAppCommand[] = [];
  replies: (TdObject | DeferredSourceResponse | Error)[];

  constructor(replies: (TdObject | DeferredSourceResponse | Error)[]) {
    this.replies = replies.slice();
  }

  async initialize(): Promise<void> {}
  async destroy(): Promise<void> {}
  getConnectionState(): 'ready' { return 'ready'; }
  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void { return (): void => {}; }

  async send(command: AnyAppCommand): Promise<Object> {
    this.commands.push(command);
    if (command.type !== 'getMessageProperties') throw new Error(`Unexpected fixture command: ${command.type}`);
    const reply = this.replies.shift();
    if (reply === undefined) throw new Error('Missing source properties fixture');
    if (reply instanceof Error) throw reply;
    if (reply instanceof DeferredSourceResponse) return await reply.promise;
    return reply;
  }
}

function assertSourceReads(gateway: SourceActionsGateway, ids: string[], sourceId: number = SOURCE_CHAT_ID): void {
  expect(gateway.commands.length).assertEqual(ids.length);
  for (let index = 0; index < ids.length; index++) {
    expect(gateway.commands[index].type).assertEqual('getMessageProperties');
    const serialized = serializeCommand(gateway.commands[index]);
    const request = TdObject.fromJSON(buildTdlibRequestJson(serialized.method, serialized.params));
    expect(request.getTopLevelStringStrict('@type')).assertEqual('getMessageProperties');
    expect(request.getTopLevelNumberStrict('chat_id')).assertEqual(sourceId);
    expect(request.getTopLevelNumberStrict('message_id')).assertEqual(Number(ids[index]));
  }
}

async function settleSourceActions(): Promise<void> {
  // Match ForwardEligibility's native then/catch drain; no TDLib receive loop.
  await new Promise<void>((resolve) => { setTimeout(resolve, 0); });
}

async function assertSourceUnavailable(raw: string, id: string): Promise<void> {
  const gateway = new SourceActionsGateway([TdObject.fromJSON(raw), TdObject.fromJSON(raw)]);
  const useCase = new ForwardMessagesUseCase(gateway);
  let rejected = false;
  try { await useCase.getSourceAvailability(SOURCE_CHAT_ID, [id]); } catch (error) {
    rejected = error instanceof ForwardMessagesEligibilityError;
  }
  expect(rejected).assertEqual(true);
  const states: string[] = [];
  new ChatForwardSourceController().load(useCase, SOURCE_CHAT_ID, [id], (): boolean => true,
    (state: string): void => { states.push(state); });
  expect(states.join(',')).assertEqual('loading');
  await settleSourceActions();
  expect(states.join(',')).assertEqual('loading,unavailable');
  assertSourceReads(gateway, [id, id]);
}

export default function forwardSourceActionsTest() {
  describe('ForwardSourceActions', () => {
    it('default server route matrix uses forward and secret flags independently of copy', 0, async () => {
      for (const id of [SERVER_ID, MAX_SERVER_ID]) {
        for (const forward of [false, true]) {
          for (const copy of [false, true]) {
            for (const secret of [false, true]) {
              const gateway = new SourceActionsGateway([sourceProperties(forward, copy, secret)]);
              const availability = await new ForwardMessagesUseCase(gateway).getSourceAvailability(SOURCE_CHAT_ID, [id]);
              expect(availability.ordinaryTargets).assertEqual(forward);
              expect(availability.secretTargets).assertEqual(secret);
              assertSourceReads(gateway, [id]);
            }
          }
        }
      }
      const gateway = new SourceActionsGateway([TdObject.fromJSON('{"@type":"messageProperties","can_be_forwarded":true,"can_be_copied_to_secret_chat":false}')]);
      const availability = await new ForwardMessagesUseCase(gateway).getSourceAvailability(SOURCE_CHAT_ID, [SERVER_ID]);
      expect(availability.ordinaryTargets).assertEqual(true);
      expect(availability.secretTargets).assertEqual(false);
      assertSourceReads(gateway, [SERVER_ID]);
    });

    it('default local route matrix uses copy and secret flags independently of forward', 0, async () => {
      for (const forward of [false, true]) {
        for (const copy of [false, true]) {
          for (const secret of [false, true]) {
            const gateway = new SourceActionsGateway([sourceProperties(forward, copy, secret)]);
            const availability = await new ForwardMessagesUseCase(gateway).getSourceAvailability(SOURCE_CHAT_ID, [LOCAL_ID]);
            expect(availability.ordinaryTargets).assertEqual(copy);
            expect(availability.secretTargets).assertEqual(secret);
            assertSourceReads(gateway, [LOCAL_ID]);
          }
        }
      }
      const gateway = new SourceActionsGateway([TdObject.fromJSON('{"@type":"messageProperties","can_be_copied":true,"can_be_copied_to_secret_chat":false}')]);
      const availability = await new ForwardMessagesUseCase(gateway).getSourceAvailability(SOURCE_CHAT_ID, [LOCAL_ID]);
      expect(availability.ordinaryTargets).assertEqual(true);
      expect(availability.secretTargets).assertEqual(false);
      assertSourceReads(gateway, [LOCAL_ID]);
    });

    it('mixed batch snapshots sorts and deduplicates IDs while intersecting every source', 0, async () => {
      const held = new DeferredSourceResponse();
      const gateway = new SourceActionsGateway([held, sourceProperties(false, true, true), sourceProperties(true, false, false)]);
      const ids = [SECOND_SERVER_ID, LOCAL_ID, SERVER_ID, LOCAL_ID];
      const pending = new ForwardMessagesUseCase(gateway).getSourceAvailability(SOURCE_CHAT_ID, ids);
      assertSourceReads(gateway, [SERVER_ID]);
      expect(ids.join(',')).assertEqual([SECOND_SERVER_ID, LOCAL_ID, SERVER_ID, LOCAL_ID].join(','));
      ids.splice(0, ids.length, MAX_SERVER_ID);
      held.resolve(sourceProperties(true, false, true));
      const availability = await pending;
      expect(availability.ordinaryTargets).assertEqual(true);
      expect(availability.secretTargets).assertEqual(false);
      expect(ids.join(',')).assertEqual(MAX_SERVER_ID);
      assertSourceReads(gateway, [SERVER_ID, LOCAL_ID, SECOND_SERVER_ID]);
      expect(gateway.replies.length).assertEqual(0);
    });

    it('per-message ordinary OR secret grants do not imply a common batch destination', 0, async () => {
      // A can reach only ordinary chats, B only secret chats; neither destination
      // accepts both. Reverse the grants to catch either route being overwritten.
      for (const firstOrdinary of [false, true]) {
        const gateway = new SourceActionsGateway([
          sourceProperties(firstOrdinary, true, !firstOrdinary),
          sourceProperties(true, !firstOrdinary, firstOrdinary)
        ]);
        const availability = await new ForwardMessagesUseCase(gateway).getSourceAvailability(SOURCE_CHAT_ID, [LOCAL_ID, SERVER_ID]);
        expect(availability.ordinaryTargets).assertEqual(false);
        expect(availability.secretTargets).assertEqual(false);
        assertSourceReads(gateway, [SERVER_ID, LOCAL_ID]);
      }
    });

    it('required flags reject missing nested and nonboolean grants rather than returning denied', 0, async () => {
      for (const id of [SERVER_ID, LOCAL_ID]) {
        const ordinaryFlag = id === SERVER_ID ? 'can_be_forwarded' : 'can_be_copied';
        await assertSourceUnavailable('{"@type":"messageProperties","nested":{"can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true}}', id);
        await assertSourceUnavailable('{"@type":"messageProperties","can_be_copied_to_secret_chat":true}', id);
        await assertSourceUnavailable(`{"@type":"messageProperties","${ordinaryFlag}":true}`, id);
        for (const value of ['"true"', '1', 'null', '{}', '[]']) {
          // The other route is explicitly true: malformed metadata must not be
          // treated as a safe partial grant by an ordinary OR secret shortcut.
          await assertSourceUnavailable(`{"@type":"messageProperties","${ordinaryFlag}":${value},"can_be_copied_to_secret_chat":true}`, id);
          await assertSourceUnavailable(`{"@type":"messageProperties","${ordinaryFlag}":true,"can_be_copied_to_secret_chat":${value}}`, id);
        }
        const gateway = new SourceActionsGateway([TdObject.fromJSON('{"@type":"messageProperties","nested":{"can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true},"can_be_forwarded":false,"can_be_copied":false,"can_be_copied_to_secret_chat":false}')]);
        const availability = await new ForwardMessagesUseCase(gateway).getSourceAvailability(SOURCE_CHAT_ID, [id]);
        expect(availability.ordinaryTargets).assertEqual(false);
        expect(availability.secretTargets).assertEqual(false);
        assertSourceReads(gateway, [id]);
      }
    });

    it('wrong missing nested or malformed response identity cannot grant source availability', 0, async () => {
      const payloads: string[] = [
        '{"@type":"message","can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true}',
        '{"@type":"error","code":404,"message":"Not found","can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true}',
        '{"can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true}',
        '{"nested":{"@type":"messageProperties"},"can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true}',
        '{"@type":"messageProperties","can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true'
      ];
      for (const raw of payloads) {
        for (const id of [SERVER_ID, LOCAL_ID]) await assertSourceUnavailable(raw, id);
      }
    });

    it('canContinue revocation blocks the first read or stops a pending batch before its next ID', 0, async () => {
      const held = new DeferredSourceResponse();
      const gateway = new SourceActionsGateway([held, sourceProperties(true, true, true)]);
      const useCase = new ForwardMessagesUseCase(gateway);
      let active = false;
      let rejectedBeforeRead = false;
      try { await useCase.getSourceAvailability(SOURCE_CHAT_ID, [SERVER_ID], (): boolean => active); } catch (error) {
        rejectedBeforeRead = error instanceof ForwardMessagesEligibilityError;
      }
      expect(rejectedBeforeRead).assertEqual(true);
      assertSourceReads(gateway, []);
      active = true;
      let rejectedAfterRead = false;
      const pending = useCase.getSourceAvailability(SOURCE_CHAT_ID, [SERVER_ID, SECOND_SERVER_ID], (): boolean => active)
        .catch((error: Object) => { rejectedAfterRead = error instanceof ForwardMessagesEligibilityError; });
      assertSourceReads(gateway, [SERVER_ID]);
      active = false;
      held.resolve(sourceProperties(true, true, true));
      await pending;
      expect(rejectedAfterRead).assertEqual(true);
      assertSourceReads(gateway, [SERVER_ID]);
      expect(gateway.replies.length).assertEqual(1);
    });

    it('cancel ignores pending success and failure without reading the rest of the batch', 0, async () => {
      for (const fails of [false, true]) {
        const held = new DeferredSourceResponse();
        const gateway = new SourceActionsGateway([held, sourceProperties(true, true, true)]);
        const controller = new ChatForwardSourceController();
        const states: string[] = [];
        controller.load(new ForwardMessagesUseCase(gateway), SOURCE_CHAT_ID, [SERVER_ID, SECOND_SERVER_ID],
          (): boolean => true, (state: string): void => { states.push(state); });
        expect(states.join(',')).assertEqual('loading');
        assertSourceReads(gateway, [SERVER_ID]);
        controller.cancel();
        if (fails) held.reject(); else held.resolve(sourceProperties(true, true, true));
        await settleSourceActions();
        expect(states.join(',')).assertEqual('loading');
        assertSourceReads(gateway, [SERVER_ID]);
        expect(gateway.replies.length).assertEqual(1);
      }
    });

    it('superseding load owns state after late success or rejection of an older request', 0, async () => {
      for (const fails of [false, true]) {
        const held = new DeferredSourceResponse();
        const gateway = new SourceActionsGateway([held, sourceProperties(false, fails, false)]);
        const useCase = new ForwardMessagesUseCase(gateway);
        const controller = new ChatForwardSourceController();
        const oldStates: string[] = [];
        const newStates: string[] = [];
        controller.load(useCase, SOURCE_CHAT_ID, [SERVER_ID, SECOND_SERVER_ID], (): boolean => true,
          (state: string): void => { oldStates.push(state); });
        controller.load(useCase, SOURCE_CHAT_ID, [LOCAL_ID], (): boolean => true,
          (state: string): void => { newStates.push(state); });
        expect(oldStates.join(',')).assertEqual('loading');
        expect(newStates.join(',')).assertEqual('loading');
        await settleSourceActions();
        expect(newStates.join(',')).assertEqual(fails ? 'loading,allowed' : 'loading,denied');
        if (fails) held.reject(); else held.resolve(sourceProperties(true, true, true));
        await settleSourceActions();
        expect(oldStates.join(',')).assertEqual('loading');
        expect(newStates.join(',')).assertEqual(fails ? 'loading,allowed' : 'loading,denied');
        assertSourceReads(gateway, [SERVER_ID, LOCAL_ID]);
        expect(gateway.replies.length).assertEqual(0);
      }
    });

    it('metadata error becomes unavailable and a fresh retry can allow the secret-only route', 0, async () => {
      const failures: (TdObject | Error)[] = [
        new Error('Offline properties unavailable'),
        TdObject.fromJSON('{"@type":"error","code":404,"message":"Not found"}')
      ];
      for (const failure of failures) {
        const gateway = new SourceActionsGateway([failure, sourceProperties(false, false, true)]);
        const useCase = new ForwardMessagesUseCase(gateway);
        const controller = new ChatForwardSourceController();
        const states: string[] = [];
        const onState = (state: string): void => { states.push(state); };
        controller.load(useCase, SOURCE_CHAT_ID, [SERVER_ID], (): boolean => true, onState);
        expect(states.join(',')).assertEqual('loading');
        await settleSourceActions();
        expect(states.join(',')).assertEqual('loading,unavailable');
        assertSourceReads(gateway, [SERVER_ID]);
        controller.load(useCase, SOURCE_CHAT_ID, [SERVER_ID], (): boolean => true, onState);
        expect(states.join(',')).assertEqual('loading,unavailable,loading');
        await settleSourceActions();
        expect(states.join(',')).assertEqual('loading,unavailable,loading,allowed');
        assertSourceReads(gateway, [SERVER_ID, SERVER_ID]);
        expect(gateway.replies.length).assertEqual(0);
      }
    });

    it('inactive lifecycle emits nothing and lifecycle changes ignore pending results without cancel', 0, async () => {
      const inactiveGateway = new SourceActionsGateway([]);
      const inactiveStates: string[] = [];
      new ChatForwardSourceController().load(new ForwardMessagesUseCase(inactiveGateway), SOURCE_CHAT_ID, [SERVER_ID],
        (): boolean => false, (state: string): void => { inactiveStates.push(state); });
      await settleSourceActions();
      expect(inactiveStates.length).assertEqual(0);
      assertSourceReads(inactiveGateway, []);
      for (const fails of [false, true]) {
        const held = new DeferredSourceResponse();
        const gateway = new SourceActionsGateway([held, sourceProperties(true, true, true)]);
        const states: string[] = [];
        let lifecycle = 1;
        const capturedLifecycle = lifecycle;
        new ChatForwardSourceController().load(new ForwardMessagesUseCase(gateway), SOURCE_CHAT_ID,
          [SERVER_ID, SECOND_SERVER_ID], (): boolean => lifecycle === capturedLifecycle,
          (state: string): void => { states.push(state); });
        expect(states.join(',')).assertEqual('loading');
        assertSourceReads(gateway, [SERVER_ID]);
        lifecycle++;
        if (fails) held.reject(); else held.resolve(sourceProperties(true, true, true));
        await settleSourceActions();
        expect(states.join(',')).assertEqual('loading');
        assertSourceReads(gateway, [SERVER_ID]);
        expect(gateway.replies.length).assertEqual(1);
      }
    });

    it('controller exposes allowed for either common route and denied only when both are false', 0, async () => {
      for (const ordinary of [false, true]) {
        for (const secret of [false, true]) {
          const gateway = new SourceActionsGateway([
            sourceProperties(ordinary, !ordinary, true),
            sourceProperties(!ordinary, true, secret)
          ]);
          const states: string[] = [];
          new ChatForwardSourceController().load(new ForwardMessagesUseCase(gateway), SOURCE_CHAT_ID,
            [SERVER_ID, LOCAL_ID], (): boolean => true, (state: string): void => { states.push(state); });
          expect(states.join(',')).assertEqual('loading');
          await settleSourceActions();
          expect(states.join(',')).assertEqual(ordinary || secret ? 'loading,allowed' : 'loading,denied');
          assertSourceReads(gateway, [SERVER_ID, LOCAL_ID]);
        }
      }
    });
  });
}
