import { describe, it, expect } from '@ohos/hypium';
import {
  AnyAppCommand,
  DownloadFileCommand,
  SearchChatMessagesCommand
} from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import {
  SearchChatMessagesResult,
  SearchChatMessagesUseCase
} from '../../../main/ets/domain/usecases/searchChatMessages';
import { TdObject } from '../../../main/ets/models/TdTypes';

class FakeSearchGateway implements TdGatewayPort {
  sentCommands: AnyAppCommand[] = [];
  private responses: Object[] = [];
  private responseIndex: number = 0;

  constructor(responses: Object[]) {
    this.responses = responses;
  }

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  send(command: AnyAppCommand): Promise<Object> {
    this.sentCommands.push(command);
    if (this.responseIndex >= this.responses.length) {
      return Promise.resolve(TdObject.empty());
    }
    const response = this.responses[this.responseIndex];
    this.responseIndex++;
    return Promise.resolve(response);
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

export default function searchChatMessagesTest() {
  describe('SearchChatMessages', () => {
    it('should default to an empty terminal result', 0, () => {
      const result = new SearchChatMessagesResult();
      expect(result.messageIds.length).assertEqual(0);
      expect(result.totalCount).assertEqual(0);
      expect(result.nextFromMessageId).assertEqual('0');
    });

    it('should preserve TDLib int64 ids and the exact next page cursor', 0, async () => {
      const gateway = new FakeSearchGateway([
        TdObject.fromJSON(
          '{"@type":"foundChatMessages","total_count":201,' +
            '"messages":[' +
            '{"@type":"message","id":"9223372036854775001"},' +
            '{"@type":"message","id":"9223372036854774999"}' +
            '],"next_from_message_id":"9223372036854774900"}'
        )
      ]);
      const useCase = new SearchChatMessagesUseCase(gateway);

      const result = await useCase.execute(42, 'telegram', '9223372036854775100');

      expect(gateway.sentCommands.length).assertEqual(1);
      const command = gateway.sentCommands[0] as SearchChatMessagesCommand;
      expect(command.type).assertEqual('searchChatMessages');
      expect(command.payload.fromMessageId).assertEqual('9223372036854775100');
      expect(result.totalCount).assertEqual(201);
      expect(result.messageIds.length).assertEqual(2);
      expect(result.messageIds[0]).assertEqual('9223372036854775001');
      expect(result.messageIds[1]).assertEqual('9223372036854774999');
      expect(result.nextFromMessageId).assertEqual('9223372036854774900');
    });

    it('requests Shared Media thumbnails without blocking for completion', 0, async () => {
      const gateway = new FakeSearchGateway([
        TdObject.fromJSON('{"@type":"file","id":77,"local":{' +
          '"is_downloading_completed":false,"path":""}}')
      ]);
      const useCase = new SearchChatMessagesUseCase(gateway);

      const path = await useCase.requestThumbDownload(77, 16);

      expect(path).assertEqual('');
      expect(gateway.sentCommands.length).assertEqual(1);
      const command = gateway.sentCommands[0] as DownloadFileCommand;
      expect(command.type).assertEqual('downloadFile');
      expect(command.payload.fileId).assertEqual(77);
      expect(command.payload.priority).assertEqual(16);
      expect(command.payload.synchronous).assertFalse();
    });

    it('reads Shared Media file ids from the TDLib file object top level', 0, async () => {
      const gateway = new FakeSearchGateway([
        TdObject.fromJSON('{"@type":"foundChatMessages","total_count":2,"messages":[' +
          '{"@type":"message","id":"101","content":{"@type":"messagePhoto","photo":{' +
          '"@type":"photo","sizes":[{"@type":"photoSize","type":"m","photo":{' +
          '"@type":"file","id":404,"local":{"is_downloading_completed":false,"path":""},' +
          '"remote":{"id":"remote-photo"}}}]}}},' +
          '{"@type":"message","id":"102","content":{"@type":"messageVideo","video":{' +
          '"@type":"video","duration":9,"thumbnail":{"@type":"thumbnail","file":{' +
          '"@type":"file","id":405,"local":{"is_downloading_completed":false,"path":""},' +
          '"remote":{"id":"remote-video"}}}}}}]}')
      ]);
      const useCase = new SearchChatMessagesUseCase(gateway);

      const items = await useCase.searchChatMedia(42);

      expect(items.length).assertEqual(2);
      expect(items[0].thumbFileId).assertEqual(404);
      expect(items[1].thumbFileId).assertEqual(405);
    });

    it('preserves the exact link-preview URL for a direct Shared Media action', 0, async () => {
      const gateway = new FakeSearchGateway([
        TdObject.fromJSON('{"@type":"foundChatMessages","total_count":1,"messages":[' +
          '{"@type":"message","id":"201","content":{"@type":"messageText","text":{' +
          '"@type":"formattedText","text":"Example","entities":[{"@type":"textEntity",' +
          '"offset":0,"length":7,"type":{"@type":"textEntityTypeTextUrl",' +
          '"url":"https://fallback.example"}}]},"link_preview":{"@type":"linkPreview",' +
          '"url":"https://preview.example/article"}}}]}')
      ]);
      const useCase = new SearchChatMessagesUseCase(gateway);

      const items = await useCase.searchChatMedia(42, 'Url');

      expect(items.length).assertEqual(1);
      expect(items[0].kind).assertEqual('link');
      expect(items[0].linkUrl).assertEqual('https://preview.example/article');
    });

    it('extracts a URL from a media caption returned by the Url filter', 0, async () => {
      const gateway = new FakeSearchGateway([
        TdObject.fromJSON('{"@type":"foundChatMessages","total_count":1,"messages":[' +
          '{"@type":"message","id":"202","content":{"@type":"messagePhoto","caption":{' +
          '"@type":"formattedText","text":"See https://caption.example/path","entities":[' +
          '{"@type":"textEntity","offset":4,"length":28,"type":{"@type":"textEntityTypeUrl"}}]},' +
          '"photo":{"@type":"photo","sizes":[]}}}]}')
      ]);
      const useCase = new SearchChatMessagesUseCase(gateway);

      const items = await useCase.searchChatMedia(42, 'Url');

      expect(items.length).assertEqual(1);
      expect(items[0].kind).assertEqual('link');
      expect(items[0].linkUrl).assertEqual('https://caption.example/path');
    });
  });
}
