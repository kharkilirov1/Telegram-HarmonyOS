// I6: story viewers — interaction parsing, the paged command, the use case cursor and the views screen.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');
const readResource = (relative) =>
  fs.readFileSync(path.join(root, '..', 'resources', relative), 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(root);

async function main() {
  // DTO --------------------------------------------------------------------------------------------
  const D = load('core/model/dto/StoryDto.ets',
    ['StoryInteractionDto', 'StoryInteractionsPageDto'], {});
  const emptyPage = new D.StoryInteractionsPageDto();
  assert.equal(emptyPage.totalCount, 0);
  assert.deepEqual(emptyPage.interactions, []);
  assert.equal(emptyPage.nextOffset, '');
  const emptyInteraction = new D.StoryInteractionDto();
  assert.equal(emptyInteraction.actorUserId, 0);
  assert.equal(emptyInteraction.kind, 'view');
  assert.equal(emptyInteraction.reactionKey, '');

  // Parser -----------------------------------------------------------------------------------------
  class TdObject {
    constructor(raw) {
      this.raw = raw;
    }
  }
  const wrap = (value) => (value !== null && typeof value === 'object' && !Array.isArray(value) && value['@type']
    ? new TdObject(value)
    : value);
  const accessors = {
    tdGetType: (object) => (object && object.raw && object.raw['@type']) || (object && object['@type']) || '',
    tdGetNumber: (object, key) => {
      const raw = object && object.raw ? object.raw : object;
      const value = raw === undefined || raw === null ? undefined : raw[key];
      return typeof value === 'number' ? value : 0;
    },
    tdGetString: (object, key) => {
      const raw = object && object.raw ? object.raw : object;
      const value = raw === undefined || raw === null ? undefined : raw[key];
      return typeof value === 'string' ? value : '';
    },
    tdGetObject: (object, key) => {
      const raw = object && object.raw ? object.raw : object;
      const value = raw === undefined || raw === null ? undefined : raw[key];
      return wrap(value);
    },
    tdGetArray: (object, key) => {
      const raw = object && object.raw ? object.raw : object;
      const value = raw === undefined || raw === null ? undefined : raw[key];
      return Array.isArray(value) ? value.map((item) => wrap(item)) : [];
    },
    parseReactionTypeKey: (tdReactionType) => {
      const raw = tdReactionType && tdReactionType.raw ? tdReactionType.raw : tdReactionType;
      if (!raw) return '';
      if (raw['@type'] === 'reactionTypeEmoji') return 'emoji:' + raw.emoji;
      if (raw['@type'] === 'reactionTypeCustomEmoji') return 'custom:' + raw.custom_emoji_id;
      return '';
    },
    StoryInteractionDto: D.StoryInteractionDto,
    StoryInteractionsPageDto: D.StoryInteractionsPageDto
  };
  const N = load('core/events/normalizers/StoryNormalizer.ets', ['parseStoryInteractions'], accessors);
  const page = N.parseStoryInteractions(new TdObject({
    '@type': 'storyInteractions',
    total_count: 120,
    total_forward_count: 4,
    total_reaction_count: 9,
    next_offset: 'cursor-2',
    interactions: [
      { '@type': 'storyInteraction', actor_id: { '@type': 'messageSenderUser', user_id: 501 },
        interaction_date: 1700000001, type: { '@type': 'storyInteractionTypeView',
          chosen_reaction_type: { '@type': 'reactionTypeEmoji', emoji: '🔥' } } },
      { '@type': 'storyInteraction', actor_id: { '@type': 'messageSenderUser', user_id: 502 },
        interaction_date: 1700000002, type: { '@type': 'storyInteractionTypeView',
          chosen_reaction_type: null } },
      { '@type': 'storyInteraction', actor_id: { '@type': 'messageSenderChat', chat_id: -1009 },
        interaction_date: 1700000003, type: { '@type': 'storyInteractionTypeForward' } },
      { '@type': 'storyInteraction', actor_id: { '@type': 'messageSenderUser', user_id: 0 },
        interaction_date: 0, type: { '@type': 'storyInteractionTypeView' } }
    ]
  }));
  assert.equal(page.totalCount, 120);
  assert.equal(page.totalForwardCount, 4);
  assert.equal(page.totalReactionCount, 9);
  assert.equal(page.nextOffset, 'cursor-2');
  assert.equal(page.interactions.length, 3, 'an actorless interaction is dropped');
  assert.equal(page.interactions[0].actorUserId, 501);
  assert.equal(page.interactions[0].kind, 'view');
  assert.equal(page.interactions[0].reactionKey, 'emoji:🔥');
  assert.equal(page.interactions[1].reactionKey, '', 'a view without reaction has an empty key');
  assert.equal(page.interactions[2].actorChatId, -1009);
  assert.equal(page.interactions[2].kind, 'forward');

  const repostPage = N.parseStoryInteractions(new TdObject({
    '@type': 'storyInteractions', total_count: 1, interactions: [
      { '@type': 'storyInteraction', actor_id: { '@type': 'messageSenderUser', user_id: 7 },
        interaction_date: 5, type: { '@type': 'storyInteractionTypeRepost' } }
    ]
  }));
  assert.equal(repostPage.interactions[0].kind, 'repost');
  assert.equal(repostPage.nextOffset, '');
  assert.equal(N.parseStoryInteractions(new TdObject({ '@type': 'storyInteractions' })).interactions.length, 0);

  const normalizerSource = read('core/events/normalizers/StoryNormalizer.ets');
  assert.match(normalizerSource, /export function parseStoryInteractions\(tdInteractions: TdObject\): StoryInteractionsPageDto \{/);

  // Command ----------------------------------------------------------------------------------------
  const C = load('core/model/AppCommand.ets',
    ['GetStoryInteractionsCommand', 'GetStoryInteractionsPayload', 'createGetStoryInteractionsCommand'], {});
  const payload = new C.GetStoryInteractionsPayload();
  assert.equal(payload.limit, 20);
  assert.equal(payload.offset, '');
  assert.equal(payload.onlyContacts, false);
  payload.storyId = 77;
  payload.offset = 'cursor-2';
  const command = C.createGetStoryInteractionsCommand(payload);
  assert.ok(command instanceof C.GetStoryInteractionsCommand);
  assert.equal(command.type, 'getStoryInteractions');
  assert.equal(command.payload, payload);
  const commandSource = read('core/model/AppCommand.ets');
  assert.match(commandSource, /  \| GetStoryInteractionsCommand/);

  // Serializer -------------------------------------------------------------------------------------
  const serializer = read('infra/td/serialization/CommandSerializer.ets');
  assert.match(serializer, /COMMAND_SERIALIZATION_HANDLERS\.set\('getStoryInteractions', serializeGetStoryInteractions\);/);
  assert.match(serializer, /result\.method = 'getStoryInteractions';/);
  assert.match(serializer, /result\.params\.setNumber\('story_id', cmd\.payload\.storyId\);/);
  assert.match(serializer, /result\.params\.setString\('query', cmd\.payload\.query\);/);
  assert.match(serializer, /result\.params\.setBool\('only_contacts', cmd\.payload\.onlyContacts\);/);
  assert.match(serializer, /result\.params\.setBool\('prefer_forwards', cmd\.payload\.preferForwards\);/);
  assert.match(serializer, /result\.params\.setBool\('prefer_with_reaction', cmd\.payload\.preferWithReaction\);/);
  assert.match(serializer, /result\.params\.setString\('offset', cmd\.payload\.offset\);/);
  assert.match(serializer, /result\.params\.setNumber\('limit', cmd\.payload\.limit\);/);

  // Use case cursor against a gateway double --------------------------------------------------------
  class TdObjectFixture {}
  const gateway = {
    pages: [],
    sent: [],
    fail: false,
    async send(cmd) {
      this.sent.push(cmd);
      if (this.fail) throw new Error('network');
      const next = this.pages.shift();
      const fixture = new TdObjectFixture();
      fixture.raw = next;
      return fixture;
    }
  };
  const parseStoryInteractions = (raw) => raw.raw;
  const hilog = { info() {} };
  class StoryInteractionsPageDto {
    constructor() {
      this.totalCount = 0;
      this.totalReactionCount = 0;
      this.interactions = [];
      this.nextOffset = '';
    }
  }
  const U = load('domain/usecases/loadStoryInteractions.ets',
    ['LoadStoryInteractionsUseCase', 'createLoadStoryInteractionsUseCase', 'STORY_INTERACTIONS_PAGE_SIZE'], {
      createGetStoryInteractionsCommand: (p) => ({ type: 'getStoryInteractions', payload: p }),
      GetStoryInteractionsPayload: C.GetStoryInteractionsPayload,
      parseStoryInteractions: (value) => value.raw,
      StoryInteractionsPageDto,
      hilog,
      TdObject: TdObjectFixture
    });
  const useCase = new U.LoadStoryInteractionsUseCase(gateway);
  assert.equal(U.STORY_INTERACTIONS_PAGE_SIZE, 20);
  assert.equal(useCase.hasMore(77), true);
  const firstPage = { totalCount: 5, totalReactionCount: 2, interactions: [], nextOffset: 'next-1' };
  const secondPage = { totalCount: 5, totalReactionCount: 2, interactions: [], nextOffset: '' };
  gateway.pages.push(firstPage, secondPage);
  assert.equal(await useCase.load(77), firstPage);
  assert.equal(gateway.sent[0].payload.offset, '', 'the first page has no cursor');
  assert.equal(await useCase.load(77), secondPage);
  assert.equal(gateway.sent[1].payload.offset, 'next-1', 'the second page carries the cursor');
  assert.equal(useCase.hasMore(77), false, 'an empty next offset exhausts the list');
  const exhaustedPage = await useCase.load(77);
  assert.equal(exhaustedPage.totalCount, 0, 'an exhausted list yields an empty page');
  assert.equal(gateway.sent.length, 2, 'an exhausted list is not requested again');
  useCase.reset(77);
  assert.equal(useCase.hasMore(77), true);
  gateway.pages.push({ totalCount: 5, totalReactionCount: 2, interactions: [], nextOffset: 'again' });
  assert.ok(await useCase.load(77));
  assert.equal(gateway.sent[2].payload.offset, '', 'a reset restarts from the first page');
  gateway.fail = true;
  gateway.pages.push({});
  const failure = await useCase.load(78);
  assert.equal(failure.totalCount, 0, 'a failure is an empty page, not a throw');
  assert.equal((await useCase.load(0)).totalCount, 0, 'a zero story id is not requested');

  // Page + route + strings ------------------------------------------------------------------------
  const viewsPage = read('ui/pages/stories/TgStoryViewsPage.ets');
  assert.match(viewsPage, /export class StoryViewsRouteParams \{/);
  assert.match(viewsPage, /export struct TgStoryViewsPage \{/);
  assert.match(viewsPage, /createLoadStoryInteractionsUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(viewsPage, /useCase\.load\(this\.storyId\)/);
  assert.match(viewsPage, /if \(index >= this\.rows\.length - 3\) \{\n\s+this\.loadPage\(\);/);
  assert.match(viewsPage, /return key\.substring\('emoji:'\.length\);/);
  assert.match(viewsPage, /@Builder\nexport function TgStoryViewsPageBuilder\(\) \{/);

  const routes = JSON.parse(readResource('base/profile/route_map.json')).routerMap;
  const route = routes.find((entry) => entry.name === 'TgStoryViewsPage');
  assert.ok(route, 'the views route is registered');
  assert.equal(route.buildFunction, 'TgStoryViewsPageBuilder');

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(readResource(`${locale}/element/string.json`)).string;
    for (const name of ['story_views_title', 'story_views_count']) {
      assert.ok(strings.find((item) => item.name === name), `${locale} ships ${name}`);
    }
  }

  const viewer = read('ui/pages/stories/TgStoryViewerPage.ets');
  assert.match(viewer, /private openStoryViews\(\): void \{/);
  assert.match(viewer, /if \(story === undefined \|\| storyId === 0 \|\| story\.viewCount <= 0\) \{/);
  assert.match(viewer, /this\.pageStack\.pushPathByName\('TgStoryViewsPage',/);
  assert.match(viewer, /this\.openStoryViews\(\);/);

  console.log('PASS story views contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
