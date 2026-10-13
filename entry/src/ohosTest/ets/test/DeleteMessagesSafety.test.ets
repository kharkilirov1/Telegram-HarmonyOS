import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand, DeleteMessagesCommand, GetMessagePropertiesCommand, createDeleteMessagesCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { AppError } from '../../../main/ets/core/model/AppError';
import { TdObject } from '../../../main/ets/core/utils/tdAccessors';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { DeleteMessagesAvailability, DeleteMessagesEligibilityError, DeleteMessagesOutcomeError, DeleteMessagesParams, DeleteMessagesUseCase } from '../../../main/ets/domain/usecases/deleteMessages';
import { ChatDeleteMessageController, ChatDeleteMessageHost, DeleteMessageConfirmation } from '../../../main/ets/ui/pages/chat/ChatDeleteMessageController';

const DELETE_CHAT_ID = -1000000000012;
const DELETE_SERVER_ID = '1048576';
const DELETE_SECOND_ID = '2097152';
const DELETE_LOCAL_ID = '1048578';
const DELETE_MAX_ID = '9007199254740991';

function deletionProperties(forSelf: boolean, forEveryone: boolean): TdObject {
  return TdObject.fromJSON(`{"@type":"messageProperties","can_be_deleted_only_for_self":${forSelf},` +
    `"can_be_deleted_for_all_users":${forEveryone}}`);
}

function deletionOk(): TdObject {
  return TdObject.fromJSON('{"@type":"ok"}');
}

function deletionParams(ids: string[], revoke: boolean = false): DeleteMessagesParams {
  const params = new DeleteMessagesParams();
  params.chatId = DELETE_CHAT_ID;
  params.messageIds = ids;
  params.revoke = revoke;
  return params;
}

class DeferredDeleteResponse {
  promise: Promise<Object>;
  private resolveResponse?: (value: Object) => void;
  private rejectResponse?: (error: Error) => void;

  constructor() {
    this.promise = new Promise<Object>((resolve, reject) => {
      this.resolveResponse = resolve;
      this.rejectResponse = reject;
    });
  }

  resolve(value: Object): void {
    if (this.resolveResponse === undefined) throw new Error('Missing response resolver');
    this.resolveResponse(value);
  }

  reject(): void {
    if (this.rejectResponse === undefined) throw new Error('Missing response rejection');
    this.rejectResponse(new Error('Fake transport unavailable'));
  }
}

class DeleteResponseStep {
  commandType: string;
  response: Object;

  constructor(commandType: string, response: Object) {
    this.commandType = commandType;
    this.response = response;
  }
}

function propertiesStep(response: Object): DeleteResponseStep {
  return new DeleteResponseStep('getMessageProperties', response);
}

function deletionStep(response: Object): DeleteResponseStep {
  return new DeleteResponseStep('deleteMessages', response);
}

// Only scripted transport: no TDLib adapter, initialization, account or network.
// Each response is reserved before awaiting; getChat and missing steps are errors,
// not permissive defaults that could accidentally make an unsafe path pass.
class DeleteSafetyGateway implements TdGatewayPort {
  commands: AnyAppCommand[] = [];
  steps: DeleteResponseStep[];
  unexpected: string[] = [];

  constructor(steps: DeleteResponseStep[]) {
    this.steps = steps.slice();
  }

  async initialize(): Promise<void> {}
  async destroy(): Promise<void> {}
  getConnectionState(): 'ready' { return 'ready'; }
  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void { return (): void => {}; }

  async send(command: AnyAppCommand): Promise<Object> {
    this.commands.push(command);
    const step = this.steps.shift();
    if (step === undefined || step.commandType !== command.type ||
      (command.type !== 'getMessageProperties' && command.type !== 'deleteMessages')) {
      this.unexpected.push(command.type);
      throw new Error(`Unexpected deletion fixture command: ${command.type}`);
    }
    if (step.response instanceof Error) throw step.response;
    if (step.response instanceof DeferredDeleteResponse) return await step.response.promise;
    return step.response;
  }
}

