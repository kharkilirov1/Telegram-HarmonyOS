import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand, CustomEmojiTextEntity, GetChatCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { AppError, AppErrorKind, classifyTdlibError } from '../../../main/ets/core/model/AppError';
import { createInitialAppState, Message } from '../../../main/ets/core/model/AppState';
import { messagesReducer } from '../../../main/ets/core/reducers/messagesReducer';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { SendMessageUseCase, SendMessageParams } from '../../../main/ets/domain/usecases/sendMessage';
import { SendMediaMessageUseCase, SendMediaMessageParams } from '../../../main/ets/domain/usecases/sendMediaMessage';
import { SendMediaAlbumUseCase, SendMediaAlbumParams } from '../../../main/ets/domain/usecases/sendMediaAlbum';
import { ForwardMessagesUseCase, ForwardMessagesParams } from '../../../main/ets/domain/usecases/forwardMessages';
import { ChatMessageActionsController, ChatMessageActionsHost, ChatForwardModeState } from '../../../main/ets/ui/pages/chat/ChatMessageActionsController';
import { ChatComposerController, ChatComposerControllerHost } from '../../../main/ets/ui/pages/chat/ChatComposerController';
import { ChatScreenRouteParams } from '../../../main/ets/ui/pages/chat/ChatScreenRouteParams';
import { EditMessageUseCase } from '../../../main/ets/domain/usecases/editMessage';
import { DeleteMessagesUseCase } from '../../../main/ets/domain/usecases/deleteMessages';
import { PinChatMessageUseCase } from '../../../main/ets/domain/usecases/pinChatMessage';
import { registerMessageHandlers } from '../../../main/ets/core/events/normalizers/MessageNormalizer';
import { MessageSendFailedEvent } from '../../../main/ets/core/model/AppEvent';

