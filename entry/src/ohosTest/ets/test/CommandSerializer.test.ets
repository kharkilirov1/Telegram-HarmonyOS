import { describe, it, expect } from '@ohos/hypium';
import {
  createCancelDownloadFileCommand,
  createDeleteMessagesCommand,
  createDownloadFileCommand,
  createEditMessageTextCommand,
  createForwardMessagesCommand,
  createGetChatHistoryCommand,
  createLoadChatsCommand,
  createPinChatMessageCommand,
  createRequestPasswordRecoveryCommand,
  createSendMediaMessageCommand,
  createSendMessageCommand,
  createSetChatMuteCommand,
  createToggleChatIsMarkedAsUnreadCommand,
  createViewMessagesCommand
} from '../../../main/ets/core/model/AppCommand';
import {
  buildTdlibRequestJson,
  SerializedCommand,
  serializeCommand
} from '../../../main/ets/infra/td/serialization/CommandSerializer';
import { TdObject } from '../../../main/ets/models/TdTypes';

/**
 * Unit tests for CommandSerializer.
 * Covers the handler-dispatch refactor without requiring native TDLib.
 */
export default function commandSerializerTest() {
  describe('CommandSerializer', () => {

    describe('dispatch handlers', () => {
      it('should serialize simple auth and list commands', 0, () => {
        const recovery = serializeCommand(createRequestPasswordRecoveryCommand());
        expect(recovery.method).assertEqual('requestAuthenticationPasswordRecovery');

        const loadChats = serializeCommand(createLoadChatsCommand(35));
        expect(loadChats.method).assertEqual('loadChats');
        expect(loadChats.params.getNumber('limit')).assertEqual(35);
        expect(loadChats.params.getString('_chat_list_json')).assertEqual('{"@type":"chatListMain"}');
      });

      it('should serialize chat mutation commands', 0, () => {
        const mute = serializeCommand(createSetChatMuteCommand(100, 3600));
        expect(mute.method).assertEqual('setChatNotificationSettings');
        expect(mute.params.getNumber('chat_id')).assertEqual(100);
        expect(mute.params.getString('_notification_settings_json')
          .indexOf('"mute_for":3600') >= 0).assertTrue();

        const unread = serializeCommand(createToggleChatIsMarkedAsUnreadCommand(100, true));
        expect(unread.method).assertEqual('toggleChatIsMarkedAsUnread');
        expect(unread.params.getBool('is_marked_as_unread')).assertTrue();
      });

      it('should serialize message send with reply raw json', 0, () => {
        const serialized = serializeCommand(createSendMessageCommand(200, 'hello "world"', '99'));

        expect(serialized.method).assertEqual('sendMessage');
        expect(serialized.params.getNumber('chat_id')).assertEqual(200);
        const content = serialized.params.getString('_input_message_content_json');
        expect(content.indexOf('"@type":"inputMessageText"') >= 0).assertTrue();
        expect(content.indexOf('hello \\"world\\"') >= 0).assertTrue();
        expect(serialized.params.getString('_reply_to_json'))
          .assertEqual('{"@type":"inputMessageReplyToMessage","message_id":99}');
      });

      it('should serialize media send as TDLib sendMessage content', 0, () => {
        const serialized = serializeCommand(createSendMediaMessageCommand(
          200,
          'photo',
          '/data/storage/el2/base/files/p.jpg',
          'caption',
          '88'
        ));

        expect(serialized.method).assertEqual('sendMessage');
        const content = serialized.params.getString('_input_message_content_json');
        expect(content.indexOf('"@type":"inputMessagePhoto"') >= 0).assertTrue();
        expect(content.indexOf('"@type":"inputFileLocal"') >= 0).assertTrue();
        expect(content.indexOf('/data/storage/el2/base/files/p.jpg') >= 0).assertTrue();
        expect(content.indexOf('"caption"') >= 0).assertTrue();
        expect(serialized.params.getString('_reply_to_json'))
          .assertEqual('{"@type":"inputMessageReplyToMessage","message_id":88}');
      });

      it('should serialize edit/delete/forward/pin message commands', 0, () => {
        const edit = serializeCommand(createEditMessageTextCommand(1, '900', 'new text'));
        expect(edit.method).assertEqual('editMessageText');
        expect(edit.params.getString('_message_id_json')).assertEqual('900');
        expect(edit.params.getString('_input_message_content_json').indexOf('new text') >= 0).assertTrue();

        const deleteMessages = serializeCommand(createDeleteMessagesCommand(1, ['900', '901'], true));
        expect(deleteMessages.method).assertEqual('deleteMessages');
        expect(deleteMessages.params.getString('_message_ids_json')).assertEqual('[900,901]');
        expect(deleteMessages.params.getBool('revoke')).assertTrue();

        const forward = serializeCommand(createForwardMessagesCommand(2, 1, ['900'], true, false));
        expect(forward.method).assertEqual('forwardMessages');
        expect(forward.params.getNumber('chat_id')).assertEqual(2);
        expect(forward.params.getNumber('from_chat_id')).assertEqual(1);
        expect(forward.params.getString('_message_ids_json')).assertEqual('[900]');
        expect(forward.params.getBool('send_copy')).assertTrue();

        const pin = serializeCommand(createPinChatMessageCommand(1, '900', true, true));
        expect(pin.method).assertEqual('pinChatMessage');
        expect(pin.params.getString('_message_id_json')).assertEqual('900');
        expect(pin.params.getBool('disable_notification')).assertTrue();
        expect(pin.params.getBool('only_for_self')).assertTrue();
      });

      it('should serialize history/view/download commands', 0, () => {
        const history = serializeCommand(createGetChatHistoryCommand(1, '700', -10, 50, true));
        expect(history.method).assertEqual('getChatHistory');
        expect(history.params.getString('_from_message_id_json')).assertEqual('700');
        expect(history.params.getNumber('offset')).assertEqual(-10);
        expect(history.params.getBool('only_local')).assertTrue();

        const view = serializeCommand(createViewMessagesCommand(1, ['700', '701']));
        expect(view.method).assertEqual('viewMessages');
        expect(view.params.getString('_message_ids_json')).assertEqual('[700,701]');
        expect(view.params.getBool('force_read')).assertTrue();

        const download = serializeCommand(createDownloadFileCommand(42, 5, true));
        expect(download.method).assertEqual('downloadFile');
        expect(download.params.getNumber('file_id')).assertEqual(42);
        expect(download.params.getNumber('priority')).assertEqual(5);
        expect(download.params.getBool('synchronous')).assertTrue();

        const cancel = serializeCommand(createCancelDownloadFileCommand(42, true));
        expect(cancel.method).assertEqual('cancelDownloadFile');
        expect(cancel.params.getBool('only_if_pending')).assertTrue();
      });
    });

    describe('buildTdlibRequestJson', () => {
      it('should expand _field_json values as raw nested json', 0, () => {
        const serialized = serializeCommand(createSendMessageCommand(1, 'hello', '500'));
        const json = buildTdlibRequestJson(serialized.method, serialized.params);

        expect(json.indexOf('"@type":"sendMessage"') >= 0).assertTrue();
        expect(json.indexOf('"chat_id":1') >= 0).assertTrue();
        expect(json.indexOf('"input_message_content":{"@type":"inputMessageText"') >= 0).assertTrue();
        expect(json.indexOf('"reply_to":{"@type":"inputMessageReplyToMessage","message_id":500}') >= 0)
          .assertTrue();
      });

      it('should serialize primitive params', 0, () => {
        const params = new TdObject();
        params.setString('query', 'a "quote"');
        params.setNumber('limit', 20);
        params.setBool('only_local', false);

        const json = buildTdlibRequestJson('searchChatMessages', params);
        expect(json.indexOf('"@type":"searchChatMessages"') >= 0).assertTrue();
        expect(json.indexOf('"query":"a \\"quote\\""') >= 0).assertTrue();
        expect(json.indexOf('"limit":20') >= 0).assertTrue();
        expect(json.indexOf('"only_local":false') >= 0).assertTrue();
      });

      it('should keep unknown command safe', 0, () => {
        const command = new SerializedCommand();
        expect(command.method).assertEqual('');
        expect(command.params.isEmpty()).assertTrue();
      });
    });
  });
}
