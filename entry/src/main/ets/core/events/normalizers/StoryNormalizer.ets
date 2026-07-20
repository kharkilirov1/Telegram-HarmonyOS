// StoryNormalizer — active story list updates used by the ChatList title previews.

import {
  AnyAppEvent,
  createChatActiveStoriesUpdatedEvent
} from '../../model/AppEvent';
import {
  ChatActiveStoriesDto,
  StoryInfoDto,
  StoryListType
} from '../../model/dto/StoryDto';
import { TdObject } from '../../../models/TdTypes';
import {
  tdGetArray,
  tdGetBoolean,
  tdGetNumber,
  tdGetObject,
  tdGetType
} from '../../utils/tdAccessors';

function storyListTypeFromTd(list: TdObject): StoryListType {
  const type = tdGetType(list);
  if (type === 'storyListMain') {
    return 'main';
  }
  if (type === 'storyListArchive') {
    return 'archive';
  }
  return 'none';
}

function storyInfoFromTd(story: TdObject): StoryInfoDto {
  const dto = new StoryInfoDto();
  dto.storyId = tdGetNumber(story, 'story_id');
  dto.date = tdGetNumber(story, 'date');
  dto.isForCloseFriends = tdGetBoolean(story, 'is_for_close_friends');
  dto.isLive = tdGetBoolean(story, 'is_live');
  return dto;
}

function handleChatActiveStories(events: AnyAppEvent[], update: TdObject): void {
  const activeStories = tdGetObject(update, 'active_stories');
  const chatId = tdGetNumber(activeStories, 'chat_id');
  if (chatId === 0) {
    return;
  }

  const dto = new ChatActiveStoriesDto();
  dto.chatId = chatId;
  dto.listType = storyListTypeFromTd(tdGetObject(activeStories, 'list'));
  dto.order = tdGetNumber(activeStories, 'order');
  dto.canBeArchived = tdGetBoolean(activeStories, 'can_be_archived');
  dto.maxReadStoryId = tdGetNumber(activeStories, 'max_read_story_id');
  const stories = tdGetArray(activeStories, 'stories');
  for (const story of stories) {
    const storyInfo = storyInfoFromTd(story);
    if (storyInfo.storyId > 0) {
      dto.stories.push(storyInfo);
    }
  }

  events.push(createChatActiveStoriesUpdatedEvent(dto));
}

export function registerStoryHandlers(
  handlers: Map<string, (events: AnyAppEvent[], update: TdObject) => void>
): void {
  handlers.set('updateChatActiveStories', handleChatActiveStories);
}
