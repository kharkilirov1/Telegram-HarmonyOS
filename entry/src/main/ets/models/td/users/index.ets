// TDLib user and supergroup types
// Users, profiles, supergroups, members, etc.

import { TdFile } from '../media';
import { TdFormattedText } from '../common';
import { TdMessageSender } from '../messages';
import { TdChatInviteLink } from '../chats';
import { TdObject } from '../common';

export interface TdUserStatus {
  // Identified by @type: userStatusOnline, userStatusOffline, etc.
}

export interface TdProfilePhoto {
  small?: TdFile;
  big?: TdFile;
}

export interface TdUsernames {
  editable_username?: string;
  active_usernames?: string[];
}

export interface TdUserType {
  ['@type']?: string;
}

export interface TdUser {
  id?: number;
  first_name?: string;
  last_name?: string;
  phone_number?: string;
  username?: string;
  usernames?: TdUsernames;
  type?: TdUserType;
  status?: TdUserStatus;
  profile_photo?: TdProfilePhoto;
  is_premium?: boolean;
}

export interface TdUserFullInfo {
  bio?: TdFormattedText;
  group_in_common_count?: number;
}

export interface TdSupergroup {
  id?: number;
  usernames?: TdUsernames;
  member_count?: number;
  is_channel?: boolean;
}

export interface TdSupergroupFullInfo {
  member_count?: number;
  administrator_count?: number;
  description?: string;
  invite_link?: TdChatInviteLink;
}

export interface TdSupergroupMember {
  member_id?: TdMessageSender;
  status?: TdObject;
}

export interface TdSupergroupMembers {
  members?: TdSupergroupMember[];
  total_count?: number;
}