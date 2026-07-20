import { describe, it, expect } from '@ohos/hypium';
import { createInitialAppState } from '../../../main/ets/core/model/AppState';
import { createChatActiveStoriesUpdatedEvent } from '../../../main/ets/core/model/AppEvent';
import {
  ChatActiveStoriesDto,
  StoryInfoDto,
  hasUnreadActiveStories,
  hasUnreadCloseFriendsStories,
  latestActiveStoryId
} from '../../../main/ets/core/model/dto/StoryDto';
import { appReducer } from '../../../main/ets/core/reducers/index';

function activeStories(
  chatId: number,
  order: number,
  storyId: number,
  maxReadStoryId: number = 0,
  closeFriends: boolean = false
): ChatActiveStoriesDto {
  const dto = new ChatActiveStoriesDto();
  dto.chatId = chatId;
  dto.listType = 'main';
  dto.order = order;
  dto.maxReadStoryId = maxReadStoryId;
  const story = new StoryInfoDto();
  story.storyId = storyId;
  story.isForCloseFriends = closeFriends;
  dto.stories = [story];
  return dto;
}

export default function activeStoriesStateTest() {
  describe('ActiveStoriesState', () => {
    it('routes, stores and sorts main active stories without mutating prior state', 0, () => {
      const initial = createInitialAppState();
      let state = appReducer(initial, createChatActiveStoriesUpdatedEvent(activeStories(10, 100, 1)));
      state = appReducer(state, createChatActiveStoriesUpdatedEvent(activeStories(30, 200, 2)));
      state = appReducer(state, createChatActiveStoriesUpdatedEvent(activeStories(20, 200, 3)));

      expect(initial.chats.activeStoriesByChatId.size).assertEqual(0);
      expect(state.chats.activeStoriesByChatId.size).assertEqual(3);
      expect(state.chats.orderedStoryChatIds.length).assertEqual(3);
      expect(state.chats.orderedStoryChatIds[0]).assertEqual(30);
      expect(state.chats.orderedStoryChatIds[1]).assertEqual(20);
      expect(state.chats.orderedStoryChatIds[2]).assertEqual(10);
    });

    it('removes order-zero story posters and derives unread/close-friends state', 0, () => {
      const unread = activeStories(10, 100, 5, 4, true);
      expect(latestActiveStoryId(unread)).assertEqual(5);
      expect(hasUnreadActiveStories(unread)).assertTrue();
      expect(hasUnreadCloseFriendsStories(unread)).assertTrue();

      let state = appReducer(createInitialAppState(), createChatActiveStoriesUpdatedEvent(unread));
      const removed = new ChatActiveStoriesDto();
      removed.chatId = 10;
      removed.listType = 'none';
      state = appReducer(state, createChatActiveStoriesUpdatedEvent(removed));

      expect(state.chats.activeStoriesByChatId.has(10)).assertFalse();
      expect(state.chats.orderedStoryChatIds.length).assertEqual(0);
    });
  });
}
