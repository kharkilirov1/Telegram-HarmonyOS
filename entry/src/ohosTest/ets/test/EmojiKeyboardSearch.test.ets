import { describe, expect, it } from '@ohos/hypium';
import { AnyAppCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import {
  createStickerPanelUseCase,
  EmojiKeyboardSearchResult,
  StickerPanelUseCase
} from '../../../main/ets/domain/usecases/stickerPanel';
import { TdObject } from '../../../main/ets/models/TdTypes';

const CUSTOM_EMOJI_STICKER: string =
  '{"@type":"sticker","id":10,"width":100,"height":100,"emoji":"🐱",' +
  '"format":{"@type":"stickerFormatTgs"},' +
  '"full_type":{"@type":"stickerFullTypeCustomEmoji",' +
  '"custom_emoji_id":5368324170671202286,"needs_repainting":false},' +
  '"sticker":{"@type":"file","id":7,"local":{"@type":"localFile",' +
  '"path":"","is_downloading_completed":false},"remote":{"@type":"remoteFile",' +
  '"id":"remote-custom-emoji"}},' +
  '"thumbnail":{"@type":"thumbnail","file":{"@type":"file","id":8,' +
  '"local":{"@type":"localFile","path":"","is_downloading_completed":false}}}}';

class EmojiSearchGateway implements TdGatewayPort {
  sentTypes: string[] = [];

  async initialize(): Promise<void> {}

  async send(command: AnyAppCommand): Promise<Object> {
    this.sentTypes.push(command.type);
    if (command.type === 'searchEmojis') {
      return TdObject.fromJSON('{"@type":"emojiKeywords","emoji_keywords":[' +
        '{"@type":"emojiKeyword","emoji":"🐱","keyword":"кот"},' +
        '{"@type":"emojiKeyword","emoji":"🐱","keyword":"кошка"},' +
        '{"@type":"emojiKeyword","emoji":"🐈","keyword":"кот"}]}');
    }
    if (command.type === 'searchCustomEmojiStickers') {
      return TdObject.fromJSON('{"@type":"stickers","stickers":[' +
        CUSTOM_EMOJI_STICKER + ',' + CUSTOM_EMOJI_STICKER + ']}');
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

export default function emojiKeyboardSearchTest() {
  describe('EmojiKeyboardSearch', () => {
    it('combines deduplicated Unicode and real custom emoji results', 0, async () => {
      const gateway = new EmojiSearchGateway();
      const useCase: StickerPanelUseCase = createStickerPanelUseCase(gateway);

      const result: EmojiKeyboardSearchResult = await useCase.searchEmojiKeyboard(
        'кот', ['ru-RU', 'en-US']);

      expect(gateway.sentTypes.length).assertEqual(2);
      expect(gateway.sentTypes[0]).assertEqual('searchEmojis');
      expect(gateway.sentTypes[1]).assertEqual('searchCustomEmojiStickers');
      expect(result.unicodeEmoji.length).assertEqual(2);
      expect(result.unicodeEmoji[0]).assertEqual('🐱');
      expect(result.unicodeEmoji[1]).assertEqual('🐈');
      expect(result.customEmoji.length).assertEqual(1);
      expect(result.customEmoji[0].customEmojiId).assertEqual('5368324170671202286');
      expect(result.customEmoji[0].remoteFileId).assertEqual('remote-custom-emoji');
    });

    it('does not hit TDLib for one-character queries', 0, async () => {
      const gateway = new EmojiSearchGateway();
      const useCase: StickerPanelUseCase = createStickerPanelUseCase(gateway);

      const result = await useCase.searchEmojiKeyboard('к', ['ru-RU']);

      expect(gateway.sentTypes.length).assertEqual(0);
      expect(result.unicodeEmoji.length).assertEqual(0);
      expect(result.customEmoji.length).assertEqual(0);
    });
  });
}
