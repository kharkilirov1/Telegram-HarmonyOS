import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand, EditMessageCaptionCommand, EditMessageTextCommand, GetMessageCommand, GetMessagePropertiesCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { AppError } from '../../../main/ets/core/model/AppError';
import { TdObject } from '../../../main/ets/core/utils/tdAccessors';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { EditMessageEligibilityError, EditMessageOutcomeError, EditMessageParams, EditMessageUseCase } from '../../../main/ets/domain/usecases/editMessage';
import { ChatEditMessageController, ChatEditMessageHost } from '../../../main/ets/ui/pages/chat/ChatEditMessageController';

const EDIT_CHAT_ID = -1000000000012;
const EDIT_ID = '1048576';
const OTHER_EDIT_ID = '2097152';

function formattedEditText(text: string): string {
  return `{"@type":"formattedText","text":${JSON.stringify(text)},"entities":[]}`;
}

function editMessageContent(content: string, id: string = EDIT_ID, chatId: number = EDIT_CHAT_ID): TdObject {
  return TdObject.fromJSON(`{"@type":"message","id":${id},"chat_id":${chatId},"content":${content}}`);
}

function editTextMessage(text: string = 'original', id: string = EDIT_ID, chatId: number = EDIT_CHAT_ID): TdObject {
  return editMessageContent(`{"@type":"messageText","text":${formattedEditText(text)},"link_preview_options":null}`, id, chatId);
}

function scheduledEditMessage(text: string, id: string, sendDate: number): TdObject {
  return TdObject.fromJSON(`{"@type":"message","id":${id},"chat_id":${EDIT_CHAT_ID},` +
    `"scheduling_state":{"@type":"messageSchedulingStateSendAtDate","send_date":${sendDate}},` +
    `"content":{"@type":"messageText","text":${formattedEditText(text)},"link_preview_options":null}}`);
}

function editCaptionMessage(kind: string, text: string, above: boolean): TdObject {
  const position = ['messageAnimation', 'messagePhoto', 'messageVideo', 'messagePaidMedia'].includes(kind)
    ? `,"show_caption_above_media":${above}` : '';
  return editMessageContent(`{"@type":"${kind}","caption":${formattedEditText(text)}${position}}`);
}

function editProperties(allowed: boolean = true): TdObject {
  return TdObject.fromJSON(`{"@type":"messageProperties","can_be_edited":${allowed}}`);
}

function editParams(text: string = 'updated', id: string = EDIT_ID): EditMessageParams {
  const params = new EditMessageParams();
  params.chatId = EDIT_CHAT_ID;
  params.messageId = id;
  params.text = text;
  return params;
}

class DeferredEditResponse {
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
    if (this.resolveResponse === undefined) throw new Error('Missing edit resolver');
    this.resolveResponse(value);
  }
  reject(): void {
    if (this.rejectResponse === undefined) throw new Error('Missing edit rejection');
    this.rejectResponse(new Error('Scripted edit transport failure'));
  }
}

class EditResponseStep {
  commandType: string;
  response: Object;
  constructor(commandType: string, response: Object) {
    this.commandType = commandType;
    this.response = response;
  }
}

function editSteps(response: Object): EditResponseStep[] {
  return [new EditResponseStep('getMessage', editTextMessage()),
    new EditResponseStep('getMessageProperties', editProperties()),
    new EditResponseStep('editMessageText', response)];
}

// The real use case and controller run against the port, never a TDLib adapter.
// Reserve the scripted reply before awaiting so superseded sends cannot steal it.
// There are no success defaults: missing or out-of-order requests fail the test.
class EditSafetyGateway implements TdGatewayPort {
  commands: AnyAppCommand[] = [];
  steps: EditResponseStep[];
  unexpected: string[] = [];
  constructor(steps: EditResponseStep[]) { this.steps = steps.slice(); }
  async initialize(): Promise<void> {}
  async destroy(): Promise<void> {}
  getConnectionState(): 'ready' { return 'ready'; }
  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void { return (): void => {}; }
  async send(command: AnyAppCommand): Promise<Object> {
    this.commands.push(command);
    const step = this.steps.shift();
    if (step === undefined || step.commandType !== command.type ||
      !['getMessage', 'getMessageProperties', 'editMessageText', 'editMessageCaption'].includes(command.type)) {
      this.unexpected.push(command.type);
      throw new Error(`Unexpected edit fixture command: ${command.type}`);
    }
    if (step.response instanceof Error) throw step.response;
    if (step.response instanceof DeferredEditResponse) return await step.response.promise;
    return step.response;
  }
}

