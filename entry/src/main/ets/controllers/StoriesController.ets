// StoriesController — manages TDLib story data
// Reference: Telegram iOS StoriesManager, Android StoriesController

import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { Story, StoryContentType, ChatActiveStories } from '../models/Story';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'StoriesController';
const DOMAIN = 0x0001;

export class StoriesController {
  private static instance: StoriesController | null = null;
  private activeStoriesByChat: Map<number, ChatActiveStories> = new Map();
  private storiesCache: Map<string, Story> = new Map(); // key: "chatId_storyId"
  private sortedActiveStories: ChatActiveStories[] = [];

  private constructor() {
    this.subscribeToUpdates();
  }

  static getInstance(): StoriesController {
    if (!StoriesController.instance) {
      StoriesController.instance = new StoriesController();
    }
    return StoriesController.instance;
  }

  // --- Public read API ---

  getSortedActiveStories(): ChatActiveStories[] {
    return this.sortedActiveStories;
  }

  getCachedStory(chatId: number, storyId: number): Story | undefined {
    return this.storiesCache.get(`${chatId}_${storyId}`);
  }

  // --- Public action API ---

  async loadActiveStories(): Promise<void> {
    try {
      // Load story list from TDLib
      const storyList: Record<string, Object> = {};
      storyList['@type'] = 'storyListMain';
      const storyListParams: Record<string, Object> = {};
      storyListParams['story_list'] = storyList;
      storyListParams['limit'] = 50;
      const result = await TDLibClient.getInstance()
        .send('getStoryList', storyListParams) as Record<string, Object>;

      // TDLib sends updateChatActiveStories for each chat via subscription
      hilog.info(DOMAIN, TAG, 'Story list loaded');
    } catch (_e) {
      hilog.warn(DOMAIN, TAG, 'Failed to load story list, trying fallback');
      // Fallback: load chats and check for stories
      try {
        const chatList: Record<string, Object> = {};
        chatList['@type'] = 'chatListMain';
        const fallbackParams: Record<string, Object> = {};
        fallbackParams['chat_list'] = chatList;
        fallbackParams['limit'] = 30;
        await TDLibClient.getInstance().send('loadChats', fallbackParams);
      } catch (_e2) {
        // Silently fail
      }
    }
  }

  async getStory(chatId: number, storyId: number): Promise<Story | null> {
    const cached = this.storiesCache.get(`${chatId}_${storyId}`);
    if (cached) return cached;

    try {
      const getStoryParams: Record<string, Object> = {};
      getStoryParams['story_sender_chat_id'] = chatId;
      getStoryParams['story_id'] = storyId;
      getStoryParams['only_local'] = false;
      const result = await TDLibClient.getInstance()
        .send('getStory', getStoryParams) as Record<string, Object>;

      const story = this.parseStory(result, chatId);
      this.storiesCache.set(`${chatId}_${storyId}`, story);
      return story;
    } catch (_e) {
      hilog.warn(DOMAIN, TAG, 'Failed to get story %{public}d', storyId);
      return null;
    }
  }

  async openStory(chatId: number, storyId: number): Promise<void> {
    try {
      const openParams: Record<string, Object> = {};
      openParams['story_sender_chat_id'] = chatId;
      openParams['story_id'] = storyId;
      await TDLibClient.getInstance().send('openStory', openParams);

      // Mark as viewed locally
      const active = this.activeStoriesByChat.get(chatId);
      if (active && storyId > active.maxReadStoryId) {
        active.maxReadStoryId = storyId;
        active.hasUnread = active.storyIds.length > 0 &&
          active.storyIds[active.storyIds.length - 1] > active.maxReadStoryId;
        this.sortActiveStories();
        NotificationCenter.getInstance().post(EventId.STORIES_UPDATED);
      }
    } catch (_e) {
      // Silently fail
    }
  }

  async closeStory(chatId: number, storyId: number): Promise<void> {
    try {
      const closeParams: Record<string, Object> = {};
      closeParams['story_sender_chat_id'] = chatId;
      closeParams['story_id'] = storyId;
      await TDLibClient.getInstance().send('closeStory', closeParams);
    } catch (_e) {
      // Silently fail
    }
  }

  // --- TDLib update subscriptions ---

