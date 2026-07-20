import { describe, expect, it } from '@ohos/hypium';
import { AnyAppCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import {
  createStickerPanelUseCase,
  GifSearchPage,
  SendAnimationParams,
  StickerPanelUseCase
} from '../../../main/ets/domain/usecases/stickerPanel';
import { TdObject } from '../../../main/ets/models/TdTypes';

const INLINE_ANIMATION: string =
  '{"@type":"animation","duration":3,"width":320,"height":240,' +
  '"file_name":"cat.mp4","mime_type":"video/mp4","has_stickers":false,' +
  '"minithumbnail":{"@type":"minithumbnail","width":20,"height":15,"data":"YWJj"},' +
  '"animation":{"@type":"file","id":9,"local":{"@type":"localFile",' +
  '"path":"","is_downloading_completed":false},"remote":{"@type":"remoteFile",' +
  '"id":"remote-inline-gif"}},"thumbnail":{"@type":"thumbnail",' +
  '"file":{"@type":"file","id":10,"local":{"@type":"localFile",' +
  '"path":"","is_downloading_completed":false}}}}';

class GifInlineGateway implements TdGatewayPort {
  sentTypes: string[] = [];

  async initialize(): Promise<void> {}

  async send(command: AnyAppCommand): Promise<Object> {
    this.sentTypes.push(command.type);
    if (command.type === 'getOption') {
      return TdObject.fromJSON('{"@type":"optionValueString","value":"gif"}');
    }
    if (command.type === 'searchPublicChat') {
      return TdObject.fromJSON('{"@type":"chat","id":700,"type":' +
        '{"@type":"chatTypePrivate","user_id":77}}');
    }
    if (command.type === 'getInlineQueryResults') {
      const result = '{"@type":"inlineQueryResultAnimation","id":"result-1",' +
        '"animation":' + INLINE_ANIMATION + ',"title":"Cat"}';
      return TdObject.fromJSON('{"@type":"inlineQueryResults",' +
        '"inline_query_id":5368324170671202286,"results":[' + result + ',' + result + '],' +
        '"next_offset":"page-2"}');
    }
    if (command.type === 'sendInlineQueryResult') {
      return TdObject.fromJSON('{"@type":"message","id":1}');
    }
    return TdObject.fromJSON('{"@type":"error","code":400,"message":"unexpected"}');
  }

  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void {
    return (): void => {};
  }

  getConnectionState(): 'connecting' | 'ready' | 'updating' | 'waitingForNetwork' {
    return 'ready';
  }

  async destroy(): Promise<void> {}
}

export default function gifInlineSearchTest() {
  describe('GifInlineSearch', () => {
    it('resolves the configured bot and keeps inline ids for send', 0, async () => {
      const gateway = new GifInlineGateway();
      const useCase: StickerPanelUseCase = createStickerPanelUseCase(gateway);

      const page: GifSearchPage = await useCase.searchGifs('cats', 100);

      expect(gateway.sentTypes.length).assertEqual(3);
      expect(gateway.sentTypes[0]).assertEqual('getOption');
      expect(gateway.sentTypes[1]).assertEqual('searchPublicChat');
      expect(gateway.sentTypes[2]).assertEqual('getInlineQueryResults');
      expect(page.queryId).assertEqual('5368324170671202286');
      expect(page.nextOffset).assertEqual('page-2');
      expect(page.items.length).assertEqual(1);
      expect(page.items[0].inlineResultId).assertEqual('result-1');
      expect(page.items[0].remoteFileId).assertEqual('remote-inline-gif');
      expect(page.items[0].minithumbnailData).assertEqual('YWJj');

      const params = new SendAnimationParams();
      params.chatId = 100;
      params.inlineQueryId = page.items[0].inlineQueryId;
      params.inlineResultId = page.items[0].inlineResultId;
      await useCase.sendAnimation(params);
      expect(gateway.sentTypes[3]).assertEqual('sendInlineQueryResult');
    });

    it('does not resolve the bot for an empty query', 0, async () => {
      const gateway = new GifInlineGateway();
      const useCase: StickerPanelUseCase = createStickerPanelUseCase(gateway);
      const page: GifSearchPage = await useCase.searchGifs('   ', 100);
      expect(gateway.sentTypes.length).assertEqual(0);
      expect(page.items.length).assertEqual(0);
    });
  });
}
