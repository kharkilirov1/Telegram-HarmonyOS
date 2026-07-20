import { describe, it, expect } from '@ohos/hypium';
import {
  cloneChat,
  cloneUser,
  cloneChatsState,
  cloneMessagesState,
  cloneUsersState,
  cloneFilesState,
  cloneAuthState,
  cloneConnectionState,
  cloneAppState
} from '../../../main/ets/core/utils/stateClone';
import {
  Chat,
  ChatLastMessage,
  User,
  AppState,
  AuthState,
  ConnectionState,
  ChatsState,
  MessagesState,
  UsersState,
  FilesState,
  Message,
  PendingMessage,
  FileTransfer
} from '../../../main/ets/core/model/AppState';
import { CustomEmojiTextEntity } from '../../../main/ets/core/model/AppCommand';

/**
 * Unit tests for stateClone utilities — validates immutable cloning
 * of all AppState slices and individual entities.
 */

export default function stateCloneTest() {
  describe('StateClone', () => {

    // -----------------------------------------------------------------------
    // cloneChat — preserves all fields
    // -----------------------------------------------------------------------
    describe('cloneChat', () => {

      it('should preserve all Chat fields', 0, () => {
        const chat = new Chat();
        chat.id = 100;
        chat.type = 'supergroup';
        chat.peerUserId = 0;
        chat.accentColorId = 5;
        chat.title = 'Test Group';
        chat.unreadCount = 3;
        chat.unreadMentionCount = 1;
        chat.muteForSeconds = 3600;
        chat.lastReadOutboxMessageId = '500';
        chat.lastReadInboxMessageId = '499';
        chat.draftText = 'Draft message';
        chat.draftCustomEmojiEntities = [new CustomEmojiTextEntity(0, 5, '123456789')];
        chat.draftReplyToMessageId = '450';
        chat.isPinned = true;
        chat.photoSmall = '/path/to/photo.jpg';
        chat.photoSmallFileId = 42;
        chat.order = '9999999999';
        chat.memberCount = 150;
        chat.description = 'A test group';
        chat.supergroupId = 200;
        chat.inviteLink = 'https://t.me/+abc';
        chat.administratorCount = 3;

        const lm = new ChatLastMessage();
        lm.id = '498';
        lm.text = 'Last message text';
        lm.timestamp = 1700000000;
        chat.lastMessage = lm;

        const cloned = cloneChat(chat);

        expect(cloned.id).assertEqual(100);
        expect(cloned.type).assertEqual('supergroup');
        expect(cloned.peerUserId).assertEqual(0);
        expect(cloned.accentColorId).assertEqual(5);
        expect(cloned.title).assertEqual('Test Group');
        expect(cloned.unreadCount).assertEqual(3);
        expect(cloned.unreadMentionCount).assertEqual(1);
        expect(cloned.muteForSeconds).assertEqual(3600);
        expect(cloned.lastReadOutboxMessageId).assertEqual('500');
        expect(cloned.lastReadInboxMessageId).assertEqual('499');
        expect(cloned.draftText).assertEqual('Draft message');
        expect(cloned.draftCustomEmojiEntities.length).assertEqual(1);
        expect(cloned.draftCustomEmojiEntities[0].customEmojiId).assertEqual('123456789');
        expect(cloned.draftCustomEmojiEntities === chat.draftCustomEmojiEntities).assertFalse();
        expect(cloned.draftReplyToMessageId).assertEqual('450');
        expect(cloned.isPinned).assertTrue();
        expect(cloned.photoSmall).assertEqual('/path/to/photo.jpg');
        expect(cloned.photoSmallFileId).assertEqual(42);
        expect(cloned.order).assertEqual('9999999999');
        expect(cloned.memberCount).assertEqual(150);
        expect(cloned.description).assertEqual('A test group');
        expect(cloned.supergroupId).assertEqual(200);
        expect(cloned.inviteLink).assertEqual('https://t.me/+abc');
        expect(cloned.administratorCount).assertEqual(3);

        expect(cloned.lastMessage !== undefined).assertTrue();
        expect(cloned.lastMessage!.id).assertEqual('498');
        expect(cloned.lastMessage!.text).assertEqual('Last message text');
        expect(cloned.lastMessage!.timestamp).assertEqual(1700000000);
      });

      it('should handle chat without lastMessage', 0, () => {
        const chat = new Chat();
        chat.id = 101;
        chat.title = 'No last message';

        const cloned = cloneChat(chat);
        expect(cloned.id).assertEqual(101);
        expect(cloned.lastMessage).assertEqual(undefined);
      });

      it('should produce independent clone — modifying clone does not affect original', 0, () => {
        const chat = new Chat();
        chat.id = 102;
        chat.title = 'Original';
        chat.unreadCount = 5;

        const lm = new ChatLastMessage();
        lm.id = '10';
        lm.text = 'Original LM';
        chat.lastMessage = lm;

        const cloned = cloneChat(chat);
        cloned.title = 'Modified';
        cloned.unreadCount = 99;
        cloned.lastMessage!.text = 'Modified LM';

        // Original should be unchanged
        expect(chat.title).assertEqual('Original');
        expect(chat.unreadCount).assertEqual(5);
        expect(chat.lastMessage!.text).assertEqual('Original LM');
      });
    });

    // -----------------------------------------------------------------------
    // cloneUser — preserves all fields
    // -----------------------------------------------------------------------
    describe('cloneUser', () => {

      it('should preserve all User fields', 0, () => {
        const user = new User();
        user.id = 1000;
        user.firstName = 'John';
        user.lastName = 'Doe';
        user.username = 'johndoe';
        user.accentColorId = 3;
        user.phoneNumber = '+1234567890';
        user.photoSmall = '/photos/small.jpg';
        user.photoBig = '/photos/big.jpg';
        user.photoSmallFileId = 77;
        user.status = 'online';
        user.isContact = true;
        user.isVerified = true;
        user.isScam = false;
        user.isFake = false;
        user.isPremium = true;
        user.bio = 'Hello there';

        const cloned = cloneUser(user);

        expect(cloned.id).assertEqual(1000);
        expect(cloned.firstName).assertEqual('John');
        expect(cloned.lastName).assertEqual('Doe');
        expect(cloned.username).assertEqual('johndoe');
        expect(cloned.accentColorId).assertEqual(3);
        expect(cloned.phoneNumber).assertEqual('+1234567890');
        expect(cloned.photoSmall).assertEqual('/photos/small.jpg');
        expect(cloned.photoBig).assertEqual('/photos/big.jpg');
        expect(cloned.photoSmallFileId).assertEqual(77);
        expect(cloned.status).assertEqual('online');
        expect(cloned.isContact).assertTrue();
        expect(cloned.isVerified).assertTrue();
        expect(cloned.isScam).assertFalse();
        expect(cloned.isFake).assertFalse();
        expect(cloned.isPremium).assertTrue();
        expect(cloned.bio).assertEqual('Hello there');
      });

      it('should produce independent clone — modifying clone does not affect original', 0, () => {
        const user = new User();
        user.id = 1001;
        user.firstName = 'Original';
        user.isPremium = false;

        const cloned = cloneUser(user);
        cloned.firstName = 'Modified';
        cloned.isPremium = true;

        expect(user.firstName).assertEqual('Original');
        expect(user.isPremium).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // cloneChatsState — Map-based cloning
    // -----------------------------------------------------------------------
    describe('cloneChatsState', () => {

      it('should clone chats map and orderedChatIds', 0, () => {
        const state = new ChatsState();
        const chat1 = new Chat();
        chat1.id = 1;
        chat1.title = 'Chat One';
        const chat2 = new Chat();
        chat2.id = 2;
        chat2.title = 'Chat Two';

        state.chats.set(1, chat1);
        state.chats.set(2, chat2);
        state.orderedChatIds = [1, 2];
        state.isLoading = true;
        state.hasMore = false;
        state.loadPhase = 'pagination';

        const cloned = cloneChatsState(state);

        expect(cloned.chats.size).assertEqual(2);
        expect(cloned.chats.get(1)!.title).assertEqual('Chat One');
        expect(cloned.chats.get(2)!.title).assertEqual('Chat Two');
        expect(cloned.orderedChatIds.length).assertEqual(2);
        expect(cloned.orderedChatIds[0]).assertEqual(1);
        expect(cloned.orderedChatIds[1]).assertEqual(2);
        expect(cloned.isLoading).assertTrue();
        expect(cloned.hasMore).assertFalse();
        expect(cloned.loadPhase).assertEqual('pagination');
      });

      it('should produce independent orderedChatIds array', 0, () => {
        const state = new ChatsState();
        state.orderedChatIds = [1, 2, 3];

        const cloned = cloneChatsState(state);
        cloned.orderedChatIds.push(4);

        expect(state.orderedChatIds.length).assertEqual(3);
        expect(cloned.orderedChatIds.length).assertEqual(4);
      });

      it('should produce independent chats map', 0, () => {
        const state = new ChatsState();
        const chat = new Chat();
        chat.id = 10;
        state.chats.set(10, chat);

        const cloned = cloneChatsState(state);
        const newChat = new Chat();
        newChat.id = 20;
        cloned.chats.set(20, newChat);

        expect(state.chats.size).assertEqual(1);
        expect(cloned.chats.size).assertEqual(2);
      });
    });

    // -----------------------------------------------------------------------
    // cloneMessagesState — Map<number, Map<string, Message>>
    // -----------------------------------------------------------------------
    describe('cloneMessagesState', () => {

      it('should clone outer messages map', 0, () => {
        const state = new MessagesState();
        const innerMap = new Map<string, Message>();
        const msg = new Message();
        msg.id = '1';
        msg.chatId = 100;
        innerMap.set('1', msg);
        state.messages.set(100, innerMap);

        const cloned = cloneMessagesState(state);
        expect(cloned.messages.size).assertEqual(1);
        expect(cloned.messages.get(100)!.get('1')!.chatId).assertEqual(100);
      });

      it('should produce independent outer map — adding chat does not affect original', 0, () => {
        const state = new MessagesState();
        const innerMap = new Map<string, Message>();
        state.messages.set(1, innerMap);

        const cloned = cloneMessagesState(state);
        cloned.messages.set(2, new Map<string, Message>());

        expect(state.messages.size).assertEqual(1);
        expect(cloned.messages.size).assertEqual(2);
      });
    });

    // -----------------------------------------------------------------------
    // cloneUsersState
    // -----------------------------------------------------------------------
    describe('cloneUsersState', () => {

      it('should clone users map', 0, () => {
        const state = new UsersState();
        const user = new User();
        user.id = 500;
        user.firstName = 'Alice';
        state.users.set(500, user);

        const cloned = cloneUsersState(state);
        expect(cloned.users.size).assertEqual(1);
        expect(cloned.users.get(500)!.firstName).assertEqual('Alice');
      });

      it('should produce independent map', 0, () => {
        const state = new UsersState();
        const user = new User();
        user.id = 600;
        state.users.set(600, user);

        const cloned = cloneUsersState(state);
        const newUser = new User();
        newUser.id = 700;
        cloned.users.set(700, newUser);

        expect(state.users.size).assertEqual(1);
        expect(cloned.users.size).assertEqual(2);
      });
    });

    // -----------------------------------------------------------------------
    // cloneFilesState
    // -----------------------------------------------------------------------
    describe('cloneFilesState', () => {

      it('should clone transfers map', 0, () => {
        const state = new FilesState();
        const transfer = new FileTransfer();
        transfer.fileId = 42;
        transfer.localPath = '/tmp/file.mp4';
        transfer.isDownloadingCompleted = true;
        transfer.size = 1024;
        state.transfers.set(42, transfer);

        const cloned = cloneFilesState(state);
        expect(cloned.transfers.size).assertEqual(1);
        expect(cloned.transfers.get(42)!.localPath).assertEqual('/tmp/file.mp4');
        expect(cloned.transfers.get(42)!.isDownloadingCompleted).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // cloneAuthState
    // -----------------------------------------------------------------------
    describe('cloneAuthState', () => {

      it('should clone all auth fields', 0, () => {
        const auth = new AuthState();
        auth.status = 'waitCode';
        auth.userId = 123;
        auth.phoneNumber = '+1234567890';
        auth.codeType = 'sms';
        auth.codeLength = 6;
        auth.codeTimeout = 120;
        auth.nextCodeType = 'call';
        auth.passwordHint = 'pet name';
        auth.qrCodeLink = 'tg://login?token=abc';
        auth.error = 'Some error';

        const cloned = cloneAuthState(auth);
        expect(cloned.status).assertEqual('waitCode');
        expect(cloned.userId).assertEqual(123);
        expect(cloned.phoneNumber).assertEqual('+1234567890');
        expect(cloned.codeType).assertEqual('sms');
        expect(cloned.codeLength).assertEqual(6);
        expect(cloned.codeTimeout).assertEqual(120);
        expect(cloned.nextCodeType).assertEqual('call');
        expect(cloned.passwordHint).assertEqual('pet name');
        expect(cloned.qrCodeLink).assertEqual('tg://login?token=abc');
        expect(cloned.error).assertEqual('Some error');
      });
    });

    // -----------------------------------------------------------------------
    // cloneConnectionState
    // -----------------------------------------------------------------------
    describe('cloneConnectionState', () => {

      it('should clone connection fields', 0, () => {
        const conn = new ConnectionState();
        conn.status = 'ready';
        conn.lastUpdated = 1700000000;

        const cloned = cloneConnectionState(conn);
        expect(cloned.status).assertEqual('ready');
        expect(cloned.lastUpdated).assertEqual(1700000000);
      });
    });

    // -----------------------------------------------------------------------
    // cloneAppState — full state clone
    // -----------------------------------------------------------------------
    describe('cloneAppState', () => {

      it('should clone all substates and version', 0, () => {
        const state = new AppState();
        state.version = 42;
        state.auth.status = 'ready';
        state.auth.userId = 100;
        state.connection.status = 'ready';

        const chat = new Chat();
        chat.id = 1;
        chat.title = 'General';
        state.chats.chats.set(1, chat);
        state.chats.orderedChatIds = [1];

        const user = new User();
        user.id = 200;
        user.firstName = 'Bob';
        state.users.users.set(200, user);

        const cloned = cloneAppState(state);

        expect(cloned.version).assertEqual(42);
        expect(cloned.auth.status).assertEqual('ready');
        expect(cloned.auth.userId).assertEqual(100);
        expect(cloned.connection.status).assertEqual('ready');
        expect(cloned.chats.chats.size).assertEqual(1);
        expect(cloned.chats.chats.get(1)!.title).assertEqual('General');
        expect(cloned.chats.orderedChatIds.length).assertEqual(1);
        expect(cloned.users.users.size).assertEqual(1);
        expect(cloned.users.users.get(200)!.firstName).assertEqual('Bob');
      });

      it('should produce fully independent state', 0, () => {
        const state = new AppState();
        state.version = 1;
        const chat = new Chat();
        chat.id = 10;
        chat.title = 'Original';
        state.chats.chats.set(10, chat);

        const cloned = cloneAppState(state);
        cloned.version = 99;
        cloned.auth.status = 'waitPhoneNumber';

        const newChat = new Chat();
        newChat.id = 20;
        cloned.chats.chats.set(20, newChat);

        // Original unchanged
        expect(state.version).assertEqual(1);
        expect(state.auth.status).assertEqual('notInitialized');
        expect(state.chats.chats.size).assertEqual(1);
      });
    });
  });
}
