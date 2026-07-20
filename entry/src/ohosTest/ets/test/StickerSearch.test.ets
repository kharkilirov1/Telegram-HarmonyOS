import { describe, expect, it } from '@ohos/hypium';
import { AnyAppCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import {
  createStickerPanelUseCase,
  StickerPanelEntry,
  StickerPanelUseCase
} from '../../../main/ets/domain/usecases/stickerPanel';
import { TdObject } from '../../../main/ets/models/TdTypes';

const REGULAR_STICKER: string =
  '{"@type":"sticker","id":42,"width":512,"height":512,"emoji":"🐱",' +
  '"format":{"@type":"stickerFormatWebp"},' +
  '"full_type":{"@type":"stickerFullTypeRegular","premium_animation":null},' +
  '"sticker":{"@type":"file","id":7,"local":{"@type":"localFile",' +
  '"path":"","is_downloading_completed":false},"remote":{"@type":"remoteFile",' +
  '"id":"remote-regular-sticker"}},' +
  '"thumbnail":{"@type":"thumbnail","file":{"@type":"file","id":8,' +
  '"local":{"@type":"localFile","path":"","is_downloading_completed":false}}}}';

class StickerSearchGateway implements TdGatewayPort {
  sentTypes: string[] = [];

  async initialize(): Promise<void> {}

  async send(command: AnyAppCommand): Promise<Object> {
    this.sentTypes.push(command.type);
    if (command.type === 'searchRegularStickers') {
      return TdObject.fromJSON('{"@type":"stickers","stickers":[' +
        REGULAR_STICKER + ',' + REGULAR_STICKER + ']}');
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

export default function stickerSearchTest() {
  describe('StickerSearch', () => {
    it('returns deduplicated regular Telegram stickers', 0, async () => {
      const gateway = new StickerSearchGateway();
      const useCase: StickerPanelUseCase = createStickerPanelUseCase(gateway);

      const result: StickerPanelEntry[] = await useCase.searchRegularStickers(
        'кот', ['ru-RU', 'en-US']);

      expect(gateway.sentTypes.length).assertEqual(1);
      expect(gateway.sentTypes[0]).assertEqual('searchRegularStickers');
      expect(result.length).assertEqual(1);
      expect(result[0].stickerId).assertEqual('42');
      expect(result[0].remoteFileId).assertEqual('remote-regular-sticker');
    });

    it('does not hit TDLib for one-character queries', 0, async () => {
      const gateway = new StickerSearchGateway();
      const useCase: StickerPanelUseCase = createStickerPanelUseCase(gateway);

      const result: StickerPanelEntry[] = await useCase.searchRegularStickers('к', ['ru-RU']);

      expect(gateway.sentTypes.length).assertEqual(0);
      expect(result.length).assertEqual(0);
    });
  });
}
