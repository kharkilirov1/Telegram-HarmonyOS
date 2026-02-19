// TDLib media types
// File, photo, video, document, audio, sticker, etc.

import { TdFormattedText } from '../common';

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

