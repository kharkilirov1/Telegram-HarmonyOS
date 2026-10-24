// Execute the page's real top-bar path. --baseline exercises the pre-extraction methods.
const { readChatSource } = require("./chat-screen-source.cjs");
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '..');
// Slow-mode imports execute real production code; only the SDK uptime service is a fixture.
const slowmodeFixtureDeps = (() => {
  const etsRoot = path.resolve(__dirname, '../entry/src/main/ets');
  function module(file, deps = {}) {
    const source = fs.readFileSync(path.join(etsRoot, file), 'utf8');
    const names = [...source.matchAll(/^export\s+(?:class|function)\s+(\w+)/gm)].map(match => match[1]);
    const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, ''), { mode: 'transform' });
    return new Function(...Object.keys(deps), js + `; return {${names.join(',')}};`)(...Object.values(deps));
  }
  const clock = module('core/utils/SlowmodeClock.ets', { systemDateTime: { TimeType: { STARTUP: 0 }, getUptime: () => 0 } });
  return { ...clock, ...module('ui/pages/chat/ChatSlowmodeController.ets', {
    ...clock, navigationUIState: { applicationForeground: true }
  }) };
})();
Object.assign(globalThis, slowmodeFixtureDeps);

const baselinePathIndex = process.argv.indexOf('--baseline-page');
const baselinePagePath = baselinePathIndex < 0 ? undefined : process.argv[baselinePathIndex + 1];
let pageSource = readChatSource(baselinePagePath || path.join(root,
  'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'), 'utf8');
const helperPath = path.join(root, 'entry/src/main/ets/ui/pages/chat/ChatTopBarPresentation.ets');
const baseline = process.argv.includes('--baseline') || baselinePagePath !== undefined;
const mutationFlags = ['--mutant-connection', '--mutant-spinner-latch',
  '--mutant-skip-observe', '--mutant-repeat-hydration'].filter(flag => process.argv.includes(flag));
assert.ok(mutationFlags.length <= 1, 'only one mutation at a time');
const mutant = mutationFlags[0] || null;
assert.ok(!baseline || !mutant, 'baseline and mutant are separate');
if (mutant === '--mutant-spinner-latch') {
  const from = 'this.chatSubtitleSpinner = value.spinner;';
  assert.equal(pageSource.split(from).length - 1, 1, 'spinner mutation site must engage once');
  pageSource = pageSource.replace(from, 'this.chatSubtitleSpinner = this.chatSubtitleSpinner || value.spinner;');
} else if (mutant === '--mutant-skip-observe') {
  const from = 'this.chatAccessController?.observe(';
  assert.equal(pageSource.split(from).length - 1, 2, 'observation mutation site must engage twice');
  pageSource = pageSource.replaceAll(from, 'this.chatAccessController?.skip?.(');
} else if (mutant === '--mutant-repeat-hydration') {
  const from = 'this.memberCountHydratedChatId !== chat.id';
  assert.equal(pageSource.split(from).length - 1, 1, 'hydration mutation site must engage once');
  pageSource = pageSource.replace(from, 'true');
}

const localized = (id, fallback) => `${id}|${fallback}`;
const localizedPlural = (id, count, fallback) => `${id}|${count}|${fallback}`;
const $r = id => ({ id });
const fileUri = { getUriFromPath: value => `file://${value}` };
const TgChatTopBarSubtitleMode = { Secondary: 'secondary', Online: 'online', Typing: 'typing',
  Activity: 'activity' };
const TgChatTopBarTrailingAction = { Search: 'search', Avatar: 'avatar' };
class Chat {}
const now = 100000;
const DateStub = { now: () => now };
const bindingNames = ['localized', 'localizedPlural', '$r', 'fileUri',
  'TgChatTopBarSubtitleMode', 'TgChatTopBarTrailingAction', 'Date', 'Chat'];
const bindingValues = [localized, localizedPlural, $r, fileUri,
  TgChatTopBarSubtitleMode, TgChatTopBarTrailingAction, DateStub, Chat];

function method(source, name) {
  const match = source.match(new RegExp(`^  private ${name}\\([\\s\\S]*?^  \\}`, 'm'));
  assert.ok(match, `Missing real page method ${name}`);
  return match[0];
}

