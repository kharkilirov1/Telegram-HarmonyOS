import { describe, it, expect } from '@ohos/hypium';
import { messagesReducer } from '../../../main/ets/core/reducers/messagesReducer';
import {
  AppState,
  Message,
  MessageContent,
  TextEntity,
  MessageQuoteEntity,
  PollOption
} from '../../../main/ets/core/model/AppState';
import {
  NewMessageEvent,
  ChatUpdatedEvent,
  MessageContentUpdatedEvent,
  MessageSendSucceededEvent,
  MessageSendFailedEvent,
  MessagesDeletedEvent,
  ChatMessagesResetEvent
} from '../../../main/ets/core/model/AppEvent';
import {
  MessageDto,
  MessageContentDto,
  MessageContentType,
  TextEntityDto,
  MessageQuoteEntityDto,
  PollOptionDto
} from '../../../main/ets/core/model/dto/MessageDto';

/**
 * Unit tests for messagesReducer — validates event-driven state transitions
 * for messages slice of AppState.
 */

function createEmptyState(): AppState {
  return new AppState();
}

function makeTextContentDto(text: string): MessageContentDto {
  const dto = new MessageContentDto();
  dto.type = MessageContentType.TEXT;
  dto.text = text;
  return dto;
}

function makeMessageDto(id: string, chatId: number, text: string): MessageDto {
  const dto = new MessageDto();
  dto.id = id;
  dto.chatId = chatId;
  dto.content = makeTextContentDto(text);
  dto.timestamp = 1000;
  dto.isOutgoing = true;
  return dto;
}

