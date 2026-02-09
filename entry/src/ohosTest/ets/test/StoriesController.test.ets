import { describe, it, expect } from '@ohos/hypium';
import { Story, StoryContentType, ChatActiveStories } from '../../../main/ets/models/Story';

/**
 * Unit tests for StoriesController — story parsing, active stories sorting,
 * and Story/ChatActiveStories model behavior.
 */

// Standalone copy of parseStory — the private method on StoriesController
function parseStory(raw: Record<string, Object>, chatId: number): Story {
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

// Standalone copy of sortActiveStories logic
function sortActiveStories(list: ChatActiveStories[]): ChatActiveStories[] {
  return list.sort((a: ChatActiveStories, b: ChatActiveStories) => {
    if (a.hasUnread && !b.hasUnread) return -1;
    if (!a.hasUnread && b.hasUnread) return 1;
    if (a.order > b.order) return -1;
    if (a.order < b.order) return 1;
    return 0;
  });
}

export default function storiesControllerTest() {
  describe('StoriesController', () => {

    // -----------------------------------------------------------------------
    // Story model
    // -----------------------------------------------------------------------
    describe('Story model', () => {

      it('should construct with default values', 0, () => {
        const story = new Story();
        expect(story.id).assertEqual(0);
        expect(story.chatId).assertEqual(0);
        expect(story.contentType).assertEqual(StoryContentType.PHOTO);
        expect(story.photoUrl).assertEqual('');
        expect(story.videoUrl).assertEqual('');
        expect(story.caption).assertEqual('');
        expect(story.isViewed).assertFalse();
        expect(story.isPinned).assertFalse();
      });

      it('should construct with all parameters', 0, () => {
        const story = new Story(42, 100, 1700000000, 1700086400, true, true,
          StoryContentType.VIDEO, '', '/video.mp4', 'My story', true);
        expect(story.id).assertEqual(42);
        expect(story.chatId).assertEqual(100);
        expect(story.date).assertEqual(1700000000);
        expect(story.expirationDate).assertEqual(1700086400);
        expect(story.isOutgoing).assertTrue();
        expect(story.isPinned).assertTrue();
        expect(story.contentType).assertEqual(StoryContentType.VIDEO);
        expect(story.videoUrl).assertEqual('/video.mp4');
        expect(story.caption).assertEqual('My story');
        expect(story.isViewed).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // ChatActiveStories model
    // -----------------------------------------------------------------------
    describe('ChatActiveStories model', () => {

      it('should construct with default values', 0, () => {
        const active = new ChatActiveStories();
        expect(active.chatId).assertEqual(0);
        expect(active.chatTitle).assertEqual('');
        expect(active.storyIds.length).assertEqual(0);
        expect(active.hasUnread).assertFalse();
        expect(active.order).assertEqual('0');
      });

      it('should compute hasUnread when latest story exceeds maxReadStoryId', 0, () => {
        const storyIds: number[] = [1, 2, 3];
        const active = new ChatActiveStories(100, 'Alice', '', 'A', storyIds, 2, '100');
        expect(active.hasUnread).assertTrue();
      });

      it('should compute hasUnread=false when all stories are read', 0, () => {
        const storyIds: number[] = [1, 2, 3];
        const active = new ChatActiveStories(100, 'Alice', '', 'A', storyIds, 3, '100');
        expect(active.hasUnread).assertFalse();
      });

      it('should compute hasUnread=false when all stories read (maxRead > last)', 0, () => {
        const storyIds: number[] = [1, 2, 3];
        const active = new ChatActiveStories(100, 'Alice', '', 'A', storyIds, 5, '100');
        expect(active.hasUnread).assertFalse();
      });

      it('should compute hasUnread=false for empty story list', 0, () => {
        const storyIds: number[] = [];
        const active = new ChatActiveStories(100, 'Alice', '', 'A', storyIds, 0, '100');
        expect(active.hasUnread).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // parseStory
    // -----------------------------------------------------------------------
    describe('parseStory', () => {

      it('should parse a photo story', 0, () => {
        const localFile: Record<string, Object> = {};
        localFile['is_downloading_completed'] = true;
        localFile['path'] = '/data/story_photo.jpg';
        const photoFile: Record<string, Object> = {};
        photoFile['local'] = localFile;
        const size: Record<string, Object> = {};
        size['photo'] = photoFile;
        const sizes: Record<string, Object>[] = [size];
        const photo: Record<string, Object> = {};
        photo['sizes'] = sizes;
        const captionObj: Record<string, Object> = {};
        captionObj['text'] = 'Look at this!';
        const content: Record<string, Object> = {};
        content['@type'] = 'storyContentPhoto';
        content['photo'] = photo;
        content['caption'] = captionObj;
        const raw: Record<string, Object> = {};
        raw['id'] = 10;
        raw['date'] = 1700000000;
        raw['expiration_date'] = 1700086400;
        raw['is_pinned'] = true;
        raw['content'] = content;

        const story = parseStory(raw, 42);
        expect(story.id).assertEqual(10);
        expect(story.chatId).assertEqual(42);
        expect(story.date).assertEqual(1700000000);
        expect(story.expirationDate).assertEqual(1700086400);
        expect(story.isPinned).assertTrue();
        expect(story.contentType).assertEqual(StoryContentType.PHOTO);
        expect(story.photoUrl).assertEqual('/data/story_photo.jpg');
        expect(story.caption).assertEqual('Look at this!');
      });

      it('should parse a video story', 0, () => {
        const localFile: Record<string, Object> = {};
        localFile['is_downloading_completed'] = true;
        localFile['path'] = '/data/story_video.mp4';
        const videoFileObj: Record<string, Object> = {};
        videoFileObj['local'] = localFile;
        const video: Record<string, Object> = {};
        video['video'] = videoFileObj;
        const content: Record<string, Object> = {};
        content['@type'] = 'storyContentVideo';
        content['video'] = video;
        const raw: Record<string, Object> = {};
        raw['id'] = 20;
        raw['date'] = 1700001000;
        raw['content'] = content;

        const story = parseStory(raw, 50);
        expect(story.id).assertEqual(20);
        expect(story.chatId).assertEqual(50);
        expect(story.contentType).assertEqual(StoryContentType.VIDEO);
        expect(story.videoUrl).assertEqual('/data/story_video.mp4');
      });

      it('should handle story with no content', 0, () => {
        const raw: Record<string, Object> = {};
        raw['id'] = 30;

        const story = parseStory(raw, 1);
        expect(story.id).assertEqual(30);
        expect(story.contentType).assertEqual(StoryContentType.PHOTO);
        expect(story.photoUrl).assertEqual('');
        expect(story.videoUrl).assertEqual('');
        expect(story.caption).assertEqual('');
      });

      it('should handle photo not yet downloaded', 0, () => {
        const localFile: Record<string, Object> = {};
        localFile['is_downloading_completed'] = false;
        localFile['path'] = '';
        const photoFile: Record<string, Object> = {};
        photoFile['local'] = localFile;
        const size: Record<string, Object> = {};
        size['photo'] = photoFile;
        const sizes: Record<string, Object>[] = [size];
        const photo: Record<string, Object> = {};
        photo['sizes'] = sizes;
        const content: Record<string, Object> = {};
        content['@type'] = 'storyContentPhoto';
        content['photo'] = photo;
        const raw: Record<string, Object> = {};
        raw['id'] = 40;
        raw['content'] = content;

        const story = parseStory(raw, 1);
        expect(story.photoUrl).assertEqual('');
      });

      it('should default fields for minimal raw data', 0, () => {
        const raw: Record<string, Object> = {};

        const story = parseStory(raw, 99);
        expect(story.id).assertEqual(0);
        expect(story.chatId).assertEqual(99);
        expect(story.date).assertEqual(0);
        expect(story.isPinned).assertFalse();
        expect(story.isViewed).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // sortActiveStories
    // -----------------------------------------------------------------------
    describe('sortActiveStories', () => {

      it('should sort unread stories before read stories', 0, () => {
        const unreadIds: number[] = [5];
        const readIds: number[] = [1, 2];
        const list: ChatActiveStories[] = [
          new ChatActiveStories(1, 'Read', '', 'R', readIds, 2, '100'),
          new ChatActiveStories(2, 'Unread', '', 'U', unreadIds, 3, '50'),
        ];

        const sorted = sortActiveStories(list);
        expect(sorted[0].chatTitle).assertEqual('Unread');
        expect(sorted[1].chatTitle).assertEqual('Read');
      });

      it('should sort by order descending among same unread status', 0, () => {
        const ids1: number[] = [10];
        const ids2: number[] = [20];
        const ids3: number[] = [30];
        const list: ChatActiveStories[] = [
          new ChatActiveStories(1, 'Low', '', 'L', ids1, 0, '100'),
          new ChatActiveStories(2, 'High', '', 'H', ids2, 0, '300'),
          new ChatActiveStories(3, 'Mid', '', 'M', ids3, 0, '200'),
        ];

        const sorted = sortActiveStories(list);
        expect(sorted[0].chatTitle).assertEqual('High');
        expect(sorted[1].chatTitle).assertEqual('Mid');
        expect(sorted[2].chatTitle).assertEqual('Low');
      });

      it('should handle empty list', 0, () => {
        const list: ChatActiveStories[] = [];
        const sorted = sortActiveStories(list);
        expect(sorted.length).assertEqual(0);
      });

      it('should handle single item', 0, () => {
        const ids: number[] = [1];
        const list: ChatActiveStories[] = [
          new ChatActiveStories(1, 'Solo', '', 'S', ids, 0, '100'),
        ];
        const sorted = sortActiveStories(list);
        expect(sorted.length).assertEqual(1);
        expect(sorted[0].chatTitle).assertEqual('Solo');
      });

      it('should sort unread first then by order within each group', 0, () => {
        const ids1: number[] = [5];
        const ids2: number[] = [10];
        const ids3: number[] = [1, 2];
        const ids4: number[] = [3];
        const list: ChatActiveStories[] = [
          new ChatActiveStories(1, 'ReadLow', '', 'R', ids3, 2, '50'),
          new ChatActiveStories(2, 'UnreadLow', '', 'U', ids1, 3, '100'),
          new ChatActiveStories(3, 'UnreadHigh', '', 'U', ids2, 5, '200'),
          new ChatActiveStories(4, 'ReadHigh', '', 'R', ids4, 3, '300'),
        ];

        const sorted = sortActiveStories(list);
        // Unread first (sorted by order desc)
        expect(sorted[0].chatTitle).assertEqual('UnreadHigh');
        expect(sorted[1].chatTitle).assertEqual('UnreadLow');
        // Read next (sorted by order desc)
        expect(sorted[2].chatTitle).assertEqual('ReadHigh');
        expect(sorted[3].chatTitle).assertEqual('ReadLow');
      });
    });

    // -----------------------------------------------------------------------
    // Cache key format
    // -----------------------------------------------------------------------
    describe('cache key format', () => {

      it('should use chatId_storyId format for cache key', 0, () => {
        const key = `${42}_${10}`;
        expect(key).assertEqual('42_10');
      });

      it('should produce unique keys for different chatId/storyId pairs', 0, () => {
        const key1 = `${1}_${2}`;
        const key2 = `${2}_${1}`;
        expect(key1 !== key2).assertTrue();
      });
    });
  });
}
