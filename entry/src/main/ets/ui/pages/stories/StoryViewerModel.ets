// I6: story viewer model. The page owns rendering; these helpers keep navigation and progress pure so
// the tap/long-press rules can be tested without ArkUI.

import { StoryFullDto, storyContentKey } from '../../../core/model/dto/StoryDto';

export class StoryViewerRouteParams {
  chatId: number = 0;
  chatTitle: string = '';
  storyIds: number[] = [];
  startIndex: number = 0;

  constructor(chatId: number = 0, chatTitle: string = '', storyIds: number[] = [], startIndex: number = 0) {
    this.chatId = chatId;
    this.chatTitle = chatTitle;
    this.storyIds = storyIds;
    this.startIndex = startIndex;
  }
}

export function clampStoryIndex(index: number, count: number): number {
  if (!Number.isFinite(index) || count <= 0) {
    return 0;
  }
  const rounded = Math.floor(index);
  if (rounded < 0) {
    return 0;
  }
  return rounded >= count ? count - 1 : rounded;
}

// Progress of the story at `index` inside the viewer's segment row, 0..1.
export function storySegmentFill(index: number, count: number, position: number): number {
  if (count <= 0 || index < 0 || index >= count) {
    return 0;
  }
  if (index > position) {
    return 0;
  }
  if (index < Math.floor(position)) {
    return 1;
  }
  const fraction = position - Math.floor(position);
  if (!Number.isFinite(fraction) || fraction <= 0) {
    return 0;
  }
  return fraction > 1 ? 1 : fraction;
}

// Tapping the right half advances; the last story closes the viewer. Returns -1 for "close".
export function nextStoryIndex(index: number, count: number): number {
  if (count <= 0) {
    return -1;
  }
  const current = clampStoryIndex(index, count);
  return current >= count - 1 ? -1 : current + 1;
}

// Tapping the left half goes back; before the first story the viewer stays (iOS keeps it open).
export function previousStoryIndex(index: number, count: number): number {
  if (count <= 0) {
    return -1;
  }
  const current = clampStoryIndex(index, count);
  return current > 0 ? current - 1 : 0;
}

// Photo stories show for five seconds, videos for their own duration (bounded).
export const STORY_PHOTO_DURATION_MS = 5000;
export const STORY_MIN_DURATION_MS = 1000;
export const STORY_MAX_DURATION_MS = 30000;

export function storyDisplayDurationMs(story: StoryFullDto | undefined): number {
  if (story === undefined) {
    return STORY_PHOTO_DURATION_MS;
  }
  if (story.kind !== 'video' || story.duration <= 0) {
    return STORY_PHOTO_DURATION_MS;
  }
  const durationMs = story.duration * 1000;
  if (durationMs < STORY_MIN_DURATION_MS) {
    return STORY_MIN_DURATION_MS;
  }
  return durationMs > STORY_MAX_DURATION_MS ? STORY_MAX_DURATION_MS : durationMs;
}

export function storyCacheKey(chatId: number, storyId: number): string {
  return storyContentKey(chatId, storyId);
}

// The viewer shows a thumbnail while the media downloads, so the frame is never empty.
export function storyPosterPath(story: StoryFullDto | undefined): string {
  if (story === undefined) {
    return '';
  }
  return story.localPath;
}

// A story whose content has no media (unsupported type) is skipped instead of blocking the viewer.
export function isRenderableStory(story: StoryFullDto | undefined): boolean {
  return story !== undefined && story.kind !== 'unsupported' && story.mediaFileId !== 0;
}
