import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand } from '../../../main/ets/core/model/AppCommand';
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
    if (this.failNextSend) {
      this.failNextSend = false;
      return Promise.reject(new Error('gateway failed'));
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
        editParams.messageId = '100';
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

        expect(gateway.sentCommands.length).assertEqual(3);
        expect(gateway.sentCommands[0].type).assertEqual('editMessageText');
        expect(gateway.sentCommands[1].type).assertEqual('deleteMessages');
        expect(gateway.sentCommands[2].type).assertEqual('forwardMessages');
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
