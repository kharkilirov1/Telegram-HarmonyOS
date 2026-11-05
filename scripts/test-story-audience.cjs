// I6: story audience — filtering, toggling, labels, page wiring, route and the composer integration.

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
  const M = load('ui/pages/stories/StoryAudienceModel.ets',
    ['StoryAudienceCandidate', 'filterAudienceCandidates', 'toggleAudienceSelection',
      'isAudienceSelected', 'audienceSelectionLabel', 'canConfirmAudience', 'audienceInitials'], {});

  const candidates = [
    Object.assign(new M.StoryAudienceCandidate(), { chatId: 1, title: 'Ann Lee', username: 'ann' }),
    Object.assign(new M.StoryAudienceCandidate(), { chatId: 2, title: 'Bob Stone', username: 'bobby' }),
    Object.assign(new M.StoryAudienceCandidate(), { chatId: 3, title: 'Chen', username: 'chen_w' })
  ];

  // Filtering --------------------------------------------------------------------------------------
  assert.equal(M.filterAudienceCandidates(candidates, '').length, 3);
  assert.equal(M.filterAudienceCandidates(candidates, '   ').length, 3);
  assert.equal(M.filterAudienceCandidates(candidates, 'ann').length, 1);
  assert.equal(M.filterAudienceCandidates(candidates, 'ANN').length, 1, 'search is case-insensitive');
  assert.equal(M.filterAudienceCandidates(candidates, 'bobby').length, 1, 'username matches too');
  assert.equal(M.filterAudienceCandidates(candidates, 'w').length, 1);
  assert.equal(M.filterAudienceCandidates(candidates, 'zzz').length, 0);
  const filteredCopy = M.filterAudienceCandidates(candidates, '');
  assert.notEqual(filteredCopy, candidates, 'the unfiltered list is a copy');

  // Toggling ---------------------------------------------------------------------------------------
  assert.deepEqual(M.toggleAudienceSelection([], 5), [5]);
  assert.deepEqual(M.toggleAudienceSelection([5], 5), []);
  assert.deepEqual(M.toggleAudienceSelection([5], 6), [5, 6]);
  assert.deepEqual(M.toggleAudienceSelection([1, 2], 1), [2]);
  const untouched = [1];
  assert.deepEqual(M.toggleAudienceSelection(untouched, 0), [1], 'a zero id is ignored');
  assert.notEqual(M.toggleAudienceSelection(untouched, 2), untouched, 'selection is copied');
  assert.deepEqual(untouched, [1], 'the input is not mutated');
  assert.equal(M.isAudienceSelected([1, 2], 2), true);
  assert.equal(M.isAudienceSelected([1], 3), false);

  // Labels and gate --------------------------------------------------------------------------------
  assert.equal(M.audienceSelectionLabel(0), 'Select People');
  assert.equal(M.audienceSelectionLabel(1), '1 Person');
  assert.equal(M.audienceSelectionLabel(2), '2 People');
  assert.equal(M.canConfirmAudience([]), false);
  assert.equal(M.canConfirmAudience([7]), true);
  assert.equal(M.audienceInitials('Ann Lee'), 'AL');
  assert.equal(M.audienceInitials('Chen'), 'C');
  assert.equal(M.audienceInitials('  '), '');
  assert.equal(M.audienceInitials('ann  lee'), 'AL');

  // Page -------------------------------------------------------------------------------------------
  const page = read('ui/pages/stories/TgStoryAudiencePage.ets');
  assert.match(page, /export class StoryAudienceRouteParams \{/);
  assert.match(page, /export class StoryAudienceResult \{/);
  assert.match(page, /export struct TgStoryAudiencePage \{/);
  assert.match(page, /if \(chat\.type !== 'private' \|\| chat\.peerUserId <= 0 \|\| chat\.peerUserId === selfUserId\) \{/);
  assert.match(page, /list\.sort\(\(left, right\) => left\.title\.localeCompare\(right\.title\)\);/);
  assert.match(page, /this\.pageStack\.pop\(new StoryAudienceResult\(this\.selectedIds\)\);/);
  assert.match(page, /if \(!canConfirmAudience\(this\.selectedIds\)\) \{/);
  assert.match(page, /filterAudienceCandidates\(this\.candidates, value\)/);
  assert.match(page, /@Builder\nexport function TgStoryAudiencePageBuilder\(\) \{/);

  const routes = JSON.parse(readResource('base/profile/route_map.json')).routerMap;
  const route = routes.find((entry) => entry.name === 'TgStoryAudiencePage');
  assert.ok(route, 'the audience route is registered');
  assert.equal(route.buildFunction, 'TgStoryAudiencePageBuilder');

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(readResource(`${locale}/element/string.json`)).string;
    for (const name of ['story_audience_cancel', 'story_audience_done', 'story_audience_subtitle',
      'story_audience_search', 'story_audience_empty']) {
      assert.ok(strings.find((item) => item.name === name), `${locale} ships ${name}`);
    }
  }

  // Composer integration ---------------------------------------------------------------------------
  const composer = read('ui/pages/stories/TgStoryComposerPage.ets');
  assert.match(composer, /@Local private selectedUserIds: number\[\] = \[\];/);
  assert.match(composer, /private openAudiencePicker\(\): void \{/);
  assert.match(composer, /this\.pageStack\.pushPathByName\('TgStoryAudiencePage', new StoryAudienceRouteParams\(this\.selectedUserIds\),/);
  assert.match(composer, /const result = info\.result as StoryAudienceResult;/);
  assert.match(composer, /this\.selectedUserIds = result\.selectedIds\.slice\(\);/);
  assert.match(composer, /this\.privacy = 'selectedUsers';/);
  assert.match(composer, /    if \(next === 'selectedUsers'\) \{\n      this\.openAudiencePicker\(\);\n      return;\n    \}/);
  assert.match(composer, /canPublishStory\(this\.mediaPath, this\.privacy, this\.selectedUserIds\.length\)/);
  assert.match(composer, /buildStoryPayload\(this\.selfUserId, this\.mediaPath,\n      clampStoryCaption\(this\.caption\), this\.privacy, this\.selectedUserIds\)/);
  assert.match(composer, /storyPrivacyLabel\(this\.privacy\) \+ ' \(' \+ this\.selectedUserIds\.length\.toString\(\) \+ '\)'/);

  console.log('PASS story audience contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