export default function messagesReducerTest() {
  describe('MessagesReducer', () => {

    // -----------------------------------------------------------------------
    // newMessage — basic text message content mapping
    // -----------------------------------------------------------------------
    describe('newMessage — content mapping', () => {

      it('should add a text message to state', 0, () => {
        const state = createEmptyState();
        const msgDto = makeMessageDto('100', 1, 'Hello world');

        const event = new NewMessageEvent();
        event.chatId = 1;
        event.messageId = '100';
        event.messageData = msgDto;

        const newState = messagesReducer(state, event);
        const chatMessages = newState.messages.messages.get(1);
        expect(chatMessages !== undefined).assertTrue();

        const msg = chatMessages!.get('100');
        expect(msg !== undefined).assertTrue();
        expect(msg!.content.type).assertEqual('text');
        expect(msg!.content.text).assertEqual('Hello world');
        expect(msg!.isOutgoing).assertTrue();
        expect(msg!.timestamp).assertEqual(1000);
      });

      it('should map photo content type and caption', 0, () => {
        const state = createEmptyState();
        const dto = new MessageDto();
        dto.id = '200';
        dto.chatId = 2;
        const content = new MessageContentDto();
        content.type = MessageContentType.PHOTO;
        content.text = '[Photo]';
        content.caption = 'Nice sunset';
        content.photoFileId = 42;
        content.photoWidth = 1920;
        content.photoHeight = 1080;
        dto.content = content;

        const event = new NewMessageEvent();
        event.chatId = 2;
        event.messageId = '200';
        event.messageData = dto;

        const newState = messagesReducer(state, event);
        const msg = newState.messages.messages.get(2)!.get('200')!;
        expect(msg.content.type).assertEqual('photo');
        expect(msg.content.caption).assertEqual('Nice sunset');
        expect(msg.content.photoFileId).assertEqual(42);
        expect(msg.content.photoWidth).assertEqual(1920);
        expect(msg.content.photoHeight).assertEqual(1080);
      });
    });

    // -----------------------------------------------------------------------
    // newMessage — TextEntity mapping from DTO to State
    // -----------------------------------------------------------------------
    describe('newMessage — TextEntity mapping', () => {

      it('should map textEntities with all fields', 0, () => {
        const state = createEmptyState();
        const dto = makeMessageDto('300', 3, 'Bold text with link');

        const entity1 = new TextEntityDto();
        entity1.offset = 0;
        entity1.length = 4;
        entity1.type = 'bold';
        entity1.url = '';
        entity1.userId = 0;
        entity1.language = '';

        const entity2 = new TextEntityDto();
        entity2.offset = 15;
        entity2.length = 4;
        entity2.type = 'textUrl';
        entity2.url = 'https://example.com';
        entity2.userId = 0;
        entity2.language = '';

        dto.content.textEntities = [entity1, entity2];

        const event = new NewMessageEvent();
        event.chatId = 3;
        event.messageId = '300';
        event.messageData = dto;

        const newState = messagesReducer(state, event);
        const msg = newState.messages.messages.get(3)!.get('300')!;
        expect(msg.content.textEntities.length).assertEqual(2);

        const e1 = msg.content.textEntities[0];
        expect(e1.offset).assertEqual(0);
        expect(e1.length).assertEqual(4);
        expect(e1.type).assertEqual('bold');

        const e2 = msg.content.textEntities[1];
        expect(e2.offset).assertEqual(15);
        expect(e2.length).assertEqual(4);
        expect(e2.type).assertEqual('textUrl');
        expect(e2.url).assertEqual('https://example.com');
      });

      it('should map mentionName entity with userId', 0, () => {
        const state = createEmptyState();
        const dto = makeMessageDto('301', 3, '@John');

        const entity = new TextEntityDto();
        entity.offset = 0;
        entity.length = 5;
        entity.type = 'mentionName';
        entity.userId = 12345;
        dto.content.textEntities = [entity];

        const event = new NewMessageEvent();
        event.chatId = 3;
        event.messageId = '301';
        event.messageData = dto;

        const newState = messagesReducer(state, event);
        const msg = newState.messages.messages.get(3)!.get('301')!;
        expect(msg.content.textEntities[0].userId).assertEqual(12345);
      });

      it('should map preCode entity with language', 0, () => {
        const state = createEmptyState();
        const dto = makeMessageDto('302', 3, 'code block');

        const entity = new TextEntityDto();
        entity.offset = 0;
        entity.length = 10;
        entity.type = 'preCode';
        entity.language = 'typescript';
        dto.content.textEntities = [entity];

        const event = new NewMessageEvent();
        event.chatId = 3;
        event.messageId = '302';
        event.messageData = dto;

        const newState = messagesReducer(state, event);
        const msg = newState.messages.messages.get(3)!.get('302')!;
        expect(msg.content.textEntities[0].language).assertEqual('typescript');
      });
    });

    // -----------------------------------------------------------------------
    // newMessage — CaptionEntity mapping
    // -----------------------------------------------------------------------
    describe('newMessage — captionEntities', () => {

      it('should map captionEntities on photo content', 0, () => {
        const state = createEmptyState();
        const dto = new MessageDto();
        dto.id = '400';
        dto.chatId = 4;
        const content = new MessageContentDto();
        content.type = MessageContentType.PHOTO;
        content.caption = 'Bold caption';

        const captionEntity = new TextEntityDto();
        captionEntity.offset = 0;
        captionEntity.length = 4;
        captionEntity.type = 'bold';
        content.captionEntities = [captionEntity];
        dto.content = content;

        const event = new NewMessageEvent();
        event.chatId = 4;
        event.messageId = '400';
        event.messageData = dto;

        const newState = messagesReducer(state, event);
        const msg = newState.messages.messages.get(4)!.get('400')!;
        expect(msg.content.captionEntities.length).assertEqual(1);
        expect(msg.content.captionEntities[0].offset).assertEqual(0);
        expect(msg.content.captionEntities[0].length).assertEqual(4);
        expect(msg.content.captionEntities[0].type).assertEqual('bold');
      });
    });

    // -----------------------------------------------------------------------
    // newMessage — QuoteEntity mapping
    // -----------------------------------------------------------------------
    describe('newMessage — quoteEntities', () => {

      it('should map quoteEntities with offset, length, isCollapsed', 0, () => {
        const state = createEmptyState();
        const dto = makeMessageDto('500', 5, 'Quoted text');

        const quoteEntity = new MessageQuoteEntityDto();
        quoteEntity.offset = 0;
        quoteEntity.length = 11;
        quoteEntity.isCollapsed = true;
        dto.content.quoteEntities = [quoteEntity];

        const event = new NewMessageEvent();
        event.chatId = 5;
        event.messageId = '500';
        event.messageData = dto;

        const newState = messagesReducer(state, event);
        const msg = newState.messages.messages.get(5)!.get('500')!;
        expect(msg.content.quoteEntities.length).assertEqual(1);
        expect(msg.content.quoteEntities[0].offset).assertEqual(0);
        expect(msg.content.quoteEntities[0].length).assertEqual(11);
        expect(msg.content.quoteEntities[0].isCollapsed).assertTrue();
      });

      it('should handle non-collapsed quote entity', 0, () => {
        const state = createEmptyState();
        const dto = makeMessageDto('501', 5, 'Another quote');

        const quoteEntity = new MessageQuoteEntityDto();
        quoteEntity.offset = 2;
        quoteEntity.length = 5;
        quoteEntity.isCollapsed = false;
        dto.content.quoteEntities = [quoteEntity];

        const event = new NewMessageEvent();
        event.chatId = 5;
        event.messageId = '501';
        event.messageData = dto;

        const newState = messagesReducer(state, event);
        const msg = newState.messages.messages.get(5)!.get('501')!;
        expect(msg.content.quoteEntities[0].isCollapsed).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // Empty entity arrays
    // -----------------------------------------------------------------------
    describe('empty entities', () => {

      it('should handle empty textEntities array', 0, () => {
        const state = createEmptyState();
        const dto = makeMessageDto('600', 6, 'Plain text');
        dto.content.textEntities = [];
        dto.content.captionEntities = [];
        dto.content.quoteEntities = [];

        const event = new NewMessageEvent();
        event.chatId = 6;
        event.messageId = '600';
        event.messageData = dto;

        const newState = messagesReducer(state, event);
        const msg = newState.messages.messages.get(6)!.get('600')!;
        expect(msg.content.textEntities.length).assertEqual(0);
        expect(msg.content.captionEntities.length).assertEqual(0);
        expect(msg.content.quoteEntities.length).assertEqual(0);
      });
    });

    // -----------------------------------------------------------------------
    // State immutability — clone preserves entity arrays
    // -----------------------------------------------------------------------
    describe('state immutability', () => {

      it('should not share entity array references between old and new state', 0, () => {
        const state = createEmptyState();
        const dto = makeMessageDto('700', 7, 'Entities check');

        const entity = new TextEntityDto();
        entity.offset = 0;
        entity.length = 8;
        entity.type = 'bold';
        dto.content.textEntities = [entity];

        const event = new NewMessageEvent();
        event.chatId = 7;
        event.messageId = '700';
        event.messageData = dto;

        const stateAfterFirst = messagesReducer(state, event);

        // Add second message to same chat
        const dto2 = makeMessageDto('701', 7, 'Second message');
        const event2 = new NewMessageEvent();
        event2.chatId = 7;
        event2.messageId = '701';
        event2.messageData = dto2;

        const stateAfterSecond = messagesReducer(stateAfterFirst, event2);

        // Both messages should exist in new state
        const chatMsgs = stateAfterSecond.messages.messages.get(7)!;
        expect(chatMsgs.has('700')).assertTrue();
        expect(chatMsgs.has('701')).assertTrue();

        // Entity from first message should still be intact
        const msg700 = chatMsgs.get('700')!;
        expect(msg700.content.textEntities.length).assertEqual(1);
        expect(msg700.content.textEntities[0].type).assertEqual('bold');
      });

      it('should increment version on each reducer call', 0, () => {
        const state = createEmptyState();
        state.version = 10;

        const dto = makeMessageDto('800', 8, 'Version check');
        const event = new NewMessageEvent();
        event.chatId = 8;
        event.messageId = '800';
        event.messageData = dto;

        const newState = messagesReducer(state, event);
        expect(newState.version).assertEqual(11);
      });
    });

    // -----------------------------------------------------------------------
    // messagesDeleted
    // -----------------------------------------------------------------------
    describe('messagesDeleted', () => {

      it('should remove permanently deleted messages', 0, () => {
        // First add a message
        let state = createEmptyState();
        const dto = makeMessageDto('900', 9, 'To be deleted');
        const addEvent = new NewMessageEvent();
        addEvent.chatId = 9;
        addEvent.messageId = '900';
        addEvent.messageData = dto;
        state = messagesReducer(state, addEvent);

        // Now delete it
        const deleteEvent = new MessagesDeletedEvent();
        deleteEvent.chatId = 9;
        deleteEvent.messageIds = ['900'];
        deleteEvent.isPermanent = true;

        const newState = messagesReducer(state, deleteEvent);
        // Chat entry should be removed since no messages remain
        expect(newState.messages.messages.has(9)).assertFalse();
      });

      it('should ignore non-permanent deletes', 0, () => {
        let state = createEmptyState();
        const dto = makeMessageDto('901', 9, 'Should survive');
        const addEvent = new NewMessageEvent();
        addEvent.chatId = 9;
        addEvent.messageId = '901';
        addEvent.messageData = dto;
        state = messagesReducer(state, addEvent);

        const deleteEvent = new MessagesDeletedEvent();
        deleteEvent.chatId = 9;
        deleteEvent.messageIds = ['901'];
        deleteEvent.isPermanent = false;

        const newState = messagesReducer(state, deleteEvent);
        expect(newState.messages.messages.get(9)!.has('901')).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // chatMessagesReset (jump-to-message)
    // -----------------------------------------------------------------------
    describe('chatMessagesReset', () => {
      it('should drop all messages of the chat and keep other chats intact', 0, () => {
        let state = createEmptyState();
        const dtoA = makeMessageDto('910', 9, 'In target chat');
        const addA = new NewMessageEvent();
        addA.chatId = 9;
        addA.messageId = '910';
        addA.messageData = dtoA;
        state = messagesReducer(state, addA);

        const dtoB = makeMessageDto('911', 10, 'In other chat');
        const addB = new NewMessageEvent();
        addB.chatId = 10;
        addB.messageId = '911';
        addB.messageData = dtoB;
        state = messagesReducer(state, addB);

        const resetEvent = new ChatMessagesResetEvent();
        resetEvent.chatId = 9;

        const newState = messagesReducer(state, resetEvent);
        expect(newState.messages.messages.has(9)).assertFalse();
        expect(newState.messages.messages.get(10)!.has('911')).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // messageSendFailed
    // -----------------------------------------------------------------------
    describe('messageSendFailed', () => {

      it('should mark pending message as failed with error info', 0, () => {
        let state = createEmptyState();
        const dto = makeMessageDto('1000', 10, 'Pending msg');
        dto.isPending = true;
        const addEvent = new NewMessageEvent();
        addEvent.chatId = 10;
        addEvent.messageId = '1000';
        addEvent.messageData = dto;
        state = messagesReducer(state, addEvent);

        const failEvent = new MessageSendFailedEvent();
        failEvent.chatId = 10;
        failEvent.oldMessageId = '1000';
        failEvent.errorCode = 400;
        failEvent.errorMessage = 'Bad request';

        const newState = messagesReducer(state, failEvent);
        const msg = newState.messages.messages.get(10)!.get('1000')!;
        expect(msg.sendStatus).assertEqual('failed');
        expect(msg.sendErrorCode).assertEqual(400);
        expect(msg.sendErrorMessage).assertEqual('Bad request');
        expect(msg.isPending).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // Non-message events should pass through unchanged
    // -----------------------------------------------------------------------
    describe('pass-through', () => {

      it('should return same state for unrelated event types', 0, () => {
        const state = createEmptyState();
        const fakeEvent = new ChatUpdatedEvent();

        const result = messagesReducer(state, fakeEvent);
        // Should be the exact same reference
        expect(result === state).assertTrue();
      });
    });
  });
}
