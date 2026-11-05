// I6: story content — DTO/keys, TDLib parsing for photo/video/unsupported, the event and reducer,
// the getStory command serialization and the load-story use case.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(root);

const td = {
  '@type': 'story',
  id: 12,
  poster_chat_id: 345,
  date: 1700000000,
  caption: { '@type': 'formattedText', text: 'Hello story', entities: [] },
  content: {
    '@type': 'storyContentPhoto',
    photo: {
      '@type': 'photo',
      has_sticker: false,
      minithumbnail: { '@type': 'minithumbnail', width: 40, height: 40, data: 'AQID' },
      sizes: [
        { '@type': 'photoSize', type: 's', width: 90, height: 120,
          photo: { '@type': 'file', id: 1, size: 100, expected_size: 100 } },
        { '@type': 'photoSize', type: 'x', width: 900, height: 1200,
          photo: { '@type': 'file', id: 2, size: 9000, expected_size: 9000 } }
      ]
    }
  }
};

const videoStory = {
  '@type': 'story',
  id: 13,
  poster_chat_id: 345,
  date: 1700000100,
  caption: { '@type': 'formattedText', text: '', entities: [] },
  content: {
    '@type': 'storyContentVideo',
    video: {
      '@type': 'storyVideo',
      duration: 11,
      width: 720,
      height: 1280,
      minithumbnail: { '@type': 'minithumbnail', width: 32, height: 32, data: 'BAUG' },
      video: { '@type': 'file', id: 77, size: 5000, expected_size: 5000 }
    }
  }
};

const unsupportedStory = {
  '@type': 'story',
  id: 14,
  poster_chat_id: 345,
  date: 1700000200,
  caption: { '@type': 'formattedText', text: 'text only', entities: [] },
  content: { '@type': 'storyContentUnsupported' }
};

// Minimal TdObject with the terse accessors the project uses.
class TdObject {
  constructor(raw) {
    this.raw = raw;
    this['@type'] = raw['@type'];
    for (const [key, value] of Object.entries(raw)) {
      if (key === '@type') continue;
      this[key] = value;
    }
  }
}
const wrap = (value) => (value !== null && typeof value === 'object' && !Array.isArray(value) && value['@type']
  ? new TdObject(value)
  : value);
const accessors = {
  tdGetType: (object) => (object && object['@type']) || '',
  tdGetNumber: (object, key) => {
    const value = object === undefined || object === null ? undefined : object[key];
    return typeof value === 'number' ? value : 0;
  },
  tdGetBoolean: (object, key) => {
    const value = object === undefined || object === null ? undefined : object[key];
    return value === true;
  },
  tdGetString: (object, key) => {
    const value = object === undefined || object === null ? undefined : object[key];
    return typeof value === 'string' ? value : '';
  },
  tdGetObject: (object, key) => {
    const value = object === undefined || object === null ? undefined : object[key];
    return wrap(value);
  },
  tdGetArray: (object, key) => {
    const value = object === undefined || object === null ? undefined : object[key];
    return Array.isArray(value) ? value.map((item) => wrap(item)) : [];
  }
};

