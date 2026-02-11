import { TDLibClient } from '../../services/TDLibClient';
import { TdMessage } from '../../models/TdTypes';

interface TdMessages {
  messages?: TdMessage[];
}

export async function sendPoll(
  chatId: number,
  question: string,
  options: string[],
  isAnonymous: boolean = true,
  isQuiz: boolean = false,
  correctOptionId: number = -1
): Promise<void> {
  let pollTypeRecord: Record<string, unknown> = {};
  if (isQuiz) {
    pollTypeRecord['@type'] = 'pollTypeQuiz';
    pollTypeRecord['correct_option_id'] = correctOptionId;
  } else {
    pollTypeRecord['@type'] = 'pollTypeRegular';
    pollTypeRecord['allow_multiple_answers'] = false;
  }

  const formattedQuestion: Record<string, unknown> = {};
  formattedQuestion['@type'] = 'formattedText';
  formattedQuestion['text'] = question;
  const formattedOptions: Record<string, unknown>[] = options.map((o: string): Record<string, unknown> => {
    const opt: Record<string, unknown> = {};
    opt['@type'] = 'formattedText';
    opt['text'] = o;
    return opt;
  });
  const inputMessageContent: Record<string, unknown> = {};
  inputMessageContent['@type'] = 'inputMessagePoll';
  inputMessageContent['question'] = formattedQuestion;
  inputMessageContent['options'] = formattedOptions;
  inputMessageContent['is_anonymous'] = isAnonymous;
  inputMessageContent['type'] = pollTypeRecord;
  const sendPollParams: Record<string, unknown> = {};
  sendPollParams['chat_id'] = chatId;
  sendPollParams['input_message_content'] = inputMessageContent;
  await TDLibClient.getInstance().send('sendMessage', sendPollParams);
}

export async function sendScheduledMessage(
  chatId: number,
  text: string,
  sendDate: number,
  replyToMessageId: number = 0
): Promise<void> {
  let replyToParam: Record<string, unknown> | undefined = undefined;
  if (replyToMessageId > 0) {
    replyToParam = {};
    replyToParam['@type'] = 'inputMessageReplyToMessage';
    replyToParam['message_id'] = replyToMessageId;
  }

  const formattedText: Record<string, unknown> = {};
  formattedText['@type'] = 'formattedText';
  formattedText['text'] = text;
  const inputContent: Record<string, unknown> = {};
  inputContent['@type'] = 'inputMessageText';
  inputContent['text'] = formattedText;
  const schedulingState: Record<string, unknown> = {};
  schedulingState['@type'] = 'messageSchedulingStateSendAtDate';
  schedulingState['send_date'] = sendDate;
  const sendScheduledParams: Record<string, unknown> = {};
  sendScheduledParams['chat_id'] = chatId;
  if (replyToParam) {
    sendScheduledParams['reply_to'] = replyToParam;
  }
  sendScheduledParams['input_message_content'] = inputContent;
  sendScheduledParams['scheduling_state'] = schedulingState;
  await TDLibClient.getInstance().send('sendMessage', sendScheduledParams);
}

export async function sendGifMessage(chatId: number, gifId: number): Promise<void> {
  const animation: Record<string, unknown> = {};
  animation['@type'] = 'inputFileId';
  animation['id'] = gifId;

  const gifContent: Record<string, unknown> = {};
  gifContent['@type'] = 'inputMessageAnimation';
  gifContent['animation'] = animation;

  const params: Record<string, unknown> = {};
  params['chat_id'] = chatId;
  params['input_message_content'] = gifContent;
  await TDLibClient.getInstance().send('sendMessage', params);
}

export async function sendStickerMessage(chatId: number, emoji: string, stickerId: number = 0): Promise<void> {
  const sticker: Record<string, unknown> = {};
  sticker['@type'] = 'inputFileId';
  sticker['id'] = stickerId;

  const stickerContent: Record<string, unknown> = {};
  stickerContent['@type'] = 'inputMessageSticker';
  stickerContent['sticker'] = sticker;
  stickerContent['emoji'] = emoji;

  const params: Record<string, unknown> = {};
  params['chat_id'] = chatId;
  params['input_message_content'] = stickerContent;
  await TDLibClient.getInstance().send('sendMessage', params);
}

