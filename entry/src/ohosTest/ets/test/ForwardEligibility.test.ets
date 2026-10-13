import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { ForwardMessagesParams, ForwardMessagesUseCase, ForwardMessagesEligibilityError } from '../../../main/ets/domain/usecases/forwardMessages';
import { SendMessageUseCase } from '../../../main/ets/domain/usecases/sendMessage';
import { EditMessageUseCase } from '../../../main/ets/domain/usecases/editMessage';
import { DeleteMessagesUseCase } from '../../../main/ets/domain/usecases/deleteMessages';
import { PinChatMessageUseCase } from '../../../main/ets/domain/usecases/pinChatMessage';
import { serializeCommand, buildTdlibRequestJson } from '../../../main/ets/infra/td/serialization/CommandSerializer';
import { ChatMessageActionsController, ChatMessageActionsHost, ChatForwardModeState } from '../../../main/ets/ui/pages/chat/ChatMessageActionsController';
import { ChatScreenRouteParams } from '../../../main/ets/ui/pages/chat/ChatScreenRouteParams';

// tdlib/td/telegram/MessageId.h: server_id << 20, local type bits = 2.
// MessagesManager.cpp get_forwarded_messages: !is_server() || to_secret || send_copy.
const SERVER_ID = '1048576';
const SECOND_SERVER_ID = '2097152';
const LOCAL_ID = '1048578';
const MAX_SERVER_ID = '2251799812636672'; // 2147483647 * 1048576, still positive int53.

function properties(forward: boolean, copy: boolean, secret: boolean): TdObject {
  return TdObject.fromJSON(`{"@type":"messageProperties","can_be_forwarded":${forward},` +
    `"can_be_copied":${copy},"can_be_copied_to_secret_chat":${secret}}`);
}

function eligibilityParams(ids: string[] = [SERVER_ID]): ForwardMessagesParams {
  const params = new ForwardMessagesParams();
  params.chatId = 7; params.fromChatId = -12; params.messageIds = ids;
  return params;
}

// No real adapter, TDLib initialization, network or account. Missing fixture replies
// fail instead of silently granting eligibility; all successful replies are TdObject.
class EligibilityGateway implements TdGatewayPort {
  commands: AnyAppCommand[] = [];
  target: TdObject = TdObject.fromJSON('{"@type":"chat","id":7,"type":{"@type":"chatTypePrivate"}}');
  sourceProperties: TdObject[];
  forwardResponse: TdObject = TdObject.fromJSON('{"@type":"messages","messages":[{"@type":"message","id":9437184,"chat_id":7}]}');
  propertyError?: Error;
  holdType: string = '';
  releaseHeld?: () => void;
  constructor(sourceProperties: TdObject[]) { this.sourceProperties = sourceProperties.slice(); }
  async initialize(): Promise<void> {}
  async destroy(): Promise<void> {}
  getConnectionState(): 'ready' { return 'ready'; }
  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void { return (): void => {}; }
  async send(command: AnyAppCommand): Promise<Object> {
    this.commands.push(command);
    if (command.type === this.holdType) {
      await new Promise<void>((resolve) => { this.releaseHeld = resolve; });
    }
    if (command.type === 'getChat') return this.target;
    if (command.type === 'getMessageProperties') {
      if (this.propertyError !== undefined) throw this.propertyError;
      const response = this.sourceProperties.shift();
      if (response === undefined) throw new Error('Missing source properties fixture');
      return response;
    }
    if (command.type === 'forwardMessages') return this.forwardResponse;
    if (command.type === 'sendMessage') {
      return TdObject.fromJSON('{"@type":"message","id":8388608,"chat_id":7}');
    }
    throw new Error(`Unexpected fixture command: ${command.type}`);
  }
}

function commandTypes(gateway: EligibilityGateway): string {
  return gateway.commands.map((command: AnyAppCommand): string => command.type).join(',');
}

function wireCommand(gateway: EligibilityGateway, index: number): TdObject {
  const serialized = serializeCommand(gateway.commands[index]);
  return TdObject.fromJSON(buildTdlibRequestJson(serialized.method, serialized.params));
}

