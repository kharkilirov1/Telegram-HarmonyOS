import { AnyAppCommand, CustomEmojiTextEntity, SendMessageCommand } from '../../../../main/ets/core/model/AppCommand';
import { TdObject } from '../../../../main/ets/models/TdTypes';
import { SendMessageUseCase } from '../../../../main/ets/domain/usecases/sendMessage';
import { ChatComposerController } from '../../../../main/ets/ui/pages/chat/ChatComposerController';
import { WriteHost, WriteGateway } from '../../test/WritePathErrors.test';

// Real text controller/usecase and mounted native UIContext. The port below is
// deterministic and never constructs TDLib or touches an account/network.
@ObservedV2
export class WriteResendState {
  @Trace mutations: number = 0;
  @Trace busy: boolean = false;
  @Trace draft: string = '\uD83D\uDE00 fixture text';
  @Trace reply: string = '55';
  @Trace entities: number = 1;
}
class ResendGateway extends WriteGateway {
  private state: WriteResendState;
  constructor(state: WriteResendState) { super(); this.state = state; }
  send(command: AnyAppCommand): Promise<Object> {
    const promise = super.send(command);
    if (command.type !== 'sendMessage') throw new Error('Native text fixture forbids other mutations');
    const request = this.requests[this.requests.length - 1]; this.state.mutations = this.requests.length;
    if (this.requests.length === 1) request.reject!(new Error('Synthetic acceptance timeout'));
    else if (this.requests.length === 2) request.resolve!(TdObject.fromJSON('{"@type":"message","id":901,"chat_id":42}'));
    else request.reject!(new Error('Unexpected duplicate text mutation'));
    return promise;
  }
}
class NativeWriteHost extends WriteHost {
  private state: WriteResendState;
  private context?: UIContext;
  constructor(state: WriteResendState) {
    super(); this.state = state; this.gateway = new ResendGateway(state); this.sender = new SendMessageUseCase(this.gateway);
    this.draft = state.draft; this.reply = state.reply; this.entities = [new CustomEmojiTextEntity(0, 2, '123')];
  }
  bind(context: UIContext): void { this.context = context; }
  getChatUIContext(): UIContext { if (this.context === undefined) throw new Error('Native text fixture is not mounted'); return this.context; }
  setSendingMessage(value: boolean): void { super.setSendingMessage(value); this.state.busy = value; }
  setDraftText(value: string): void { super.setDraftText(value); this.state.draft = value; }
  setCustomEmojiEntities(value: CustomEmojiTextEntity[]): void { super.setCustomEmojiEntities(value); this.state.entities = value.length; }
  clearReplyMode(): void { super.clearReplyMode(); this.state.reply = this.reply; }
}
export class WriteResendFixture {
  static readonly state: WriteResendState = new WriteResendState();
  private static host: NativeWriteHost = new NativeWriteHost(WriteResendFixture.state);
  private static controller: ChatComposerController = new ChatComposerController();
  static reset(): void {
    if (WriteResendFixture.state.busy) throw new Error('Close the native text confirmation before reset');
    const state = WriteResendFixture.state; state.mutations = 0; state.busy = false;
    state.draft = '\uD83D\uDE00 fixture text'; state.reply = '55'; state.entities = 1;
    WriteResendFixture.host = new NativeWriteHost(state); WriteResendFixture.controller = new ChatComposerController();
  }
  static send(context: UIContext): void {
    WriteResendFixture.host.bind(context); WriteResendFixture.controller.handleSendMessage(WriteResendFixture.host.draft, WriteResendFixture.host);
  }
  static capturedTexts(): SendMessageCommand[] {
    const result: SendMessageCommand[] = [];
    for (const command of WriteResendFixture.host.gateway.trace) {
      if (command.type === 'sendMessage') result.push(command as SendMessageCommand);
    }
    return result;
  }
  static screenshotPath(): string {
    const context = WriteResendFixture.host.getChatUIContext().getHostContext();
    if (context === undefined || context.filesDir.length === 0) throw new Error('Native fixture filesDir unavailable');
    return context.filesDir + '/tg-text-resend.png';
  }
}
@ComponentV2
export struct WriteResendFixtureView {
  @Local private state: WriteResendState = WriteResendFixture.state;
  build() {
    Column({ space: 4 }) {
      Button('Send fixture text').id('write-resend-fixture-send').onClick(() => WriteResendFixture.send(this.getUIContext()))
      Text('text mutations:' + this.state.mutations.toString()).id('write-resend-fixture-mutations')
      Text('text busy:' + this.state.busy.toString()).id('write-resend-fixture-busy')
      Text('text reply:' + this.state.reply).id('write-resend-fixture-reply')
      Text('text entities:' + this.state.entities.toString()).id('write-resend-fixture-entities')
    }
  }
}
