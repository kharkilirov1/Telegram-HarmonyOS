// TDLib chat types
// Chats, positions, types, photos, permissions, etc.

import { TdFile } from '../media';
import { TdMessage, TdDraftMessage } from '../messages';
import { TdObject } from '../common';

export interface TdChatPosition {
  list?: TdObject;
  order?: string;
  is_pinned?: boolean;
}

export interface TdChatType {
  is_channel?: boolean;
  supergroup_id?: number;
  user_id?: number;
}

export interface TdNotificationSettings {
  mute_for?: number;
}

export interface TdChatAction {
  // empty — identified by @type
}

export interface TdChatPhoto {
  small?: TdFile;
  big?: TdFile;
}

export interface TdChat {
  id: number;
  title: string;
  last_message?: TdMessage;
  last_read_outbox_message_id?: number;
  last_read_inbox_message_id?: number;
  photo?: TdChatPhoto;
  positions?: TdChatPosition[];
  notification_settings?: TdNotificationSettings;
  unread_count?: number;
  is_marked_as_unread?: boolean;
  type?: TdChatType;
  draft_message?: TdDraftMessage;
}

export interface TdChats {
  chat_ids?: number[];
  total_count?: number;
}

export interface TdChatPermissions {
  can_send_basic_messages?: boolean;
  can_send_audios?: boolean;
  can_send_documents?: boolean;
  can_send_photos?: boolean;
  can_send_videos?: boolean;
  can_send_video_notes?: boolean;
  can_send_voice_notes?: boolean;
  can_send_polls?: boolean;
  can_send_other_messages?: boolean;
  can_add_web_page_previews?: boolean;
  can_change_info?: boolean;
  can_invite_users?: boolean;
  can_pin_messages?: boolean;
}

export interface TdNearbyChat {
  user_id?: number;
  chat_id?: number;
  distance?: number;
}

export interface TdChatsNearby {
  users_nearby?: TdNearbyChat[];
  supergroups_nearby?: TdNearbyChat[];
}

export interface TdChatInviteLink {
  invite_link?: string;
  member_count?: number;
  is_revoked?: boolean;
  is_primary?: boolean;
  expiration_date?: number;
  name?: string;
  creator_user_id?: number;
}

export interface TdChatInviteLinks {
  invite_links?: TdChatInviteLink[];
  total_count?: number;
}