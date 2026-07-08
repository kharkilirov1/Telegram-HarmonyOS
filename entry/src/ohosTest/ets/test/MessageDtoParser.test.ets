import { describe, it, expect } from '@ohos/hypium';
import {
  MessageContentType,
  MessageContentDto,
  MessageDto,
  TextEntityDto,
  MessageQuoteEntityDto,
  PollOptionDto,
  MessageUpdateDto,
  applyMessageUpdate,
  parseMessageContent
} from '../../../main/ets/core/model/dto/MessageDto';
import { TdObject } from '../../../main/ets/core/utils/tdAccessors';

/**
 * Unit tests for MessageDto — DTO classes, enum values, parseMessageContent,
 * and applyMessageUpdate.
 *
 * Note: mapEntityType and extractTextEntities are module-private.
 * We test them indirectly through parseMessageContent where possible,
 * and directly test exported symbols.
 */

export default function messageDtoParserTest() {
  describe('MessageDtoParser', () => {

    // -----------------------------------------------------------------------
    // parseMessageContent — service (chat event) messages
    // -----------------------------------------------------------------------
    describe('parseMessageContent service messages', () => {
      it('parses messageChatAddMembers into SERVICE with member ids', 0, () => {
        const dto = parseMessageContent(TdObject.fromJSON(
          '{"@type":"messageChatAddMembers","member_user_ids":[111,222]}'
        ));
        expect(dto.type).assertEqual(MessageContentType.SERVICE);
        expect(dto.serviceType).assertEqual('messageChatAddMembers');
        expect(dto.serviceUserIds.length).assertEqual(2);
        expect(dto.serviceUserIds[0]).assertEqual(111);
        expect(dto.serviceUserIds[1]).assertEqual(222);
      });

      it('parses messageChatChangeTitle into SERVICE with title', 0, () => {
        const dto = parseMessageContent(TdObject.fromJSON(
          '{"@type":"messageChatChangeTitle","title":"New Title"}'
        ));
        expect(dto.type).assertEqual(MessageContentType.SERVICE);
        expect(dto.serviceType).assertEqual('messageChatChangeTitle');
        expect(dto.serviceTitle).assertEqual('New Title');
      });

      it('parses messageChatDeleteMember into SERVICE with single user id', 0, () => {
        const dto = parseMessageContent(TdObject.fromJSON(
          '{"@type":"messageChatDeleteMember","user_id":333}'
        ));
        expect(dto.type).assertEqual(MessageContentType.SERVICE);
        expect(dto.serviceUserIds.length).assertEqual(1);
        expect(dto.serviceUserIds[0]).assertEqual(333);
      });

      it('keeps unknown content as UNKNOWN with bracket text', 0, () => {
        const dto = parseMessageContent(TdObject.fromJSON(
          '{"@type":"messageGiveawayCreated"}'
        ));
        expect(dto.type).assertEqual(MessageContentType.UNKNOWN);
        expect(dto.text).assertEqual('[messageGiveawayCreated]');
      });
    });

    // -----------------------------------------------------------------------
    // MessageContentType enum values
    // -----------------------------------------------------------------------
    describe('MessageContentType enum', () => {

      it('should have correct TEXT value', 0, () => {
        expect(MessageContentType.TEXT).assertEqual('text');
      });

      it('should have correct PHOTO value', 0, () => {
        expect(MessageContentType.PHOTO).assertEqual('photo');
      });

      it('should have correct VIDEO value', 0, () => {
        expect(MessageContentType.VIDEO).assertEqual('video');
      });

      it('should have correct DOCUMENT value', 0, () => {
        expect(MessageContentType.DOCUMENT).assertEqual('document');
      });

      it('should have correct AUDIO value', 0, () => {
        expect(MessageContentType.AUDIO).assertEqual('audio');
      });

      it('should have correct VOICE value', 0, () => {
        expect(MessageContentType.VOICE).assertEqual('voice');
      });

      it('should have correct STICKER value', 0, () => {
        expect(MessageContentType.STICKER).assertEqual('sticker');
      });

      it('should have correct LOCATION value', 0, () => {
        expect(MessageContentType.LOCATION).assertEqual('location');
      });

      it('should have correct CONTACT value', 0, () => {
        expect(MessageContentType.CONTACT).assertEqual('contact');
      });

      it('should have correct POLL value', 0, () => {
        expect(MessageContentType.POLL).assertEqual('poll');
      });

      it('should have correct ANIMATION value', 0, () => {
        expect(MessageContentType.ANIMATION).assertEqual('animation');
      });

      it('should have correct VIDEO_NOTE value', 0, () => {
        expect(MessageContentType.VIDEO_NOTE).assertEqual('videoNote');
      });

      it('should have correct UNKNOWN value', 0, () => {
        expect(MessageContentType.UNKNOWN).assertEqual('unknown');
      });
    });

    // -----------------------------------------------------------------------
    // TextEntityDto — field defaults
    // -----------------------------------------------------------------------
    describe('TextEntityDto defaults', () => {

      it('should initialize with zero/empty defaults', 0, () => {
        const dto = new TextEntityDto();
        expect(dto.offset).assertEqual(0);
        expect(dto.length).assertEqual(0);
        expect(dto.type).assertEqual('');
        expect(dto.url).assertEqual('');
        expect(dto.userId).assertEqual(0);
        expect(dto.language).assertEqual('');
      });

      it('should accept assigned values', 0, () => {
        const dto = new TextEntityDto();
        dto.offset = 5;
        dto.length = 10;
        dto.type = 'bold';
        dto.url = 'https://test.com';
        dto.userId = 999;
        dto.language = 'python';

        expect(dto.offset).assertEqual(5);
        expect(dto.length).assertEqual(10);
        expect(dto.type).assertEqual('bold');
        expect(dto.url).assertEqual('https://test.com');
        expect(dto.userId).assertEqual(999);
        expect(dto.language).assertEqual('python');
      });
    });

    // -----------------------------------------------------------------------
    // MessageQuoteEntityDto — field defaults
    // -----------------------------------------------------------------------
    describe('MessageQuoteEntityDto defaults', () => {

      it('should initialize with zero/false defaults', 0, () => {
        const dto = new MessageQuoteEntityDto();
        expect(dto.offset).assertEqual(0);
        expect(dto.length).assertEqual(0);
        expect(dto.isCollapsed).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // MessageContentDto — defaults
    // -----------------------------------------------------------------------
    describe('MessageContentDto defaults', () => {

      it('should default to TEXT type with empty fields', 0, () => {
        const dto = new MessageContentDto();
        expect(dto.type).assertEqual(MessageContentType.TEXT);
        expect(dto.text).assertEqual('');
        expect(dto.caption).assertEqual('');
        expect(dto.textEntities.length).assertEqual(0);
        expect(dto.captionEntities.length).assertEqual(0);
        expect(dto.quoteEntities.length).assertEqual(0);
        expect(dto.pollOptions.length).assertEqual(0);
      });

      it('should default numeric fields to zero', 0, () => {
        const dto = new MessageContentDto();
        expect(dto.photoFileId).assertEqual(0);
        expect(dto.photoWidth).assertEqual(0);
        expect(dto.videoFileId).assertEqual(0);
        expect(dto.videoDuration).assertEqual(0);
        expect(dto.documentFileId).assertEqual(0);
        expect(dto.fileSize).assertEqual(0);
        expect(dto.audioFileId).assertEqual(0);
        expect(dto.voiceFileId).assertEqual(0);
        expect(dto.voiceDuration).assertEqual(0);
        expect(dto.stickerFileId).assertEqual(0);
      });

      it('should default boolean fields correctly', 0, () => {
        const dto = new MessageContentDto();
        expect(dto.isVoiceListened).assertFalse();
        expect(dto.isAnimatedSticker).assertFalse();
        expect(dto.isVideoSticker).assertFalse();
        expect(dto.isPremiumSticker).assertFalse();
        expect(dto.pollIsClosed).assertFalse();
        expect(dto.pollIsAnonymous).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // MessageDto — defaults
    // -----------------------------------------------------------------------
    describe('MessageDto defaults', () => {

      it('should initialize with correct default values', 0, () => {
        const dto = new MessageDto();
        expect(dto.id).assertEqual('0');
        expect(dto.chatId).assertEqual(0);
        expect(dto.senderId).assertEqual(0);
        expect(dto.senderChatId).assertEqual(0);
        expect(dto.mediaAlbumId).assertEqual('0');
        expect(dto.timestamp).assertEqual(0);
        expect(dto.isOutgoing).assertFalse();
        expect(dto.isRead).assertFalse();
        expect(dto.isPending).assertFalse();
        expect(dto.editDate).assertEqual(0);
        expect(dto.replyToMessageId).assertEqual('0');
        expect(dto.replyIsQuote).assertFalse();
        expect(dto.replyQuoteText).assertEqual('');
        expect(dto.replyQuoteOffset).assertEqual(-1);
      });
    });

    // -----------------------------------------------------------------------
    // PollOptionDto
    // -----------------------------------------------------------------------
    describe('PollOptionDto', () => {

      it('should initialize with empty/zero defaults', 0, () => {
        const opt = new PollOptionDto();
        expect(opt.text).assertEqual('');
        expect(opt.voterCount).assertEqual(0);
        expect(opt.votePercentage).assertEqual(0);
        expect(opt.isChosen).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // applyMessageUpdate — partial update
    // -----------------------------------------------------------------------
    describe('applyMessageUpdate', () => {

      it('should update isRead without changing other fields', 0, () => {
        const original = new MessageDto();
        original.id = '100';
        original.chatId = 1;
        original.isRead = false;
        original.editDate = 0;
        original.content.text = 'Hello';

        const update = new MessageUpdateDto();
        update.isRead = true;

        const result = applyMessageUpdate(original, update);
        expect(result.isRead).assertTrue();
        expect(result.id).assertEqual('100');
        expect(result.chatId).assertEqual(1);
        expect(result.content.text).assertEqual('Hello');
        expect(result.editDate).assertEqual(0);
      });

      it('should update editDate', 0, () => {
        const original = new MessageDto();
        original.id = '101';
        original.editDate = 0;

        const update = new MessageUpdateDto();
        update.editDate = 1700000000;

        const result = applyMessageUpdate(original, update);
        expect(result.editDate).assertEqual(1700000000);
      });

      it('should update content when provided', 0, () => {
        const original = new MessageDto();
        original.id = '102';
        original.content.type = MessageContentType.TEXT;
        original.content.text = 'Old text';

        const newContent = new MessageContentDto();
        newContent.type = MessageContentType.TEXT;
        newContent.text = 'New text';

        const update = new MessageUpdateDto();
        update.content = newContent;

        const result = applyMessageUpdate(original, update);
        expect(result.content.text).assertEqual('New text');
      });

      it('should preserve all fields when no updates provided', 0, () => {
        const original = new MessageDto();
        original.id = '103';
        original.chatId = 5;
        original.senderId = 42;
        original.senderChatId = 99;
        original.mediaAlbumId = '777';
        original.timestamp = 12345;
        original.isOutgoing = true;
        original.isRead = true;
        original.isPending = false;
        original.editDate = 100;
        original.replyToMessageId = '50';
        original.replyIsQuote = true;
        original.replyQuoteText = 'Quote';
        original.replyQuoteOffset = 3;

        const update = new MessageUpdateDto();
        // No fields set on update

        const result = applyMessageUpdate(original, update);
        expect(result.id).assertEqual('103');
        expect(result.chatId).assertEqual(5);
        expect(result.senderId).assertEqual(42);
        expect(result.senderChatId).assertEqual(99);
        expect(result.mediaAlbumId).assertEqual('777');
        expect(result.timestamp).assertEqual(12345);
        expect(result.isOutgoing).assertTrue();
        expect(result.isRead).assertTrue();
        expect(result.isPending).assertFalse();
        expect(result.editDate).assertEqual(100);
        expect(result.replyToMessageId).assertEqual('50');
        expect(result.replyIsQuote).assertTrue();
        expect(result.replyQuoteText).assertEqual('Quote');
        expect(result.replyQuoteOffset).assertEqual(3);
      });
    });

    // -----------------------------------------------------------------------
    // MessageUpdateDto — defaults
    // -----------------------------------------------------------------------
    describe('MessageUpdateDto', () => {

      it('should have undefined optional fields by default', 0, () => {
        const update = new MessageUpdateDto();
        expect(update.content).assertEqual(undefined);
        expect(update.isRead).assertEqual(undefined);
        expect(update.editDate).assertEqual(undefined);
      });
    });
  });
}