class EditSafetyHost implements ChatEditMessageHost {
  chatId: number = EDIT_CHAT_ID;
  lifecycle: number = 1;
  active: boolean = true;
  useCase?: EditMessageUseCase;
  editId: string = EDIT_ID;
  original: string = 'original';
  draft: string = 'updated';
  busy: boolean = false;
  operation: number = 0;
  clears: number = 0;
  rebases: number = 0;
  uiRequests: number = 0;
  // Sentinels at the host boundary, not a claim of rich-editor restoration.
  draftEntities: string[] = ['newer-draft-entity'];
  selection: number = 3;
  constructor(gateway: EditSafetyGateway) { this.useCase = new EditMessageUseCase(gateway); }
  getActiveChatId(): number { return this.chatId; }
  getLifecycleToken(): number { return this.lifecycle; }
  hasActiveChatState(): boolean { return this.active; }
  getEditUseCase(): EditMessageUseCase | undefined { return this.useCase; }
  getEditingMessageId(): string { return this.editId; }
  getEditingOriginalText(): string { return this.original; }
  rebaseEditingMessage(id: string, text: string): void {
    this.rebases++;
    this.editId = id;
    this.original = text;
  }
  getDraftText(): string { return this.draft; }
  clearEditMode(clearDraft: boolean): void {
    this.clears++;
    this.editId = '0';
    this.original = '';
    if (clearDraft) { this.draft = ''; this.draftEntities = []; this.selection = 0; }
  }
  isSendingMessage(): boolean { return this.busy; }
  setSendingMessage(value: boolean): void { this.operation++; this.busy = value; }
  getSendOperationToken(): number { return this.operation; }
  getChatUIContext(): UIContext { this.uiRequests++; throw new Error('Native UI outside fixture'); }
}

async function settleEdit(): Promise<void> {
  await new Promise<void>((resolve) => { setTimeout(resolve, 0); });
}

function assertEditTransport(gateway: EditSafetyGateway, types: string,
  id: string = EDIT_ID, propertyId: string = id): void {
  expect(gateway.commands.map((command: AnyAppCommand): string => command.type).join(',')).assertEqual(types);
  expect(gateway.unexpected.length).assertEqual(0);
  expect(gateway.steps.length).assertEqual(0);
  for (const command of gateway.commands) {
    if (command.type === 'getMessage') {
      const read = command as GetMessageCommand;
      expect(read.payload.chatId).assertEqual(EDIT_CHAT_ID);
      expect(read.payload.messageId).assertEqual(id);
    } else if (command.type === 'getMessageProperties') {
      const properties = command as GetMessagePropertiesCommand;
      expect(properties.payload.chatId).assertEqual(EDIT_CHAT_ID);
      expect(properties.payload.messageId).assertEqual(propertyId);
    } else if (command.type === 'editMessageText') {
      const text = command as EditMessageTextCommand;
      expect(text.payload.chatId).assertEqual(EDIT_CHAT_ID);
      expect(text.payload.messageId).assertEqual(propertyId);
    } else if (command.type === 'editMessageCaption') {
      const caption = command as EditMessageCaptionCommand;
      expect(caption.payload.chatId).assertEqual(EDIT_CHAT_ID);
      expect(caption.payload.messageId).assertEqual(propertyId);
    }
  }
}

function assertEditDraft(host: EditSafetyHost, text: string = 'updated', original: string = 'original',
  id: string = EDIT_ID): void {
  expect(host.draft).assertEqual(text);
  expect(host.original).assertEqual(original);
  expect(host.editId).assertEqual(id);
  expect(host.clears).assertEqual(0);
}

