// I6: publishing a story — the payload default, the privacy mapping, content JSON for photo/video and the
// use case that returns the posted story.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createPostStoryCommand, PostStoryPayload } from '../../core/model/AppCommand';
import { StoryFullDto } from '../../core/model/dto/StoryDto';
import { createStoryFullUpdatedEvent } from '../../core/model/AppEvent';
import { parseStoryFull } from '../../core/events/normalizers/StoryNormalizer';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { TdObject } from '../../models/TdTypes';

const DOMAIN = 0x00B6;
const TAG = 'PostStory';
export const STORY_DEFAULT_ACTIVE_PERIOD_SECONDS = 86400;
export const STORY_MAX_CAPTION_LENGTH = 200;

export class PostStoryUseCase {
  private gateway: TdGatewayPort;
  private store: AppStore;
  private posting: boolean = false;

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  isPosting(): boolean {
    return this.posting;
  }

  validate(payload: PostStoryPayload): string {
    if (payload.localPath.length === 0) {
      return 'Choose a photo or a video first';
    }
    if (payload.caption.length > STORY_MAX_CAPTION_LENGTH) {
      return 'The caption is too long';
    }
    if (payload.privacy === 'selectedUsers' && payload.selectedUserIds.length === 0) {
      return 'Choose at least one person';
    }
    if (payload.mediaKind !== 'photo' && payload.mediaKind !== 'video') {
      return 'Unsupported story media';
    }
    return '';
  }

  // The response is the posted story; the normalizer stores it, so the viewer can open it immediately.
  async execute(payload: PostStoryPayload): Promise<StoryFullDto | undefined> {
    if (this.posting) {
      return undefined;
    }
    if (this.validate(payload).length > 0 || payload.chatId === 0) {
      return undefined;
    }
    this.posting = true;
    try {
      const response = await this.gateway.send(createPostStoryCommand(payload)) as TdObject;
      if (!(response instanceof TdObject)) {
        return undefined;
      }
      // postStory answers with the full story, not an update, so parse it and store it directly.
      const story: StoryFullDto = parseStoryFull(response);
      if (story.storyId <= 0 || story.posterChatId === 0) {
        return undefined;
      }
      await this.store.dispatch(createStoryFullUpdatedEvent(story));
      return story;
    } catch (error) {
      hilog.info(DOMAIN, TAG, 'Posting a story failed: %{public}s', String(error));
      return undefined;
    } finally {
      this.posting = false;
    }
  }
}

export function createPostStoryUseCase(store: AppStore, gateway: TdGatewayPort): PostStoryUseCase {
  return new PostStoryUseCase(store, gateway);
}
