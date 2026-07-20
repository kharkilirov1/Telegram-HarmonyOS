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
