import { describe, expect, it } from '@ohos/hypium';
import { BotMenuInfo, parseBotMenuInfo } from '../../../main/ets/domain/usecases/loadBotMenu';
import { TdObject } from '../../../main/ets/core/utils/tdAccessors';

export default function loadBotMenuTest() {
  describe('LoadBotMenu', () => {
    it('parses web app metadata and bot commands from userFullInfo', 0, () => {
      const response = TdObject.fromJSON(
        '{"@type":"userFullInfo","bot_info":{"@type":"botInfo",' +
          '"menu_button":{"@type":"botMenuButton","text":"Open app","url":"https://example.com/app"},' +
          '"commands":[{"@type":"botCommand","command":"start","description":"Start bot"},' +
          '{"@type":"botCommand","command":"help","description":"Get help"}]}}'
      );

      const info: BotMenuInfo = parseBotMenuInfo(response);
      expect(info.isAvailable).assertTrue();
      expect(info.title).assertEqual('Open app');
      expect(info.url).assertEqual('https://example.com/app');
      expect(info.commands.length).assertEqual(2);
      expect(info.commands[0].command).assertEqual('start');
      expect(info.commands[1].description).assertEqual('Get help');
    });

    it('keeps menu hidden for non-userFullInfo responses', 0, () => {
      const info: BotMenuInfo = parseBotMenuInfo(TdObject.fromJSON('{"@type":"error","code":404}'));
      expect(info.isAvailable).assertFalse();
      expect(info.commands.length).assertEqual(0);
    });
  });
}