  private subscribeToUpdates(): void {
    const client = TDLibClient.getInstance();

    client.on('updateChatActiveStories', (update: Record<string, Object>) => {
      const activeStories = update['active_stories'] as Record<string, Object>;
      if (!activeStories) return;

      const chatId = activeStories['chat_id'] as number || 0;
      if (chatId === 0) return;

      const storyList = activeStories['list'] as Record<string, Object>;
      // Only handle main story list
      if (storyList && (storyList['@type'] as string) !== 'storyListMain') return;

      const maxReadId = (activeStories['max_read_story_id'] as number) || 0;
      const rawStories = activeStories['stories'] as Record<string, Object>[];
      const storyIds: number[] = [];

      if (rawStories) {
        for (const raw of rawStories) {
          const storyId = raw['id'] as number || 0;
          if (storyId > 0) {
            storyIds.push(storyId);
            const story = this.parseStory(raw, chatId);
            this.storiesCache.set(`${chatId}_${storyId}`, story);
          }
        }
      }

      const order = (activeStories['order'] as string) || '0';

      // Get chat info for display
      this.resolveChatInfo(chatId, storyIds, maxReadId, order);
    });

    client.on('updateStoryDeleted', (update: Record<string, Object>) => {
      const chatId = update['story_sender_chat_id'] as number || 0;
      const storyId = update['story_id'] as number || 0;

      this.storiesCache.delete(`${chatId}_${storyId}`);

      const active = this.activeStoriesByChat.get(chatId);
      if (active) {
        active.storyIds = active.storyIds.filter((id: number) => id !== storyId);
        if (active.storyIds.length === 0) {
          this.activeStoriesByChat.delete(chatId);
        }
        this.sortActiveStories();
        const deletedArgs: Record<string, Object> = {};
        deletedArgs['chatId'] = chatId;
        deletedArgs['storyId'] = storyId;
        NotificationCenter.getInstance().post(EventId.STORY_DELETED, deletedArgs);
      }
    });
  }

  private async resolveChatInfo(chatId: number, storyIds: number[], maxReadId: number,
    order: string): Promise<void> {
    let title = '';
    let photoUrl = '';
    let initial = '';

    try {
      const chatParams: Record<string, Object> = {};
      chatParams['chat_id'] = chatId;
      const chatResult = await TDLibClient.getInstance()
        .send('getChat', chatParams) as Record<string, Object>;

      title = (chatResult['title'] as string) || '';
      initial = title.length > 0 ? title.charAt(0).toUpperCase() : '?';

      const photo = chatResult['photo'] as Record<string, Object>;
      if (photo) {
        const small = photo['small'] as Record<string, Object>;
        if (small) {
          const localFile = small['local'] as Record<string, Object>;
          if (localFile && (localFile['is_downloading_completed'] as boolean)) {
            photoUrl = (localFile['path'] as string) || '';
          }
        }
      }
    } catch (_e) {
      initial = '?';
    }

    const activeStory = new ChatActiveStories(
      chatId, title, photoUrl, initial, storyIds, maxReadId, order
    );
    this.activeStoriesByChat.set(chatId, activeStory);
    this.sortActiveStories();
    NotificationCenter.getInstance().post(EventId.STORIES_UPDATED);
  }

  private sortActiveStories(): void {
    const list: ChatActiveStories[] = [];
    this.activeStoriesByChat.forEach((value: ChatActiveStories) => {
      if (value.storyIds.length > 0) {
        list.push(value);
      }
    });

    // Sort: unread first, then by order (like Telegram iOS/Android)
    list.sort((a: ChatActiveStories, b: ChatActiveStories) => {
      if (a.hasUnread && !b.hasUnread) return -1;
      if (!a.hasUnread && b.hasUnread) return 1;
      if (a.order > b.order) return -1;
      if (a.order < b.order) return 1;
      return 0;
    });

    this.sortedActiveStories = list;
  }

  private parseStory(raw: Record<string, Object>, chatId: number): Story {
    const id = (raw['id'] as number) || 0;
    const date = (raw['date'] as number) || 0;
    const expirationDate = (raw['expiration_date'] as number) || 0;
    const isPinned = (raw['is_pinned'] as boolean) || false;

    let contentType = StoryContentType.PHOTO;
    let photoUrl = '';
    let videoUrl = '';
    let caption = '';

    const content = raw['content'] as Record<string, Object>;
    if (content) {
      const type = (content['@type'] as string) || '';
      if (type === 'storyContentVideo') {
        contentType = StoryContentType.VIDEO;
        const video = content['video'] as Record<string, Object>;
        if (video) {
          const videoFile = video['video'] as Record<string, Object>;
          if (videoFile) {
            const localFile = videoFile['local'] as Record<string, Object>;
            if (localFile && (localFile['is_downloading_completed'] as boolean)) {
              videoUrl = (localFile['path'] as string) || '';
            }
          }
        }
      } else {
        // storyContentPhoto
        const photo = content['photo'] as Record<string, Object>;
        if (photo) {
          const sizes = photo['sizes'] as Record<string, Object>[];
          if (sizes && sizes.length > 0) {
            const lastSize = sizes[sizes.length - 1];
            const photoFile = lastSize['photo'] as Record<string, Object>;
            if (photoFile) {
              const localFile = photoFile['local'] as Record<string, Object>;
              if (localFile && (localFile['is_downloading_completed'] as boolean)) {
                photoUrl = (localFile['path'] as string) || '';
              }
            }
          }
        }
      }

      const captionObj = content['caption'] as Record<string, Object>;
      if (captionObj) {
        caption = (captionObj['text'] as string) || '';
      }
    }

    return new Story(id, chatId, date, expirationDate, false, isPinned,
      contentType, photoUrl, videoUrl, caption, false);
  }
}
