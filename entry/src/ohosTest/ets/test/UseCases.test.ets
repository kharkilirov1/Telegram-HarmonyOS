import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand, EditMessageTextCommand, ForwardMessagesCommand, GetChatCommand, GetMessageCommand, GetMessagePropertiesCommand, SendMessageCommand, SendMediaMessageCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { AppError } from '../../../main/ets/core/model/AppError';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { DeleteMessagesParams, DeleteMessagesUseCase } from '../../../main/ets/domain/usecases/deleteMessages';
import { EditMessageParams, EditMessageUseCase } from '../../../main/ets/domain/usecases/editMessage';
import { ForwardMessagesParams, ForwardMessagesUseCase } from '../../../main/ets/domain/usecases/forwardMessages';
import { SendMediaMessageParams, SendMediaMessageUseCase } from '../../../main/ets/domain/usecases/sendMediaMessage';
import { SendMessageParams, SendMessageUseCase } from '../../../main/ets/domain/usecases/sendMessage';
import { TdObject } from '../../../main/ets/models/TdTypes';

class FakeGateway implements TdGatewayPort {
  sentCommands: AnyAppCommand[] = [];
  failNextSend: boolean = false;

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  send(command: AnyAppCommand): Promise<Object> {
    this.sentCommands.push(command);
    if (command.type === 'getChat') {
      const target = command as GetChatCommand;
      return Promise.resolve(TdObject.fromJSON(`{"@type":"chat","id":${target.payload.chatId},"type":{"@type":"chatTypePrivate"}}`));
    }
    if (command.type === 'getMessageProperties') {
      return Promise.resolve(TdObject.fromJSON('{"@type":"messageProperties","can_be_edited":true,"can_be_forwarded":true,"can_be_copied":true,"can_be_copied_to_secret_chat":true,"can_be_deleted_only_for_self":true,"can_be_deleted_for_all_users":true}'));
    }
    if (command.type === 'getMessage') {
      const source = command as GetMessageCommand;
      return Promise.resolve(TdObject.fromJSON(`{"@type":"message","id":${source.payload.messageId},"chat_id":${source.payload.chatId},` +
        '"content":{"@type":"messageText","text":{"@type":"formattedText","text":"original","entities":[]},"link_preview_options":null}}'));
    }
    // failNextSend targets the mutating request, not its eligibility reads.
    if (this.failNextSend) {
      this.failNextSend = false;
      return Promise.reject(new Error('gateway failed'));
    }
    if (command.type === 'editMessageText') {
      const edit = command as EditMessageTextCommand;
      return Promise.resolve(TdObject.fromJSON(`{"@type":"message","id":${edit.payload.messageId},"chat_id":${edit.payload.chatId},` +
        `"content":{"@type":"messageText","text":{"@type":"formattedText","text":${JSON.stringify(edit.payload.text)},"entities":[]},"link_preview_options":null}}`));
    }
    if (command.type === 'deleteMessages') {
      return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}'));
    }
    if (command.type === 'forwardMessages') {
      const forward = command as ForwardMessagesCommand;
      const messages: string[] = forward.payload.messageIds.map((_id: string, index: number): string =>
        `{"@type":"message","id":${900 + index},"chat_id":${forward.payload.chatId}}`);
      return Promise.resolve(TdObject.fromJSON(`{"@type":"messages","messages":[${messages.join(',')}]}`));
    }
    if (command.type === 'sendMessage' || command.type === 'sendMediaMessage') {
      const send = command as SendMessageCommand | SendMediaMessageCommand;
      return Promise.resolve(TdObject.fromJSON(`{"@type":"message","id":900,"chat_id":${send.payload.chatId}}`));
    }
    return Promise.resolve(new TdObject());
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

export default function useCasesTest() {
  describe('UseCases', () => {

    describe('SendMessageUseCase', () => {
      it('should send command with reply id', 0, async () => {
        const gateway = new FakeGateway();
        const useCase = new SendMessageUseCase(gateway);
        const params = new SendMessageParams();
        params.chatId = 10;
        params.text = 'hello';
        params.replyToMessageId = '5';

        await useCase.execute(params);

        expect(gateway.sentCommands.length).assertEqual(1);
        expect(gateway.sentCommands[0].type).assertEqual('sendMessage');
      });

      it('should reject empty message text before gateway send', 0, async () => {
        const gateway = new FakeGateway();
        const useCase = new SendMessageUseCase(gateway);
        const params = new SendMessageParams();
        params.chatId = 10;
        params.text = '';

        let gotError = false;
        try {
          await useCase.execute(params);
        } catch (error) {
          gotError = error instanceof AppError;
        }

        expect(gotError).assertTrue();
        expect(gateway.sentCommands.length).assertEqual(0);
      });
    });

    describe('SendMediaMessageUseCase', () => {
      it('should send supported local media command', 0, async () => {
        const gateway = new FakeGateway();
        const useCase = new SendMediaMessageUseCase(gateway);
        const params = new SendMediaMessageParams();
        params.chatId = 10;
        params.mediaKind = 'photo';
        params.localPath = '/data/file.jpg';
        params.caption = 'caption';

        await useCase.execute(params);

        expect(gateway.sentCommands.length).assertEqual(1);
        expect(gateway.sentCommands[0].type).assertEqual('sendMediaMessage');
      });

      it('should reject unsupported media kind', 0, async () => {
        const gateway = new FakeGateway();
        const useCase = new SendMediaMessageUseCase(gateway);
        const params = new SendMediaMessageParams();
        params.chatId = 10;
        params.mediaKind = 'voice';
        params.localPath = '/data/file.ogg';

        let gotError = false;
        try {
          await useCase.execute(params);
        } catch (error) {
          gotError = error instanceof AppError;
        }

        expect(gotError).assertTrue();
        expect(gateway.sentCommands.length).assertEqual(0);
      });
    });

    describe('Message mutation use cases', () => {
      it('should send edit, delete, and forward commands', 0, async () => {
        const gateway = new FakeGateway();

        const editParams = new EditMessageParams();
        editParams.chatId = 10;
        editParams.messageId = '1048576';
        editParams.text = 'updated';
        await new EditMessageUseCase(gateway).execute(editParams);

        const deleteParams = new DeleteMessagesParams();
        deleteParams.chatId = 10;
        deleteParams.messageIds = ['100'];
        deleteParams.revoke = true;
        await new DeleteMessagesUseCase(gateway).execute(deleteParams);

        const forwardParams = new ForwardMessagesParams();
        forwardParams.chatId = 11;
        forwardParams.fromChatId = 10;
        forwardParams.messageIds = ['100'];
        await new ForwardMessagesUseCase(gateway).execute(forwardParams);

        expect(gateway.sentCommands.length).assertEqual(8);
        expect(gateway.sentCommands[0].type).assertEqual('getMessage');
        expect((gateway.sentCommands[0] as GetMessageCommand).payload.chatId).assertEqual(10);
        expect((gateway.sentCommands[0] as GetMessageCommand).payload.messageId).assertEqual('1048576');
        expect(gateway.sentCommands[1].type).assertEqual('getMessageProperties');
        expect((gateway.sentCommands[1] as GetMessagePropertiesCommand).payload.chatId).assertEqual(10);
        expect((gateway.sentCommands[1] as GetMessagePropertiesCommand).payload.messageId).assertEqual('1048576');
        expect(gateway.sentCommands[2].type).assertEqual('editMessageText');
        expect((gateway.sentCommands[2] as EditMessageTextCommand).payload.text).assertEqual('updated');
        expect(gateway.sentCommands[3].type).assertEqual('getMessageProperties');
        expect((gateway.sentCommands[3] as GetMessagePropertiesCommand).payload.chatId).assertEqual(10);
        expect((gateway.sentCommands[3] as GetMessagePropertiesCommand).payload.messageId).assertEqual('100');
        expect(gateway.sentCommands[4].type).assertEqual('deleteMessages');
        expect(gateway.sentCommands[5].type).assertEqual('getChat');
        expect((gateway.sentCommands[5] as GetChatCommand).payload.chatId).assertEqual(11);
        expect(gateway.sentCommands[6].type).assertEqual('getMessageProperties');
        expect((gateway.sentCommands[6] as GetMessagePropertiesCommand).payload.chatId).assertEqual(10);
        expect((gateway.sentCommands[6] as GetMessagePropertiesCommand).payload.messageId).assertEqual('100');
        expect(gateway.sentCommands[7].type).assertEqual('forwardMessages');

        const failingGateway = new FakeGateway();
        failingGateway.failNextSend = true;
        let failedEdit = false;
        try { await new EditMessageUseCase(failingGateway).execute(editParams); }
        catch (error) { failedEdit = error instanceof AppError; }
        expect(failedEdit).assertEqual(true);
        expect(failingGateway.sentCommands.map((command: AnyAppCommand): string => command.type).join(',')).assertEqual(
          'getMessage,getMessageProperties,editMessageText');
        expect(failingGateway.failNextSend).assertEqual(false);
      });

      it('should reject invalid mutation params before gateway send', 0, async () => {
        const gateway = new FakeGateway();
        const deleteParams = new DeleteMessagesParams();
        deleteParams.chatId = 10;
        deleteParams.messageIds = [];

        let gotError = false;
        try {
          await new DeleteMessagesUseCase(gateway).execute(deleteParams);
        } catch (error) {
          gotError = error instanceof AppError;
        }

        expect(gotError).assertTrue();
        expect(gateway.sentCommands.length).assertEqual(0);
      });
    });
  });
}