let helper = {};
if (!baseline) {
  assert.ok(fs.existsSync(helperPath), 'ChatTopBarPresentation.ets must exist');
  let source = readChatSource(helperPath, 'utf8');
  if (mutant === '--mutant-connection') {
    const from = "case 'waitingForNetwork':";
    assert.equal(source.split(from).length - 1, 1, 'mutation site must engage once');
    source = source.replace(from, "case 'unreachableStatus':");
  }
  const js = stripTypeScriptTypes(source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s+/gm, ''), { mode: 'transform' });
  helper = new Function(...bindingNames,
    `${js}\nreturn { chatAvatarPresentation, chatSubtitlePresentation, CHAT_ACTIVITY_TTL_MS };`)(...bindingValues);
}

const names = ['updateChatTopBarData'];
if (baseline) names.push('computeInitials', 'formatUserStatus',
  'formatTypingSubtitle', 'formatConnectionSubtitle');
else names.push('applyChatAvatarPresentation', 'applyChatSubtitlePresentation');
const classSource = `class PageProbe {
  slowmodeController = new globalThis.ChatSlowmodeController();
  composerSlowmodeSeconds = 0;\n${names.map(name => method(pageSource, name)).join('\n')}\n}`;
const pageJs = stripTypeScriptTypes(classSource, { mode: 'transform' });
const loadCalls = [];
const effectCalls = [];
const PageProbe = new Function(...bindingNames, 'loadSupergroupFullInfo',
  'loadBasicGroupFullInfo', 'chatAvatarPresentation', 'chatSubtitlePresentation',
  `${pageJs}\nreturn PageProbe;`)(...bindingValues,
  (...args) => { loadCalls.push(['supergroup', ...args]); effectCalls.push(['supergroup', ...args]); },
  (...args) => { loadCalls.push(['basic', ...args]); effectCalls.push(['basic', ...args]); },
  helper.chatAvatarPresentation, helper.chatSubtitlePresentation);

function chat(overrides = {}) {
  return { id: 7, title: 'Alice Bob', type: 'private', peerUserId: 55,
    photoSmall: '/avatar', memberCount: 0, supergroupId: 0, basicGroupId: 0, ...overrides };
}
function user(overrides = {}) {
  return { isBot: false, status: 'online', firstName: 'Alice', username: 'alice', ...overrides };
}
function run({ chatValue = chat(), userValue = user(), typing, connection = 'ready',
  activeChatId = 7, hydratedChatId = 0, existingPage } = {}) {
  loadCalls.length = 0;
  effectCalls.length = 0;
  const calls = [];
  const state = {
    chats: { chats: new Map(chatValue ? [[activeChatId, chatValue]] : []),
      basicGroupAccess: new Map(), supergroupAccess: new Map(),
      supergroupBoosts: new Map(), supergroupSlowmode: new Map(), typingActions: new Map(typing ? [[activeChatId, typing]] : []) },
    users: { users: new Map(userValue ? [[55, userValue], [66, userValue]] : []) },
    connection: { status: connection }
  };
  const page = existingPage || new PageProbe();
  if (!existingPage) page.memberCountHydratedChatId = hydratedChatId;
  Object.assign(page, { activeChatId,
    chatAccessController: { observe: (...args) => { calls.push(['observe', ...args]); effectCalls.push(['observe', ...args]); },
      isUnavailable: () => false },
    deriveChatBottomBar: (...args) => { calls.push(['bottom', ...args]); effectCalls.push(['bottom', ...args]); } });
  page.updateChatTopBarData(state);
  const presentation = {
    subtitle: page.chatSubtitle, mode: page.chatSubtitleMode,
    spinner: page.chatSubtitleSpinner, initials: page.chatAvatarInitials,
    colorIndex: page.chatAvatarColorIndex, imageSrc: page.chatAvatarImageSrc,
    online: page.chatIsOnline, trailing: page.chatTopBarTrailingAction
  };
  return { presentation, calls, loadCalls: [...loadCalls], effects: [...effectCalls], page, state };
}