async function assertDenied(gateway: EligibilityGateway, params: ForwardMessagesParams = eligibilityParams(),
  canDispatch: () => boolean = (): boolean => true): Promise<void> {
  let rejected = false;
  try { await new ForwardMessagesUseCase(gateway).execute(params, canDispatch); } catch (error) {
    rejected = error instanceof ForwardMessagesEligibilityError;
  }
  expect(rejected).assertEqual(true);
  expect(commandTypes(gateway).includes('forwardMessages')).assertEqual(false);
  expect(commandTypes(gateway).includes('sendMessage')).assertEqual(false);
}

// Check the same untrusted payload through ordinary forward, explicit copy,
// secret forced copy and local forced copy, using the actual use case each time.
async function assertDeniedInEveryMode(raw: string): Promise<void> {
  for (let mode = 0; mode < 4; mode++) {
    const gateway = new EligibilityGateway([TdObject.fromJSON(raw)]);
    const params = eligibilityParams(mode === 3 ? [LOCAL_ID] : [SERVER_ID]);
    params.sendCopy = mode === 1;
    if (mode === 2) gateway.target = TdObject.fromJSON('{"@type":"chat","id":7,"type":{"@type":"chatTypeSecret"}}');
    await assertDenied(gateway, params);
    expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties');
  }
}

// Minimal typed controller host, patterned after ForwardSendOwnership. Both
// use cases are real; only the gateway and page/UI boundary are fixtures.
class EligibilityHost implements ChatMessageActionsHost {
  gateway: EligibilityGateway;
  sender: SendMessageUseCase;
  forwarder: ForwardMessagesUseCase;
  busy: boolean = false;
  operation: number = 0;
  draft: string = '';
  revision: number = 0;
  editId: string = '0';
  editOriginal: string = '';
  forward: ChatForwardModeState = new ChatForwardModeState();
  constructor(gateway: EligibilityGateway) {
    this.gateway = gateway;
    this.sender = new SendMessageUseCase(gateway);
    this.forwarder = new ForwardMessagesUseCase(gateway);
  }
  getActiveChatId(): number { return 7; }
  getChatRouteToken(): number { return 0; }
  getLifecycleToken(): number { return 1; }
  canSendNewMessages(_kind?: string): boolean { return this.editId === '0'; }
  getChatUIContext(): UIContext { throw new Error('UI is outside this fixture'); }
  bindNavigationStack(): NavPathStack | undefined { return undefined; }
  createChatRouteParams(_chatId: number, _title: string): ChatScreenRouteParams | undefined { return undefined; }
  getSendUseCase(): SendMessageUseCase | undefined { return this.sender; }
  getForwardUseCase(): ForwardMessagesUseCase | undefined { return this.forwarder; }
  getSourceForwardUseCase(): ForwardMessagesUseCase | undefined { return this.hasActiveChatState() ? this.forwarder : undefined; }
  getEditUseCase(): EditMessageUseCase | undefined { return undefined; }
  getDeleteUseCase(): DeleteMessagesUseCase | undefined { return undefined; }
  getPinUseCase(): PinChatMessageUseCase | undefined { return undefined; }
  onPinnedMessageChanged(): void {}
  isSendingMessage(): boolean { return this.busy; }
  setSendingMessage(value: boolean): void { this.operation++; this.busy = value; }
  getSendOperationToken(): number { return this.operation; }
  hasActiveChatState(): boolean { return true; }
  getPendingAttachmentUris(): string[] { return []; }
  getDraftText(): string { return this.draft; }
  getComposerInputRevision(): number { return this.revision; }
  setDraftText(value: string): void { this.revision++; this.draft = value; }
  isNearBottom(): boolean { return false; }
  scrollToBottomSoon(): void {}
  setReplyMode(_id: string, _author: string, _preview: string, _quote: boolean): void {}
  clearReplyMode(): void {}
  setEditMode(id: string, text: string): void { this.editId = id; this.editOriginal = text; this.draft = text; }
  getEditingMessageId(): string { return this.editId; }
  getEditingOriginalText(): string { return this.editOriginal; }
  rebaseEditingMessage(id: string, text: string): void { this.editId = id; this.editOriginal = text; }
  clearEditMode(clearDraft: boolean): void { this.editId = '0'; if (clearDraft) this.draft = ''; }
  setForwardMode(ids: string[], sourceId: number, title: string, preview: string): void {
    const state = new ChatForwardModeState();
    state.isForwardingMessages = true;
    state.messageIds = ids.slice(); state.sourceChatId = sourceId; state.title = title; state.preview = preview;
    this.forward = state;
  }
  getForwardModeState(): ChatForwardModeState { return this.forward; }
  clearForwardMode(): void { this.forward = new ChatForwardModeState(); }
}

