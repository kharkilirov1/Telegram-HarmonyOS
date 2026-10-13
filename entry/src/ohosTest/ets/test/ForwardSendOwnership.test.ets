import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand, GetChatCommand, GetMessagePropertiesCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { SendMessageUseCase } from '../../../main/ets/domain/usecases/sendMessage';
import { ForwardMessagesUseCase } from '../../../main/ets/domain/usecases/forwardMessages';
import { EditMessageUseCase } from '../../../main/ets/domain/usecases/editMessage';
import { DeleteMessagesUseCase } from '../../../main/ets/domain/usecases/deleteMessages';
import { PinChatMessageUseCase } from '../../../main/ets/domain/usecases/pinChatMessage';
import { ChatMessageActionsController, ChatMessageActionsHost, ChatForwardModeState } from '../../../main/ets/ui/pages/chat/ChatMessageActionsController';
import { ChatScreenRouteParams } from '../../../main/ets/ui/pages/chat/ChatScreenRouteParams';

class ForwardRequest {
  command: AnyAppCommand;
  resolve?: (value: Object) => void;
  reject?: (reason: Error) => void;
  constructor(command: AnyAppCommand) { this.command = command; }
}

class ForwardGateway implements TdGatewayPort {
  trace: AnyAppCommand[] = [];
  // Deferred mutating commands only; reads are recorded separately in trace.
  requests: ForwardRequest[] = [];
  async initialize(): Promise<void> {}
  async destroy(): Promise<void> {}
  getConnectionState(): 'ready' { return 'ready'; }
  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void { return (): void => {}; }
  send(command: AnyAppCommand): Promise<Object> {
    this.trace.push(command);
    if (command.type === 'getChat') {
      const target = command as GetChatCommand;
      return Promise.resolve(TdObject.fromJSON(`{"@type":"chat","id":${target.payload.chatId},"type":{"@type":"chatTypeSupergroup"}}`));
    }
    if (command.type === 'getMessageProperties') {
      return Promise.resolve(TdObject.fromJSON('{"@type":"messageProperties","can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true}'));
    }
    const request = new ForwardRequest(command);
    this.requests.push(request);
    return new Promise<Object>((resolve, reject) => { request.resolve = resolve; request.reject = reject; });
  }
}