// Only the TDLib transport and presentation boundary are controlled. Every
// tested classification, validation, use case and controller is actual code.
export class WriteRequest {
  command: AnyAppCommand;
  resolve?: (value: Object) => void;
  reject?: (reason: Object) => void;
  constructor(command: AnyAppCommand) { this.command = command; }
}
export class WriteGateway implements TdGatewayPort {
  trace: AnyAppCommand[] = [];
  requests: WriteRequest[] = [];
  readError?: AppError;
  async initialize(): Promise<void> {}
  async destroy(): Promise<void> {}
  getConnectionState(): 'ready' { return 'ready'; }
  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void { return (): void => {}; }
  send(command: AnyAppCommand): Promise<Object> {
    this.trace.push(command);
    if (command.type === 'getChat' || command.type === 'getMessageProperties') {
      if (this.readError !== undefined) return Promise.reject(this.readError);
      if (command.type === 'getChat') return Promise.resolve(TdObject.fromJSON(
        `{"@type":"chat","id":${(command as GetChatCommand).payload.chatId},"type":{"@type":"chatTypePrivate"}}`));
      return Promise.resolve(TdObject.fromJSON('{"@type":"messageProperties","can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true}'));
    }
    const request = new WriteRequest(command); this.requests.push(request);
    return new Promise<Object>((resolve, reject) => { request.resolve = resolve; request.reject = reject; });
  }
}
export class WriteHost implements ChatMessageActionsHost, ChatComposerControllerHost {
  gateway: WriteGateway = new WriteGateway();
  sender: SendMessageUseCase = new SendMessageUseCase(this.gateway);
  media: SendMediaMessageUseCase = new SendMediaMessageUseCase(this.gateway);
  forwarder: ForwardMessagesUseCase = new ForwardMessagesUseCase(this.gateway);
  chatId: number = 42;
  lifecycle: number = 1;
  active: boolean = true;
  allowed: boolean = true;
  busy: boolean = false;
  operation: number = 0;
  revision: number = 0;
  draft: string = '';
  entities: CustomEmojiTextEntity[] = [];
  reply: string = '0';
  selectionStart: number = 0;
  selectionEnd: number = 0;
  editId: string = '0';
  attachments: string[] = [];
  forward: ChatForwardModeState = new ChatForwardModeState();
  contextRequests: number = 0;
  scrolls: number = 0;
  emoji: boolean = false;
  getActiveChatId(): number { return this.chatId; }
  getChatRouteToken(): number { return 0; }
  getLifecycleToken(): number { return this.lifecycle; }
  canSendNewMessages(_kind?: string): boolean { return this.active && this.allowed && this.editId === '0'; }
  getChatUIContext(): UIContext { this.contextRequests++; throw new Error('Presentation is outside this native callback'); }
  bindNavigationStack(): NavPathStack | undefined { return undefined; }
  createChatRouteParams(_id: number, _title: string): ChatScreenRouteParams | undefined { return undefined; }
  getSendUseCase(): SendMessageUseCase | undefined { return this.active && this.allowed && this.editId === '0' ? this.sender : undefined; }
  getSendMediaUseCase(_kind?: string): SendMediaMessageUseCase | undefined { return this.active && this.allowed ? this.media : undefined; }
  getForwardUseCase(_source?: number, _ids?: string[]): ForwardMessagesUseCase | undefined { return this.active && this.allowed && this.editId === '0' ? this.forwarder : undefined; }
  getSourceForwardUseCase(): ForwardMessagesUseCase | undefined { return this.active ? this.forwarder : undefined; }
  getEditUseCase(): EditMessageUseCase | undefined { return undefined; }
  getDeleteUseCase(): DeleteMessagesUseCase | undefined { return undefined; }
  getPinUseCase(): PinChatMessageUseCase | undefined { return undefined; }
  onPinnedMessageChanged(): void {}
  isSendingMessage(): boolean { return this.busy; }
  setSendingMessage(value: boolean): void { this.operation++; this.busy = value; }
  getSendOperationToken(): number { return this.operation; }
  getComposerInputRevision(): number { return this.revision; }
  hasActiveChatState(): boolean { return this.active; }
  isEditModeActive(): boolean { return this.editId !== '0'; }
  isForwardModeActive(): boolean { return this.forward.isForwardingMessages; }
  submitEditMessage(_text: string): void {}
  submitForwardMessages(_text: string): void {}
  getDraftText(): string { return this.draft; }
  setDraftText(value: string): void { this.revision++; this.draft = value; }
  getDraftSelectionStart(): number { return this.selectionStart; }
  getDraftSelectionEnd(): number { return this.selectionEnd; }
  setDraftSelection(start: number, end: number): void { this.selectionStart = start; this.selectionEnd = end; }
  getCustomEmojiEntities(): CustomEmojiTextEntity[] { return this.entities; }
  setCustomEmojiEntities(value: CustomEmojiTextEntity[]): void { this.entities = value.slice(); }
  setEmojiPanelVisible(value: boolean): void { this.emoji = value; }
  getEmojiPanelVisible(): boolean { return this.emoji; }
  getReplyToMessageId(): string { return this.reply; }
  clearReplyMode(): void { this.reply = '0'; }
  getPendingAttachmentUris(): string[] { return this.attachments; }
  getPendingAttachmentKind(): string { return 'document'; }
  setPendingAttachmentState(_kind: string, _title: string, _preview: string, uris: string[]): void { this.attachments = uris.slice(); }
  clearPendingAttachmentState(): void { this.attachments = []; }
  isNearBottom(): boolean { return true; }
  scrollToBottomSoon(): void { this.scrolls++; }
  setReplyMode(id: string, _author: string, _preview: string, _quote: boolean): void { this.reply = id; }
  setEditMode(id: string, text: string, _allowEmpty?: boolean): void { this.editId = id; this.setDraftText(text); }
  getEditingMessageId(): string { return this.editId; }
  getEditingOriginalText(): string { return this.draft; }
  rebaseEditingMessage(id: string, originalText: string): void { this.editId = id; this.setDraftText(originalText); }
  clearEditMode(clearDraft: boolean): void { this.editId = '0'; if (clearDraft) this.setDraftText(''); }
  setForwardMode(ids: string[], source: number, title: string, preview: string): void {
    const value = new ChatForwardModeState(); value.isForwardingMessages = true; value.messageIds = ids.slice();
    value.sourceChatId = source; value.title = title; value.preview = preview; this.forward = value;
  }
  getForwardModeState(): ChatForwardModeState { return this.forward; }
  clearForwardMode(): void { this.forward = new ChatForwardModeState(); }
}
export async function settleWrites(): Promise<void> {
  await new Promise<void>((resolve) => { setTimeout(() => resolve(), 0); });
}
async function rejection(promise: Promise<void>): Promise<AppError> {
  try { await promise; } catch (error) { expect(error instanceof AppError).assertTrue(); return error as AppError; }
  throw new Error('Expected typed rejection');
}
function forwardParams(): ForwardMessagesParams {
  const value = new ForwardMessagesParams(); value.chatId = 42; value.fromChatId = 88; value.messageIds = ['2', '10']; return value;
}
function beginForward(host: WriteHost, controller: ChatMessageActionsController, comment: string = ''): void {
  host.setForwardMode(['2', '10'], 88, 'source title', 'source preview'); host.setDraftText(comment);
  controller.handleForwardMessages(comment, host);
}
export default function writePathErrorsTest() {
  describe('WritePathErrors', () => {
    for (const code of [400, 401, 403, 429, 503]) {
      for (const kind of ['text', 'media', 'album', 'forward']) {
        it(kind + ' preserves definitive TDLib cause ' + code, 0, async () => {
          const gateway = new WriteGateway(); const original = classifyTdlibError(code, code === 429 ? 'FLOOD_WAIT_37' : 'CAUSE_SECRET_' + code);
          let promise: Promise<void>;
          if (kind === 'text') { const p = new SendMessageParams(); p.chatId = 42; p.text = 'text'; promise = new SendMessageUseCase(gateway).execute(p); }
          else if (kind === 'media') { const p = new SendMediaMessageParams(); p.chatId = 42; p.localPath = '/fixture/local'; promise = new SendMediaMessageUseCase(gateway).execute(p); }
          else if (kind === 'album') { const p = new SendMediaAlbumParams(); p.chatId = 42; p.localPaths = ['/fixture/one', '/fixture/two']; promise = new SendMediaAlbumUseCase(gateway).execute(p); }
          else promise = new ForwardMessagesUseCase(gateway).execute(forwardParams());
          await settleWrites(); expect(gateway.requests.length).assertEqual(1);
          gateway.requests[0].reject!(original); const actual = await rejection(promise);
          expect(actual.kind).assertEqual(original.kind); expect(actual.userMessage).assertEqual(original.userMessage);
          expect(actual.tdlibCode).assertEqual(code); expect(actual.technicalMessage).assertEqual(original.technicalMessage);
          expect(actual.retryable).assertEqual(original.retryable); expect(gateway.requests.length).assertEqual(1);
        });
      }
    }
    for (const detail of ['SILENT_SECRET', 'FLOOD_WAIT_99', 'TDLIB_INIT_TIMEOUT silent', '']) {
      it('406 discards payload before any classification ' + detail, 0, () => {
        const error = classifyTdlibError(406, detail); expect(error.tdlibCode).assertEqual(406);
        expect(error.userMessage).assertEqual(''); expect(error.message).assertEqual('');
        expect(error.technicalMessage).assertEqual(''); expect(error.retryable).assertFalse();
      });
    }
    for (const kind of ['text', 'media', 'album', 'forward']) {
      it(kind + ' preserves silent 406 through usecase', 0, async () => {
        const gateway = new WriteGateway(); const original = classifyTdlibError(406, 'FLOOD_WAIT_99 SILENT_SECRET');
        let promise: Promise<void>;
        if (kind === 'text') { const p = new SendMessageParams(); p.chatId = 42; p.text = 'text'; promise = new SendMessageUseCase(gateway).execute(p); }
        else if (kind === 'media') { const p = new SendMediaMessageParams(); p.chatId = 42; p.localPath = '/fixture/local'; promise = new SendMediaMessageUseCase(gateway).execute(p); }
        else if (kind === 'album') { const p = new SendMediaAlbumParams(); p.chatId = 42; p.localPaths = ['/fixture/one', '/fixture/two']; promise = new SendMediaAlbumUseCase(gateway).execute(p); }
        else promise = new ForwardMessagesUseCase(gateway).execute(forwardParams());
        await settleWrites(); gateway.requests[0].reject!(original); const actual = await rejection(promise);
        expect(actual.tdlibCode).assertEqual(406); expect(actual.userMessage).assertEqual(''); expect(actual.technicalMessage).assertEqual('');
        expect(actual.retryable).assertFalse(); expect(gateway.requests.length).assertEqual(1);
      });
    }
    for (const kind of ['text', 'media']) {
      for (const wire of ['{}', '{"@type":"ok"}', '{"@type":"message","id":900,"chat_id":43}',
        '{"@type":"message","id":0,"chat_id":42}', '{"@type":"message","id":1.5,"chat_id":42}',
        '{"nested":{"@type":"message","id":900,"chat_id":42}}']) {
        it(kind + ' malformed fulfilled Message remains uncertain ' + wire, 0, async () => {
          const gateway = new WriteGateway(); let promise: Promise<void>;
          if (kind === 'text') { const p = new SendMessageParams(); p.chatId = 42; p.text = 'text'; promise = new SendMessageUseCase(gateway).execute(p); }
          else { const p = new SendMediaMessageParams(); p.chatId = 42; p.localPath = '/fixture/local'; promise = new SendMediaMessageUseCase(gateway).execute(p); }
          await settleWrites(); gateway.requests[0].resolve!(TdObject.fromJSON(wire));
          let rejected = false; try { await promise; } catch (error) { rejected = error instanceof AppError; }
          expect(rejected).assertTrue(); expect(gateway.requests.length).assertEqual(1);
        });
      }
      it(kind + ' accepts matching positive Message without claiming delivery', 0, async () => {
        const gateway = new WriteGateway(); let promise: Promise<void>;
        if (kind === 'text') { const p = new SendMessageParams(); p.chatId = 42; p.text = 'text'; promise = new SendMessageUseCase(gateway).execute(p); }
        else { const p = new SendMediaMessageParams(); p.chatId = 42; p.localPath = '/fixture/local'; promise = new SendMediaMessageUseCase(gateway).execute(p); }
        await settleWrites(); gateway.requests[0].resolve!(TdObject.fromJSON('{"@type":"message","id":900,"chat_id":42}'));
        await promise; expect(gateway.requests.length).assertEqual(1);
      });
    }
    it('shared typed transport cause remains unchanged after mutating catch', 0, async () => {
      const gateway = new WriteGateway(); const original = new AppError(AppErrorKind.NETWORK, 'transport issue', 'original detail', 400, true);
      const before = JSON.stringify(original); const p = new SendMessageParams(); p.chatId = 42; p.text = 'text';
      const promise = new SendMessageUseCase(gateway).execute(p); gateway.requests[0].reject!(original); const actual = await rejection(promise);
      expect(JSON.stringify(original)).assertEqual(before); expect(actual.kind).assertEqual(AppErrorKind.NETWORK);
      expect(actual.technicalMessage).assertEqual('original detail'); expect(actual.tdlibCode).assertEqual(400); expect(actual.retryable).assertTrue();
    });
    it('fabricated positive TDLib code does not make unknown transport safe to replay', 0, async () => {
      const host = new WriteHost(); const controller = new ChatMessageActionsController(); beginForward(host, controller); await settleWrites();
      host.gateway.requests[0].reject!(new AppError(AppErrorKind.NETWORK, 'timeout', 'transport body', 400, true)); await settleWrites();
      expect(host.forward.isForwardingMessages).assertFalse(); expect(host.gateway.requests.length).assertEqual(1); expect(host.busy).assertFalse();
    });
    for (const phase of ['comment', 'forward']) {
      it('unknown ' + phase + ' outcome never restores a repeatable forward selection', 0, async () => {
        const host = new WriteHost(); const controller = new ChatMessageActionsController();
        beginForward(host, controller, phase === 'comment' ? 'ambiguous comment' : ''); await settleWrites();
        expect(host.gateway.requests.length).assertEqual(1);
        expect(host.gateway.requests[0].command.type).assertEqual(phase === 'comment' ? 'sendMessage' : 'forwardMessages');
        host.gateway.requests[0].reject!(new Error('Synthetic transport timeout')); await settleWrites();
        expect(host.forward.isForwardingMessages).assertFalse(); expect(host.draft).assertEqual(''); expect(host.busy).assertFalse();
        controller.handleForwardMessages('', host); await settleWrites(); expect(host.gateway.requests.length).assertEqual(1);
      });
      it('silent ' + phase + ' failure releases busy without feedback or automatic retry', 0, async () => {
        const host = new WriteHost(); const controller = new ChatMessageActionsController();
        beginForward(host, controller, phase === 'comment' ? 'comment' : ''); await settleWrites();
        host.gateway.requests[0].reject!(classifyTdlibError(406, 'SILENT_SECRET')); await settleWrites();
        expect(host.contextRequests).assertEqual(0); expect(host.busy).assertFalse();
        expect(host.forward.messageIds.join(',')).assertEqual('2,10'); expect(host.draft).assertEqual(phase === 'comment' ? 'comment' : '');
        expect(host.gateway.requests.length).assertEqual(1); expect(host.scrolls).assertEqual(0);
      });
    }
    it('definitive rejected comment restores unsent intent and never forwards', 0, async () => {
      const host = new WriteHost(); const controller = new ChatMessageActionsController(); beginForward(host, controller, 'unsent comment'); await settleWrites();
      host.gateway.requests[0].reject!(classifyTdlibError(400, 'CHAT_WRITE_FORBIDDEN')); await settleWrites();
      expect(host.busy).assertFalse(); expect(host.forward.messageIds.join(',')).assertEqual('2,10');
      expect(host.draft).assertEqual('unsent comment'); expect(host.gateway.requests.length).assertEqual(1);
    });
    it('forward rejection after accepted comment restores only forward intent', 0, async () => {
      const host = new WriteHost(); const controller = new ChatMessageActionsController(); beginForward(host, controller, 'accepted comment'); await settleWrites();
      host.gateway.requests[0].resolve!(TdObject.fromJSON('{"@type":"message","id":900,"chat_id":42}')); await settleWrites();
      expect(host.gateway.requests.length).assertEqual(2); host.gateway.requests[1].reject!(classifyTdlibError(400, 'CHAT_WRITE_FORBIDDEN')); await settleWrites();
      expect(host.busy).assertFalse(); expect(host.forward.messageIds.join(',')).assertEqual('2,10'); expect(host.draft).assertEqual('');
    });
    for (const boundary of ['account', 'lifecycle', 'new-operation', 'edit', 'new-draft']) {
      it('unknown failure preserves newer composer owner ' + boundary, 0, async () => {
        const host = new WriteHost(); const controller = new ChatMessageActionsController(); beginForward(host, controller, 'old comment'); await settleWrites();
        if (boundary === 'account') host.active = false;
        if (boundary === 'lifecycle') host.lifecycle++;
        if (boundary === 'new-operation') host.setSendingMessage(true);
        if (boundary === 'edit') host.setEditMode('90', 'new edit');
        if (boundary === 'new-draft') host.setDraftText('new draft');
        const beforeContext = host.contextRequests; host.gateway.requests[0].reject!(new Error('Synthetic timeout')); await settleWrites();
        expect(host.forward.isForwardingMessages).assertFalse();
        if (boundary === 'edit') expect(host.draft).assertEqual('new edit');
        if (boundary === 'new-draft') expect(host.draft).assertEqual('new draft');
        if (boundary === 'new-operation' || boundary === 'lifecycle') { expect(host.busy).assertTrue(); expect(host.contextRequests).assertEqual(beforeContext); }
        else expect(host.busy).assertFalse();
      });
    }
    it('forward cancellation before deferred reads sends no comment or forward', 0, async () => {
      const host = new WriteHost(); const controller = new ChatMessageActionsController(); beginForward(host, controller, 'comment');
      host.lifecycle++; host.setSendingMessage(false); controller.cancelForwardMessages(host); await settleWrites();
      expect(host.gateway.trace.length).assertEqual(0); expect(host.gateway.requests.length).assertEqual(0); expect(host.busy).assertFalse();
    });
    it('silent text outcome preserves untouched buffer without success scrolling', 0, async () => {
      const host = new WriteHost(); const controller = new ChatComposerController(); host.setDraftText('silent unsent text');
      controller.handleSendMessage(host.draft, host); await settleWrites(); host.gateway.requests[0].reject!(classifyTdlibError(406, 'SILENT_SECRET')); await settleWrites();
      expect(host.busy).assertFalse(); expect(host.draft).assertEqual('silent unsent text'); expect(host.scrolls).assertEqual(0);
      expect(host.contextRequests).assertEqual(0); expect(host.gateway.requests.length).assertEqual(1);
    });
    it('definitive text rejection restores entities and selection with original reply', 0, async () => {
      const host = new WriteHost(); const controller = new ChatComposerController(); host.setDraftText('\uD83D\uDE00 unsent');
      host.entities = [new CustomEmojiTextEntity(0, 2, '123')]; host.reply = '55'; host.selectionStart = 3; host.selectionEnd = 5;
      controller.handleSendMessage(host.draft, host); await settleWrites(); expect(host.draft).assertEqual('');
      host.gateway.requests[0].reject!(classifyTdlibError(400, 'CHAT_WRITE_FORBIDDEN')); await settleWrites();
      expect(host.draft).assertEqual('\uD83D\uDE00 unsent'); expect(host.entities.length).assertEqual(1); expect(host.entities[0].customEmojiId).assertEqual('123');
      expect(host.reply).assertEqual('55'); expect(host.selectionStart).assertEqual(3); expect(host.selectionEnd).assertEqual(5); expect(host.busy).assertFalse();
    });
    it('trimmed text rejection restores raw whitespace draft and original emoji offsets', 0, async () => {
      const host = new WriteHost(); const controller = new ChatComposerController(); host.setDraftText('  \uD83D\uDE00 unsent  ');
      host.entities = [new CustomEmojiTextEntity(2, 2, '123')]; host.reply = '55'; host.selectionStart = 4; host.selectionEnd = 8;
      controller.handleSendMessage(host.draft.trim(), host); await settleWrites();
      host.gateway.requests[0].reject!(classifyTdlibError(400, 'CHAT_WRITE_FORBIDDEN')); await settleWrites();
      expect(host.draft).assertEqual('  \uD83D\uDE00 unsent  '); expect(host.entities.length).assertEqual(1);
      expect(host.entities[0].offset).assertEqual(2); expect(host.selectionStart).assertEqual(4); expect(host.selectionEnd).assertEqual(8);
      expect(host.reply).assertEqual('55'); expect(host.busy).assertFalse();
    });
    it('accepted text clears only its unchanged reply and follows bottom intent', 0, async () => {
      const host = new WriteHost(); const controller = new ChatComposerController(); host.setDraftText('accepted'); host.reply = '55';
      controller.handleSendMessage(host.draft, host); await settleWrites();
      host.gateway.requests[0].resolve!(TdObject.fromJSON('{"@type":"message","id":900,"chat_id":42}')); await settleWrites();
      expect(host.reply).assertEqual('0'); expect(host.draft).assertEqual(''); expect(host.scrolls).assertEqual(1); expect(host.busy).assertFalse();
    });
    for (const outcome of ['reject', 'resolve']) {
      it('text completion preserves newer draft and reply ' + outcome, 0, async () => {
        const host = new WriteHost(); const controller = new ChatComposerController(); host.setDraftText('old'); host.reply = '55';
        controller.handleSendMessage(host.draft, host); await settleWrites(); host.setDraftText('new'); host.reply = '66';
        if (outcome === 'reject') host.gateway.requests[0].reject!(classifyTdlibError(400, 'CHAT_WRITE_FORBIDDEN'));
        else host.gateway.requests[0].resolve!(TdObject.fromJSON('{"@type":"message","id":900,"chat_id":42}'));
        await settleWrites(); expect(host.draft).assertEqual('new'); expect(host.reply).assertEqual('66'); expect(host.busy).assertFalse();
      });
    }
    it('typing then clearing newer text prevents old failure restoration', 0, async () => {
      const host = new WriteHost(); const controller = new ChatComposerController(); host.setDraftText('old text');
      controller.handleSendMessage(host.draft, host); await settleWrites(); host.setDraftText('new temporary text'); host.setDraftText('');
      host.gateway.requests[0].reject!(classifyTdlibError(400, 'CHAT_WRITE_FORBIDDEN')); await settleWrites();
      expect(host.draft).assertEqual(''); expect(host.entities.length).assertEqual(0); expect(host.busy).assertFalse();
    });
    it('unknown text outcome cannot replay when confirmation presentation fails', 0, async () => {
      const host = new WriteHost(); const controller = new ChatComposerController(); host.setDraftText('ambiguous text'); host.reply = '55';
      controller.handleSendMessage(host.draft, host); await settleWrites(); host.gateway.requests[0].reject!(new Error('Synthetic timeout')); await settleWrites();
      expect(host.draft).assertEqual('ambiguous text'); expect(host.reply).assertEqual('55'); expect(host.busy).assertFalse();
      controller.handleSendMessage(host.draft, host); await settleWrites(); expect(host.gateway.requests.length).assertEqual(1); expect(host.busy).assertFalse();
    });
    it('definitive text rejection permits an ordinary fresh tap without uncertain confirmation', 0, async () => {
      const host = new WriteHost(); const controller = new ChatComposerController(); host.setDraftText('known rejected text');
      controller.handleSendMessage(host.draft, host); await settleWrites(); host.gateway.requests[0].reject!(classifyTdlibError(400, 'CHAT_WRITE_FORBIDDEN')); await settleWrites();
      const feedbackRequests = host.contextRequests;
      controller.handleSendMessage(host.draft, host); await settleWrites(); expect(host.gateway.requests.length).assertEqual(2);
      host.gateway.requests[1].resolve!(TdObject.fromJSON('{"@type":"message","id":901,"chat_id":42}')); await settleWrites();
      expect(host.busy).assertFalse(); expect(host.contextRequests).assertEqual(feedbackRequests);
    });
    for (const code of [406, 400]) {
      it('send-failed update retains bookkeeping and safe error text ' + code, 0, () => {
        const handlers: Map<string, (events: AnyAppEvent[], update: TdObject) => void> = new Map(); registerMessageHandlers(handlers);
        const events: AnyAppEvent[] = []; const update = TdObject.fromJSON(
          `{"@type":"updateMessageSendFailed","old_message_id":100,"message":{"@type":"message","id":101,"chat_id":42},"error":{"@type":"error","code":${code},"message":"UPDATE_SECRET"}}`);
        handlers.get('updateMessageSendFailed')!(events, update); expect(events.length).assertEqual(1);
        const event = events[0] as MessageSendFailedEvent; expect(event.chatId).assertEqual(42);
        expect(event.oldMessageId).assertEqual('100'); expect(event.messageId).assertEqual('101'); expect(event.errorCode).assertEqual(code);
        expect(event.errorMessage).assertEqual(code === 406 ? '' : 'UPDATE_SECRET');
        const state = createInitialAppState(); const pending = new Message(); pending.id = '100'; pending.chatId = 42;
        pending.isPending = true; pending.sendStatus = 'pending'; const pendingMap: Map<string, Message> = new Map();
        pendingMap.set('100', pending); state.messages.messages.set(42, pendingMap);
        const reduced = messagesReducer(state, event); const failed = reduced.messages.messages.get(42)?.get('100');
        expect(failed?.isPending).assertEqual(false); expect(failed?.sendStatus).assertEqual('failed');
        expect(failed?.sendErrorCode).assertEqual(code); expect(failed?.sendErrorMessage).assertEqual(code === 406 ? '' : 'UPDATE_SECRET');
        expect(state.messages.messages.get(42)?.get('100')?.isPending).assertEqual(true);
      });
    }
  });
}
