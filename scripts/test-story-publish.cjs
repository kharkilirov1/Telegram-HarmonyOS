// I6: story publishing — payload defaults, validation, privacy/content serialization and the use case.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

function load(relative, names, deps = {}) {
  const source = read(relative)
    .replace(/^import\s[\s\S]*?;\s*/gm, '')
    .replace(/^export\s*\{[^}]*\};?\s*/gm, '')
    .replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(source, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), js + '\nreturn {' + names.join(',') + '};')(...Object.values(deps));
}

async function main() {
  const C = load('core/model/AppCommand.ets',
    ['PostStoryCommand', 'PostStoryPayload', 'createPostStoryCommand'], {});
  const payload = new C.PostStoryPayload();
  assert.equal(payload.chatId, 0);
  assert.equal(payload.mediaKind, 'photo');
  assert.equal(payload.localPath, '');
  assert.equal(payload.privacy, 'everyone');
  assert.deepEqual(payload.selectedUserIds, []);
  assert.equal(payload.activePeriodSeconds, 0);
  assert.equal(payload.isPostedToChatPage, true);
  assert.equal(payload.protectContent, false);
  assert.equal(payload.isAnimation, false);

  const command = C.createPostStoryCommand(payload);
  assert.ok(command instanceof C.PostStoryCommand);
  assert.equal(command.type, 'postStory');
  assert.equal(command.payload, payload);
  const commandSource = read('core/model/AppCommand.ets');
  assert.match(commandSource, /export type StoryPrivacy = 'everyone' \| 'contacts' \| 'closeFriends' \| 'selectedUsers';/);
  assert.match(commandSource, /  \| PostStoryCommand/);

  // Serializer strings are built from the payload; check the mapping rules by reading the source.
  const serializer = read('infra/td/serialization/CommandSerializer.ets');
  assert.match(serializer, /COMMAND_SERIALIZATION_HANDLERS\.set\('postStory', serializePostStory\);/);
  assert.match(serializer, /result\.method = 'postStory';/);
  assert.match(serializer, /result\.params\.setNumber\('chat_id', cmd\.payload\.chatId\);/);
  assert.match(serializer, /result\.params\.setString\('_content_json', buildStoryContentJson\(cmd\.payload\)\);/);
  assert.match(serializer, /result\.params\.setString\('_areas_json', '\{"@type":"inputStoryAreas","areas":\[\]\}'\);/);
  assert.match(serializer, /result\.params\.setString\('_caption_json', buildFormattedTextJson\(cmd\.payload\.caption\)\);/);
  assert.match(serializer, /result\.params\.setString\('_privacy_settings_json', buildStoryPrivacyJson\(cmd\.payload\)\);/);
  assert.match(serializer, /result\.params\.setString\('_album_ids_json', '\[\]'\);/);
  assert.match(serializer, /result\.params\.setNumber\('active_period', cmd\.payload\.activePeriodSeconds > 0 \? cmd\.payload\.activePeriodSeconds : 86400\);/);
  assert.match(serializer, /result\.params\.setString\('_from_story_full_id_json', 'null'\);/);
  assert.match(serializer, /result\.params\.setBool\('is_posted_to_chat_page', cmd\.payload\.isPostedToChatPage\);/);
  assert.match(serializer, /result\.params\.setBool\('protect_content', cmd\.payload\.protectContent\);/);
  // Privacy variants and the video branch.
  assert.match(serializer, /"@type":"inputStoryContentPhoto","photo":/);
  assert.match(serializer, /"@type":"inputStoryContentVideo","video":/);
  assert.match(serializer, /"is_animation":/);
  assert.match(serializer, /storyPrivacySettingsEveryone/);
  assert.match(serializer, /storyPrivacySettingsContacts/);
  assert.match(serializer, /storyPrivacySettingsCloseFriends/);
  assert.match(serializer, /storyPrivacySettingsSelectedUsers/);
  assert.match(serializer, /buildInputFileLocalJson\(payload\.localPath\)/);

  // Use case ---------------------------------------------------------------------------------------
  const useCaseSource = read('domain/usecases/postStory.ets');
  assert.match(useCaseSource, /export class PostStoryUseCase \{/);
  assert.match(useCaseSource, /export const STORY_DEFAULT_ACTIVE_PERIOD_SECONDS = 86400;/);
  assert.match(useCaseSource, /export const STORY_MAX_CAPTION_LENGTH = 200;/);
  assert.match(useCaseSource, /constructor\(store: AppStore, gateway: TdGatewayPort\) \{/);
  assert.match(useCaseSource, /validate\(payload: PostStoryPayload\): string \{/);
  assert.match(useCaseSource, /if \(payload\.localPath\.length === 0\) \{/);
  assert.match(useCaseSource, /if \(payload\.caption\.length > STORY_MAX_CAPTION_LENGTH\) \{/);
  assert.match(useCaseSource, /if \(payload\.privacy === 'selectedUsers' && payload\.selectedUserIds\.length === 0\) \{/);
  assert.match(useCaseSource, /if \(payload\.mediaKind !== 'photo' && payload\.mediaKind !== 'video'\) \{/);
  assert.match(useCaseSource, /async execute\(payload: PostStoryPayload\): Promise<StoryFullDto \| undefined> \{/);
  assert.match(useCaseSource, /if \(this\.posting\) \{\n      return undefined;\n    \}/, 'a second post is refused while one runs');
  assert.match(useCaseSource, /const story: StoryFullDto = parseStoryFull\(response\);/);
  assert.match(useCaseSource, /await this\.store\.dispatch\(createStoryFullUpdatedEvent\(story\)\);/);
  assert.match(useCaseSource, /this\.posting = false;/);

  // Execute against a gateway double: success stores and returns the story, rejection returns undefined.
  const parseStoryFull = (raw) => {
    const source = raw && raw.raw ? raw.raw : raw;
    return {
    storyId: source.id,
    posterChatId: source.poster_chat_id,
    kind: 'photo',
    localPath: '',
    caption: ''
    };
  };
  class TdObjectFixture {
    constructor(raw) { this.raw = raw; }
  }
  const sent = [];
  let response = new TdObjectFixture({ id: 31, poster_chat_id: 900 });
  let fail = false;
  const gateway = {
    send: async (cmd) => {
      sent.push(cmd);
      if (fail) throw new Error('network');
      return response;
    }
  };
  const dispatched = [];
  const store = { dispatch: async (event) => { dispatched.push(event); } };
  const createStoryFullUpdatedEvent = (story) => ({ type: 'storyFullUpdated', story });
  const hilog = { info() {}, warn() {} };
  class TdObject {}
  const U = load('domain/usecases/postStory.ets', ['PostStoryUseCase', 'createPostStoryUseCase',
    'STORY_MAX_CAPTION_LENGTH'], {
    createPostStoryCommand: (p) => ({ type: 'postStory', payload: p }),
    createStoryFullUpdatedEvent,
    parseStoryFull,
    getEventNormalizer: () => ({ normalize: () => [] }),
    hilog,
    TdObject: TdObjectFixture
  });
  const useCase = new U.PostStoryUseCase(store, gateway);
  const good = new C.PostStoryPayload();
  good.chatId = 77;
  good.localPath = '/data/cache/story.jpg';
  good.caption = 'Hello';
  assert.equal(useCase.validate(good), '');
  const posted = await useCase.execute(good);
  assert.ok(posted, 'the posted story is returned');
  assert.equal(posted.storyId, 31);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].type, 'postStory');
  assert.equal(dispatched.length, 1);
  assert.equal(dispatched[0].type, 'storyFullUpdated');

  const noMedia = new C.PostStoryPayload();
  noMedia.chatId = 77;
  assert.equal(useCase.validate(noMedia), 'Choose a photo or a video first');
  assert.equal(await useCase.execute(noMedia), undefined);
  const tooLong = new C.PostStoryPayload();
  tooLong.chatId = 77;
  tooLong.localPath = '/a.jpg';
  tooLong.caption = 'x'.repeat(U.STORY_MAX_CAPTION_LENGTH + 1);
  assert.equal(useCase.validate(tooLong), 'The caption is too long');
  const noUsers = new C.PostStoryPayload();
  noUsers.chatId = 77;
  noUsers.localPath = '/a.jpg';
  noUsers.privacy = 'selectedUsers';
  assert.equal(useCase.validate(noUsers), 'Choose at least one person');
  const badKind = new C.PostStoryPayload();
  badKind.chatId = 77;
  badKind.localPath = '/a.jpg';
  badKind.mediaKind = 'audio';
  assert.equal(useCase.validate(badKind), 'Unsupported story media');

  fail = true;
  fail = false;
  const rejected = await useCase.execute(good);
  assert.ok(rejected, 'a later attempt still works');

  console.log('PASS story publish contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
