// Message DTO - domain data transfer object for messages
// ArkTS compliant - uses TdObject wrapper class

import { ChatId, MessageId, UserId } from '../EntityId';
import { TdObject, tdGetString, tdGetNumber, tdGetBoolean, tdGetInt64, tdGetObject, tdHasKeys } from '../../utils/tdAccessors';

export enum MessageContentType {
  TEXT = 'text',
  PHOTO = 'photo',
  VIDEO = 'video',
  DOCUMENT = 'document',
  AUDIO = 'audio',
  VOICE = 'voice',
  STICKER = 'sticker',
  LOCATION = 'location',
  CONTACT = 'contact',
  POLL = 'poll',
  UNKNOWN = 'unknown'
}

export class MessageContentDto {
  type: MessageContentType = MessageContentType.TEXT;
  text: string = '';
  caption: string = '';
}

export class MessageDto {
  id: MessageId = '0';
  chatId: ChatId = 0;
  senderId: UserId = 0;
  senderChatId: ChatId = 0;
  content: MessageContentDto = new MessageContentDto();
  timestamp: number = 0;
  isOutgoing: boolean = false;
  isRead: boolean = false;
  isPending: boolean = false;
  editDate: number = 0;
  replyToMessageId: MessageId = '0';
}

// Helper to create DTO from raw TDLib message object
export function createMessageDtoFromTd(tdMessage: TdObject): MessageDto {
  const content = tdGetObject(tdMessage, 'content');
  const contentType = tdGetString(content, '@type') || 'messageText';
  let messageContentType: MessageContentType = MessageContentType.TEXT;
  let text: string = '';

  switch (contentType) {
    case 'messageText': {
      messageContentType = MessageContentType.TEXT;
      const textObj = tdGetObject(content, 'text');
      text = tdGetString(textObj, 'text');
      break;
    }
    case 'messagePhoto': {
      messageContentType = MessageContentType.PHOTO;
      const photoCaption = tdGetObject(content, 'caption');
      text = tdGetString(photoCaption, 'text');
      break;
    }
    case 'messageVideo': {
      messageContentType = MessageContentType.VIDEO;
      const videoCaption = tdGetObject(content, 'caption');
      text = tdGetString(videoCaption, 'text');
      break;
    }
    case 'messageDocument': {
      messageContentType = MessageContentType.DOCUMENT;
      const docCaption = tdGetObject(content, 'caption');
      text = tdGetString(docCaption, 'text');
      break;
    }
    case 'messageAudio': {
      messageContentType = MessageContentType.AUDIO;
      const audioCaption = tdGetObject(content, 'caption');
      text = tdGetString(audioCaption, 'text');
      break;
    }
    case 'messageVoiceNote': {
      messageContentType = MessageContentType.VOICE;
      const voiceCaption = tdGetObject(content, 'caption');
      text = tdGetString(voiceCaption, 'text');
      break;
    }
    case 'messageSticker':
      messageContentType = MessageContentType.STICKER;
      break;
    case 'messageLocation':
      messageContentType = MessageContentType.LOCATION;
      break;
    case 'messageContact':
      messageContentType = MessageContentType.CONTACT;
      break;
    case 'messagePoll':
      messageContentType = MessageContentType.POLL;
      break;
    case 'messageAnimation': {
      messageContentType = MessageContentType.TEXT;
      const animCaption = tdGetObject(content, 'caption');
      text = tdGetString(animCaption, 'text');
      break;
    }
    case 'messageVideoNote':
      messageContentType = MessageContentType.VIDEO;
      break;
    default:
      messageContentType = MessageContentType.UNKNOWN;
      text = `[${contentType}]`;
  }

  let senderId: UserId = 0;
  let senderChatId: ChatId = 0;
  const sender = tdGetObject(tdMessage, 'sender_id');
  const senderType = tdGetString(sender, '@type');
  if (senderType === 'messageSenderUser') {
    senderId = tdGetNumber(sender, 'user_id');
  } else if (senderType === 'messageSenderChat') {
    senderChatId = tdGetNumber(sender, 'chat_id');
  }

  const messageDto = new MessageDto();
  messageDto.id = tdGetInt64(tdMessage, 'id');
  messageDto.chatId = tdGetNumber(tdMessage, 'chat_id');
  messageDto.senderId = senderId;
  messageDto.senderChatId = senderChatId;

  const contentDto = new MessageContentDto();
  contentDto.type = messageContentType;
  contentDto.text = text;
  messageDto.content = contentDto;

  messageDto.timestamp = tdGetNumber(tdMessage, 'date') || Date.now();
  messageDto.isOutgoing = tdGetBoolean(tdMessage, 'is_outgoing');
  messageDto.isRead = tdGetBoolean(tdMessage, 'is_read');
  messageDto.replyToMessageId = tdGetInt64(tdMessage, 'reply_to_message_id');

  return messageDto;
}