async function main() {
  const S = load('core/model/dto/StoryDto.ets',
    ['StoryFullDto', 'storyContentKey', 'ChatActiveStoriesDto', 'StoryInfoDto',
      'latestActiveStoryId', 'hasUnreadActiveStories', 'hasUnreadCloseFriendsStories',
      ], {});
  assert.equal(S.storyContentKey(345, 12), '345:12');
  assert.equal(S.storyContentKey(0, 1), '0:1');
  const emptyStory = new S.StoryFullDto();
  assert.equal(emptyStory.kind, 'unsupported');
  assert.equal(emptyStory.mediaFileId, 0);

  const E = load('core/model/AppEvent.ets',
    ['StoryFullUpdatedEvent', 'createStoryFullUpdatedEvent', 'ChatActiveStoriesUpdatedEvent'],
    { StoryFullDto: S.StoryFullDto });

  // Parser -----------------------------------------------------------------------------------------
  const N = load('core/events/normalizers/StoryNormalizer.ets',
    ['parseStoryFull', 'registerStoryHandlers'],
    { ...accessors, StoryFullDto: S.StoryFullDto, ChatActiveStoriesDto: S.ChatActiveStoriesDto,
      StoryInfoDto: S.StoryInfoDto, createChatActiveStoriesUpdatedEvent: E.createChatActiveStoriesUpdatedEvent,
      createStoryFullUpdatedEvent: E.createStoryFullUpdatedEvent,
      parseReactionTypeKey: () => '' });
  const photo = N.parseStoryFull(new TdObject(td));
  assert.equal(photo.storyId, 12);
  assert.equal(photo.posterChatId, 345);
  assert.equal(photo.date, 1700000000);
  assert.equal(photo.kind, 'photo');
  assert.equal(photo.caption, 'Hello story');
  assert.equal(photo.mediaFileId, 2, 'the largest photo size wins');
  assert.equal(photo.mediaWidth, 900);
  assert.equal(photo.mediaHeight, 1200);
  assert.equal(photo.minithumbnail, 'AQID');
  assert.equal(photo.duration, 0);

  const video = N.parseStoryFull(new TdObject(videoStory));
  assert.equal(video.kind, 'video');
  assert.equal(video.mediaFileId, 77);
  assert.equal(video.duration, 11);
  assert.equal(video.mediaWidth, 720);
  assert.equal(video.mediaHeight, 1280);
  assert.equal(video.minithumbnail, 'BAUG');
  assert.equal(video.caption, '');

  const unsupported = N.parseStoryFull(new TdObject(unsupportedStory));
  assert.equal(unsupported.kind, 'unsupported');
  assert.equal(unsupported.mediaFileId, 0);
  assert.equal(unsupported.caption, 'text only');

  const missingContent = N.parseStoryFull(new TdObject({ '@type': 'story', id: 15, poster_chat_id: 1 }));
  assert.equal(missingContent.kind, 'unsupported');
  assert.equal(missingContent.caption, '');

  // Event ------------------------------------------------------------------------------------------
  const storyDto = photo;
  const event = E.createStoryFullUpdatedEvent(storyDto);
  assert.equal(event.type, 'storyFullUpdated');
  assert.equal(event.story.storyId, 12);
  assert.equal(typeof event.timestamp, 'number');
  assert.ok(event instanceof E.StoryFullUpdatedEvent);

  // Handlers ---------------------------------------------------------------------------------------
  const handlers = new Map();
  N.registerStoryHandlers(handlers);
  assert.ok(handlers.has('updateStory'), 'updateStory is registered');
  assert.ok(handlers.has('updateChatActiveStories'));
  const events = [];
  handlers.get('updateStory')(events, new TdObject({ '@type': 'updateStory', story: td }));
  assert.equal(events.length, 1);
  assert.equal(events[0].type, 'storyFullUpdated');
  assert.equal(events[0].story.storyId, 12);
  const badEvents = [];
  handlers.get('updateStory')(badEvents, new TdObject({ '@type': 'updateStory' }));
  assert.equal(badEvents.length, 0, 'an update without a story is ignored');
  const zeroEvents = [];
  handlers.get('updateStory')(zeroEvents, new TdObject({ '@type': 'updateStory',
    story: { '@type': 'story', id: 0, poster_chat_id: 5 } }));
  assert.equal(zeroEvents.length, 0, 'an empty id is ignored');

  assert.equal(event.type, 'storyFullUpdated');
  assert.equal(event.story.storyId, 12);
  assert.equal(typeof event.timestamp, 'number');
  assert.ok(event instanceof E.StoryFullUpdatedEvent);

  const state = read('core/model/AppState.ets');
  assert.match(state, /storyContentsByKey: Map<string, StoryFullDto> = new Map<string, StoryFullDto>\(\);/);
  const reducer = read('core/reducers/chatsReducer.ets');
  assert.match(reducer, /case 'storyFullUpdated': \{/);
  assert.match(reducer, /newState\.chats\.storyContentsByKey\.set\(storyContentKey\(story\.posterChatId, story\.storyId\), story\);/);
  assert.match(reducer, /type === 'storyFullUpdated' \|\|/);
  const clone = read('core/utils/stateClone.ets');
  assert.match(clone, /newChats\.storyContentsByKey = new Map<string, StoryFullDto>\(chats\.storyContentsByKey\);/);

  // Command ----------------------------------------------------------------------------------------
  const C = load('core/model/AppCommand.ets',
    ['GetStoryCommand', 'GetStoryPayload', 'createGetStoryCommand'], {});
  const command = C.createGetStoryCommand(345, 12);
  assert.ok(command instanceof C.GetStoryCommand);
  assert.equal(command.type, 'getStory');
  assert.equal(command.payload.posterChatId, 345);
  assert.equal(command.payload.storyId, 12);
  const commandSource = read('core/model/AppCommand.ets');
  assert.match(commandSource, /  \| GetStoryCommand/);

  const serializer = read('infra/td/serialization/CommandSerializer.ets');
  assert.match(serializer, /COMMAND_SERIALIZATION_HANDLERS\.set\('getStory', serializeGetStory\);/);
  assert.match(serializer, /result\.method = 'getStory';/);
  assert.match(serializer, /result\.params\.setString\('poster_chat_id', cmd\.payload\.posterChatId\.toString\(\)\);/);
  assert.match(serializer, /result\.params\.setNumber\('story_id', cmd\.payload\.storyId\);/);
  assert.match(serializer, /result\.params\.setBool\('only_local', false\);/);

  // Use case ---------------------------------------------------------------------------------------
  const useCase = read('domain/usecases/loadStory.ets');
  assert.match(useCase, /export class LoadStoryUseCase \{/);
  assert.match(useCase, /cached\(posterChatId: number, storyId: number\): StoryFullDto \| undefined \{/);
  assert.match(useCase, /async execute\(posterChatId: number, storyId: number\): Promise<StoryFullDto \| undefined> \{/);
  assert.match(useCase, /const cached = this\.cached\(posterChatId, storyId\);/);
  assert.match(useCase, /await this\.gateway\.send\(createGetStoryCommand\(posterChatId, storyId\)\);/);
  assert.match(useCase, /getEventNormalizer\(\)\.normalize\(story\)/);
  assert.match(useCase, /await this\.store\.dispatchBatch\(events\);/);
  assert.match(useCase, /this\.inFlightKeys\.delete\(key\);/);

  console.log('PASS story content contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