export async function sendVoiceMessage(
  chatId: number,
  duration: number,
  filePath: string = '',
  replyToMessageId: number = 0
): Promise<void> {
  const voiceNote: Record<string, unknown> = {};
  voiceNote['@type'] = 'inputFileLocal';
  voiceNote['path'] = filePath;

  const voiceContent: Record<string, unknown> = {};
  voiceContent['@type'] = 'inputMessageVoiceNote';
  voiceContent['voice_note'] = voiceNote;
  voiceContent['duration'] = duration;
  voiceContent['waveform'] = '';

  const params: Record<string, unknown> = {};
  params['chat_id'] = chatId;
  if (replyToMessageId > 0) {
    const replyTo: Record<string, unknown> = {};
    replyTo['@type'] = 'inputMessageReplyToMessage';
    replyTo['message_id'] = replyToMessageId;
    params['reply_to'] = replyTo;
  }
  params['input_message_content'] = voiceContent;
  await TDLibClient.getInstance().send('sendMessage', params);
}

export async function searchChatMessages(
  chatId: number,
  query: string,
  fromMessageId: number = 0,
  limit: number = 50,
  senderId: number = 0,
  filter: string = ''
): Promise<TdMessage[]> {
  let senderParam: Record<string, unknown> | undefined = undefined;
  if (senderId > 0) {
    senderParam = {};
    senderParam['@type'] = 'messageSenderUser';
    senderParam['user_id'] = senderId;
  }

  let filterParam: Record<string, unknown> | undefined = undefined;
  switch (filter) {
    case 'photo':
      filterParam = {};
      filterParam['@type'] = 'searchMessagesFilterPhoto';
      break;
    case 'video':
      filterParam = {};
      filterParam['@type'] = 'searchMessagesFilterVideo';
      break;
    case 'document':
      filterParam = {};
      filterParam['@type'] = 'searchMessagesFilterDocument';
      break;
    case 'url':
      filterParam = {};
      filterParam['@type'] = 'searchMessagesFilterUrl';
      break;
    default:
      break;
  }

  const searchParams: Record<string, unknown> = {};
  searchParams['chat_id'] = chatId;
  searchParams['query'] = query;
  searchParams['from_message_id'] = fromMessageId;
  searchParams['offset'] = 0;
  searchParams['limit'] = limit;
  searchParams['message_thread_id'] = 0;
  if (senderParam) {
    searchParams['sender_id'] = senderParam;
  }
  if (filterParam) {
    searchParams['filter'] = filterParam;
  }
  const result: TdMessages = await TDLibClient.getInstance().send('searchChatMessages', searchParams) as TdMessages;
  return result.messages || [];
}

export async function setDraft(chatId: number, text: string, replyToMessageId: number = 0): Promise<void> {
  if (text.length === 0 && replyToMessageId === 0) {
    const clearDraftParams: Record<string, unknown> = {};
    clearDraftParams['chat_id'] = chatId;
    await TDLibClient.getInstance().send('setChatDraftMessage', clearDraftParams);
    return;
  }

  let draftReplyTo: Record<string, unknown> | undefined = undefined;
  if (replyToMessageId > 0) {
    draftReplyTo = {};
    draftReplyTo['@type'] = 'inputMessageReplyToMessage';
    draftReplyTo['message_id'] = replyToMessageId;
  }

  const draftFormattedText: Record<string, unknown> = {};
  draftFormattedText['@type'] = 'formattedText';
  draftFormattedText['text'] = text;
  const draftInputMessageText: Record<string, unknown> = {};
  draftInputMessageText['@type'] = 'inputMessageText';
  draftInputMessageText['text'] = draftFormattedText;
  const draftMessage: Record<string, unknown> = {};
  draftMessage['@type'] = 'draftMessage';
  if (draftReplyTo) {
    draftMessage['reply_to'] = draftReplyTo;
  }
  draftMessage['input_message_text'] = draftInputMessageText;
  const setDraftParams: Record<string, unknown> = {};
  setDraftParams['chat_id'] = chatId;
  setDraftParams['draft_message'] = draftMessage;
  await TDLibClient.getInstance().send('setChatDraftMessage', setDraftParams);
}
