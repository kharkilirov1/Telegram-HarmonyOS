// I6: story viewer — navigation/progress math, the page wiring, the route, the chat-list entry point and
// the story media path applied by the files reducer.

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
  const M = load('ui/pages/stories/StoryViewerModel.ets',
    ['StoryViewerRouteParams', 'clampStoryIndex', 'storySegmentFill', 'nextStoryIndex',
      'previousStoryIndex', 'storyDisplayDurationMs', 'storyCacheKey', 'storyPosterPath',
      'isRenderableStory', 'STORY_PHOTO_DURATION_MS', 'STORY_MIN_DURATION_MS', 'STORY_MAX_DURATION_MS',
      'compactStoryCount', 'storyViewsLabel', 'storyReactionsLabel'],
    { storyContentKey: (chatId, storyId) => chatId + ':' + storyId });

  // Params -----------------------------------------------------------------------------------------
  const params = new M.StoryViewerRouteParams(77, 'Ann', [1, 2, 3], 2);
  assert.equal(params.chatId, 77);
  assert.equal(params.chatTitle, 'Ann');
  assert.deepEqual(params.storyIds, [1, 2, 3]);
  assert.equal(params.startIndex, 2);
  const emptyParams = new M.StoryViewerRouteParams();
  assert.equal(emptyParams.chatId, 0);
  assert.deepEqual(emptyParams.storyIds, []);

  // Index clamping ---------------------------------------------------------------------------------
  assert.equal(M.clampStoryIndex(0, 3), 0);
  assert.equal(M.clampStoryIndex(2, 3), 2);
  assert.equal(M.clampStoryIndex(9, 3), 2, 'a stale index is clamped');
  assert.equal(M.clampStoryIndex(-4, 3), 0);
  assert.equal(M.clampStoryIndex(1.7, 3), 1);
  assert.equal(M.clampStoryIndex(1, 0), 0);
  assert.equal(M.clampStoryIndex(Number.NaN, 3), 0);

  // Navigation -------------------------------------------------------------------------------------
  assert.equal(M.nextStoryIndex(0, 3), 1);
  assert.equal(M.nextStoryIndex(1, 3), 2);
  assert.equal(M.nextStoryIndex(2, 3), -1, 'the last story closes the viewer');
  assert.equal(M.nextStoryIndex(0, 0), -1);
  assert.equal(M.previousStoryIndex(2, 3), 1);
  assert.equal(M.previousStoryIndex(1, 3), 0);
  assert.equal(M.previousStoryIndex(0, 3), 0, 'the first story stays open');
  assert.equal(M.previousStoryIndex(0, 0), -1);

  // Segment fill -----------------------------------------------------------------------------------
  assert.equal(M.storySegmentFill(0, 3, 1.5), 1, 'finished segments are full');
  assert.equal(M.storySegmentFill(2, 3, 1.5), 0, 'future segments are empty');
  assert.equal(M.storySegmentFill(1, 3, 1.25), 0.25, 'the current segment follows the position');
  assert.equal(M.storySegmentFill(1, 3, 1), 0);
  assert.ok(Math.abs(M.storySegmentFill(0, 3, 0.5) - 0.5) < 1e-9);
  assert.equal(M.storySegmentFill(-1, 3, 0.5), 0);
  assert.equal(M.storySegmentFill(0, 0, 0.5), 0);
  assert.equal(M.storySegmentFill(0, 3, 3.5), 1, 'the position is clamped by the segment check');

  // Durations --------------------------------------------------------------------------------------
  assert.equal(M.storyDisplayDurationMs(undefined), M.STORY_PHOTO_DURATION_MS);
  assert.equal(M.storyDisplayDurationMs({ kind: 'photo', duration: 0 }), M.STORY_PHOTO_DURATION_MS);
  assert.equal(M.storyDisplayDurationMs({ kind: 'video', duration: 7 }), 7000);
  assert.equal(M.storyDisplayDurationMs({ kind: 'video', duration: 0 }), M.STORY_PHOTO_DURATION_MS);
  assert.equal(M.storyDisplayDurationMs({ kind: 'video', duration: 999 }), M.STORY_MAX_DURATION_MS);
  assert.equal(M.storyDisplayDurationMs({ kind: 'video', duration: 0.1 }), M.STORY_MIN_DURATION_MS);

  // Keys, posters and renderability ---------------------------------------------------------------
  assert.equal(M.storyCacheKey(5, 9), '5:9');
  assert.equal(M.storyPosterPath(undefined), '');
  assert.equal(M.storyPosterPath({ localPath: '/cache/a.jpg' }), '/cache/a.jpg');
  assert.equal(M.isRenderableStory(undefined), false);
  assert.equal(M.isRenderableStory({ kind: 'unsupported', mediaFileId: 5 }), false);
  assert.equal(M.isRenderableStory({ kind: 'photo', mediaFileId: 0 }), false);
  assert.equal(M.isRenderableStory({ kind: 'photo', mediaFileId: 5 }), true);
  assert.equal(M.isRenderableStory({ kind: 'video', mediaFileId: 5 }), true);

  // View counters ----------------------------------------------------------------------------------
  assert.equal(M.compactStoryCount(0), '0');
  assert.equal(M.compactStoryCount(-3), '0');
  assert.equal(M.compactStoryCount(7), '7');
  assert.equal(M.compactStoryCount(999), '999');
  assert.equal(M.compactStoryCount(1000), '1K');
  assert.equal(M.compactStoryCount(1200), '1.2K');
  assert.equal(M.compactStoryCount(12000), '12K');
  assert.equal(M.compactStoryCount(150000), '150K');
  assert.equal(M.compactStoryCount(1000000), '1M');
  assert.equal(M.compactStoryCount(2500000), '2.5M');
  assert.equal(M.compactStoryCount(120000000), '120M');
  assert.equal(M.compactStoryCount(Number.NaN), '0');
  assert.equal(M.storyViewsLabel(undefined), '');
  assert.equal(M.storyViewsLabel({ viewCount: 0 }), '');
  assert.equal(M.storyViewsLabel({ viewCount: 42 }), '42');
  assert.equal(M.storyReactionsLabel(undefined), '');
  assert.equal(M.storyReactionsLabel({ reactionCount: 0 }), '');
  assert.equal(M.storyReactionsLabel({ reactionCount: 1500 }), '1.5K');
  const dtoSource = read('core/model/dto/StoryDto.ets');
  assert.match(dtoSource, /viewCount: number = 0;/);
  assert.match(dtoSource, /reactionCount: number = 0;/);
  assert.match(dtoSource, /forwardCount: number = 0;/);
  const normalizerSource = read('core/events/normalizers/StoryNormalizer.ets');
  assert.match(normalizerSource, /const interactionInfo = tdGetObject\(story, 'interaction_info'\);/);
  assert.match(normalizerSource, /dto\.viewCount = tdGetNumber\(interactionInfo, 'view_count'\);/);
  assert.match(normalizerSource, /dto\.reactionCount = tdGetNumber\(interactionInfo, 'reaction_count'\);/);
  assert.match(normalizerSource, /dto\.forwardCount = tdGetNumber\(interactionInfo, 'forward_count'\);/);

  // Page wiring ------------------------------------------------------------------------------------
  const page = read('ui/pages/stories/TgStoryViewerPage.ets');
  assert.match(page, /export struct TgStoryViewerPage \{/);
  assert.match(page, /@Local private story: StoryFullDto \| undefined = undefined;/);
  assert.match(page, /const useCase = this\.loadStoryUseCase;/);
  assert.match(page, /createLoadStoryUseCase\(store, getTdGatewayAdapter\(\)\)/);
  assert.match(page, /gateway\.send\(createDownloadFileCommand\(story\.mediaFileId, STORY_DOWNLOAD_PRIORITY, false\)\)/);
  assert.match(page, /private startProgress\(\): void \{/);
  assert.match(page, /setInterval\(/);
  assert.match(page, /clearInterval\(this\.progressTimerId\)/);
  assert.match(page, /this\.paused = true;/);
  assert.match(page, /private advance\(\): void \{/);
  assert.match(page, /private goBack\(\): void \{/);
  assert.match(page, /this\.pageStack\.pop\(\);/);
  assert.match(page, /ForEach\(this\.storyIds/);
  assert.match(page, /storySegmentFill\(position, this\.storyIds\.length, this\.index \+ this\.progress\)/);
  assert.match(page, /Video\(\{ src: this\.story\.localPath \}\)/);
  assert.match(page, /Image\(this\.story\.localPath\)/);
  assert.match(page, /onReady\(\(context: NavDestinationContext\): void => \{/);
  assert.match(page, /const params = context\.pathInfo\.param as StoryViewerRouteParams;/);
  assert.match(page, /@Builder\nexport function TgStoryViewerPageBuilder\(\) \{/);
  assert.match(page, /storyViewsLabel\(this\.story\)/);
  assert.match(page, /storyReactionsLabel\(this\.story\)/);

  // Route ------------------------------------------------------------------------------------------
  const routes = JSON.parse(readResource('base/profile/route_map.json')).routerMap;
  const route = routes.find((entry) => entry.name === 'TgStoryViewerPage');
  assert.ok(route, 'the viewer route is registered');
  assert.equal(route.pageSourceFile, 'src/main/ets/ui/pages/stories/TgStoryViewerPage.ets');
  assert.equal(route.buildFunction, 'TgStoryViewerPageBuilder');

  // Chat list entry point --------------------------------------------------------------------------
  const list = read('ui/pages/chatlist/ChatListPage.ets');
  assert.match(list, /import \{ StoryViewerRouteParams \} from '\.\.\/stories\/StoryViewerModel';/);
  assert.match(list, /private openStoryViewer\(\): void \{/);
  assert.match(list, /const chatIds = state\.chats\.orderedStoryChatIds;/);
  assert.match(list, /state\.chats\.activeStoriesByChatId\.get\(chatId\)/);
  assert.match(list, /this\.pageStack\.pushPathByName\('TgStoryViewerPage', params\);/);
  assert.match(list, /onStoryPress: \(\): void => \{\n\s+this\.openStoryViewer\(\);/);
  assert.match(list, /onStoryStripPress: \(\): void => \{\n\s+this\.openStoryViewer\(\);/);
  assert.match(list, /storyStripInteractive: true,/);

  // Story media path in the files reducer ----------------------------------------------------------
  const reducer = read('core/reducers/filesReducer.ets');
  assert.match(reducer, /function applyStoryFilePath\(newState: AppState, fileId: number, localPath: string\): void \{/);
  assert.match(reducer, /for \(const story of newState\.chats\.storyContentsByKey\.values\(\)\) \{/);
  assert.match(reducer, /if \(story\.mediaFileId === fileId\) \{/);
  assert.match(reducer, /updated\.localPath = localPath;/);
  assert.match(reducer, /let storyNeedsUpdate = false;/);
  assert.match(reducer, /needsUpdate = needsUpdate \|\| storyNeedsUpdate;/);
  assert.match(reducer, /applyStoryFilePath\(newState, fileId, localPath\);/);
  const dto = read('core/model/dto/StoryDto.ets');
  assert.match(dto, /localPath: string = '';/);

  // Tokens -----------------------------------------------------------------------------------------
  const tokens = read('ui/tg_ui/tokens/TgUiTokens.ets');
  for (const name of ['STORY_VIEWER_BACKGROUND', 'STORY_PROGRESS_HEIGHT', 'STORY_PROGRESS_TRACK',
    'STORY_LOADING_SIZE']) {
    assert.match(tokens, new RegExp('static readonly ' + name + ':'), name + ' is a token');
  }
  assert.equal(/STORY_PROGRESS_HEIGHT: number = 2;/.test(tokens), true);

  console.log('PASS story viewer contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