let checks = 0;
let failed = 0;
function check(actual, expected) {
  checks++;
  try { assert.deepEqual(actual, expected); }
  catch (error) { failed++; console.error('FAIL', error.message); }
}
const secondary = TgChatTopBarSubtitleMode.Secondary;
const activity = TgChatTopBarSubtitleMode.Activity;
const typingMode = TgChatTopBarSubtitleMode.Typing;
// The activity deadline comes from the production module, not from the fixture.
const activityTtlMs = helper.CHAT_ACTIVITY_TTL_MS ?? 8000;
check(run({ chatValue: null }).presentation, {
  subtitle: '', mode: secondary, spinner: false, initials: '', colorIndex: 0,
  imageSrc: '', online: false, trailing: 'search'
});
check(run().presentation, {
  subtitle: 'app.string.online|online', mode: 'online', spinner: false,
  initials: 'AB', colorIndex: 7, imageSrc: 'file:///avatar', online: true, trailing: 'search'
});
check(run({ userValue: user({ isBot: true }) }).presentation.subtitle,
  'app.string.member_role_bot|bot');
check(run({ userValue: null }).presentation.subtitle, '');
check(run({ chatValue: chat({ title: '   ' }) }).presentation.initials, '');
check(run({ chatValue: chat({ title: 'Alice  Bob' }) }).presentation.initials, 'A');
const statuses = [
  ['recently', 'app.string.last_seen_recently|last seen recently'],
  ['lastWeek', 'app.string.last_seen_within_week|last seen within a week'],
  ['lastMonth', 'app.string.last_seen_within_month|last seen within a month'],
  ['longTimeAgo', 'app.string.last_seen_long_ago|last seen a long time ago'],
  ['unknown', '']
];
for (const [status, expected] of statuses) {
  check(run({ userValue: user({ status }) }).presentation.subtitle, expected);
}
const group = chat({ id: -100, title: 'Team Chat', type: 'group', peerUserId: 0,
  memberCount: 42, photoSmall: '', basicGroupId: 3 });
check(run({ chatValue: group, activeChatId: -100 }).presentation.subtitle,
  'app.plural.group_members_count_plural|42|42 members');
const channel = chat({ id: -200, title: 'News', type: 'channel', peerUserId: 0,
  photoSmall: '', supergroupId: 5 });
const channelResult = run({ chatValue: channel, activeChatId: -200 });
check(channelResult.presentation.subtitle, 'app.string.channel_label|channel');
check(channelResult.loadCalls, [['supergroup', -200, 5]]);
const emptyGroup = chat({ id: -300, title: 'New Group', type: 'group', peerUserId: 0,
  photoSmall: '', basicGroupId: 3 });
const emptyGroupResult = run({ chatValue: emptyGroup, activeChatId: -300 });
check(emptyGroupResult.presentation.subtitle, 'app.string.group_label|group');
check(emptyGroupResult.loadCalls, [['basic', -300, 3]]);
const typing = { actionType: 'recordingVoice', senderUserId: 66, timestamp: now - 1 };
// A group subtitle carries only the sender (iOS ChatTitleComponent group branch),
// never the one-to-one activity label.
check(run({ chatValue: group, activeChatId: -100, typing }).presentation, {
  subtitle: 'Alice',
  mode: activity, spinner: false, initials: 'TC', colorIndex: -4,
  imageSrc: '', online: false, trailing: 'avatar'
});
check(run({ chatValue: group, activeChatId: -100,
  typing: { ...typing, timestamp: now - (activityTtlMs - 1) } }).presentation.subtitle, 'Alice');
check(run({ chatValue: group, activeChatId: -100,
  typing: { ...typing, timestamp: now - (activityTtlMs + 1) } }).presentation.subtitle,
  'app.plural.group_members_count_plural|42|42 members');
