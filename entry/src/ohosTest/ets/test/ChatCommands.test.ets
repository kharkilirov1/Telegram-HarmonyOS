import { describe, it, expect } from '@ohos/hypium';
import {
  createLoadChatsCommand,
  createOpenChatCommand,
  createCloseChatCommand,
  createSetChatMuteCommand,
  createPinChatMessageCommand,
  createUnpinChatMessageCommand,
  createDeleteChatHistoryCommand,
  createToggleChatIsMarkedAsUnreadCommand,
  createForwardMessagesCommand,
  createSendMediaMessageCommand,
  createSearchChatMessagesCommand
} from '../../../main/ets/core/model/AppCommand';

/**
 * Unit tests for the current chat command factory surface.
 * This replaces legacy ChatService singleton/API-existence checks with
 * command payload checks for the active usecase/gateway architecture.
 */
export default function chatCommandsTest() {
  describe('ChatCommands', () => {

    describe('chat loading and route commands', () => {
      it('should create loadChats command with limit', 0, () => {
        const command = createLoadChatsCommand(35);
        expect(command.type).assertEqual('loadChats');
        expect(command.payload.limit).assertEqual(35);
      });

      it('should create open and close chat commands', 0, () => {
        const openCommand = createOpenChatCommand(123);
        const closeCommand = createCloseChatCommand(123);

        expect(openCommand.type).assertEqual('openChat');
        expect(openCommand.payload.chatId).assertEqual(123);
        expect(closeCommand.type).assertEqual('closeChat');
        expect(closeCommand.payload.chatId).assertEqual(123);
      });
    });

    describe('chat state mutation commands', () => {
      it('should create mute and unmute payloads through setChatMute', 0, () => {
        const muteCommand = createSetChatMuteCommand(123, 3600);
        const unmuteCommand = createSetChatMuteCommand(123, 0);

        expect(muteCommand.type).assertEqual('setChatMute');
        expect(muteCommand.payload.chatId).assertEqual(123);
        expect(muteCommand.payload.muteForSeconds).assertEqual(3600);
        expect(unmuteCommand.payload.chatId).assertEqual(123);
        expect(unmuteCommand.payload.muteForSeconds).assertEqual(0);
      });

      it('should create pin and unpin message commands', 0, () => {
        const pinCommand = createPinChatMessageCommand(123, '456', true, true);
        const unpinCommand = createUnpinChatMessageCommand(123, '456');

        expect(pinCommand.type).assertEqual('pinChatMessage');
        expect(pinCommand.payload.chatId).assertEqual(123);
        expect(pinCommand.payload.messageId).assertEqual('456');
        expect(pinCommand.payload.disableNotification).assertTrue();
        expect(pinCommand.payload.onlyForSelf).assertTrue();
        expect(unpinCommand.type).assertEqual('unpinChatMessage');
        expect(unpinCommand.payload.chatId).assertEqual(123);
        expect(unpinCommand.payload.messageId).assertEqual('456');
      });

      it('should create delete history and unread-toggle commands', 0, () => {
        const deleteCommand = createDeleteChatHistoryCommand(123, false, true);
        const unreadCommand = createToggleChatIsMarkedAsUnreadCommand(123, true);

        expect(deleteCommand.type).assertEqual('deleteChatHistory');
        expect(deleteCommand.payload.chatId).assertEqual(123);
        expect(deleteCommand.payload.removeFromChatList).assertFalse();
        expect(deleteCommand.payload.revoke).assertTrue();
        expect(unreadCommand.type).assertEqual('toggleChatIsMarkedAsUnread');
        expect(unreadCommand.payload.chatId).assertEqual(123);
        expect(unreadCommand.payload.isMarkedAsUnread).assertTrue();
      });
    });

    describe('chat content commands', () => {
      it('should create forward messages payload', 0, () => {
        const command = createForwardMessagesCommand(200, 100, ['1', '2'], true, false);

        expect(command.type).assertEqual('forwardMessages');
        expect(command.payload.chatId).assertEqual(200);
        expect(command.payload.fromChatId).assertEqual(100);
        expect(command.payload.messageIds.length).assertEqual(2);
        expect(command.payload.messageIds[0]).assertEqual('1');
        expect(command.payload.messageIds[1]).assertEqual('2');
        expect(command.payload.sendCopy).assertTrue();
        expect(command.payload.removeCaption).assertFalse();
      });

      it('should create send media message payload', 0, () => {
        const command = createSendMediaMessageCommand(200, 'photo', '/data/storage/el2/base/files/p.jpg',
          'caption', '99');

        expect(command.type).assertEqual('sendMediaMessage');
        expect(command.payload.chatId).assertEqual(200);
        expect(command.payload.mediaKind).assertEqual('photo');
        expect(command.payload.localPath).assertEqual('/data/storage/el2/base/files/p.jpg');
        expect(command.payload.caption).assertEqual('caption');
        expect(command.payload.replyToMessageId).assertEqual('99');
      });

      it('should create search chat messages payload', 0, () => {
        const command = createSearchChatMessagesCommand(123, 'telegram', '50', 5, 25);

        expect(command.type).assertEqual('searchChatMessages');
        expect(command.payload.chatId).assertEqual(123);
        expect(command.payload.query).assertEqual('telegram');
        expect(command.payload.fromMessageId).assertEqual('50');
        expect(command.payload.offset).assertEqual(5);
        expect(command.payload.limit).assertEqual(25);
      });
    });
  });
}