class DeferredDeleteConfirmation {
  promise: Promise<boolean | undefined>;
  private resolveMode?: (value: boolean | undefined) => void;
  private rejectMode?: (error: Error) => void;

  constructor() {
    this.promise = new Promise<boolean | undefined>((resolve, reject) => {
      this.resolveMode = resolve;
      this.rejectMode = reject;
    });
  }

  resolve(value: boolean | undefined): void {
    if (this.resolveMode === undefined) throw new Error('Missing confirmation resolver');
    this.resolveMode(value);
  }

  reject(): void {
    if (this.rejectMode === undefined) throw new Error('Missing confirmation rejection');
    this.rejectMode(new Error('Fake confirmation unavailable'));
  }
}

class DeleteSafetyConfirmation implements DeleteMessageConfirmation {
  offers: DeleteMessagesAvailability[] = [];
  currents: (() => boolean)[] = [];
  replies: DeferredDeleteConfirmation[];

  constructor(replies: DeferredDeleteConfirmation[]) {
    this.replies = replies.slice();
  }

  async confirm(availability: DeleteMessagesAvailability, _host: ChatDeleteMessageHost,
    isCurrent: () => boolean): Promise<boolean | undefined> {
    const snapshot = new DeleteMessagesAvailability();
    snapshot.forSelf = availability.forSelf;
    snapshot.forEveryone = availability.forEveryone;
    this.offers.push(snapshot);
    this.currents.push(isCurrent);
    const reply = this.replies.shift();
    if (reply === undefined) throw new Error('Unexpected duplicate confirmation');
    return await reply.promise;
  }
}

class DeleteSafetyHost implements ChatDeleteMessageHost {
  chatId: number = DELETE_CHAT_ID;
  lifecycle: number = 1;
  active: boolean = true;
  useCase?: DeleteMessagesUseCase;
  uiRequests: number = 0;

  constructor(useCase: DeleteMessagesUseCase) { this.useCase = useCase; }
  getActiveChatId(): number { return this.chatId; }
  getLifecycleToken(): number { return this.lifecycle; }
  hasActiveChatState(): boolean { return this.active; }
  getDeleteUseCase(): DeleteMessagesUseCase | undefined { return this.useCase; }
  getChatUIContext(): UIContext {
    this.uiRequests++;
    throw new Error('Native UI is forbidden in DeleteMessagesSafety');
  }
}

async function settleDeletion(): Promise<void> {
  // Drain controller then/catch/finally without starting a native receive loop.
  await new Promise<void>((resolve) => { setTimeout(resolve, 0); });
}

async function deletionRejection(useCase: DeleteMessagesUseCase, params: DeleteMessagesParams,
  canDispatch: () => boolean = (): boolean => true): Promise<Object | undefined> {
  try { await useCase.execute(params, canDispatch); } catch (error) { return error as Object; }
  return undefined;
}

function assertDeleteTransport(gateway: DeleteSafetyGateway, readIds: string[], deletes: number = 0): void {
  expect(gateway.unexpected.length).assertEqual(0);
  const reads = gateway.commands.filter((command: AnyAppCommand): boolean => command.type === 'getMessageProperties');
  const mutations = gateway.commands.filter((command: AnyAppCommand): boolean => command.type === 'deleteMessages');
  expect(reads.length).assertEqual(readIds.length);
  expect(mutations.length).assertEqual(deletes);
  expect(gateway.commands.length).assertEqual(readIds.length + deletes);
  for (let index = 0; index < readIds.length; index++) {
    const command = reads[index] as GetMessagePropertiesCommand;
    expect(command.payload.chatId).assertEqual(DELETE_CHAT_ID);
    expect(command.payload.messageId).assertEqual(readIds[index]);
  }
}

