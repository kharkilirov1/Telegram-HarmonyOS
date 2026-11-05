// StoryNormalizer — active story list updates used by the ChatList title previews.

import {
  AnyAppEvent,
  createChatActiveStoriesUpdatedEvent,
  createStoryFullUpdatedEvent
} from '../../model/AppEvent';
import {
  ChatActiveStoriesDto,
  StoryContentKind,
  StoryFullDto,
  StoryInfoDto,
  StoryListType
} from '../../model/dto/StoryDto';
import { TdObject } from '../../../models/TdTypes';
import {
  tdGetArray,
  tdGetBoolean,
  tdGetNumber,
  tdGetObject,
  tdGetString,
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
  handlers.set('updateStory', handleStoryFull);
}

// I6: story content. Photos carry sizes, videos carry a file plus duration; anything else stays
// 'unsupported' so the viewer can show a placeholder instead of crashing on a new TDLib type.
function largestPhotoSize(sizes: TdObject[]): TdObject | undefined {
  let best: TdObject | undefined = undefined;
  let bestArea = 0;
  for (const size of sizes) {
    const width = tdGetNumber(size, 'width');
    const height = tdGetNumber(size, 'height');
    if (width > 0 && height > 0 && width * height > bestArea) {
      best = size;
      bestArea = width * height;
    }
  }
  return best;
}

export function parseStoryFull(story: TdObject): StoryFullDto {
  const dto = new StoryFullDto();
  dto.storyId = tdGetNumber(story, 'id');
  dto.posterChatId = tdGetNumber(story, 'poster_chat_id');
  dto.date = tdGetNumber(story, 'date');
  const caption = tdGetObject(story, 'caption');
  if (caption !== undefined) {
    dto.caption = tdGetString(caption, 'text');
  }
  const content = tdGetObject(story, 'content');
  const contentKind: StoryContentKind = content !== undefined ? storyContentKindFromTd(content) : 'unsupported';
  dto.kind = contentKind;
  if (contentKind === 'photo') {
    const photo = tdGetObject(content, 'photo');
    if (photo !== undefined) {
      dto.minithumbnail = minithumbnailData(photo);
      const best = largestPhotoSize(tdGetArray(photo, 'sizes'));
      if (best !== undefined) {
        dto.mediaWidth = tdGetNumber(best, 'width');
        dto.mediaHeight = tdGetNumber(best, 'height');
        const photoFile = tdGetObject(best, 'photo');
        if (photoFile !== undefined) {
          dto.mediaFileId = tdGetNumber(photoFile, 'id');
        }
      }
    }
  } else if (contentKind === 'video') {
    const video = tdGetObject(content, 'video');
    if (video !== undefined) {
      dto.duration = tdGetNumber(video, 'duration');
      dto.mediaWidth = tdGetNumber(video, 'width');
      dto.mediaHeight = tdGetNumber(video, 'height');
      dto.minithumbnail = minithumbnailData(video);
      const videoFile = tdGetObject(video, 'video');
      if (videoFile !== undefined) {
        dto.mediaFileId = tdGetNumber(videoFile, 'id');
      }
    }
  }
  return dto;
}

function storyContentKindFromTd(content: TdObject): StoryContentKind {
  const type = tdGetType(content);
  if (type === 'storyContentPhoto') {
    return 'photo';
  }
  if (type === 'storyContentVideo') {
    return 'video';
  }
  return 'unsupported';
}

function minithumbnailData(media: TdObject): string {
  const minithumbnail = tdGetObject(media, 'minithumbnail');
  if (minithumbnail === undefined) {
    return '';
  }
  return tdGetString(minithumbnail, 'data');
}

function handleStoryFull(events: AnyAppEvent[], update: TdObject): void {
  const story = tdGetObject(update, 'story');
  if (story === undefined) {
    return;
  }
  const dto = parseStoryFull(story);
  if (dto.storyId <= 0 || dto.posterChatId === 0) {
    return;
  }
  events.push(createStoryFullUpdatedEvent(dto));
}

