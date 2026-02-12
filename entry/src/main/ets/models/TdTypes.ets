// TDLib response interfaces for ArkTS strict typing
// Extracted from MessagesController for reuse across parsers/controllers

// --- Type guard helper ---

export type TdObject = Record<string, Object>;

export function tdType(obj: TdObject | undefined | null): string {
  if (!obj) return '';
  return (obj['@type'] as string) || '';
}

// --- Type guard functions for TDLib responses ---

export function isTdError(response: TdObject): boolean {
  return tdType(response) === 'error';
}

export function getTdErrorCode(response: TdObject): number {
  return (response['code'] as number) || 0;
}

export function getTdErrorMessage(response: TdObject): string {
  return (response['message'] as string) || 'Unknown error';
}

// --- Safe accessor helpers ---

export function safeNumber(value: Object | undefined | null): number {
  if (value === undefined || value === null) return 0;
  if (typeof value === 'number') return value as number;
  return 0;
}

export function safeString(value: Object | undefined | null): string {
  if (value === undefined || value === null) return '';
  if (typeof value === 'string') return value as string;
  return '';
}

export function safeBool(value: Object | undefined | null): boolean {
  if (value === undefined || value === null) return false;
  if (typeof value === 'boolean') return value as boolean;
  return false;
}

export function asRecord(value: Object | undefined | null): TdObject {
  if (value === undefined || value === null) return {};
  return value as TdObject;
}

export function asArray(value: Object | undefined | null): Object[] | undefined {
  if (value === undefined || value === null) return undefined;
  if (!Array.isArray(value)) return undefined;
  return value as Object[];
}

export function safeNumberArray(value: Object | undefined | null): number[] | undefined {
  const arr = asArray(value);
  if (!arr) return undefined;
  const result: number[] = [];
  for (const item of arr) {
    if (typeof item === 'number') {
      result.push(item as number);
    }
  }
  return result;
}

// --- Poll option display ---

export interface PollOptionDisplay {
  text: string;
  voterCount: number;
  votePercentage: number;
  isChosen: boolean;
}

// --- TDLib raw interfaces ---

export interface TdMessageSender {
  user_id?: number;
  chat_id?: number;
}

export interface TdFormattedText {
  text: string;
}

export interface TdFile {
  id: number;
  size?: number;
  expected_size?: number;
  local?: TdLocalFile;
}

export interface TdLocalFile {
  path: string;
  is_downloading_completed: boolean;
}

export interface TdPhoto {
  sizes?: TdPhotoSize[];
}

export interface TdPhotoSize {
  photo?: TdFile;
  width?: number;
  height?: number;
}

export interface TdThumbnail {
  file?: TdFile;
  width?: number;
  height?: number;
}

export interface TdWebPage {
  url?: string;
  display_url?: string;
  type?: string;
  site_name?: string;
  title?: string;
  description?: TdFormattedText;
  photo?: TdPhoto;
}

export interface TdContact {
  phone_number?: string;
  first_name?: string;
  last_name?: string;
  user_id?: number;
}

export interface TdLocation {
  latitude?: number;
  longitude?: number;
}

export interface TdVenue {
  location?: TdLocation;
  title?: string;
  address?: string;
}

export interface TdAudioNote {
  duration?: number;
  title?: string;
  performer?: string;
  audio?: TdFile;
}

export interface TdCallDiscardReason {
  // Identified by @type
}

export interface TdCall {
  duration?: number;
  is_video?: boolean;
  discard_reason?: TdCallDiscardReason;
}

export interface TdDice {
  emoji?: string;
  value?: number;
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

export interface TdVideo {
  duration: number;
  video?: TdFile;
  thumbnail?: TdThumbnail;
}

export interface TdAnimation {
  duration?: number;
  animation?: TdFile;
  thumbnail?: TdThumbnail;
  file_name?: string;
}

export interface TdDocument {
  file_name: string;
  document?: TdFile;
}

export interface TdVoiceNote {
  duration: number;
  waveform: string;
  voice?: TdFile;
}

export interface TdVideoNote {
  duration: number;
  length: number;
  video?: TdFile;
}

export interface TdSticker {
  emoji: string;
  sticker?: TdFile;
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

// --- TDLib raw message ---

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

// --- TDLib draft message ---

export interface TdDraftMessage {
  input_message_text?: TdInputMessageText;
}

export interface TdInputMessageText {
  text?: TdFormattedText;
}

// --- TDLib raw chat ---

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

// --- TDLib update interfaces ---

export interface TdUpdateNewChat {
  chat?: TdChat;
}

export interface TdUpdateChatLastMessage {
  chat_id: number;
  last_message?: TdMessage;
  positions?: TdChatPosition[];
}

export interface TdUpdateChatPosition {
  chat_id: number;
  position?: TdChatPosition;
}

export interface TdUpdateNewMessage {
  message?: TdMessage;
}

export interface TdUpdateMessageContent {
  chat_id: number;
  message_id: number;
  new_content?: TdMessageContent;
}

export interface TdUpdateChatReadInbox {
  chat_id: number;
  unread_count: number;
}

export interface TdUpdateChatNotificationSettings {
  chat_id: number;
  notification_settings?: TdNotificationSettings;
}

export interface TdUpdateChatAction {
  chat_id: number;
  action?: TdChatAction;
}

// --- TDLib user/profile interfaces ---

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

// --- TDLib supergroup interfaces ---

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

// --- TDLib chat invite link ---

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

// --- TDLib secret chat ---

export interface TdSecretChat {
  id?: number;
  state?: TdObject;
  key_hash?: string;
  user_id?: number;
}

// --- TDLib auto-download settings ---

export interface TdAutoDownloadSettings {
  is_auto_download_enabled?: boolean;
  max_photo_file_size?: number;
  max_video_file_size?: number;
  max_other_file_size?: number;
  video_upload_bitrate?: number;
  preload_large_videos?: boolean;
  preload_next_audio?: boolean;
}

export interface TdAutoDownloadSettingsPresets {
  low?: TdAutoDownloadSettings;
  medium?: TdAutoDownloadSettings;
  high?: TdAutoDownloadSettings;
}

// --- TDLib passport ---

export interface TdPassportAuthorizationForm {
  id?: number;
  required_elements?: Object[];
}

// --- TDLib chats search result ---

export interface TdChats {
  chat_ids?: number[];
  total_count?: number;
}

// --- TDLib chat permissions ---

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

// --- TDLib nearby chat ---

export interface TdNearbyChat {
  user_id?: number;
  chat_id?: number;
  distance?: number;
}

export interface TdChatsNearby {
  users_nearby?: TdNearbyChat[];
  supergroups_nearby?: TdNearbyChat[];
}

// --- TDLib session ---

export interface TdSession {
  id?: number;
  is_current?: boolean;
  api_id?: number;
  application_name?: string;
  application_version?: string;
  device_model?: string;
  platform?: string;
  system_version?: string;
  log_in_date?: number;
  last_active_date?: number;
  ip_address?: string;
  location?: string;
}

export interface TdSessions {
  sessions?: TdSession[];
}

// --- TDLib proxy ---

export interface TdProxyType {
  username?: string;
  password?: string;
  http_only?: boolean;
  secret?: string;
}

export interface TdProxy {
  id: number;
  server?: string;
  port?: number;
  last_used_date?: number;
  is_enabled?: boolean;
  type?: TdProxyType;
}

export interface TdProxies {
  proxies?: TdProxy[];
}

// --- TDLib response wrappers ---

export interface TdMessages {
  messages?: TdMessage[];
}

export interface TdOk {
  // empty — @type = 'ok'
}
