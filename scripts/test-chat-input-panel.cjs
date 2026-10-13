// Actual page dispatcher and pure selector; no ArkUI rendering, backend or account actions.
const { readChatSource } = require("./chat-screen-source.cjs");
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '../entry/src/main/ets');
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

const selectorPath = path.join(root, 'ui/pages/chat/ChatInputPanelPolicy.ets');
let selector, needsSupergroupBoosts, selectorCalls = 0;
if (fs.existsSync(selectorPath)) {
  const s = readChatSource(selectorPath, 'utf8').replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '');
  const policy = new Function(stripTypeScriptTypes(s, { mode: 'transform' }) + '; return {selectChatInputPanel, needsSupergroupBoosts};')();
  selector = policy.selectChatInputPanel; needsSupergroupBoosts = policy.needsSupergroupBoosts;
}
const page = readChatSource(path.join(root, 'ui/pages/chat/TgChatScreenPage.ets'), 'utf8');
const start = page.indexOf('  private deriveChatBottomBar(');
const end = page.indexOf('\n  private bottomBarActionLabel(', start);
assert.ok(start >= 0 && end > start, 'actual dispatcher boundary must exist');
const gateStart = page.indexOf('  private shouldReactToStoreChange(');
const gateEnd = page.indexOf('\n  private scheduleLifecycleTask(', gateStart);
const editStart = page.indexOf('  setEditMode(');
const editEnd = page.indexOf('\n  setForwardMode(', editStart);
assert.ok(gateEnd > gateStart && editEnd > editStart, 'page lifecycle method boundaries');
const Panel = new Function('selectChatInputPanel', 'needsSupergroupBoosts', stripTypeScriptTypes(`class Panel {
  slowmodeController = new globalThis.ChatSlowmodeController();
  composerSlowmodeSeconds = 0;\n${page.slice(start, end)}\n${page.slice(gateStart, gateEnd)}\n${page.slice(editStart, editEnd)}\n}`, { mode: 'transform' }) + '; return Panel;')(
  (...args) => { selectorCalls++; return selector(...args); }, needsSupergroupBoosts);

function check(role, access, expected, options = {}) {
  const chat = { id: -100123, supergroupId: 123, basicGroupId: 123, type: 'channel', peerUserId: 0,
    order: '0', archiveOrder: '0', canSendBasicMessages: false, muteForSeconds: 0, ...options.chat };
  chat.sendPermissions = { canSendBasicMessages: chat.canSendBasicMessages };
  const state = { chats: { supergroupBoosts: new Map(), supergroupSlowmode: new Map(), supergroupAccess: new Map(access ? [[123, { groupId: 123, kind: 'supergroup', role,
    isMember: false, canPostMessages: false, canEditMessages: false, ...access }]] : []),
    basicGroupAccess: new Map(chat.type === 'group' && access ? [[123, { groupId: 123, kind: 'basicGroup', role,
      isMember: false, isActive: true, ...access }]] : []) } };
  const p = Object.assign(new Panel(), { editingMessageId: '0', chatAccessUnavailable: false, ...options.page });
  const before = selectorCalls;
  p.deriveChatBottomBar(chat, state);
  if (selector) assert.equal(selectorCalls, before + 10, 'page must engage selector for the panel and nine reactive kind flags');
  const actual = p.chatBottomBarReason || (p.chatBottomBarRestricted ? 'restricted' :
    p.chatBottomBarAction === 'none' ? 'composer' : p.chatBottomBarAction);
  assert.equal(actual, expected);
}

