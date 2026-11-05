// Story DTOs kept independent from UI and TDLib wrapper types.

import { ChatId } from '../EntityId';

export type StoryListType = 'main' | 'archive' | 'none';

export class StoryInfoDto {
  storyId: number = 0;
  date: number = 0;
  isForCloseFriends: boolean = false;
  isLive: boolean = false;
}

export class ChatActiveStoriesDto {
  chatId: ChatId = 0;
  listType: StoryListType = 'none';
  order: number = 0;
  canBeArchived: boolean = false;
  maxReadStoryId: number = 0;
  stories: StoryInfoDto[] = [];
}

export function latestActiveStoryId(activeStories: ChatActiveStoriesDto): number {
  if (activeStories.stories.length === 0) {
    return 0;
  }
  return activeStories.stories[activeStories.stories.length - 1].storyId;
}

export function hasUnreadActiveStories(activeStories: ChatActiveStoriesDto): boolean {
  return latestActiveStoryId(activeStories) > activeStories.maxReadStoryId;
}

export function hasUnreadCloseFriendsStories(activeStories: ChatActiveStoriesDto): boolean {
  for (const story of activeStories.stories) {
    if (story.storyId > activeStories.maxReadStoryId && story.isForCloseFriends) {
      return true;
    }
  }
  return false;
}

// I6: the full story content shown by the viewer. Story list updates only carry ids, so the viewer asks
// TDLib for one story at a time and the store keeps the parsed content.
export type StoryContentKind = 'photo' | 'video' | 'unsupported';

export class StoryFullDto {
  storyId: number = 0;
  posterChatId: number = 0;
  date: number = 0;
  kind: StoryContentKind = 'unsupported';
  caption: string = '';
  // Photo: largest size file id; video: the video file id. Zero when the content has no media.
  mediaFileId: number = 0;
  mediaWidth: number = 0;
  mediaHeight: number = 0;
  // Video only.
  duration: number = 0;
  minithumbnail: string = '';
  // Set once TDLib reports the media file as downloaded; empty until then.
  localPath: string = '';
  // Chip key of the reaction chosen by the current user ('emoji:👍' / 'custom:<id>'), empty if none.
  chosenReactionKey: string = '';
  // Only present for stories the current user may see interactions of (own stories).
  viewCount: number = 0;
  reactionCount: number = 0;
  forwardCount: number = 0;
}

export function storyContentKey(posterChatId: number, storyId: number): string {
  return posterChatId.toString() + ':' + storyId.toString();
}
