import { AnyAppCommand, CustomEmojiTextEntity, SendMediaMessageCommand } from '../../../../main/ets/core/model/AppCommand';
import { SendMediaMessageUseCase } from '../../../../main/ets/domain/usecases/sendMediaMessage';
import { ChatComposerControllerHost } from '../../../../main/ets/ui/pages/chat/ChatComposerController';
import { WriteGateway } from '../../test/WritePathErrors.test';
import { SequentialMediaHost, SequentialMediaComposer, acceptedMedia } from '../../test/SequentialMediaSend.test';

@ObservedV2
export class SequentialMediaDialogState {
  @Trace kind: string = 'document';
  @Trace mutations: number = 0;
  @Trace preparations: number = 0;
  @Trace discarded: number = 0;
  @Trace busy: boolean = false;
  @Trace uris: string = 'fixture:a|fixture:b';
  @Trace draft: string = '\uD83D\uDE00 caption';
  @Trace reply: string = '55';
  @Trace entities: number = 1;
  @Trace selection: string = '2:4';
}
class SequentialNativeGateway extends WriteGateway {
  private state: SequentialMediaDialogState;
  constructor(state: SequentialMediaDialogState) { super(); this.state = state; }
  send(command: AnyAppCommand): Promise<Object> {
    if (command.type !== 'sendMediaMessage') throw new Error('Sequential native fixture forbids other requests');
    const promise = super.send(command); const request = this.requests[this.requests.length - 1]; this.state.mutations = this.requests.length;
    if (this.requests.length === 1 || this.requests.length === 3) request.resolve!(acceptedMedia(900 + this.requests.length));
    else if (this.requests.length === 2) request.reject!(new Error('Synthetic unknown tail acceptance'));
    else request.reject!(new Error('Unexpected duplicate sequential mutation'));
    return promise;
  }
}
class SequentialNativeHost extends SequentialMediaHost {
  private state: SequentialMediaDialogState;
  private context?: UIContext;
  constructor(state: SequentialMediaDialogState) {
    super(); this.state = state; this.gateway = new SequentialNativeGateway(state); this.media = new SendMediaMessageUseCase(this.gateway);
    this.kind = state.kind; this.attachments = ['fixture:a', 'fixture:b']; this.draft = state.draft; this.reply = state.reply;
    this.selectionStart = 2; this.selectionEnd = 4;
    // The fixture has one real composer custom-emoji entity, never synthetic markup.
    this.entities = [new CustomEmojiTextEntity(0, 2, '123')];
  }
  bind(context: UIContext): void { this.context = context; }
  getChatUIContext(): UIContext { if (this.context === undefined) throw new Error('Sequential native fixture is not mounted'); return this.context; }
  setSendingMessage(value: boolean): void { super.setSendingMessage(value); this.state.busy = value; }
  setDraftText(value: string): void { super.setDraftText(value); this.state.draft = value; }
  setCustomEmojiEntities(value: CustomEmojiTextEntity[]): void { super.setCustomEmojiEntities(value); this.state.entities = value.length; }
  setDraftSelection(start: number, end: number): void { super.setDraftSelection(start, end); this.state.selection = start.toString() + ':' + end.toString(); }
  clearReplyMode(): void { super.clearReplyMode(); this.state.reply = this.reply; }
  setPendingAttachmentState(kind: string, title: string, preview: string, uris: string[]): void {
    super.setPendingAttachmentState(kind, title, preview, uris); this.state.uris = this.attachments.join('|');
  }
  clearPendingAttachmentState(): void { super.clearPendingAttachmentState(); this.state.uris = ''; }
}
class SequentialNativeComposer extends SequentialMediaComposer {
  private state: SequentialMediaDialogState;
  constructor(state: SequentialMediaDialogState) { super(); this.state = state; }
  protected preparePickedAttachmentLocalPath(kind: string, uri: string, host: ChatComposerControllerHost): Promise<string> {
    const result = super.preparePickedAttachmentLocalPath(kind, uri, host); this.state.preparations = this.preparations.length; return result;
  }
  protected discardPreparedAttachment(path: string): void { super.discardPreparedAttachment(path); this.state.discarded = this.discarded.length; }
}
export class SequentialMediaDialogFixture {
  static readonly state: SequentialMediaDialogState = new SequentialMediaDialogState();
  private static host: SequentialNativeHost = new SequentialNativeHost(SequentialMediaDialogFixture.state);
  private static controller: SequentialNativeComposer = new SequentialNativeComposer(SequentialMediaDialogFixture.state);
  static reset(kind: string): void {
    const state = SequentialMediaDialogFixture.state; if (state.busy) throw new Error('Close the owned sequential native modal before reset');
    state.kind = kind; state.mutations = 0; state.preparations = 0; state.discarded = 0; state.busy = false;
    state.uris = 'fixture:a|fixture:b'; state.draft = '\uD83D\uDE00 caption'; state.reply = '55'; state.entities = 1; state.selection = '2:4';
    SequentialMediaDialogFixture.host = new SequentialNativeHost(state); SequentialMediaDialogFixture.controller = new SequentialNativeComposer(state);
  }
  static send(context: UIContext): void {
    SequentialMediaDialogFixture.host.bind(context);
    SequentialMediaDialogFixture.controller.handleSendMessage(SequentialMediaDialogFixture.host.draft, SequentialMediaDialogFixture.host);
  }
  static commands(): SendMediaMessageCommand[] {
    const result: SendMediaMessageCommand[] = [];
    for (const command of SequentialMediaDialogFixture.host.gateway.trace) {
      if (command.type === 'sendMediaMessage') result.push(command as SendMediaMessageCommand);
    }
    return result;
  }
  static preparedUris(): string[] { return SequentialMediaDialogFixture.controller.preparations.map(value => value.uri); }
  static screenshotPath(): string {
    const context = SequentialMediaDialogFixture.host.getChatUIContext().getHostContext();
    if (context === undefined || context.filesDir.length === 0) throw new Error('Sequential native fixture filesDir unavailable');
    return context.filesDir + '/tg-sequential-' + SequentialMediaDialogFixture.state.kind + '-resend.png';
  }
}
@ComponentV2
export struct SequentialMediaDialogFixtureView {
  @Local private state: SequentialMediaDialogState = SequentialMediaDialogFixture.state;
  build() {
    Column({ space: 4 }) {
      Button('Send fixture document/video').id('sequential-media-fixture-send').onClick(() => SequentialMediaDialogFixture.send(this.getUIContext()))
      Text('sequential busy:' + this.state.busy.toString()).id('sequential-media-fixture-busy')
      Text('sequential mutations:' + this.state.mutations.toString()).id('sequential-media-fixture-mutations')
      Text('sequential remaining:' + this.state.uris).id('sequential-media-fixture-remaining')
      Text('sequential reply:' + this.state.reply).id('sequential-media-fixture-reply')
    }
  }
}
