// I6: story composer — media kind detection, caption clamp, privacy cycle, payload building, page wiring,
// route, strings and the chat-list entry decision.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');
const readResource = (relative) =>
  fs.readFileSync(path.join(root, '..', 'resources', relative), 'utf8').replaceAll('\r\n', '\n');

function load(relative, names, deps = {}) {
  const source = read(relative)
    .replace(/^import\s[\s\S]*?;\s*/gm, '')
    .replace(/^export\s*\{[^}]*\};?\s*/gm, '')
    .replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(source, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), js + '\nreturn {' + names.join(',') + '};')(...Object.values(deps));
}

async function main() {
  class PostStoryPayload {
    constructor() {
      this.chatId = 0;
      this.mediaKind = 'photo';
      this.localPath = '';
      this.caption = '';
      this.privacy = 'everyone';
      this.selectedUserIds = [];
      this.durationSeconds = 0;
      this.isAnimation = false;
      this.activePeriodSeconds = 0;
      this.isPostedToChatPage = true;
      this.protectContent = false;
    }
  }
  const M = load('ui/pages/stories/StoryComposerModel.ets',
    ['storyFileExtension', 'storyMediaKindFromPath', 'clampStoryCaption', 'nextStoryPrivacy',
      'storyPrivacyLabel', 'buildStoryPayload', 'canPublishStory', 'STORY_PRIVACY_ORDER',
      'STORY_VIDEO_EXTENSIONS'],
    { PostStoryPayload, STORY_MAX_CAPTION_LENGTH: 200 });

  // Media kind -------------------------------------------------------------------------------------
  assert.equal(M.storyFileExtension('/cache/a.JPG'), 'jpg');
  assert.equal(M.storyFileExtension('/cache/a.MP4'), 'mp4');
  assert.equal(M.storyFileExtension('/cache/noext'), '');
  assert.equal(M.storyFileExtension('/cache/trailing.'), '');
  assert.deepEqual(M.STORY_VIDEO_EXTENSIONS.includes('mov'), true);
  assert.equal(M.storyMediaKindFromPath('/cache/story.mp4'), 'video');
  assert.equal(M.storyMediaKindFromPath('/cache/story.MOV'), 'video');
  assert.equal(M.storyMediaKindFromPath('/cache/story.webm'), 'video');
  assert.equal(M.storyMediaKindFromPath('/cache/story.jpg'), 'photo');
  assert.equal(M.storyMediaKindFromPath('/cache/story.heic'), 'photo');
  assert.equal(M.storyMediaKindFromPath('/cache/noext'), 'photo');

  // Caption ----------------------------------------------------------------------------------------
  assert.equal(M.clampStoryCaption('  hello  '), 'hello');
  assert.equal(M.clampStoryCaption('   '), '');
  const long = 'x'.repeat(250);
  assert.equal(M.clampStoryCaption(long).length, 200);
  assert.equal(M.clampStoryCaption('ok').length, 2);

  // Privacy ----------------------------------------------------------------------------------------
  assert.deepEqual(M.STORY_PRIVACY_ORDER, ['everyone', 'contacts', 'closeFriends', 'selectedUsers']);
  assert.equal(M.nextStoryPrivacy('everyone', 1), 'contacts');
  assert.equal(M.nextStoryPrivacy('contacts', 1), 'closeFriends');
  assert.equal(M.nextStoryPrivacy('closeFriends', 1), 'selectedUsers');
  assert.equal(M.nextStoryPrivacy('selectedUsers', 1), 'everyone', 'the cycle wraps');
  assert.equal(M.nextStoryPrivacy('everyone', -1), 'selectedUsers');
  assert.equal(M.nextStoryPrivacy('bogus', 1), 'everyone');
  assert.equal(M.storyPrivacyLabel('everyone'), 'Everyone');
  assert.equal(M.storyPrivacyLabel('contacts'), 'My Contacts');
  assert.equal(M.storyPrivacyLabel('closeFriends'), 'Close Friends');
  assert.equal(M.storyPrivacyLabel('selectedUsers'), 'Selected People');
  assert.equal(M.storyPrivacyLabel('bogus'), 'Everyone');

  // Payload ----------------------------------------------------------------------------------------
  const payload = M.buildStoryPayload(42, '/cache/story.mp4', '  caption  ', 'contacts', [1, 2]);
  assert.ok(payload instanceof PostStoryPayload);
  assert.equal(payload.chatId, 42);
  assert.equal(payload.mediaKind, 'video');
  assert.equal(payload.localPath, '/cache/story.mp4');
  assert.equal(payload.caption, 'caption');
  assert.equal(payload.privacy, 'contacts');
  assert.deepEqual(payload.selectedUserIds, [1, 2]);
  const defaults = M.buildStoryPayload(42, '/cache/a.jpg', '', 'everyone');
  assert.deepEqual(defaults.selectedUserIds, [], 'no audience by default');
  assert.equal(defaults.mediaKind, 'photo');

  // Publish gate -----------------------------------------------------------------------------------
  assert.equal(M.canPublishStory('', 'everyone', 0), false);
  assert.equal(M.canPublishStory('/a.jpg', 'everyone', 0), true);
  assert.equal(M.canPublishStory('/a.jpg', 'selectedUsers', 0), false);
  assert.equal(M.canPublishStory('/a.jpg', 'selectedUsers', 2), true);

  // Page wiring ------------------------------------------------------------------------------------
  const prep = read('ui/pages/stories/storyMediaPrep.ets');
  assert.match(prep, /static async copyPickedMedia\(context: common\.UIAbilityContext, sourceUri: string\): Promise<string> \{/);
  assert.match(prep, /fileIo\.copyFileSync\(source\.fd, target\.fd\);/);
  assert.match(prep, /const STORY_CACHE_SUBDIR = 'stories';/);

  const page = read('ui/pages/stories/TgStoryComposerPage.ets');
  assert.match(page, /export struct TgStoryComposerPage \{/);
  assert.match(page, /@Local private mediaPath: string = '';/);
  assert.match(page, /@Local private privacy: StoryPrivacy = 'everyone';/);
  assert.match(page, /picker\.select\(\{\n      MIMEType: photoAccessHelper\.PhotoViewMIMETypes\.IMAGE_VIDEO_TYPE,/);
  assert.match(page, /this\.mediaKind = storyMediaKindFromPath\(path\);/);
  assert.match(page, /private cyclePrivacy\(\): void \{/);
  assert.match(page, /this\.privacy = nextStoryPrivacy\(this\.privacy, 1\);/);
  assert.match(page, /if \(this\.privacy === 'selectedUsers'\) \{/);
  assert.match(page, /const payload: PostStoryPayload = buildStoryPayload\(this\.selfUserId, this\.mediaPath,/);
  assert.match(page, /useCase\.execute\(payload\)/);
  assert.match(page, /this\.pageStack\.pop\(\);/);
  assert.match(page, /maxLength\(STORY_MAX_CAPTION_LENGTH\)/);
  assert.match(page, /@Builder\nexport function TgStoryComposerPageBuilder\(\) \{/);

  // Route ------------------------------------------------------------------------------------------
  const routes = JSON.parse(readResource('base/profile/route_map.json')).routerMap;
  const route = routes.find((entry) => entry.name === 'TgStoryComposerPage');
  assert.ok(route, 'the composer route is registered');
  assert.equal(route.pageSourceFile, 'src/main/ets/ui/pages/stories/TgStoryComposerPage.ets');
  assert.equal(route.buildFunction, 'TgStoryComposerPageBuilder');

  // Strings ----------------------------------------------------------------------------------------
  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(readResource(`${locale}/element/string.json`)).string;
    for (const name of ['story_composer_title', 'story_composer_cancel', 'story_composer_publish',
      'story_composer_picking', 'story_composer_pick', 'story_composer_caption', 'story_composer_who_sees',
      'story_error_prepare', 'story_error_media', 'story_error_publish', 'story_published']) {
      const entry = strings.find((item) => item.name === name);
      if (name === 'story_composer_picking') continue;
      assert.ok(entry, `${locale} ships ${name}`);
      assert.ok(entry.value.length > 0);
    }
  }

  // Chat list entry --------------------------------------------------------------------------------
  const list = read('ui/pages/chatlist/ChatListPage.ets');
  assert.match(list, /private openStoryComposer\(\): void \{/);
  assert.match(list, /this\.pageStack\.pushPathByName\('TgStoryComposerPage', undefined\);/);
  assert.match(list, /private openOwnStoryOrComposer\(\): void \{/);
  assert.match(list, /const selfUserId = state\.auth\.userId;/);
  assert.match(list, /state\.chats\.activeStoriesByChatId\.get\(selfUserId\)/);
  assert.match(list, /onStoryPress: \(\): void => \{\n\s+this\.openOwnStoryOrComposer\(\);/);

  // Tokens -----------------------------------------------------------------------------------------
  const tokens = read('ui/tg_ui/tokens/TgUiTokens.ets');
  for (const name of ['STORY_COMPOSER_MEDIA_HEIGHT', 'STORY_COMPOSER_MEDIA_BG', 'STORY_COMPOSER_PLUS_SIZE']) {
    assert.match(tokens, new RegExp('static readonly ' + name + ':'), name + ' is a token');
  }

  console.log('PASS story composer contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
