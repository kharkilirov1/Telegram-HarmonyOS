import { describe, it, expect } from '@ohos/hypium';
import { CustomEmojiTextEntity, SendMediaMessageCommand } from '../../../main/ets/core/model/AppCommand';
import { classifyTdlibError } from '../../../main/ets/core/model/AppError';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { ChatComposerController, ChatComposerControllerHost } from '../../../main/ets/ui/pages/chat/ChatComposerController';
import { SendMediaMessageUseCase } from '../../../main/ets/domain/usecases/sendMediaMessage';
import { ChatScreenContext } from '../../../main/ets/ui/pages/chat/ChatScreenContext';
import { ChatScreenViewState } from '../../../main/ets/ui/pages/chat/ChatScreenViewState';
import { WriteHost, settleWrites } from './WritePathErrors.test';

export class SequentialMediaHost extends WriteHost {
  kind: string = 'document';
  route: number = 1;
  getPendingAttachmentKind(): string { return this.kind; }
  getChatRouteToken(): number { return this.route; }
  setPendingAttachmentState(kind: string, _title: string, _preview: string, uris: string[]): void {
    this.revision++; this.kind = kind; this.attachments = uris.slice();
  }
  clearPendingAttachmentState(): void { this.revision++; this.kind = ''; this.attachments = []; }
  setCustomEmojiEntities(value: CustomEmojiTextEntity[]): void { this.revision++; super.setCustomEmojiEntities(value); }
  clearReplyMode(): void { if (this.reply !== '0') this.revision++; super.clearReplyMode(); }
}
export class SequentialPreparation {
  kind: string;
  uri: string;
  path: string;
  resolve?: (path: string) => void;
  reject?: (reason: Object) => void;
  constructor(kind: string, uri: string, index: number) {
    this.kind = kind; this.uri = uri; this.path = '/fixture/prepared-' + index + '-' + kind;
  }
}
// Only file/provider preparation is controlled. Dispatch, provenance, ownership,
// selection retirement and composer mutations are the actual controller code.
export class SequentialMediaComposer extends ChatComposerController {
  preparations: SequentialPreparation[] = [];
  discarded: string[] = [];
  deferPreparation: boolean = false;
  protected preparePickedAttachmentLocalPath(kind: string, uri: string, _host: ChatComposerControllerHost): Promise<string> {
    const value = new SequentialPreparation(kind, uri, this.preparations.length); this.preparations.push(value);
    if (!this.deferPreparation) return Promise.resolve(value.path);
    return new Promise<string>((resolve, reject) => { value.resolve = resolve; value.reject = reject; });
  }
  protected discardPreparedAttachment(path: string): void { this.discarded.push(path); }
}
export function createSequentialHost(kind: string = 'document', uris: string[] = ['file:///a', 'file:///b']): SequentialMediaHost {
  const host = new SequentialMediaHost(); host.setPendingAttachmentState(kind, kind, kind, uris);
  host.setDraftText('\uD83D\uDE00 caption'); host.reply = '55'; host.entities = [new CustomEmojiTextEntity(0, 2, '123')];
  host.setDraftSelection(2, 4); return host;
}
export function acceptedMedia(id: number = 901): TdObject {
  return TdObject.fromJSON('{"@type":"message","id":' + id.toString() + ',"chat_id":42}');
}
export function capturedMedia(host: SequentialMediaHost, index: number): SendMediaMessageCommand {
  const command = host.gateway.requests[index].command;
  expect(command.type).assertEqual('sendMediaMessage'); return command as SendMediaMessageCommand;
}
export function changeSequentialOwner(host: SequentialMediaHost, boundary: string): void {
  if (boundary === 'draft') host.setDraftText('new draft');
  if (boundary === 'draft-ABA') { host.setDraftText('new draft'); host.setDraftText('\uD83D\uDE00 caption'); }
  if (boundary === 'reply') { host.reply = '99'; host.revision++; }
  if (boundary === 'entities') host.setCustomEmojiEntities([new CustomEmojiTextEntity(0, 2, '999')]);
  // Actual ChatScreenContext caret setters do not advance input revision.
  if (boundary === 'selection') host.setDraftSelection(5, 6);
  if (boundary === 'pending-cancel') host.clearPendingAttachmentState();
  if (boundary === 'selection-replace') host.setPendingAttachmentState(host.kind, 'new', 'new', ['file:///new']);
  if (boundary === 'kind') host.setPendingAttachmentState('video', 'video', 'video', host.attachments);
  if (boundary === 'permission') host.allowed = false;
  if (boundary === 'account') host.media = new SendMediaMessageUseCase(host.gateway);
  if (boundary === 'inactive') host.active = false;
  if (boundary === 'edit') host.editId = '99';
  if (boundary === 'forward') host.setForwardMode(['99'], 88, 'new', 'new');
  if (boundary === 'navigation') host.chatId = 43;
  if (boundary === 'lifecycle') host.lifecycle++;
  if (boundary === 'operation') host.setSendingMessage(true);
}
export default function sequentialMediaSendTest() {
  describe('SequentialMediaSend', () => {
    for (const kind of ['document', 'video']) {
      it(kind + ' retires accepted prefix and consumes its caption and reply before next mutation', 0, async () => {
        const host = createSequentialHost(kind); const controller = new SequentialMediaComposer();
        controller.handleSendMessage(host.draft, host); await settleWrites();
        expect(host.gateway.requests.length).assertEqual(1); const first = capturedMedia(host, 0);
        expect(first.payload.mediaKind).assertEqual(kind); expect(first.payload.caption).assertEqual('\uD83D\uDE00 caption');
        expect(first.payload.replyToMessageId).assertEqual('55');
        host.gateway.requests[0].resolve!(acceptedMedia()); await settleWrites();
        expect(host.attachments.join('|')).assertEqual('file:///b'); expect(host.draft).assertEqual('');
        expect(host.reply).assertEqual('0'); expect(host.entities.length).assertEqual(0);
        expect(host.selectionStart).assertEqual(0); expect(host.selectionEnd).assertEqual(0);
        expect(host.gateway.requests.length).assertEqual(2); const second = capturedMedia(host, 1);
        expect(second.payload.caption).assertEqual(''); expect(second.payload.replyToMessageId).assertEqual('0');
        host.gateway.requests[1].reject!(classifyTdlibError(400, 'CHAT_WRITE_FORBIDDEN')); await settleWrites();
        expect(host.busy).assertFalse(); expect(host.attachments.join('|')).assertEqual('file:///b');
        const feedback = host.contextRequests; controller.handleSendMessage(host.draft, host); await settleWrites();
        expect(host.gateway.requests.length).assertEqual(3); expect(host.contextRequests).assertEqual(feedback);
        expect(capturedMedia(host, 2).payload.caption).assertEqual(''); expect(capturedMedia(host, 2).payload.replyToMessageId).assertEqual('0');
        host.gateway.requests[2].resolve!(acceptedMedia(903)); await settleWrites(); expect(host.attachments.length).assertEqual(0);
      });
      it(kind + ' unknown first outcome preserves input and cannot repeat when native confirmation is unavailable', 0, async () => {
        const host = createSequentialHost(kind, ['file:///a']); const controller = new SequentialMediaComposer();
        controller.handleSendMessage(host.draft, host); await settleWrites(); expect(host.gateway.requests.length).assertEqual(1);
        host.gateway.requests[0].reject!(new Error('Synthetic transport timeout')); await settleWrites();
        expect(host.busy).assertFalse(); expect(host.attachments.join('|')).assertEqual('file:///a');
        expect(host.draft).assertEqual('\uD83D\uDE00 caption'); expect(host.reply).assertEqual('55');
        expect(host.entities.length).assertEqual(1); expect(host.selectionStart).assertEqual(2); expect(host.selectionEnd).assertEqual(4);
        controller.handleSendMessage(host.draft, host); await settleWrites();
        expect(host.gateway.requests.length).assertEqual(1); expect(controller.preparations.length).assertEqual(1);
        expect(host.busy).assertFalse(); expect(host.attachments.join('|')).assertEqual('file:///a');
      });
      it(kind + ' accepted prefix plus unknown tail never transfers the original caption or repeats the prefix', 0, async () => {
        const host = createSequentialHost(kind); const controller = new SequentialMediaComposer();
        controller.handleSendMessage(host.draft, host); await settleWrites();
        host.gateway.requests[0].resolve!(acceptedMedia()); await settleWrites();
        expect(host.gateway.requests.length).assertEqual(2); host.gateway.requests[1].reject!(new Error('Synthetic timeout')); await settleWrites();
        expect(host.attachments.join('|')).assertEqual('file:///b'); expect(host.draft).assertEqual(''); expect(host.reply).assertEqual('0');
        expect(host.entities.length).assertEqual(0); expect(host.busy).assertFalse();
        controller.handleSendMessage(host.draft, host); await settleWrites();
        expect(host.gateway.requests.length).assertEqual(2); expect(controller.preparations.length).assertEqual(2);
        expect(host.attachments.join('|')).assertEqual('file:///b'); expect(host.busy).assertFalse();
      });
      it(kind + ' definitive first rejection permits ordinary retry and cleans only its unaccepted copy', 0, async () => {
        const host = createSequentialHost(kind, ['file:///a']); const controller = new SequentialMediaComposer();
        controller.handleSendMessage(host.draft, host); await settleWrites();
        host.gateway.requests[0].reject!(classifyTdlibError(400, 'CHAT_WRITE_FORBIDDEN')); await settleWrites();
        expect(host.busy).assertFalse(); expect(host.attachments.join('|')).assertEqual('file:///a'); expect(host.draft).assertEqual('\uD83D\uDE00 caption');
        expect(controller.discarded.join('|')).assertEqual(controller.preparations[0].path);
        const feedback = host.contextRequests; controller.handleSendMessage(host.draft, host); await settleWrites();
        expect(host.gateway.requests.length).assertEqual(2); expect(host.contextRequests).assertEqual(feedback);
        expect(capturedMedia(host, 1).payload.caption).assertEqual('\uD83D\uDE00 caption'); expect(capturedMedia(host, 1).payload.replyToMessageId).assertEqual('55');
        host.gateway.requests[1].resolve!(acceptedMedia(902)); await settleWrites(); expect(host.attachments.length).assertEqual(0);
      });
      it(kind + ' explicit silent406 preserves untouched composer without presentation or payload feedback', 0, async () => {
        const host = createSequentialHost(kind, ['file:///a']); const controller = new SequentialMediaComposer();
        controller.handleSendMessage(host.draft, host); await settleWrites(); host.gateway.requests[0].reject!(classifyTdlibError(406, 'FLOOD_WAIT_99 SECRET')); await settleWrites();
        expect(host.contextRequests).assertEqual(0); expect(host.busy).assertFalse(); expect(host.draft).assertEqual('\uD83D\uDE00 caption');
        expect(host.reply).assertEqual('55'); expect(host.entities.length).assertEqual(1); expect(host.selectionStart).assertEqual(2); expect(host.selectionEnd).assertEqual(4);
        expect(host.attachments.join('|')).assertEqual('file:///a'); controller.handleSendMessage(host.draft, host); await settleWrites();
        expect(host.gateway.requests.length).assertEqual(2); expect(host.contextRequests).assertEqual(0);
        host.gateway.requests[1].resolve!(acceptedMedia(902)); await settleWrites();
      });
    }
    for (const phase of ['preparation', 'send']) {
      for (const boundary of ['draft', 'draft-ABA', 'reply', 'entities', 'selection', 'pending-cancel', 'selection-replace', 'kind', 'permission', 'account', 'inactive', 'edit', 'forward', 'navigation', 'lifecycle', 'operation']) {
        it(phase + ' completion preserves changed composer owner ' + boundary, 0, async () => {
          const host = createSequentialHost(); const controller = new SequentialMediaComposer(); controller.deferPreparation = phase === 'preparation';
          controller.handleSendMessage(host.draft, host); await settleWrites();
          expect(controller.preparations.length).assertEqual(1); expect(host.gateway.requests.length).assertEqual(phase === 'send' ? 1 : 0);
          changeSequentialOwner(host, boundary);
          const draft = host.draft, reply = host.reply, uris = host.attachments.join('|'), kind = host.kind;
          const emojiId = host.entities[0].customEmojiId, start = host.selectionStart, end = host.selectionEnd, operation = host.operation;
          if (phase === 'preparation') controller.preparations[0].resolve!(controller.preparations[0].path);
          else host.gateway.requests[0].resolve!(acceptedMedia());
          await settleWrites();
          expect(host.gateway.requests.length).assertEqual(phase === 'send' ? 1 : 0); expect(controller.preparations.length).assertEqual(1);
          expect(host.draft).assertEqual(draft); expect(host.reply).assertEqual(reply); expect(host.attachments.join('|')).assertEqual(uris); expect(host.kind).assertEqual(kind);
          expect(host.entities[0].customEmojiId).assertEqual(emojiId); expect(host.selectionStart).assertEqual(start); expect(host.selectionEnd).assertEqual(end);
          expect(host.scrolls).assertEqual(0);
          if (phase === 'preparation') expect(controller.discarded.join('|')).assertEqual(controller.preparations[0].path);
          else expect(controller.discarded.length).assertEqual(0);
          if (boundary === 'operation' || boundary === 'navigation' || boundary === 'lifecycle') {
            expect(host.busy).assertTrue(); expect(host.operation).assertEqual(operation);
          } else expect(host.busy).assertFalse();
        });
      }
    }
    it('preparation failure is known unsent and retries without a duplicate confirmation', 0, async () => {
      const host = createSequentialHost('document', ['file:///a']); const controller = new SequentialMediaComposer(); controller.deferPreparation = true;
      controller.handleSendMessage(host.draft, host); await settleWrites(); controller.preparations[0].reject!(new Error('Synthetic provider revoked')); await settleWrites();
      expect(host.busy).assertFalse(); expect(host.gateway.requests.length).assertEqual(0); expect(host.attachments.join('|')).assertEqual('file:///a');
      const feedback = host.contextRequests; controller.deferPreparation = false; controller.handleSendMessage(host.draft, host); await settleWrites();
      expect(host.gateway.requests.length).assertEqual(1); expect(host.contextRequests).assertEqual(feedback);
      host.gateway.requests[0].resolve!(acceptedMedia()); await settleWrites(); expect(host.attachments.length).assertEqual(0);
    });
    it('accepted response followed by canceled tail preparation discards only the unsubmitted tail copy', 0, async () => {
      const host = createSequentialHost(); const controller = new SequentialMediaComposer();
      controller.handleSendMessage(host.draft, host); await settleWrites(); controller.deferPreparation = true;
      host.gateway.requests[0].resolve!(acceptedMedia()); await settleWrites(); expect(controller.preparations.length).assertEqual(2);
      expect(host.attachments.join('|')).assertEqual('file:///b'); host.clearPendingAttachmentState(); host.setDraftText('new draft');
      controller.preparations[1].resolve!(controller.preparations[1].path); await settleWrites();
      expect(host.gateway.requests.length).assertEqual(1); expect(controller.discarded.join('|')).assertEqual(controller.preparations[1].path);
      expect(host.draft).assertEqual('new draft'); expect(host.attachments.length).assertEqual(0); expect(host.busy).assertFalse();
    });
    it('actual Context forward enter and cancel advances revision while equal values remain no-ops', 0, () => {
      const context = new ChatScreenContext(new ChatScreenViewState(), (): UIContext => {
        throw new Error('The Context revision callback requires no native presentation');
      }, () => undefined);
      const initial = context.composerInputRevision;
      context.isForwardingMessages = false; expect(context.composerInputRevision).assertEqual(initial);
      context.isForwardingMessages = true; expect(context.composerInputRevision).assertEqual(initial + 1);
      context.isForwardingMessages = true; expect(context.composerInputRevision).assertEqual(initial + 1);
      context.isForwardingMessages = false; expect(context.composerInputRevision).assertEqual(initial + 2);
      context.isForwardingMessages = false; expect(context.composerInputRevision).assertEqual(initial + 2);
    });
  });
}