// Controller contract fixture. The actual page counter/scoped store and
// cross-controller text/media flows are exercised by the companion host harness.
class ForwardHost implements ChatMessageActionsHost {
  gateway: ForwardGateway = new ForwardGateway();
  sender: SendMessageUseCase = new SendMessageUseCase(this.gateway);
  forwarder: ForwardMessagesUseCase = new ForwardMessagesUseCase(this.gateway);
  busy: boolean = false;
  operation: number = 0;
  allowForward: boolean = true;
  allowText: boolean = true;
  activeAccount: boolean = true;
  draft: string = '';
  revision: number = 0;
  editId: string = '0';
  editOriginal: string = '';
  forward: ChatForwardModeState = new ChatForwardModeState();
  getActiveChatId(): number { return -100123; }
  getChatRouteToken(): number { return 0; }
  getLifecycleToken(): number { return 1; }
  canSendNewMessages(kind?: string): boolean { return this.activeAccount && this.editId === '0' && (kind === 'text' ? this.allowText : this.allowForward); }
  getChatUIContext(): UIContext { throw new Error('UI is outside this fixture'); }
  bindNavigationStack(): NavPathStack | undefined { return undefined; }
  createChatRouteParams(_chatId: number, _title: string): ChatScreenRouteParams | undefined { return undefined; }
  getSendUseCase(): SendMessageUseCase | undefined { return this.activeAccount && this.allowText ? this.sender : undefined; }
  getForwardUseCase(): ForwardMessagesUseCase | undefined { return this.activeAccount && this.allowForward && this.editId === '0' ? this.forwarder : undefined; }
  getSourceForwardUseCase(): ForwardMessagesUseCase | undefined { return this.hasActiveChatState() ? this.forwarder : undefined; }
  getEditUseCase(): EditMessageUseCase | undefined { return undefined; }
  getDeleteUseCase(): DeleteMessagesUseCase | undefined { return undefined; }
  getPinUseCase(): PinChatMessageUseCase | undefined { return undefined; }
  onPinnedMessageChanged(): void {}
  isSendingMessage(): boolean { return this.busy; }
  setSendingMessage(value: boolean): void { this.operation++; this.busy = value; }
  getSendOperationToken(): number { return this.operation; }
  hasActiveChatState(): boolean { return this.activeAccount; }
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

async function drainForward(): Promise<void> {
  await new Promise<void>((resolve) => { setTimeout(resolve, 0); });
}

function startForward(host: ForwardHost, controller: ChatMessageActionsController, comment: string = ''): void {
  host.setForwardMode(['31'], 88, 'Forward fixture', 'Preview');
  host.draft = comment;
  controller.handleForwardMessages(comment, host);
}

export default function forwardSendOwnershipTest() {
  describe('ForwardSendOwnership', () => {
    it('preflights before sending a comment or clearing the draft', 0, async () => {
      const host = new ForwardHost(); const controller = new ChatMessageActionsController();
      host.setForwardMode(['2,3'], 88, 'source', 'preview'); host.draft = 'comment';
      controller.handleForwardMessages('comment', host); await drainForward();
      expect(host.gateway.requests.length).assertEqual(0); expect(host.draft).assertEqual('comment');
      expect(host.gateway.trace.length).assertEqual(0);
      expect(host.forward.isForwardingMessages).assertEqual(true); expect(host.busy).assertEqual(false);
    });
    it('restores only the null result slot, not the accepted forward', 0, async () => {
      const host = new ForwardHost(); const controller = new ChatMessageActionsController();
      host.setForwardMode(['100', '2'], 88, 'source', 'preview');
      controller.handleForwardMessages('', host); await drainForward();
      expect(host.gateway.requests.length).assertEqual(1);
      expect(host.gateway.requests[0].command.type).assertEqual('forwardMessages');
      expect(host.gateway.trace.map((command: AnyAppCommand): string => command.type).join(',')).assertEqual(
        'getChat,getMessageProperties,getMessageProperties,getChat,getMessageProperties,getMessageProperties,forwardMessages');
      expect((host.gateway.trace[1] as GetMessagePropertiesCommand).payload.chatId).assertEqual(88);
      expect((host.gateway.trace[1] as GetMessagePropertiesCommand).payload.messageId).assertEqual('2');
      expect((host.gateway.trace[2] as GetMessagePropertiesCommand).payload.messageId).assertEqual('100');
      host.gateway.requests[0].resolve!(TdObject.fromJSON('{"@type":"messages","messages":[{"@type":"message","id":900,"chat_id":-100123},null]}'));
      await drainForward();
      expect(host.forward.messageIds.join(',')).assertEqual('100'); expect(host.busy).assertEqual(false);
    });
    it('revalidates before deferred dispatch and releases its busy state after revoke', 0, async () => {
      const host = new ForwardHost();
      startForward(host, new ChatMessageActionsController(), 'comment');
      host.allowForward = false;
      await drainForward();
      expect(host.gateway.requests.length).assertEqual(0);
      expect(host.gateway.trace.length).assertEqual(0);
      expect(host.busy).assertEqual(false);
      expect(host.draft).assertEqual('comment');
      expect(host.forward.isForwardingMessages).assertEqual(true);
    });

    it('does not forward after comment await loses permission or retry the sent comment', 0, async () => {
      const host = new ForwardHost();
      startForward(host, new ChatMessageActionsController(), 'comment');
      await drainForward();
      expect(host.gateway.requests.length).assertEqual(1);
      expect(host.gateway.requests[0].command.type).assertEqual('sendMessage');
      expect(host.gateway.trace.map((command: AnyAppCommand): string => command.type).join(',')).assertEqual(
        'getChat,getMessageProperties,sendMessage');
      expect((host.gateway.trace[0] as GetChatCommand).payload.chatId).assertEqual(-100123);
      expect((host.gateway.trace[1] as GetMessagePropertiesCommand).payload.chatId).assertEqual(88);
      expect((host.gateway.trace[1] as GetMessagePropertiesCommand).payload.messageId).assertEqual('31');
      host.allowForward = false;
      host.gateway.requests[0].resolve!(TdObject.fromJSON('{"@type":"message","id":900,"chat_id":-100123}'));
      await drainForward();
      expect(host.gateway.requests.length).assertEqual(1);
      expect(host.busy).assertEqual(false);
      expect(host.gateway.trace.length).assertEqual(3);
      expect(host.draft).assertEqual('');
      expect(host.forward.isForwardingMessages).assertEqual(true);
    });

    it('does not silently omit a required comment', 0, async () => {
      const host = new ForwardHost(); host.allowText = false;
      startForward(host, new ChatMessageActionsController(), 'required comment');
      await drainForward();
      expect(host.gateway.requests.length).assertEqual(0);
      expect(host.gateway.trace.length).assertEqual(0);
      expect(host.draft).assertEqual('required comment');
      expect(host.busy).assertEqual(false);
      expect(host.forward.isForwardingMessages).assertEqual(true);
    });

    it('old finally cannot release a newer send owner', 0, async () => {
      const host = new ForwardHost();
      startForward(host, new ChatMessageActionsController());
      await drainForward();
      host.setSendingMessage(false); host.setSendingMessage(true);
      host.gateway.requests[0].resolve!(TdObject.fromJSON('{"@type":"messages","messages":[{"@type":"message","id":900,"chat_id":-100123}]}'));
      await drainForward();
      expect(host.busy).assertEqual(true);
      host.setSendingMessage(false);
    });

    it('failure never restores a prior account buffer', 0, async () => {
      const host = new ForwardHost();
      startForward(host, new ChatMessageActionsController(), 'account A comment');
      await drainForward(); host.activeAccount = false;
      host.gateway.requests[0].reject!(new Error('fixture failure'));
      await drainForward();
      expect(host.busy).assertEqual(false);
      expect(host.draft).assertEqual('');
      expect(host.forward.isForwardingMessages).assertEqual(false);
    });

    it('failure leaves a newer edit intact while releasing old busy', 0, async () => {
      const host = new ForwardHost();
      startForward(host, new ChatMessageActionsController());
      await drainForward(); host.setEditMode('5', 'new edit');
      host.gateway.requests[0].reject!(new Error('fixture failure'));
      await drainForward();
      expect(host.busy).assertEqual(false);
      expect(host.draft).assertEqual('new edit');
      expect(host.editId).assertEqual('5');
      expect(host.forward.isForwardingMessages).assertEqual(false);
    });
  });
}
