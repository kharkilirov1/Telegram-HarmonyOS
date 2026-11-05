// I6: story composer helpers — media kind detection, caption clamping and the privacy cycle. Kept pure so
// the composer page only renders and calls the post use case.

import { PostStoryPayload, StoryPrivacy } from '../../../core/model/AppCommand';
import { STORY_MAX_CAPTION_LENGTH } from '../../../domain/usecases/postStory';

export const STORY_VIDEO_EXTENSIONS: string[] = ['mp4', 'mov', 'm4v', '3gp', 'webm', 'mkv'];

export function storyFileExtension(path: string): string {
  const trimmed = path.trim();
  const dot = trimmed.lastIndexOf('.');
  if (dot < 0 || dot === trimmed.length - 1) {
    return '';
  }
  return trimmed.substring(dot + 1).toLowerCase();
}

// The picker does not tell photo from video reliably, so the file extension decides.
export function storyMediaKindFromPath(path: string): string {
  const extension = storyFileExtension(path);
  return STORY_VIDEO_EXTENSIONS.includes(extension) ? 'video' : 'photo';
}

export function clampStoryCaption(caption: string): string {
  const trimmed = caption.trim();
  if (trimmed.length <= STORY_MAX_CAPTION_LENGTH) {
    return trimmed;
  }
  return trimmed.substring(0, STORY_MAX_CAPTION_LENGTH);
}

export const STORY_PRIVACY_ORDER: StoryPrivacy[] = ['everyone', 'contacts', 'closeFriends', 'selectedUsers'];

// iOS shows the visibility as a row that cycles through the options; selected users need a picker.
export function nextStoryPrivacy(current: StoryPrivacy, delta: number): StoryPrivacy {
  const index = STORY_PRIVACY_ORDER.indexOf(current);
  if (index < 0) {
    return 'everyone';
  }
  const next = (index + delta + STORY_PRIVACY_ORDER.length) % STORY_PRIVACY_ORDER.length;
  return STORY_PRIVACY_ORDER[next];
}

export function storyPrivacyLabel(privacy: StoryPrivacy): string {
  switch (privacy) {
    case 'contacts':
      return 'My Contacts';
    case 'closeFriends':
      return 'Close Friends';
    case 'selectedUsers':
      return 'Selected People';
    default:
      return 'Everyone';
  }
}

// Builds the command payload from composer state so the page stays declarative.
export function buildStoryPayload(chatId: number, localPath: string, caption: string,
  privacy: StoryPrivacy, selectedUserIds: number[] = []): PostStoryPayload {
  const payload = new PostStoryPayload();
  payload.chatId = chatId;
  payload.localPath = localPath;
  payload.mediaKind = storyMediaKindFromPath(localPath);
  payload.caption = clampStoryCaption(caption);
  payload.privacy = privacy;
  payload.selectedUserIds = selectedUserIds.slice();
  return payload;
}

// Publish is enabled only with media and, for the selected-people mode, at least one person.
export function canPublishStory(localPath: string, privacy: StoryPrivacy, selectedCount: number): boolean {
  if (localPath.length === 0) {
    return false;
  }
  if (privacy === 'selectedUsers' && selectedCount === 0) {
    return false;
  }
  return true;
}