function assertDeletion(gateway: DeleteSafetyGateway, ids: string[], revoke: boolean, index: number = 0): void {
  const mutations = gateway.commands.filter((command: AnyAppCommand): boolean => command.type === 'deleteMessages');
  expect(mutations.length > index).assertEqual(true);
  const command = mutations[index] as DeleteMessagesCommand;
  expect(command.payload.chatId).assertEqual(DELETE_CHAT_ID);
  expect(command.payload.messageIds.join(',')).assertEqual(ids.join(','));
  expect(command.payload.revoke).assertEqual(revoke);
}

export default function deleteMessagesSafetyTest() {
  describe('DeleteMessagesSafety', () => {
    it('availability intersects both literal deletion flags across every message', 0, async () => {
      for (const firstSelf of [false, true]) {
        for (const firstAll of [false, true]) {
          for (const secondSelf of [false, true]) {
            for (const secondAll of [false, true]) {
              const gateway = new DeleteSafetyGateway([
                propertiesStep(deletionProperties(firstSelf, firstAll)),
                propertiesStep(deletionProperties(secondSelf, secondAll))
              ]);
              const result = await new DeleteMessagesUseCase(gateway).getAvailability(DELETE_CHAT_ID,
                [DELETE_LOCAL_ID, DELETE_SERVER_ID, DELETE_LOCAL_ID]);
              expect(result.forSelf).assertEqual(firstSelf && secondSelf);
              expect(result.forEveryone).assertEqual(firstAll && secondAll);
              assertDeleteTransport(gateway, [DELETE_LOCAL_ID, DELETE_SERVER_ID]);
              expect(gateway.steps.length).assertEqual(0);
            }
          }
        }
      }
    });

    it('availability rejects missing nested nonboolean and non-TdObject grants', 0, async () => {
      // A real parsed plain object (not TdObject), without an untyped ArkTS
      // object literal. Native compilation enforces the fixture boundary too.
      const plain = JSON.parse('{"@type":"messageProperties","can_be_deleted_only_for_self":true,"can_be_deleted_for_all_users":true}') as Object;
      const failures: Object[] = [plain, new Error('Fake properties failure')];
      const flags = '"can_be_deleted_only_for_self":true,"can_be_deleted_for_all_users":true';
      const raws: string[] = [
        `{${flags}}`, `{"@type":"message",${flags}}`, `{"@type":"error",${flags}}`,
        `{"nested":{"@type":"messageProperties"},${flags}}`,
        `{"@type":"messageProperties","nested":{${flags}}}`,
        '{"@type":"messageProperties","can_be_deleted_only_for_self":true}',
        '{"@type":"messageProperties","can_be_deleted_for_all_users":true}',
        `{"@type":"messageProperties",${flags}`
      ];
      for (const value of ['"true"', '1', 'null', '{}', '[]']) {
        raws.push(`{"@type":"messageProperties","can_be_deleted_only_for_self":${value},"can_be_deleted_for_all_users":true}`);
        raws.push(`{"@type":"messageProperties","can_be_deleted_only_for_self":true,"can_be_deleted_for_all_users":${value}}`);
      }
      for (const raw of raws) failures.push(TdObject.fromJSON(raw));
      for (const failure of failures) {
        const gateway = new DeleteSafetyGateway([propertiesStep(failure)]);
        let rejected = false;
        try {
          await new DeleteMessagesUseCase(gateway).getAvailability(DELETE_CHAT_ID, [DELETE_SERVER_ID]);
        } catch (error) {
          rejected = failure instanceof Error ? error === failure : error instanceof DeleteMessagesEligibilityError;
        }
        expect(rejected).assertEqual(true);
        assertDeleteTransport(gateway, [DELETE_SERVER_ID]);
      }
      const gateway = new DeleteSafetyGateway([propertiesStep(TdObject.fromJSON(
        `{"@type":"messageProperties","nested":{${flags}},"can_be_deleted_only_for_self":false,"can_be_deleted_for_all_users":false}`))]);
      const denied = await new DeleteMessagesUseCase(gateway).getAvailability(DELETE_CHAT_ID, [DELETE_LOCAL_ID]);
      expect(denied.forSelf).assertEqual(false);
      expect(denied.forEveryone).assertEqual(false);
      assertDeleteTransport(gateway, [DELETE_LOCAL_ID]);
    });

    it('execute validates positive int53 identifiers before any transport and defaults to self', 0, async () => {
      expect(new DeleteMessagesParams().revoke).assertEqual(false);
      expect(createDeleteMessagesCommand(DELETE_CHAT_ID, [DELETE_SERVER_ID]).payload.revoke).assertEqual(false);
      const invalid: string[][] = [[], [''], ['0'], ['-1'], ['+1'], ['01'], ['1.5'], ['1e3'],
        [' 1'], ['1 '], ['1,2'], ['NaN'], ['Infinity'], ['9007199254740992'], [DELETE_SERVER_ID, '0']];
      for (const ids of invalid) {
        const gateway = new DeleteSafetyGateway([]);
        const error = await deletionRejection(new DeleteMessagesUseCase(gateway), deletionParams(ids));
        expect(error instanceof AppError).assertEqual(true);
        assertDeleteTransport(gateway, []);
      }
      for (const chatId of [0, 0.5, Number.NaN, Number.POSITIVE_INFINITY, 9007199254740992]) {
        const gateway = new DeleteSafetyGateway([]);
        const params = deletionParams([DELETE_SERVER_ID]);
        params.chatId = chatId;
        expect((await deletionRejection(new DeleteMessagesUseCase(gateway), params)) instanceof AppError).assertEqual(true);
        assertDeleteTransport(gateway, []);
      }
    });

    it('execute snapshots and deduplicates in input order without a forward 100-ID cap or getChat', 0, async () => {
      const held = new DeferredDeleteResponse();
      const ids = [DELETE_MAX_ID, DELETE_LOCAL_ID];
      for (let id = 101; id >= 1; id--) ids.push(String(id));
      const expected = ids.slice();
      ids.push(DELETE_LOCAL_ID, DELETE_MAX_ID);
      const steps: DeleteResponseStep[] = [propertiesStep(held)];
      for (let index = 1; index < expected.length; index++) steps.push(propertiesStep(deletionProperties(true, false)));
      steps.push(deletionStep(deletionOk()));
      const gateway = new DeleteSafetyGateway(steps);
      const params = deletionParams(ids);
      const pending = new DeleteMessagesUseCase(gateway).execute(params);
      assertDeleteTransport(gateway, [DELETE_MAX_ID]);
      expect(ids.join(',')).assertEqual(expected.concat([DELETE_LOCAL_ID, DELETE_MAX_ID]).join(','));
      ids.splice(0, ids.length, '0');
      params.chatId = 7;
      params.messageIds = [DELETE_SECOND_ID];
      params.revoke = true;
      held.resolve(deletionProperties(true, false));
      await pending;
      // Public schema's forced-revoke wording is not a blanket channel/local
      // self-denial rule: messageProperties is authoritative, with no getChat.
      expect(expected.length).assertEqual(103);
      assertDeleteTransport(gateway, expected, 1);
      assertDeletion(gateway, expected, false);
      expect(gateway.commands[gateway.commands.length - 1].type).assertEqual('deleteMessages');
      expect(gateway.steps.length).assertEqual(0);
    });

    it('execute repeats eligibility and dispatches only the exact selected mode', 0, async () => {
      for (const revoke of [false, true]) {
        for (const forSelf of [false, true]) {
          for (const forEveryone of [false, true]) {
            const allowed = revoke ? forEveryone : forSelf;
            const steps = [propertiesStep(deletionProperties(true, true)),
              propertiesStep(deletionProperties(forSelf, forEveryone))];
            if (allowed) steps.push(deletionStep(deletionOk()));
            const gateway = new DeleteSafetyGateway(steps);
            const useCase = new DeleteMessagesUseCase(gateway);
            const before = await useCase.getAvailability(DELETE_CHAT_ID, [DELETE_SERVER_ID]);
            expect(before.forSelf && before.forEveryone).assertEqual(true);
            const error = await deletionRejection(useCase, deletionParams([DELETE_SERVER_ID], revoke));
            expect(allowed ? error === undefined : error instanceof DeleteMessagesEligibilityError).assertEqual(true);
            assertDeleteTransport(gateway, [DELETE_SERVER_ID, DELETE_SERVER_ID], allowed ? 1 : 0);
            if (allowed) assertDeletion(gateway, [DELETE_SERVER_ID], revoke);
            expect(gateway.steps.length).assertEqual(0);
          }
        }
      }
    });

    it('only a strict top-level TdObject ok confirms deletion and failures never replay', 0, async () => {
      const plain = JSON.parse('{"@type":"ok"}') as Object;
      const responses: Object[] = [plain, new Error('Fake deletion transport failure'),
        TdObject.fromJSON('{"@type":"error","code":403,"message":"Denied"}'),
        TdObject.fromJSON('{"@type":"message"}'), TdObject.fromJSON('{}'),
        TdObject.fromJSON('{"nested":{"@type":"ok"}}'), TdObject.fromJSON('{"@type":true}'),
        TdObject.fromJSON('{"@type":"ok"'), deletionOk()];
      for (let index = 0; index < responses.length; index++) {
        const gateway = new DeleteSafetyGateway([
          propertiesStep(deletionProperties(true, true)), deletionStep(responses[index])
        ]);
        const error = await deletionRejection(new DeleteMessagesUseCase(gateway), deletionParams([DELETE_SERVER_ID]));
        expect(index === responses.length - 1 ? error === undefined : error instanceof DeleteMessagesOutcomeError).assertEqual(true);
        assertDeleteTransport(gateway, [DELETE_SERVER_ID], 1);
        assertDeletion(gateway, [DELETE_SERVER_ID], false);
        expect(gateway.steps.length).assertEqual(0);
      }
    });

    it('execute cancellation blocks the first read or the next batch step before deletion', 0, async () => {
      const gateway = new DeleteSafetyGateway([]);
      const before = await deletionRejection(new DeleteMessagesUseCase(gateway), deletionParams([DELETE_SERVER_ID]),
        (): boolean => false);
      expect(before instanceof DeleteMessagesEligibilityError).assertEqual(true);
      assertDeleteTransport(gateway, []);
      for (const ids of [[DELETE_SERVER_ID], [DELETE_SERVER_ID, DELETE_SECOND_ID]]) {
        const held = new DeferredDeleteResponse();
        const pendingGateway = new DeleteSafetyGateway([propertiesStep(held)]);
        let active = true;
        const pending = deletionRejection(new DeleteMessagesUseCase(pendingGateway), deletionParams(ids), (): boolean => active);
        assertDeleteTransport(pendingGateway, [DELETE_SERVER_ID]);
        active = false;
        held.resolve(deletionProperties(true, true));
        expect((await pending) instanceof DeleteMessagesEligibilityError).assertEqual(true);
        assertDeleteTransport(pendingGateway, [DELETE_SERVER_ID]);
      }
    });

    it('injected confirmation gates the real core flow and preserves self or everyone exactly', 0, async () => {
      for (const revoke of [false, true]) {
        const reply = new DeferredDeleteConfirmation();
        const gateway = new DeleteSafetyGateway([
          propertiesStep(deletionProperties(!revoke, revoke)), propertiesStep(deletionProperties(!revoke, revoke)),
          deletionStep(deletionOk())
        ]);
        const confirmation = new DeleteSafetyConfirmation([reply]);
        const host = new DeleteSafetyHost(new DeleteMessagesUseCase(gateway));
        new ChatDeleteMessageController(confirmation).request(DELETE_LOCAL_ID, host);
        await settleDeletion();
        assertDeleteTransport(gateway, [DELETE_LOCAL_ID]);
        expect(confirmation.offers.length).assertEqual(1);
        expect(confirmation.offers[0].forSelf).assertEqual(!revoke);
        expect(confirmation.offers[0].forEveryone).assertEqual(revoke);
        expect(confirmation.currents[0]()).assertEqual(true);
        reply.resolve(revoke);
        await settleDeletion();
        assertDeleteTransport(gateway, [DELETE_LOCAL_ID, DELETE_LOCAL_ID], 1);
        assertDeletion(gateway, [DELETE_LOCAL_ID], revoke);
        expect(host.uiRequests).assertEqual(0);
        expect(gateway.steps.length).assertEqual(0);
      }
    });

    it('latest loading request supersedes and old success or failure cannot unlock its confirmation', 0, async () => {
      for (const fails of [false, true]) {
        const old = new DeferredDeleteResponse();
        const reply = new DeferredDeleteConfirmation();
        const gateway = new DeleteSafetyGateway([propertiesStep(old), propertiesStep(deletionProperties(true, true))]);
        const confirmation = new DeleteSafetyConfirmation([reply]);
        const host = new DeleteSafetyHost(new DeleteMessagesUseCase(gateway));
        const controller = new ChatDeleteMessageController(confirmation);
        controller.request(DELETE_SERVER_ID, host);
        controller.request(DELETE_SERVER_ID, host);
        assertDeleteTransport(gateway, [DELETE_SERVER_ID]);
        controller.request(DELETE_SECOND_ID, host);
        await settleDeletion();
        expect(confirmation.offers.length).assertEqual(1);
        if (fails) old.reject(); else old.resolve(deletionProperties(true, true));
        await settleDeletion();
        controller.request(DELETE_LOCAL_ID, host);
        await settleDeletion();
        assertDeleteTransport(gateway, [DELETE_SERVER_ID, DELETE_SECOND_ID]);
        expect(confirmation.offers.length).assertEqual(1);
        expect(confirmation.currents[0]()).assertEqual(true);
        expect(host.uiRequests).assertEqual(0);
        reply.resolve(undefined);
        await settleDeletion();
        expect(gateway.steps.length).assertEqual(0);
      }
    });

    it('duplicate requests are blocked during confirmation and send then a fresh request can proceed', 0, async () => {
      const reply = new DeferredDeleteConfirmation();
      const nextReply = new DeferredDeleteConfirmation();
      const held = new DeferredDeleteResponse();
      const gateway = new DeleteSafetyGateway([
        propertiesStep(deletionProperties(true, true)), propertiesStep(deletionProperties(true, true)),
        deletionStep(held), propertiesStep(deletionProperties(true, false))
      ]);
      const confirmation = new DeleteSafetyConfirmation([reply, nextReply]);
      const host = new DeleteSafetyHost(new DeleteMessagesUseCase(gateway));
      const controller = new ChatDeleteMessageController(confirmation);
      controller.request(DELETE_SERVER_ID, host);
      await settleDeletion();
      controller.request(DELETE_SERVER_ID, host);
      controller.request(DELETE_SECOND_ID, host);
      assertDeleteTransport(gateway, [DELETE_SERVER_ID]);
      expect(confirmation.offers.length).assertEqual(1);
      reply.resolve(true);
      await settleDeletion();
      assertDeleteTransport(gateway, [DELETE_SERVER_ID, DELETE_SERVER_ID], 1);
      controller.request(DELETE_SERVER_ID, host);
      controller.request(DELETE_SECOND_ID, host);
      await settleDeletion();
      assertDeleteTransport(gateway, [DELETE_SERVER_ID, DELETE_SERVER_ID], 1);
      expect(confirmation.offers.length).assertEqual(1);
      held.resolve(deletionOk());
      await settleDeletion();
      controller.request(DELETE_SECOND_ID, host);
      await settleDeletion();
      assertDeleteTransport(gateway, [DELETE_SERVER_ID, DELETE_SERVER_ID, DELETE_SECOND_ID], 1);
      assertDeletion(gateway, [DELETE_SERVER_ID], true);
      expect(confirmation.offers.length).assertEqual(2);
      nextReply.resolve(undefined);
      await settleDeletion();
      expect(host.uiRequests).assertEqual(0);
      expect(gateway.steps.length).assertEqual(0);
    });

    it('cancelled or rejected confirmation never deletes and a later explicit retry is possible', 0, async () => {
      for (const fails of [false, true]) {
        const first = new DeferredDeleteConfirmation();
        const retry = new DeferredDeleteConfirmation();
        const gateway = new DeleteSafetyGateway([
          propertiesStep(deletionProperties(true, true)), propertiesStep(deletionProperties(true, true)),
          propertiesStep(deletionProperties(true, false)), deletionStep(deletionOk())
        ]);
        const confirmation = new DeleteSafetyConfirmation([first, retry]);
        const host = new DeleteSafetyHost(new DeleteMessagesUseCase(gateway));
        const controller = new ChatDeleteMessageController(confirmation);
        controller.request(DELETE_SERVER_ID, host);
        await settleDeletion();
        if (fails) first.reject(); else first.resolve(undefined);
        await settleDeletion();
        assertDeleteTransport(gateway, [DELETE_SERVER_ID]);
        expect(host.uiRequests).assertEqual(fails ? 1 : 0);
        controller.request(DELETE_SERVER_ID, host);
        await settleDeletion();
        expect(confirmation.offers.length).assertEqual(2);
        assertDeleteTransport(gateway, [DELETE_SERVER_ID, DELETE_SERVER_ID]);
        retry.resolve(false);
        await settleDeletion();
        assertDeleteTransport(gateway, [DELETE_SERVER_ID, DELETE_SERVER_ID, DELETE_SERVER_ID], 1);
        assertDeletion(gateway, [DELETE_SERVER_ID], false);
        expect(gateway.steps.length).assertEqual(0);
      }
    });

    it('cancel account chat lifecycle and use-case changes fence loading confirmation and recheck', 0, async () => {
      for (const stage of ['loading', 'confirming', 'rechecking']) {
        for (const change of ['cancel', 'account', 'chat', 'lifecycle', 'usecase', 'missing-usecase']) {
          const held = new DeferredDeleteResponse();
          const reply = new DeferredDeleteConfirmation();
          const steps: DeleteResponseStep[] = [propertiesStep(stage === 'loading' ? held : deletionProperties(true, true))];
          if (stage === 'rechecking') steps.push(propertiesStep(held));
          const gateway = new DeleteSafetyGateway(steps);
          const replacementGateway = new DeleteSafetyGateway([]);
          const confirmation = new DeleteSafetyConfirmation([reply]);
          const host = new DeleteSafetyHost(new DeleteMessagesUseCase(gateway));
          const controller = new ChatDeleteMessageController(confirmation);
          controller.request(DELETE_SERVER_ID, host);
          await settleDeletion();
          expect(confirmation.offers.length).assertEqual(stage === 'loading' ? 0 : 1);
          if (stage === 'rechecking') {
            reply.resolve(true);
            await settleDeletion();
            assertDeleteTransport(gateway, [DELETE_SERVER_ID, DELETE_SERVER_ID]);
          }
          if (change === 'cancel') controller.cancel();
          if (change === 'account') host.active = false;
          if (change === 'chat') host.chatId = 7;
          if (change === 'lifecycle') host.lifecycle++;
          if (change === 'usecase') host.useCase = new DeleteMessagesUseCase(replacementGateway);
          if (change === 'missing-usecase') host.useCase = undefined;
          if (stage === 'confirming') reply.resolve(true); else held.resolve(deletionProperties(true, true));
          await settleDeletion();
          assertDeleteTransport(gateway, stage === 'rechecking' ? [DELETE_SERVER_ID, DELETE_SERVER_ID] : [DELETE_SERVER_ID]);
          assertDeleteTransport(replacementGateway, []);
          expect(confirmation.offers.length).assertEqual(stage === 'loading' ? 0 : 1);
          if (stage !== 'loading') expect(confirmation.currents[0]()).assertEqual(false);
          expect(host.uiRequests).assertEqual(0);
          expect(gateway.steps.length).assertEqual(0);
        }
      }
    });

    it('permission loss after confirmation cannot fall back to the other deletion mode', 0, async () => {
      for (const revoke of [false, true]) {
        const reply = new DeferredDeleteConfirmation();
        const gateway = new DeleteSafetyGateway([
          propertiesStep(deletionProperties(true, true)), propertiesStep(deletionProperties(revoke, !revoke))
        ]);
        const confirmation = new DeleteSafetyConfirmation([reply]);
        const host = new DeleteSafetyHost(new DeleteMessagesUseCase(gateway));
        new ChatDeleteMessageController(confirmation).request(DELETE_SERVER_ID, host);
        await settleDeletion();
        expect(confirmation.offers.length).assertEqual(1);
        expect(confirmation.offers[0].forSelf && confirmation.offers[0].forEveryone).assertEqual(true);
        assertDeleteTransport(gateway, [DELETE_SERVER_ID]);
        reply.resolve(revoke);
        await settleDeletion();
        assertDeleteTransport(gateway, [DELETE_SERVER_ID, DELETE_SERVER_ID]);
        expect(confirmation.offers.length).assertEqual(1);
        expect(host.uiRequests).assertEqual(1);
        expect(gateway.steps.length).assertEqual(0);
      }
    });

    it('replaced confirmation cleanup cannot unlock a newer flow awaiting its final eligibility', 0, async () => {
      for (const fails of [false, true]) {
        const old = new DeferredDeleteConfirmation();
        const next = new DeferredDeleteConfirmation();
        const recheck = new DeferredDeleteResponse();
        const gateway = new DeleteSafetyGateway([
          propertiesStep(deletionProperties(true, true)), propertiesStep(deletionProperties(true, true)),
          propertiesStep(recheck), deletionStep(deletionOk())
        ]);
        const confirmation = new DeleteSafetyConfirmation([old, next]);
        const host = new DeleteSafetyHost(new DeleteMessagesUseCase(gateway));
        const controller = new ChatDeleteMessageController(confirmation);
        controller.request(DELETE_SERVER_ID, host);
        await settleDeletion();
        controller.cancel();
        controller.request(DELETE_SECOND_ID, host);
        await settleDeletion();
        expect(confirmation.offers.length).assertEqual(2);
        expect(confirmation.currents[0]()).assertEqual(false);
        expect(confirmation.currents[1]()).assertEqual(true);
        next.resolve(false);
        await settleDeletion();
        assertDeleteTransport(gateway, [DELETE_SERVER_ID, DELETE_SECOND_ID, DELETE_SECOND_ID]);
        if (fails) old.reject(); else old.resolve(true);
        await settleDeletion();
        controller.request(DELETE_LOCAL_ID, host);
        controller.request(DELETE_SECOND_ID, host);
        await settleDeletion();
        assertDeleteTransport(gateway, [DELETE_SERVER_ID, DELETE_SECOND_ID, DELETE_SECOND_ID]);
        expect(confirmation.offers.length).assertEqual(2);
        expect(confirmation.currents[1]()).assertEqual(true);
        recheck.resolve(deletionProperties(true, false));
        await settleDeletion();
        assertDeleteTransport(gateway, [DELETE_SERVER_ID, DELETE_SECOND_ID, DELETE_SECOND_ID], 1);
        assertDeletion(gateway, [DELETE_SECOND_ID], false);
        expect(host.uiRequests).assertEqual(0);
        expect(gateway.steps.length).assertEqual(0);
      }
    });
  });
}
