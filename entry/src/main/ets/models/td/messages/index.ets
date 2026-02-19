// TDLib message types
// Messages, content, polls, dice, etc.

import { TdFormattedText } from '../common';
import { 
  TdPhoto, TdVideo, TdAnimation, TdDocument, TdVoiceNote, TdVideoNote, TdSticker,
  TdWebPage, TdContact, TdLocation, TdVenue, TdAudioNote
} from '../media';
import { TdObject } from '../common';

export interface TdMessageSender {
  user_id?: number;
  chat_id?: number;
}

export interface TdMessageContent {
  text?: TdFormattedText;
  caption?: TdFormattedText;
  photo?: TdPhoto;
  video?: TdVideo;
  animation?: TdAnimation;
  document?: TdDocument;
  voice_note?: TdVoiceNote;
  video_note?: TdVideoNote;
  sticker?: TdSticker;
  poll?: TdPoll;
  web_page?: TdWebPage;
  contact?: TdContact;
  location?: TdLocation;
  venue?: TdVenue;
  audio?: TdAudioNote;
  dice?: TdDice;
  has_spoiler?: boolean;
  live_period?: number;
}

export interface TdMessage {
  id: number;
  chat_id: number;
  sender_id?: TdMessageSender;
  content?: TdMessageContent;
  date: number;
  edit_date?: number;
  is_outgoing: boolean;
  reply_to?: TdReplyTo;
  forward_info?: TdForwardInfo;
  media_album_id?: string;
  scheduling_state?: TdSchedulingState;
  self_destruct_type?: TdSelfDestructType;
  sending_state?: TdObject;
}

export interface TdDraftMessage {
  input_message_text?: TdInputMessageText;
}

export interface TdInputMessageText {
  text?: TdFormattedText;
}

export interface TdReplyTo {
  message_id?: number;
}

export interface TdForwardInfo {
  origin?: TdMessageOrigin;
}

export interface TdMessageOrigin {
  sender_name?: string;
}

export interface TdSchedulingState {
  send_date?: number;
}

export interface TdSelfDestructType {
  self_destruct_time?: number;
}

export interface TdPollOptionDisplay {
  text: string;
  voterCount: number;
  votePercentage: number;
  isChosen: boolean;
}

export interface TdPollOption {
  text?: TdFormattedText;
  voter_count: number;
  vote_percentage: number;
  is_chosen: boolean;
}

export interface TdPollType {
  allow_multiple_answers?: boolean;
  correct_option_id?: number;
}

export interface TdPoll {
  id: string;
  question?: TdFormattedText;
  options?: TdPollOption[];
  total_voter_count: number;
  is_closed: boolean;
  is_anonymous: boolean;
  type?: TdPollType;
}

export interface TdDice {
  emoji?: string;
  value?: number;
}

export interface TdMessages {
  messages?: TdMessage[];
  total_count?: number;
}