async function drainEligibility(): Promise<void> {
  await new Promise<void>((resolve) => { setTimeout(resolve, 0); });
}

function startCommentForward(host: EligibilityHost): void {
  host.setForwardMode([SERVER_ID], -12, 'source', 'preview');
  host.draft = 'comment';
  new ChatMessageActionsController().handleForwardMessages('comment', host);
}

export default function forwardEligibilityTest() {
  describe('ForwardEligibility', () => {
    it('server forward uses can_be_forwarded without requiring either copy flag', 0, async () => {
      const gateway = new EligibilityGateway([properties(true, false, false)]);
      const params = eligibilityParams(); params.removeCaption = true;
      await new ForwardMessagesUseCase(gateway).execute(params);
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties,forwardMessages');
      const sent = wireCommand(gateway, 2);
      expect(sent.getTopLevelBooleanStrict('send_copy')).assertEqual(false);
      expect(sent.getTopLevelBooleanStrict('remove_caption')).assertEqual(false);
    });

    it('server forward cannot substitute a granted copy flag for denied forwarding', 0, async () => {
      const gateway = new EligibilityGateway([properties(false, true, true)]);
      await assertDenied(gateway);
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties');
    });

    it('explicit server copy uses can_be_copied and preserves copy caption options', 0, async () => {
      const gateway = new EligibilityGateway([properties(false, true, false)]);
      const params = eligibilityParams(); params.sendCopy = true; params.removeCaption = true;
      await new ForwardMessagesUseCase(gateway).execute(params);
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties,forwardMessages');
      const sent = wireCommand(gateway, 2);
      expect(sent.getTopLevelBooleanStrict('send_copy')).assertEqual(true);
      expect(sent.getTopLevelBooleanStrict('remove_caption')).assertEqual(true);
    });

    it('explicit copy cannot substitute can_be_forwarded or secret-copy permission', 0, async () => {
      const gateway = new EligibilityGateway([properties(true, false, true)]);
      const params = eligibilityParams(); params.sendCopy = true;
      await assertDenied(gateway, params);
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties');
    });

    it('secret target forces secret-copy eligibility even when sendCopy is false', 0, async () => {
      const gateway = new EligibilityGateway([properties(false, false, true)]);
      gateway.target = TdObject.fromJSON('{"@type":"chat","id":7,"type":{"@type":"chatTypeSecret"}}');
      await new ForwardMessagesUseCase(gateway).execute(eligibilityParams());
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties,forwardMessages');
    });

    it('secret target rejects ordinary copy and forward grants without its own flag', 0, async () => {
      for (const sendCopy of [false, true]) {
        const gateway = new EligibilityGateway([properties(true, true, false)]);
        gateway.target = TdObject.fromJSON('{"@type":"chat","id":7,"type":{"@type":"chatTypeSecret"}}');
        const params = eligibilityParams(); params.sendCopy = sendCopy;
        await assertDenied(gateway, params);
        expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties');
      }
    });

    it('local ID forces can_be_copied even when sendCopy is false', 0, async () => {
      const gateway = new EligibilityGateway([properties(false, true, false)]);
      await new ForwardMessagesUseCase(gateway).execute(eligibilityParams([LOCAL_ID]));
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties,forwardMessages');
    });

    it('local ID cannot use can_be_forwarded instead of denied copy permission', 0, async () => {
      const gateway = new EligibilityGateway([properties(true, false, true)]);
      await assertDenied(gateway, eligibilityParams([LOCAL_ID]));
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties');
    });

    it('maximum server ID remains a server forward without 32-bit truncation', 0, async () => {
      const gateway = new EligibilityGateway([properties(true, false, false)]);
      await new ForwardMessagesUseCase(gateway).execute(eligibilityParams([MAX_SERVER_ID]));
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties,forwardMessages');
      const request = wireCommand(gateway, 1);
      expect(request.getTopLevelNumberStrict('message_id')).assertEqual(2251799812636672);
    });

    it('mixed server and local IDs use per-message flags in sorted distinct order', 0, async () => {
      const gateway = new EligibilityGateway([properties(true, false, false), properties(false, true, false)]);
      gateway.forwardResponse = TdObject.fromJSON('{"@type":"messages","messages":[{"@type":"message","id":9437184,"chat_id":7},{"@type":"message","id":10485760,"chat_id":7}]}');
      await new ForwardMessagesUseCase(gateway).execute(eligibilityParams([LOCAL_ID, SERVER_ID, LOCAL_ID]));
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties,getMessageProperties,forwardMessages');
      expect(wireCommand(gateway, 1).getTopLevelNumberStrict('message_id')).assertEqual(1048576);
      expect(wireCommand(gateway, 2).getTopLevelNumberStrict('message_id')).assertEqual(1048578);
      const sent = serializeCommand(gateway.commands[3]);
      expect(sent.params.getString('_message_ids_json')).assertEqual('[1048576,1048578]');
    });

    it('one denied source blocks the whole selection before any forward command', 0, async () => {
      const gateway = new EligibilityGateway([properties(true, false, false), properties(false, true, true)]);
      await assertDenied(gateway, eligibilityParams([SECOND_SERVER_ID, SERVER_ID]));
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties,getMessageProperties');
      expect(wireCommand(gateway, 2).getTopLevelNumberStrict('message_id')).assertEqual(2097152);
    });

    it('missing top-level flags cannot borrow nested grants in any dispatch mode', 0, async () => {
      await assertDeniedInEveryMode('{"@type":"messageProperties","nested":{"can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true}}');
    });

    it('explicit false flags win over nested true values in every dispatch mode', 0, async () => {
      await assertDeniedInEveryMode('{"@type":"messageProperties","nested":{"can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true},"can_be_forwarded":false,"can_be_copied":false,"can_be_copied_to_secret_chat":false}');
    });

    it('string numeric null object and array flag values never grant eligibility', 0, async () => {
      for (const value of ['"true"', '1', 'null', '{}', '[]']) {
        await assertDeniedInEveryMode(`{"@type":"messageProperties","can_be_forwarded":${value},` +
          `"can_be_copied":${value},"can_be_copied_to_secret_chat":${value}}`);
      }
    });

    it('malformed JSON cannot grant eligibility through legacy accessor fallback', 0, async () => {
      await assertDeniedInEveryMode('{"@type":"messageProperties","can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true');
    });

    it('wrong response identity with granted flags is not MessageProperties', 0, async () => {
      await assertDeniedInEveryMode('{"@type":"message","can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true}');
    });

    it('TDLib error responses cannot grant eligibility even with true flag fields', 0, async () => {
      await assertDeniedInEveryMode('{"@type":"error","code":404,"message":"Not found","can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true}');
    });

    it('rejected getMessageProperties stops before forward without fallback', 0, async () => {
      const gateway = new EligibilityGateway([]);
      const failure = new Error('Offline properties unavailable'); gateway.propertyError = failure;
      let rejected = false;
      try { await new ForwardMessagesUseCase(gateway).execute(eligibilityParams()); } catch (error) {
        rejected = error === failure;
      }
      expect(rejected).assertEqual(true);
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties');
    });

    it('untrusted target identity or type fails before source properties are read', 0, async () => {
      const targets: string[] = [
        '{"@type":"error","code":404,"message":"Not found"}',
        '{"@type":"chat","id":8,"type":{"@type":"chatTypePrivate"}}',
        '{"@type":"chat","id":"7","type":{"@type":"chatTypePrivate"}}',
        '{"@type":"chat","nested":{"id":7,"type":{"@type":"chatTypePrivate"}}}',
        '{"@type":"chat","id":7,"type":"chatTypePrivate"}',
        '{"@type":"chat","id":7,"type":{"@type":"unknown"}}'
      ];
      for (const target of targets) {
        const gateway = new EligibilityGateway([properties(true, true, true)]);
        gateway.target = TdObject.fromJSON(target);
        await assertDenied(gateway);
        expect(commandTypes(gateway)).assertEqual('getChat');
      }
    });

    it('cancelled capability prevents even the first offline read', 0, async () => {
      const gateway = new EligibilityGateway([properties(true, true, true)]);
      await assertDenied(gateway, eligibilityParams(), (): boolean => false);
      expect(gateway.commands.length).assertEqual(0);
    });

    it('cancellation while getChat is pending prevents all source reads and forward', 0, async () => {
      const gateway = new EligibilityGateway([properties(true, false, false)]);
      gateway.holdType = 'getChat'; let active = true;
      const pending = assertDenied(gateway, eligibilityParams(), (): boolean => active);
      await drainEligibility();
      expect(commandTypes(gateway)).assertEqual('getChat');
      expect(gateway.releaseHeld !== undefined).assertEqual(true);
      active = false; gateway.releaseHeld!();
      await pending;
      expect(commandTypes(gateway)).assertEqual('getChat');
    });

    it('cancellation during source preflight prevents the next source and forward', 0, async () => {
      const gateway = new EligibilityGateway([properties(true, false, false), properties(true, false, false)]);
      gateway.holdType = 'getMessageProperties'; let active = true;
      const pending = assertDenied(gateway, eligibilityParams([SERVER_ID, SECOND_SERVER_ID]), (): boolean => active);
      await drainEligibility();
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties');
      expect(gateway.releaseHeld !== undefined).assertEqual(true);
      active = false; gateway.releaseHeld!();
      await pending;
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties');
      expect(gateway.sourceProperties.length).assertEqual(1);
    });

    it('controller denies source before comment and restores the untouched intent', 0, async () => {
      const gateway = new EligibilityGateway([properties(false, true, true)]);
      const host = new EligibilityHost(gateway);
      startCommentForward(host); await drainEligibility();
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties');
      expect(host.busy).assertEqual(false); expect(host.draft).assertEqual('comment');
      expect(host.forward.isForwardingMessages).assertEqual(true);
      expect(host.forward.messageIds.join(',')).assertEqual(SERVER_ID);
      expect(host.forward.sourceChatId).assertEqual(-12);
    });

    it('controller granted source checks precede comment and are repeated before forward', 0, async () => {
      const gateway = new EligibilityGateway([properties(true, false, false), properties(true, false, false)]);
      const host = new EligibilityHost(gateway);
      startCommentForward(host); await drainEligibility();
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties,sendMessage,getChat,getMessageProperties,forwardMessages');
      expect(host.busy).assertEqual(false); expect(host.draft).assertEqual('');
      expect(host.forward.isForwardingMessages).assertEqual(false);
    });

    it('real commands serialize target chat and exact int53 source IDs independently', 0, async () => {
      const gateway = new EligibilityGateway([properties(true, false, false)]);
      await new ForwardMessagesUseCase(gateway).execute(eligibilityParams([MAX_SERVER_ID]));
      expect(commandTypes(gateway)).assertEqual('getChat,getMessageProperties,forwardMessages');
      expect(wireCommand(gateway, 0).getTopLevelNumberStrict('chat_id')).assertEqual(7);
      const source = wireCommand(gateway, 1);
      expect(source.getTopLevelStringStrict('@type')).assertEqual('getMessageProperties');
      expect(source.getTopLevelNumberStrict('chat_id')).assertEqual(-12);
      expect(source.getTopLevelNumberStrict('message_id')).assertEqual(2251799812636672);
      const sent = serializeCommand(gateway.commands[2]);
      expect(sent.params.getString('_message_ids_json')).assertEqual('[2251799812636672]');
      expect(wireCommand(gateway, 2).getTopLevelNumberStrict('chat_id')).assertEqual(7);
      expect(wireCommand(gateway, 2).getTopLevelNumberStrict('from_chat_id')).assertEqual(-12);
    });
  });
}
