import { describe, expect, it } from '@ohos/hypium';
import {
  createLoadPinnedMessagesUseCase,
  LoadPinnedMessagesUseCase,
  parsePinnedMessageInfo,
  parsePinnedMessagesPage,
  PinnedMessagesPage,
  PinnedMessageInfo
} from '../../../main/ets/domain/usecases/loadPinnedMessage';
import { AnyAppCommand, SearchChatMessagesCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { TdObject } from '../../../main/ets/core/utils/tdAccessors';

class FakePinnedGateway implements TdGatewayPort {
  sentCommands: AnyAppCommand[] = [];
  response: Object;

  constructor(response: Object) {
    this.response = response;
  }

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  send(command: AnyAppCommand): Promise<Object> {
    this.sentCommands.push(command);
    return Promise.resolve(this.response);
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

export default function loadPinnedMessageTest() {
  describe('LoadPinnedMessage', () => {
    it('parses the real pinned text message response', 0, () => {
      const response = TdObject.fromJSON(
        '{"@type":"message","id":9007199254740991,"chat_id":-100123,"date":1,' +
          '"content":{"@type":"messageText","text":{"@type":"formattedText",' +
          '"text":"Pinned hello","entities":[]}}}'
      );

      const info: PinnedMessageInfo = parsePinnedMessageInfo(response);
      expect(info.isAvailable).assertTrue();
      expect(info.messageId).assertEqual('9007199254740991');
      expect(info.preview).assertEqual('Pinned hello');
      expect(info.hasThumbnail).assertFalse();
    });

    it('uses the smallest downloaded photo as the panel thumbnail', 0, () => {
      const response = TdObject.fromJSON(
        '{"@type":"message","id":901,"chat_id":1,"date":1,"content":{"@type":"messagePhoto",' +
          '"caption":{"@type":"formattedText","text":"","entities":[]},"photo":{"@type":"photo",' +
          '"sizes":[' +
          '{"@type":"photoSize","width":90,"height":90,"photo":{"@type":"file","id":2,' +
          '"local":{"@type":"localFile","path":"/data/thumb.jpg"}}},' +
          '{"@type":"photoSize","width":900,"height":900,"photo":{"@type":"file","id":3,' +
          '"local":{"@type":"localFile","path":"/data/full.jpg"}}}]}}}'
      );

      const info: PinnedMessageInfo = parsePinnedMessageInfo(response);
      expect(info.isAvailable).assertTrue();
      expect(info.preview).assertEqual('[Photo]');
      expect(info.hasThumbnail).assertTrue();
      expect(info.thumbnailPath).assertEqual('/data/thumb.jpg');
    });

    it('keeps the panel hidden for TDLib error responses', 0, () => {
      const info: PinnedMessageInfo = parsePinnedMessageInfo(
        TdObject.fromJSON('{"@type":"error","code":404,"message":"Message not found"}')
      );
      expect(info.isAvailable).assertFalse();
      expect(info.messageId).assertEqual('0');
    });

    it('parses exact multi-pin page state and preserves the int64 cursor', 0, () => {
      const page: PinnedMessagesPage = parsePinnedMessagesPage(TdObject.fromJSON(
        '{"@type":"foundChatMessages","total_count":3,"messages":[' +
          '{"@type":"message","id":"9223372036854775001","chat_id":42,"date":3,' +
          '"content":{"@type":"messageText","text":{"@type":"formattedText","text":"Newest"}}},' +
          '{"@type":"message","id":"9223372036854774999","chat_id":42,"date":2,' +
          '"content":{"@type":"messageText","text":{"@type":"formattedText","text":"Older"}}}' +
          '],"next_from_message_id":"9223372036854774900"}'
      ));

      expect(page.totalCount).assertEqual(3);
      expect(page.items.length).assertEqual(2);
      expect(page.items[0].messageId).assertEqual('9223372036854775001');
      expect(page.items[0].preview).assertEqual('Newest');
      expect(page.nextFromMessageId).assertEqual('9223372036854774900');
    });

    it('requests pinned messages through the exact TDLib filter contract', 0, async () => {
      const gateway = new FakePinnedGateway(TdObject.fromJSON(
        '{"@type":"foundChatMessages","total_count":0,"messages":[],"next_from_message_id":"0"}'
      ));
      const useCase: LoadPinnedMessagesUseCase = createLoadPinnedMessagesUseCase(gateway);

      await useCase.execute(42, '9223372036854775001', 500);

      expect(gateway.sentCommands.length).assertEqual(1);
      const command = gateway.sentCommands[0] as SearchChatMessagesCommand;
      expect(command.type).assertEqual('searchChatMessages');
      expect(command.payload.chatId).assertEqual(42);
      expect(command.payload.query).assertEqual('');
      expect(command.payload.fromMessageId).assertEqual('9223372036854775001');
      expect(command.payload.limit).assertEqual(100);
      expect(command.payload.filterType).assertEqual('Pinned');
    });
  });
}
