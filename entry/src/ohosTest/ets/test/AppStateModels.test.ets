import { describe, it, expect } from '@ohos/hypium';
import {
  TextEntity,
  MessageQuoteEntity,
  MessageContent,
  Message,
  Chat,
  User,
  FileTransfer,
  PollOption,
  AuthState,
  ConnectionState,
  ChatLastMessage,
  ChatTypingInfo,
  ChatsState,
  MessagesState,
  FilesState,
  UsersState,
  AppState,
  createInitialAppState
} from '../../../main/ets/core/model/AppState';
import type {
  MessageContentType,
  MessageSendStatus,
  UserStatusType,
  AuthStatus,
  ConnectionStatus,
  ChatType,
  ChatsLoadPhase
} from '../../../main/ets/core/model/AppState';

/**
 * Unit tests for AppState model classes — default values, type correctness.
 */

export default function appStateModelsTest() {
  describe('AppStateModels', () => {

    // -----------------------------------------------------------------------
    // TextEntity defaults
    // -----------------------------------------------------------------------
    describe('TextEntity', () => {

      it('should default offset to 0', 0, () => {
        const e = new TextEntity();
        expect(e.offset).assertEqual(0);
      });

      it('should default length to 0', 0, () => {
        const e = new TextEntity();
        expect(e.length).assertEqual(0);
      });

      it('should default type to empty string', 0, () => {
        const e = new TextEntity();
        expect(e.type).assertEqual('');
      });

      it('should default url to empty string', 0, () => {
        const e = new TextEntity();
        expect(e.url).assertEqual('');
      });

      it('should default userId to 0', 0, () => {
        const e = new TextEntity();
        expect(e.userId).assertEqual(0);
      });

      it('should default language to empty string', 0, () => {
        const e = new TextEntity();
        expect(e.language).assertEqual('');
      });
    });

    // -----------------------------------------------------------------------
    // MessageQuoteEntity defaults
    // -----------------------------------------------------------------------
    describe('MessageQuoteEntity', () => {

      it('should default offset to 0', 0, () => {
        const e = new MessageQuoteEntity();
        expect(e.offset).assertEqual(0);
      });

      it('should default length to 0', 0, () => {
        const e = new MessageQuoteEntity();
        expect(e.length).assertEqual(0);
      });

      it('should default isCollapsed to false', 0, () => {
        const e = new MessageQuoteEntity();
        expect(e.isCollapsed).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // MessageContent defaults
    // -----------------------------------------------------------------------
    describe('MessageContent', () => {

      it('should default type to text', 0, () => {
        const c = new MessageContent();
        expect(c.type).assertEqual('text');
      });

      it('should default text to empty string', 0, () => {
        const c = new MessageContent();
        expect(c.text).assertEqual('');
      });

      it('should default caption to empty string', 0, () => {
        const c = new MessageContent();
        expect(c.caption).assertEqual('');
      });

      it('should default textEntities to empty array', 0, () => {
        const c = new MessageContent();
        expect(c.textEntities.length).assertEqual(0);
      });

      it('should default captionEntities to empty array', 0, () => {
        const c = new MessageContent();
        expect(c.captionEntities.length).assertEqual(0);
      });

      it('should default quoteEntities to empty array', 0, () => {
        const c = new MessageContent();
        expect(c.quoteEntities.length).assertEqual(0);
      });

      it('should default photoPath to empty string', 0, () => {
        const c = new MessageContent();
        expect(c.photoPath).assertEqual('');
      });

      it('should default photoFileId to 0', 0, () => {
        const c = new MessageContent();
        expect(c.photoFileId).assertEqual(0);
      });

      it('should default photoWidth to 0', 0, () => {
        const c = new MessageContent();
        expect(c.photoWidth).assertEqual(0);
      });

      it('should default photoHeight to 0', 0, () => {
        const c = new MessageContent();
        expect(c.photoHeight).assertEqual(0);
      });

      it('should default videoFileId to 0', 0, () => {
        const c = new MessageContent();
        expect(c.videoFileId).assertEqual(0);
      });

      it('should default videoDuration to 0', 0, () => {
        const c = new MessageContent();
        expect(c.videoDuration).assertEqual(0);
      });

      it('should default documentFileId to 0', 0, () => {
        const c = new MessageContent();
        expect(c.documentFileId).assertEqual(0);
      });

      it('should default fileName to empty string', 0, () => {
        const c = new MessageContent();
        expect(c.fileName).assertEqual('');
      });

      it('should default fileSize to 0', 0, () => {
        const c = new MessageContent();
        expect(c.fileSize).assertEqual(0);
      });

      it('should default mimeType to empty string', 0, () => {
        const c = new MessageContent();
        expect(c.mimeType).assertEqual('');
      });

      it('should default voiceDuration to 0', 0, () => {
        const c = new MessageContent();
        expect(c.voiceDuration).assertEqual(0);
      });

      it('should default voiceWaveform to empty string', 0, () => {
        const c = new MessageContent();
        expect(c.voiceWaveform).assertEqual('');
      });

      it('should default isVoiceListened to false', 0, () => {
        const c = new MessageContent();
        expect(c.isVoiceListened).assertFalse();
      });

      it('should default stickerEmoji to empty string', 0, () => {
        const c = new MessageContent();
        expect(c.stickerEmoji).assertEqual('');
      });

      it('should default isAnimatedSticker to false', 0, () => {
        const c = new MessageContent();
        expect(c.isAnimatedSticker).assertFalse();
      });

      it('should default pollOptions to empty array', 0, () => {
        const c = new MessageContent();
        expect(c.pollOptions.length).assertEqual(0);
      });

      it('should default pollIsAnonymous to true', 0, () => {
        const c = new MessageContent();
        expect(c.pollIsAnonymous).assertTrue();
      });

      it('should default pollType to regular', 0, () => {
        const c = new MessageContent();
        expect(c.pollType).assertEqual('regular');
      });

      it('should default pollIsClosed to false', 0, () => {
        const c = new MessageContent();
        expect(c.pollIsClosed).assertFalse();
      });

      it('should default locationLatitude to 0', 0, () => {
        const c = new MessageContent();
        expect(c.locationLatitude).assertEqual(0);
      });

      it('should default locationLongitude to 0', 0, () => {
        const c = new MessageContent();
        expect(c.locationLongitude).assertEqual(0);
      });

      it('should default audioDuration to 0', 0, () => {
        const c = new MessageContent();
        expect(c.audioDuration).assertEqual(0);
      });

      it('should default audioTitle to empty string', 0, () => {
        const c = new MessageContent();
        expect(c.audioTitle).assertEqual('');
      });

      it('should default audioPerformer to empty string', 0, () => {
        const c = new MessageContent();
        expect(c.audioPerformer).assertEqual('');
      });
    });

    // -----------------------------------------------------------------------
    // Message defaults
    // -----------------------------------------------------------------------
    describe('Message', () => {

      it('should default id to "0"', 0, () => {
        const m = new Message();
        expect(m.id).assertEqual('0');
      });

      it('should default chatId to 0', 0, () => {
        const m = new Message();
        expect(m.chatId).assertEqual(0);
      });

      it('should default senderId to 0', 0, () => {
        const m = new Message();
        expect(m.senderId).assertEqual(0);
      });

      it('should default senderChatId to 0', 0, () => {
        const m = new Message();
        expect(m.senderChatId).assertEqual(0);
      });

      it('should default mediaAlbumId to "0"', 0, () => {
        const m = new Message();
        expect(m.mediaAlbumId).assertEqual('0');
      });

      it('should default timestamp to 0', 0, () => {
        const m = new Message();
        expect(m.timestamp).assertEqual(0);
      });

      it('should default isOutgoing to false', 0, () => {
        const m = new Message();
        expect(m.isOutgoing).assertFalse();
      });

      it('should default isRead to false', 0, () => {
        const m = new Message();
        expect(m.isRead).assertFalse();
      });

      it('should default isPending to false', 0, () => {
        const m = new Message();
        expect(m.isPending).assertFalse();
      });

      it('should default editDate to 0', 0, () => {
        const m = new Message();
        expect(m.editDate).assertEqual(0);
      });

      it('should default replyToMessageId to "0"', 0, () => {
        const m = new Message();
        expect(m.replyToMessageId).assertEqual('0');
      });

      it('should default replyIsQuote to false', 0, () => {
        const m = new Message();
        expect(m.replyIsQuote).assertFalse();
      });

      it('should default replyQuoteText to empty string', 0, () => {
        const m = new Message();
        expect(m.replyQuoteText).assertEqual('');
      });

      it('should default replyQuoteOffset to -1', 0, () => {
        const m = new Message();
        expect(m.replyQuoteOffset).assertEqual(-1);
      });

      it('should default sendStatus to none', 0, () => {
        const m = new Message();
        expect(m.sendStatus).assertEqual('none');
      });

      it('should default sendErrorCode to 0', 0, () => {
        const m = new Message();
        expect(m.sendErrorCode).assertEqual(0);
      });

      it('should default sendErrorMessage to empty string', 0, () => {
        const m = new Message();
        expect(m.sendErrorMessage).assertEqual('');
      });

      it('should have a default MessageContent', 0, () => {
        const m = new Message();
        expect(m.content.type).assertEqual('text');
        expect(m.content.text).assertEqual('');
      });
    });

    // -----------------------------------------------------------------------
    // Chat defaults
    // -----------------------------------------------------------------------
    describe('Chat', () => {

      it('should default id to 0', 0, () => {
        const c = new Chat();
        expect(c.id).assertEqual(0);
      });

      it('should default type to private', 0, () => {
        const c = new Chat();
        expect(c.type).assertEqual('private');
      });

      it('should default title to empty string', 0, () => {
        const c = new Chat();
        expect(c.title).assertEqual('');
      });

      it('should default unreadCount to 0', 0, () => {
        const c = new Chat();
        expect(c.unreadCount).assertEqual(0);
      });

      it('should default unreadMentionCount to 0', 0, () => {
        const c = new Chat();
        expect(c.unreadMentionCount).assertEqual(0);
      });

      it('should default muteForSeconds to 0', 0, () => {
        const c = new Chat();
        expect(c.muteForSeconds).assertEqual(0);
      });

      it('should default isPinned to false', 0, () => {
        const c = new Chat();
        expect(c.isPinned).assertFalse();
      });

      it('should default order to "0"', 0, () => {
        const c = new Chat();
        expect(c.order).assertEqual('0');
      });

      it('should default peerUserId to 0', 0, () => {
        const c = new Chat();
        expect(c.peerUserId).assertEqual(0);
      });

      it('should default accentColorId to -1', 0, () => {
        const c = new Chat();
        expect(c.accentColorId).assertEqual(-1);
      });

      it('should default lastReadOutboxMessageId to "0"', 0, () => {
        const c = new Chat();
        expect(c.lastReadOutboxMessageId).assertEqual('0');
      });

      it('should default lastReadInboxMessageId to "0"', 0, () => {
        const c = new Chat();
        expect(c.lastReadInboxMessageId).assertEqual('0');
      });

      it('should default photoSmall to empty string', 0, () => {
        const c = new Chat();
        expect(c.photoSmall).assertEqual('');
      });

      it('should default memberCount to 0', 0, () => {
        const c = new Chat();
        expect(c.memberCount).assertEqual(0);
      });

      it('should default description to empty string', 0, () => {
        const c = new Chat();
        expect(c.description).assertEqual('');
      });

      it('should default draftText to empty string', 0, () => {
        const c = new Chat();
        expect(c.draftText).assertEqual('');
      });

      it('should default draftReplyToMessageId to "0"', 0, () => {
        const c = new Chat();
        expect(c.draftReplyToMessageId).assertEqual('0');
      });

      it('should default supergroupId to 0', 0, () => {
        const c = new Chat();
        expect(c.supergroupId).assertEqual(0);
      });

      it('should default inviteLink to empty string', 0, () => {
        const c = new Chat();
        expect(c.inviteLink).assertEqual('');
      });

      it('should default administratorCount to 0', 0, () => {
        const c = new Chat();
        expect(c.administratorCount).assertEqual(0);
      });
    });

    // -----------------------------------------------------------------------
    // User defaults
    // -----------------------------------------------------------------------
    describe('User', () => {

      it('should default id to 0', 0, () => {
        const u = new User();
        expect(u.id).assertEqual(0);
      });

      it('should default firstName to empty string', 0, () => {
        const u = new User();
        expect(u.firstName).assertEqual('');
      });

      it('should default lastName to empty string', 0, () => {
        const u = new User();
        expect(u.lastName).assertEqual('');
      });

      it('should default username to empty string', 0, () => {
        const u = new User();
        expect(u.username).assertEqual('');
      });

      it('should default accentColorId to -1', 0, () => {
        const u = new User();
        expect(u.accentColorId).assertEqual(-1);
      });

      it('should default phoneNumber to empty string', 0, () => {
        const u = new User();
        expect(u.phoneNumber).assertEqual('');
      });

      it('should default status to offline', 0, () => {
        const u = new User();
        expect(u.status).assertEqual('offline');
      });

      it('should default isContact to false', 0, () => {
        const u = new User();
        expect(u.isContact).assertFalse();
      });

      it('should default isVerified to false', 0, () => {
        const u = new User();
        expect(u.isVerified).assertFalse();
      });

      it('should default isScam to false', 0, () => {
        const u = new User();
        expect(u.isScam).assertFalse();
      });

      it('should default isFake to false', 0, () => {
        const u = new User();
        expect(u.isFake).assertFalse();
      });

      it('should default isPremium to false', 0, () => {
        const u = new User();
        expect(u.isPremium).assertFalse();
      });

      it('should default bio to empty string', 0, () => {
        const u = new User();
        expect(u.bio).assertEqual('');
      });

      it('should default photoSmall to empty string', 0, () => {
        const u = new User();
        expect(u.photoSmall).assertEqual('');
      });

      it('should default photoBig to empty string', 0, () => {
        const u = new User();
        expect(u.photoBig).assertEqual('');
      });
    });

    // -----------------------------------------------------------------------
    // FileTransfer defaults
    // -----------------------------------------------------------------------
    describe('FileTransfer', () => {

      it('should default fileId to 0', 0, () => {
        const f = new FileTransfer();
        expect(f.fileId).assertEqual(0);
      });

      it('should default localPath to empty string', 0, () => {
        const f = new FileTransfer();
        expect(f.localPath).assertEqual('');
      });

      it('should default isDownloadingActive to false', 0, () => {
        const f = new FileTransfer();
        expect(f.isDownloadingActive).assertFalse();
      });

      it('should default isDownloadingCompleted to false', 0, () => {
        const f = new FileTransfer();
        expect(f.isDownloadingCompleted).assertFalse();
      });

      it('should default size to 0', 0, () => {
        const f = new FileTransfer();
        expect(f.size).assertEqual(0);
      });

      it('should default expectedSize to 0', 0, () => {
        const f = new FileTransfer();
        expect(f.expectedSize).assertEqual(0);
      });

      it('should default downloadOffset to 0', 0, () => {
        const f = new FileTransfer();
        expect(f.downloadOffset).assertEqual(0);
      });

      it('should default downloadedPrefixSize to 0', 0, () => {
        const f = new FileTransfer();
        expect(f.downloadedPrefixSize).assertEqual(0);
      });

      it('should default downloadedSize to 0', 0, () => {
        const f = new FileTransfer();
        expect(f.downloadedSize).assertEqual(0);
      });
    });

    // -----------------------------------------------------------------------
    // PollOption defaults
    // -----------------------------------------------------------------------
    describe('PollOption', () => {

      it('should default text to empty string', 0, () => {
        const p = new PollOption();
        expect(p.text).assertEqual('');
      });

      it('should default voterCount to 0', 0, () => {
        const p = new PollOption();
        expect(p.voterCount).assertEqual(0);
      });

      it('should default votePercentage to 0', 0, () => {
        const p = new PollOption();
        expect(p.votePercentage).assertEqual(0);
      });

      it('should default isChosen to false', 0, () => {
        const p = new PollOption();
        expect(p.isChosen).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // MessageContentType values
    // -----------------------------------------------------------------------
    describe('MessageContentType values', () => {

      it('should accept text as valid MessageContentType', 0, () => {
        const mc = new MessageContent();
        mc.type = 'text';
        expect(mc.type).assertEqual('text');
      });

      it('should accept photo as valid MessageContentType', 0, () => {
        const mc = new MessageContent();
        mc.type = 'photo';
        expect(mc.type).assertEqual('photo');
      });

      it('should accept video as valid MessageContentType', 0, () => {
        const mc = new MessageContent();
        mc.type = 'video';
        expect(mc.type).assertEqual('video');
      });

      it('should accept document as valid MessageContentType', 0, () => {
        const mc = new MessageContent();
        mc.type = 'document';
        expect(mc.type).assertEqual('document');
      });

      it('should accept audio as valid MessageContentType', 0, () => {
        const mc = new MessageContent();
        mc.type = 'audio';
        expect(mc.type).assertEqual('audio');
      });

      it('should accept voice as valid MessageContentType', 0, () => {
        const mc = new MessageContent();
        mc.type = 'voice';
        expect(mc.type).assertEqual('voice');
      });

      it('should accept sticker as valid MessageContentType', 0, () => {
        const mc = new MessageContent();
        mc.type = 'sticker';
        expect(mc.type).assertEqual('sticker');
      });

      it('should accept poll as valid MessageContentType', 0, () => {
        const mc = new MessageContent();
        mc.type = 'poll';
        expect(mc.type).assertEqual('poll');
      });

      it('should accept animation as valid MessageContentType', 0, () => {
        const mc = new MessageContent();
        mc.type = 'animation';
        expect(mc.type).assertEqual('animation');
      });

      it('should accept videoNote as valid MessageContentType', 0, () => {
        const mc = new MessageContent();
        mc.type = 'videoNote';
        expect(mc.type).assertEqual('videoNote');
      });

      it('should accept location as valid MessageContentType', 0, () => {
        const mc = new MessageContent();
        mc.type = 'location';
        expect(mc.type).assertEqual('location');
      });

      it('should accept contact as valid MessageContentType', 0, () => {
        const mc = new MessageContent();
        mc.type = 'contact';
        expect(mc.type).assertEqual('contact');
      });

      it('should accept unknown as valid MessageContentType', 0, () => {
        const mc = new MessageContent();
        mc.type = 'unknown';
        expect(mc.type).assertEqual('unknown');
      });
    });

    // -----------------------------------------------------------------------
    // createInitialAppState
    // -----------------------------------------------------------------------
    describe('createInitialAppState', () => {

      it('should create state with notInitialized auth', 0, () => {
        const state = createInitialAppState();
        expect(state.auth.status).assertEqual('notInitialized');
      });

      it('should create state with connecting connection', 0, () => {
        const state = createInitialAppState();
        expect(state.connection.status).assertEqual('connecting');
      });

      it('should create state with version 1', 0, () => {
        const state = createInitialAppState();
        expect(state.version).assertEqual(1);
      });

      it('should create state with empty chats map', 0, () => {
        const state = createInitialAppState();
        expect(state.chats.chats.size).assertEqual(0);
      });

      it('should create state with empty users map', 0, () => {
        const state = createInitialAppState();
        expect(state.users.users.size).assertEqual(0);
      });

      it('should create state with empty files transfers', 0, () => {
        const state = createInitialAppState();
        expect(state.files.transfers.size).assertEqual(0);
      });
    });
  });
}