export default function editMessagesSafetyTest() {
  describe('EditMessagesSafety', () => {
    it('reads source then fresh properties before the text mutation and returns server text', 0, async () => {
      const gateway = new EditSafetyGateway(editSteps(editTextMessage('server normalized')));
      const result = await new EditMessageUseCase(gateway).execute(editParams(' updated '));
      assertEditTransport(gateway, 'getMessage,getMessageProperties,editMessageText');
      expect((gateway.commands[2] as EditMessageTextCommand).payload.text).assertEqual(' updated ');
      expect(result.kind).assertEqual('text');
      expect(result.text).assertEqual('server normalized');
      expect(result.messageId).assertEqual(EDIT_ID);
    });

    it('routes supported media through caption editing including removal and literal placement', 0, async () => {
      for (const kind of ['messageAnimation', 'messageAudio', 'messageDocument', 'messagePhoto',
        'messageVideo', 'messageVoiceNote', 'messagePaidMedia']) {
        for (const text of ['', 'new caption']) {
          for (const above of [false, true]) {
            const gateway = new EditSafetyGateway([
              new EditResponseStep('getMessage', editCaptionMessage(kind, 'old caption', above)),
              new EditResponseStep('getMessageProperties', editProperties()),
              new EditResponseStep('editMessageCaption', editCaptionMessage(kind, text, above))]);
            const result = await new EditMessageUseCase(gateway).execute(editParams(text));
            assertEditTransport(gateway, 'getMessage,getMessageProperties,editMessageCaption');
            const mutation = gateway.commands[2] as EditMessageCaptionCommand;
            expect(mutation.payload.caption).assertEqual(text);
            const expectedAbove = ['messageAnimation', 'messagePhoto', 'messageVideo', 'messagePaidMedia'].includes(kind) && above;
            expect(mutation.payload.showCaptionAboveMedia).assertEqual(expectedAbove);
            expect(result.kind).assertEqual('caption');
            expect(result.text).assertEqual(text);
          }
        }
      }
    });

    it('rejects invalid identifiers and excessive text before transport, empty text after source', 0, async () => {
      const invalid: EditMessageParams[] = [];
      for (const id of ['0', '-1', '01', '1.5', '1,2', '9007199254740992']) invalid.push(editParams('updated', id));
      for (const chatId of [0, 1.5, 9007199254740992]) {
        const params = editParams(); params.chatId = chatId; invalid.push(params);
      }
      invalid.push(editParams('x'.repeat(4097)));
      for (const params of invalid) {
        const gateway = new EditSafetyGateway([]);
        let rejected = false;
        try { await new EditMessageUseCase(gateway).execute(params); }
        catch (error) { rejected = error instanceof AppError; }
        expect(rejected).assertEqual(true);
        assertEditTransport(gateway, '');
      }
      for (const text of ['', ' \n ']) {
        const gateway = new EditSafetyGateway([new EditResponseStep('getMessage', editTextMessage())]);
        let rejected = false;
        try { await new EditMessageUseCase(gateway).execute(editParams(text)); }
        catch (error) { rejected = error instanceof EditMessageEligibilityError; }
        expect(rejected).assertEqual(true);
        assertEditTransport(gateway, 'getMessage');
      }
    });

    it('fails closed on wrong source identity, unsupported content and malformed formatted text', 0, async () => {
      const sources: Object[] = [TdObject.fromJSON('{"@type":"ok"}'), editTextMessage('old', OTHER_EDIT_ID),
        editTextMessage('old', EDIT_ID, 42), editMessageContent('{"@type":"messageSticker"}'),
        editMessageContent('{"@type":"messageText","text":{"@type":"formattedText","text":"old"},"link_preview_options":null}'),
        editMessageContent('{"@type":"messageText","text":{"@type":"formattedText","text":"old","entities":null},"link_preview_options":null}'),
        editMessageContent('{"@type":"messageText","text":{"@type":"formattedText","text":42,"entities":[]},"link_preview_options":null}'),
        editMessageContent(`{"@type":"messagePhoto","caption":${formattedEditText('old')},"show_caption_above_media":"true"}`)];
      for (const source of sources) {
        const gateway = new EditSafetyGateway([new EditResponseStep('getMessage', source)]);
        let rejected = false;
        try { await new EditMessageUseCase(gateway).execute(editParams()); }
        catch (error) { rejected = error instanceof Error; }
        expect(rejected).assertEqual(true);
        assertEditTransport(gateway, 'getMessage');
      }
    });

    it('requires literal top-level can_be_edited true from messageProperties', 0, async () => {
      const raws: string[] = ['{"@type":"messageProperties"}',
        '{"@type":"messageProperties","nested":{"can_be_edited":true}}',
        '{"@type":"ok","can_be_edited":true}', '{"@type":"messageProperties","can_be_edited":false,"nested":{"can_be_edited":true}}'];
      for (const value of ['false', 'null', '0', '1', '"true"', '{}', '[]']) {
        raws.push(`{"@type":"messageProperties","can_be_edited":${value}}`);
      }
      for (const raw of raws) {
        const gateway = new EditSafetyGateway([new EditResponseStep('getMessage', editTextMessage()),
          new EditResponseStep('getMessageProperties', TdObject.fromJSON(raw))]);
        let rejected = false;
        try { await new EditMessageUseCase(gateway).execute(editParams()); }
        catch (error) { rejected = error instanceof EditMessageEligibilityError; }
        expect(rejected).assertEqual(true);
        assertEditTransport(gateway, 'getMessage,getMessageProperties');
      }
    });

    it('checks the dispatch fence before reads and after each eligibility await', 0, async () => {
      for (const stage of [0, 1, 2]) {
        const deferred = new DeferredEditResponse();
        const steps: EditResponseStep[] = [];
        if (stage === 1) steps.push(new EditResponseStep('getMessage', deferred));
        if (stage === 2) {
          steps.push(new EditResponseStep('getMessage', editTextMessage()));
          steps.push(new EditResponseStep('getMessageProperties', deferred));
        }
        const gateway = new EditSafetyGateway(steps);
        let allowed = stage !== 0;
        let rejected = false;
        const pending = new EditMessageUseCase(gateway).execute(editParams(), (): boolean => allowed)
          .catch((error: Object): void => { rejected = error instanceof EditMessageEligibilityError; });
        await settleEdit();
        expect(gateway.commands.length).assertEqual(stage);
        allowed = false;
        if (stage !== 0) deferred.resolve(stage === 1 ? editTextMessage() : editProperties());
        await pending;
        expect(rejected).assertEqual(true);
        assertEditTransport(gateway, stage === 0 ? '' : stage === 1 ? 'getMessage' : 'getMessage,getMessageProperties');
      }
    });

    it('requires a matching mutating Message result and never replays an unknown outcome', 0, async () => {
      const outcomes: Object[] = [new Error('lost reply'), TdObject.fromJSON('{"@type":"ok"}'),
        TdObject.fromJSON('{"@type":"error","code":400,"message":"MESSAGE_NOT_MODIFIED"}'),
        editTextMessage('updated', OTHER_EDIT_ID), editTextMessage('updated', EDIT_ID, 42),
        editCaptionMessage('messagePhoto', 'updated', false)];
      for (const outcome of outcomes) {
        const gateway = new EditSafetyGateway(editSteps(outcome));
        let rejected = false;
        try { await new EditMessageUseCase(gateway).execute(editParams()); }
        catch (error) { rejected = error instanceof EditMessageOutcomeError; }
        expect(rejected).assertEqual(true);
        await settleEdit();
        assertEditTransport(gateway, 'getMessage,getMessageProperties,editMessageText');
      }
    });

    it('retains the draft before and after properties until success and blocks double submission', 0, async () => {
      const source = new DeferredEditResponse(); const properties = new DeferredEditResponse();
      const mutation = new DeferredEditResponse();
      const gateway = new EditSafetyGateway([new EditResponseStep('getMessage', source),
        new EditResponseStep('getMessageProperties', properties), new EditResponseStep('editMessageText', mutation)]);
      const host = new EditSafetyHost(gateway); const controller = new ChatEditMessageController();
      controller.submit('updated', host);
      await settleEdit();
      assertEditDraft(host); expect(host.busy).assertEqual(true); expect(gateway.commands.length).assertEqual(1);
      source.resolve(editTextMessage()); await settleEdit();
      assertEditDraft(host); expect(host.busy).assertEqual(true); expect(gateway.commands.length).assertEqual(2);
      controller.submit('updated', host);
      expect(gateway.commands.length).assertEqual(2);
      properties.resolve(editProperties()); await settleEdit();
      assertEditDraft(host); expect(host.busy).assertEqual(true);
      assertEditTransport(gateway, 'getMessage,getMessageProperties,editMessageText');
      mutation.resolve(editTextMessage('updated')); await settleEdit();
      expect(host.clears).assertEqual(1); expect(host.draft).assertEqual(''); expect(host.editId).assertEqual('0');
      expect(host.busy).assertEqual(false); expect(host.rebases).assertEqual(0); expect(host.uiRequests).assertEqual(0);
    });

    it('retains edit intent on source, permission and mutation failures without automatic replay', 0, async () => {
      for (const stage of [1, 2, 3]) {
        const deferred = new DeferredEditResponse();
        const steps: EditResponseStep[] = [new EditResponseStep('getMessage', stage === 1 ? deferred : editTextMessage())];
        if (stage >= 2) steps.push(new EditResponseStep('getMessageProperties', stage === 2 ? deferred : editProperties()));
        if (stage === 3) steps.push(new EditResponseStep('editMessageText', deferred));
        const gateway = new EditSafetyGateway(steps); const host = new EditSafetyHost(gateway);
        new ChatEditMessageController().submit('updated', host); await settleEdit();
        assertEditDraft(host); expect(host.busy).assertEqual(true);
        if (stage === 2) deferred.resolve(editProperties(false)); else deferred.reject();
        await settleEdit();
        assertEditDraft(host); expect(host.busy).assertEqual(false); expect(host.rebases).assertEqual(0);
        expect(host.uiRequests).assertEqual(1);
        assertEditTransport(gateway, stage === 1 ? 'getMessage' : stage === 2 ? 'getMessage,getMessageProperties' :
          'getMessage,getMessageProperties,editMessageText');
      }
      // The displayed baseline no longer matches a fresh source: do not overwrite
      // an edit made elsewhere even when this page still has editing capability.
      const gateway = new EditSafetyGateway([new EditResponseStep('getMessage', editTextMessage('remote changed'))]);
      const host = new EditSafetyHost(gateway);
      new ChatEditMessageController().submit('updated', host); await settleEdit();
      assertEditDraft(host); expect(host.busy).assertEqual(false); expect(host.uiRequests).assertEqual(1);
      expect(host.rebases).assertEqual(0);
      assertEditTransport(gateway, 'getMessage');
    });

    it('rebases only the confirmed original when newer typing exists', 0, async () => {
      const mutation = new DeferredEditResponse(); const gateway = new EditSafetyGateway(editSteps(mutation));
      const host = new EditSafetyHost(gateway); const entities = host.draftEntities;
      new ChatEditMessageController().submit('updated', host); await settleEdit();
      host.draft = 'newer typing'; host.selection = 8;
      mutation.resolve(editTextMessage('canonical server text')); await settleEdit();
      assertEditDraft(host, 'newer typing', 'canonical server text');
      expect(host.rebases).assertEqual(1); expect(host.busy).assertEqual(false);
      expect(host.draftEntities === entities).assertEqual(true); expect(host.selection).assertEqual(8);
      expect(host.uiRequests).assertEqual(0);
      assertEditTransport(gateway, 'getMessage,getMessageProperties,editMessageText');
    });

    it('cancel and same-ID replacement fence stale completion even with an identical original', 0, async () => {
      const oldMutation = new DeferredEditResponse(); const newMutation = new DeferredEditResponse();
      const gateway = new EditSafetyGateway(editSteps(oldMutation).concat(editSteps(newMutation)));
      const host = new EditSafetyHost(gateway); const controller = new ChatEditMessageController();
      controller.submit('updated', host); await settleEdit();
      controller.cancel(); expect(host.busy).assertEqual(false);
      // A replacement edit deliberately has the same ID, baseline and draft.
      controller.submit('updated', host); await settleEdit();
      const newerOwner = host.operation;
      oldMutation.resolve(editTextMessage('old accepted')); await settleEdit();
      assertEditDraft(host); expect(host.busy).assertEqual(true); expect(host.operation).assertEqual(newerOwner);
      expect(host.rebases).assertEqual(0); expect(host.uiRequests).assertEqual(0);
      newMutation.resolve(editTextMessage('updated')); await settleEdit();
      expect(host.busy).assertEqual(false); expect(host.clears).assertEqual(1);
      assertEditTransport(gateway, 'getMessage,getMessageProperties,editMessageText,getMessage,getMessageProperties,editMessageText');
    });

    it('stale edit success or failure cannot release a newer shared send owner', 0, async () => {
      for (const fail of [false, true]) {
        const mutation = new DeferredEditResponse(); const gateway = new EditSafetyGateway(editSteps(mutation));
        const host = new EditSafetyHost(gateway);
        new ChatEditMessageController().submit('updated', host); await settleEdit();
        host.setSendingMessage(false); host.setSendingMessage(true);
        const newerOwner = host.operation;
        if (fail) mutation.reject(); else mutation.resolve(editTextMessage('updated'));
        await settleEdit();
        assertEditDraft(host); expect(host.busy).assertEqual(true); expect(host.operation).assertEqual(newerOwner);
        expect(host.rebases).assertEqual(0); expect(host.uiRequests).assertEqual(0);
        assertEditTransport(gateway, 'getMessage,getMessageProperties,editMessageText');
      }
    });

    it('account capability and lifecycle changes fence every await without writing stale edit state', 0, async () => {
      for (const boundary of ['account', 'useCase', 'lifecycle', 'chat']) {
        for (const stage of [1, 2, 3]) {
          const deferred = new DeferredEditResponse();
          const steps: EditResponseStep[] = [new EditResponseStep('getMessage', stage === 1 ? deferred : editTextMessage())];
          if (stage >= 2) steps.push(new EditResponseStep('getMessageProperties', stage === 2 ? deferred : editProperties()));
          if (stage === 3) steps.push(new EditResponseStep('editMessageText', deferred));
          const gateway = new EditSafetyGateway(steps); const host = new EditSafetyHost(gateway);
          new ChatEditMessageController().submit('updated', host); await settleEdit();
          expect(gateway.commands.length).assertEqual(stage);
          if (boundary === 'account') host.active = false;
          if (boundary === 'useCase') host.useCase = new EditMessageUseCase(new EditSafetyGateway([]));
          if (boundary === 'lifecycle') host.lifecycle++;
          if (boundary === 'chat') host.chatId = 77;
          const owner = host.operation;
          deferred.resolve(stage === 2 ? editProperties() : editTextMessage(stage === 3 ? 'updated' : 'original'));
          await settleEdit();
          assertEditDraft(host); expect(host.rebases).assertEqual(0); expect(host.uiRequests).assertEqual(0);
          const differentContext = boundary === 'lifecycle' || boundary === 'chat';
          expect(host.busy).assertEqual(differentContext);
          expect(host.operation).assertEqual(differentContext ? owner : owner + 1);
          assertEditTransport(gateway, stage === 1 ? 'getMessage' : stage === 2 ? 'getMessage,getMessageProperties' :
            'getMessage,getMessageProperties,editMessageText');
        }
      }
    });

    it('accepts scheduled date aliases and rebases the canonical ID without discarding newer typing', 0, async () => {
      // MessageId.h/.cpp: (send_date - 2**30) * 2**21 + server_id * 8 + 4.
      // All three IDs have scheduled server_id 7; only the send-date part changes.
      const scheduledId = '209715260';
      const freshId = '211812412';
      const canonicalId = '213909564';
      const response = new DeferredEditResponse();
      const gateway = new EditSafetyGateway([
        new EditResponseStep('getMessage', scheduledEditMessage('original', freshId, 1073741925)),
        new EditResponseStep('getMessageProperties', editProperties()), new EditResponseStep('editMessageText', response)]);
      const host = new EditSafetyHost(gateway); host.editId = scheduledId;
      new ChatEditMessageController().submit('updated', host); await settleEdit();
      host.draft = 'newer scheduled draft';
      response.resolve(scheduledEditMessage('confirmed scheduled text', canonicalId, 1073741926)); await settleEdit();
      assertEditDraft(host, 'newer scheduled draft', 'confirmed scheduled text', canonicalId);
      expect(host.rebases).assertEqual(1); expect(host.busy).assertEqual(false); expect(host.uiRequests).assertEqual(0);
      assertEditTransport(gateway, 'getMessage,getMessageProperties,editMessageText', scheduledId, freshId);
    });
  });
}