// A one-to-one chat keeps the sender in the title and shows the activity text.
check(run({ typing: { actionType: 'typing', senderUserId: 66, timestamp: now - 1 } }).presentation, {
  subtitle: 'app.string.typing|typing…', mode: typingMode, spinner: false,
  initials: 'AB', colorIndex: 7, imageSrc: 'file:///avatar', online: true, trailing: 'search'
});
const actions = [
  ['typing', 'app.string.typing|typing…'],
  ['recordingVideo', 'app.string.chat_preview_recording_video|recording video...'],
  ['uploadingVideo', 'app.string.chat_preview_sending_video|sending video...'],
  ['recordingVoice', 'app.string.chat_preview_recording_voice|recording voice...'],
  ['uploadingVoice', 'app.string.chat_preview_sending_voice|sending voice...'],
  ['uploadingPhoto', 'app.string.chat_preview_sending_photo|sending photo...'],
  ['uploadingDocument', 'app.string.chat_preview_sending_file|sending file...'],
  ['choosingSticker', 'app.string.chat_preview_choosing_sticker|choosing sticker...'],
  ['choosingLocation', 'app.string.chat_preview_choosing_location|choosing location...'],
  ['choosingContact', 'app.string.chat_preview_choosing_contact|choosing contact...'],
  ['playingGame', 'app.string.chat_preview_playing_game|playing game...'],
  ['recordingVideoNote', 'app.string.chat_preview_recording_video_note|recording video message...'],
  ['uploadingVideoNote', 'app.string.chat_preview_sending_video_note|sending video message...'],
  ['unknownAction', 'app.string.typing|typing…']
];
for (const [actionType, label] of actions) {
  const direct = run({ typing: { actionType, senderUserId: 66, timestamp: now - 1 } }).presentation;
  check(direct.subtitle, label);
  check(direct.mode, actionType === 'typing' ? typingMode : activity);
  const grouped = run({ chatValue: group, activeChatId: -100,
    typing: { actionType, senderUserId: 66, timestamp: now - 1 } }).presentation;
  check(grouped.subtitle, 'Alice');
}
check(run({ chatValue: group, activeChatId: -100, typing,
  connection: 'waitingForNetwork' }).presentation.subtitle,
  'app.string.connection_waiting_network|Waiting for network...');
check(run({ connection: 'connecting' }).presentation.spinner, true);
check(run({ connection: 'updating' }).presentation.subtitle,
  'app.string.connection_updating|Updating...');

// The same page instance must clear stale reactive values on successive updates.
const connecting = run({ connection: 'connecting' });
check(connecting.presentation.spinner, true);
const reconnected = run({ existingPage: connecting.page });
check(reconnected.presentation.spinner, false);
check(reconnected.presentation.mode, TgChatTopBarSubtitleMode.Online);
const typingActive = run({ existingPage: reconnected.page, chatValue: group,
  activeChatId: -100, typing });
check(typingActive.presentation.mode, activity);
const typingExpired = run({ existingPage: typingActive.page, chatValue: group,
  activeChatId: -100, typing: { ...typing, timestamp: now - (activityTtlMs + 1) } });
check(typingExpired.presentation.subtitle,
  'app.plural.group_members_count_plural|42|42 members');
check(typingExpired.presentation.mode, secondary);
const disappeared = run({ existingPage: typingExpired.page, chatValue: null,
  activeChatId: -100 });
check(disappeared.presentation, {
  subtitle: '', mode: secondary, spinner: false, initials: '', colorIndex: 0,
  imageSrc: '', online: false, trailing: 'search'
});

// Page-owned observation, bottom-bar derivation and hydration retain their order.
check(channelResult.effects.map(effect => effect[0]), ['observe', 'bottom', 'supergroup']);
check(channelResult.calls[0]?.[1] === channel, true);
check(channelResult.calls[1]?.[1] === channel, true);
check(channelResult.calls[1]?.[2] === channelResult.state, true);
check(channelResult.page.memberCountHydratedChatId, -200);
const hydratedAgain = run({ existingPage: channelResult.page, chatValue: channel,
  activeChatId: -200 });
check(hydratedAgain.effects.map(effect => effect[0]), ['observe', 'bottom']);
check(hydratedAgain.loadCalls, []);
const missing = run({ chatValue: null });
check(missing.effects.map(effect => effect[0]), ['observe']);
check(missing.calls[0]?.[1] instanceof Chat, true);

console.log(JSON.stringify({ checks, failed, baseline, mutant,
  pageLines: pageSource.split(/\r?\n/).length - 1 }));
process.exitCode = failed ? 1 : 0;