// Parse message content from TDLib object
export function parseMessageContent(contentObj: TdObject): MessageContentDto {
  const contentDto = new MessageContentDto();

  if (!tdHasKeys(contentObj)) {
    return contentDto;
  }

  const contentType = tdGetString(contentObj, '@type');

  switch (contentType) {
    case 'messageText': {
      const textObj = tdGetObject(contentObj, 'text');
      contentDto.text = tdGetString(textObj, 'text');
      contentDto.type = MessageContentType.TEXT;
      break;
    }
    case 'messagePhoto': {
      const caption = tdGetObject(contentObj, 'caption');
      contentDto.text = tdGetString(caption, 'text');
      contentDto.type = MessageContentType.PHOTO;
      break;
    }
    case 'messageVideo': {
      const caption = tdGetObject(contentObj, 'caption');
      contentDto.text = tdGetString(caption, 'text');
      contentDto.type = MessageContentType.VIDEO;
      break;
    }
    case 'messageDocument': {
      const caption = tdGetObject(contentObj, 'caption');
      contentDto.text = tdGetString(caption, 'text');
      contentDto.type = MessageContentType.DOCUMENT;
      break;
    }
    case 'messageAudio': {
      const caption = tdGetObject(contentObj, 'caption');
      contentDto.text = tdGetString(caption, 'text');
      contentDto.type = MessageContentType.AUDIO;
      break;
    }
    case 'messageVoiceNote': {
      const caption = tdGetObject(contentObj, 'caption');
      contentDto.text = tdGetString(caption, 'text');
      contentDto.type = MessageContentType.VOICE;
      break;
    }
    case 'messageSticker':
      contentDto.type = MessageContentType.STICKER;
      break;
    case 'messageLocation':
      contentDto.type = MessageContentType.LOCATION;
      break;
    case 'messageContact':
      contentDto.type = MessageContentType.CONTACT;
      break;
    case 'messagePoll':
      contentDto.type = MessageContentType.POLL;
      break;
    case 'messageAnimation':
      contentDto.type = MessageContentType.TEXT;
      break;
    default:
      contentDto.type = MessageContentType.UNKNOWN;
      contentDto.text = `[${contentType}]`;
  }

  return contentDto;
}

// Helper for partial updates (messageUpdated event)
export class MessageUpdateDto {
  content?: MessageContentDto;
  isRead?: boolean;
  editDate?: number;
}

export function applyMessageUpdate(message: MessageDto, update: MessageUpdateDto): MessageDto {
  const updatedMessage = new MessageDto();
  updatedMessage.id = message.id;
  updatedMessage.chatId = message.chatId;
  updatedMessage.senderId = message.senderId;
  updatedMessage.senderChatId = message.senderChatId;
  updatedMessage.content = message.content;
  updatedMessage.timestamp = message.timestamp;
  updatedMessage.isOutgoing = message.isOutgoing;
  updatedMessage.isRead = message.isRead;
  updatedMessage.isPending = message.isPending;
  updatedMessage.editDate = message.editDate;
  updatedMessage.replyToMessageId = message.replyToMessageId;

  if (update.content !== undefined) {
    updatedMessage.content = update.content;
  }
  if (update.isRead !== undefined) {
    updatedMessage.isRead = update.isRead;
  }
  if (update.editDate !== undefined) {
    updatedMessage.editDate = update.editDate;
  }

  return updatedMessage;
}