const tests = [];
const states = [
  ['creator', { isMember: true }, 'composer'],
  ['creator', { isMember: false }, 'join'],
  ['administrator', { isMember: true, canPostMessages: true }, 'composer'],
  ['administrator', { isMember: true, canPostMessages: false }, 'mute'],
  ['member', { isMember: true }, 'mute'],
  ['left', { isMember: false }, 'join'],
  ['banned', { isMember: false }, 'banned'],
  ['unknown', undefined, 'unknown']
];
for (const [role, access, expected] of states) {
  for (const order of ['0', '99']) for (const archiveOrder of ['0', '88']) for (const canSendBasicMessages of [false, true]) {
    tests.push([`${role}/${access?.isMember}/${access?.canPostMessages} orders=${order}/${archiveOrder} defaults=${canSendBasicMessages}`,
      () => check(role, access, expected, { chat: { order, archiveOrder, canSendBasicMessages } })]);
  }
}
tests.push(
  ['muted subscriber', () => check('member', { isMember: true }, 'unmute', { chat: { muteForSeconds: 999 } })],
  ['mismatched group cannot grant composer', () => check('creator', { groupId: 999, isMember: true }, 'unknown')],
  ['basic-group id collision cannot grant composer', () => check('creator', { kind: 'basicGroup', isMember: true }, 'unknown')],
  ['edit-only admin composes while editing', () => check('administrator', { isMember: true, canEditMessages: true }, 'composer', { page: { editingMessageId: '5' } })],
  ['edit-only admin does not compose new message', () => check('administrator', { isMember: true, canEditMessages: true }, 'mute')],
  ['editing cannot bypass banned', () => check('banned', { canEditMessages: true }, 'banned', { page: { editingMessageId: '5' } })],
  ['unknown failure exposes explicit retry, not composer', () => check('unknown', undefined, 'retry', { page: { chatAccessUnavailable: true } })],
  ['fractional group ID is unavailable without a dead Retry', () => check('unknown', undefined, 'unknown', { chat: { supergroupId: 0.5 }, page: { chatAccessUnavailable: true } })],
  ['invalid chat ID is unavailable without a dead Retry', () => check('unknown', undefined, 'unknown', { chat: { id: 0 }, page: { chatAccessUnavailable: true } })],
  ['private chat unaffected', () => check('unknown', undefined, 'composer', { chat: { type: 'private', peerUserId: 7 } })],
  ['active basic-group member can compose', () => check('member', { isMember: true }, 'composer', { chat: { type: 'group', canSendBasicMessages: true } })],
  ['active basic-group member obeys defaults', () => check('member', { isMember: true }, 'restricted', { chat: { type: 'group', canSendBasicMessages: false } })]
);
const matrixCaseCount = tests.length;
function statesForGate() {
  const chat = { id: -100123, type: 'channel', supergroupId: 123 };
  const a = { chats: { chats: new Map([[chat.id, chat]]), supergroupBoosts: new Map(), supergroupSlowmode: new Map(), supergroupAccess: new Map(), typingActions: new Map() },
    messages: { messages: new Map(), associatedMessages: new Map() }, files: { transfers: new Map() }, users: { users: new Map() } };
  const b = { ...a, chats: { ...a.chats, supergroupAccess: new Map(a.chats.supergroupAccess) } };
  return [a, b];
}
tests.push(
  ['active permission update engages the page subscription gate', () => {
    const [a, b] = statesForGate(); b.chats.supergroupAccess.set(123, { role: 'administrator', canPostMessages: true });
    const p = Object.assign(new Panel(), { activeChatId: -100123 });
    assert.equal(p.shouldReactToStoreChange(b, a), true);
  }],
  ['another group update does not rebuild this chat', () => {
    const [a, b] = statesForGate(); b.chats.supergroupAccess.set(456, { role: 'banned' });
    const p = Object.assign(new Panel(), { activeChatId: -100123 });
    assert.equal(p.shouldReactToStoreChange(b, a), false);
  }],
  ['edit-only composer opens and closes without waiting for an unrelated TDLib update', () => {
    const chat = { id: -100123, type: 'channel', supergroupId: 123, muteForSeconds: 0 };
    const state = { chats: { chats: new Map([[chat.id, chat]]), supergroupBoosts: new Map(), supergroupSlowmode: new Map(), supergroupAccess: new Map([[123,
      { kind: 'supergroup', groupId: 123, role: 'administrator', isMember: true, canEditMessages: true }]]) } };
    const p = Object.assign(new Panel(), { activeChatId: chat.id, accountStore: { getState: () => state, subscribeScopeInvalidation: () => () => {}, isScopeCurrent: () => true }, setDraftSelection() {}, setStickerPanelVisible() {} });
    p.setEditMode('5', 'existing post');
    assert.equal(p.chatBottomBarAction, 'none'); assert.equal(p.chatBottomBarRestricted, false);
    p.clearEditMode(false);
    assert.equal(p.chatBottomBarAction, 'mute');
  }]
);
let passed = 0;
for (const [name, run] of tests) {
  try { run(); passed++; }
  catch (error) { console.log('FAIL', name, error.message); }
}
if (selector) assert.ok(selectorCalls >= matrixCaseCount, 'page must engage the actual selector for every matrix case');
console.log(JSON.stringify({ passed, failed: tests.length - passed, selectorCalls, actualPageDispatcher: true }));
process.exitCode = passed === tests.length ? 0 : 1;
