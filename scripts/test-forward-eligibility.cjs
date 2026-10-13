// Node >=24. Actual forwarding page guards, controller and use cases.
// Only transport/platform/presentation are fixtures; no real sends or SDK needed.
const { readChatSource } = require("./chat-screen-source.cjs");
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
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

const sources = {};
const mutant = process.argv.find(arg => arg.startsWith('--mutant='))?.slice(9);
assert.ok(!mutant || ['source-gate', 'copy-flag', 'target-kind', 'before-comment', 'dispatch-guard'].includes(mutant));
let mutations = 0;
function read(file) {
  let s = readChatSource(path.join(root, file), 'utf8').replaceAll('\r\n', '\n'); sources[file] = createHash('sha256').update(s).digest('hex');
  let from, to;
  if (file === 'domain/usecases/forwardMessages.ets') {
    if (mutant === 'source-gate') { from = "properties.getTopLevelBooleanStrict(flag) !== true"; to = 'false'; }
    if (mutant === 'copy-flag') { from = ": params.sendCopy || !serverId ? 'can_be_copied' : 'can_be_forwarded'"; to = ": 'can_be_forwarded'"; }
    if (mutant === 'dispatch-guard') { from = 'if (!canDispatch())'; to = 'if (false)'; }
  }
  if (file === 'ui/pages/chat/TgChatScreenPage.ets' && mutant === 'target-kind') { from = "targetType !== 'group' && targetType !== 'supergroup'"; to = "targetType !== 'group'"; }
  if (file === 'ui/pages/chat/ChatMessageActionsController.ets' && mutant === 'before-comment') {
    from = 'await forwardUseCase.validateEligibility(prepared, (): boolean =>'; to = 'await Promise.resolve(((): boolean =>';
    assert.ok(s.includes(from)); s = s.replace(from, to);
    const end = 'trimmedComment.length > 0 ? sendUseCase : undefined, targetChatId, sourceChatId, messageIds));';
    assert.ok(s.includes(end)); s = s.replace(end, end.slice(0, -2) + ')());'); mutations++; from = undefined;
  }
  if (from) { assert.ok(s.includes(from), `mutation engages ${mutant}`); s = s.replaceAll(from, to); mutations++; }
  return s;
}
function load(file, deps = {}) {
  const s = read(file), names = [...s.matchAll(/^export\s+(?:default\s+)?(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(s.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+(?:default\s+)?/gm, ''), { mode: 'transform', sourceUrl: file });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const hilog = { info() {}, warn() {}, debug() {}, error() {} }, platform = { hilog, localized: (_id, fallback) => fallback, $r: id => ({ id }) };
const A = load('core/model/AppState.ets'), C = load('core/model/AppCommand.ets');
const td = load('models/td/common/index.ets'), accessors = load('core/utils/tdAccessors.ets', td);
const G = load('core/model/dto/GroupAccessDto.ets', accessors), P = load('ui/pages/chat/ChatInputPanelPolicy.ets', G);
const errors = load('core/model/AppError.ets');
const forwarding = load('domain/usecases/forwardMessages.ets', { ...C, ...td, ...errors, ...platform });
const sending = load('domain/usecases/sendMessage.ets', { ...C, ...td, ...errors, ...platform });
const actions = load('ui/pages/chat/ChatMessageActionsController.ets', { ...errors, ...forwarding, ...sending, ...platform });
const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...C, ...td, ...platform });
const page = read('ui/pages/chat/TgChatScreenPage.ets');
const methods = ['getForwardUseCase', 'canUseComposer', 'canSendNewMessages'].map(name => {
  const start = new RegExp(`^  (?:(?:private|public)\\s+)?${name}\\(`, 'm').exec(page)?.index;
  assert.notEqual(start, undefined); const end = page.indexOf('\n  }', start); assert.ok(end > start); return page.slice(start, end + 4);
});
const Page = new Function('selectChatInputPanel', stripTypeScriptTypes(`class Page {
  slowmodeController = new globalThis.ChatSlowmodeController();
  composerSlowmodeSeconds = 0;${methods.join('\n')}}`, { mode: 'transform' }) + '\nreturn Page;')(P.selectChatInputPanel);
const raw = value => td.TdObject.fromJSON(JSON.stringify(value));
const tick = () => new Promise(resolve => setImmediate(resolve));
const tests = []; function test(name, run) { tests.push({ name, run }); }
function groupFixture(type = 'supergroup') {
  const state = A.createInitialAppState();
  const chat = Object.assign(new A.Chat(), { id: -77, type, supergroupId: 77, basicGroupId: 77, sendPermissions: Object.assign(new G.GroupSendPermissionsDto(), { canSendBasicMessages: true }) });
  state.chats.chats.set(-77, chat);
  const access = Object.assign(new G.GroupAccessDto(), { groupId: 77, kind: type === 'group' ? 'basicGroup' : 'supergroup', role: 'member', isMember: true });
  (type === 'group' ? state.chats.basicGroupAccess : state.chats.supergroupAccess).set(77, access);
  state.chats.supergroupBoosts.set(77, Object.assign(new G.SupergroupBoostsDto(), { groupId: 77 }));
  state.messages.messages.set(-55, new Map([['100', { content: { type: 'photo' } }], ['101', { content: { type: 'text' } }]]));
  const p = Object.assign(new Page(), { activeChatId: -77, isEditingMessage: false, accountStore: { getState: () => state }, forwardUseCase: {}, forwardSourceChatId: -55, forwardingMessageIds: ['100'] });
  return { state, p, chat };
}
test('supergroup forward respects known photo kind even when text retains composer', () => {
  const f = groupFixture(); assert.equal(f.p.getForwardUseCase(-55, ['100']), undefined); assert.equal(f.p.getForwardUseCase(-55, ['101']), f.p.forwardUseCase);
});
test('supergroup unknown source cannot silently bypass target media permissions', () => {
  const f = groupFixture(); assert.equal(f.p.getForwardUseCase(-55, ['102']), undefined);
});
test('basic-group source type gate stays intact', () => {
  const f = groupFixture('group'); assert.equal(f.p.getForwardUseCase(-55, ['100']), undefined); assert.equal(f.p.getForwardUseCase(-55, ['101']), f.p.forwardUseCase);
});
function deniedForwardFixture(overrides = {}) {
  const commands = [];
  const gateway = { send(command) {
    commands.push(command);
    if (overrides.send) { const response = overrides.send(command, commands); if (response !== undefined) return response; }
    if (command.type === 'getMessageProperties') return Promise.resolve(raw({ '@type': 'messageProperties', can_be_forwarded: false, can_be_copied: false, can_be_copied_to_secret_chat: false }));
    if (command.type === 'getChat') return Promise.resolve(raw({ '@type': 'chat', id: command.payload.chatId, type: { '@type': 'chatTypePrivate', user_id: 7 } }));
    if (command.type === 'getMessages') return Promise.resolve(raw({ '@type': 'messages', total_count: 1, messages: [{ '@type': 'message', id: 100, chat_id: -55, content: { '@type': 'messageText', text: { '@type': 'formattedText', text: 'source', entities: [] } } }] }));
    if (command.type === 'sendMessage') return Promise.resolve(raw({ '@type': 'message', id: 900, chat_id: 7 }));
    if (command.type === 'forwardMessages') return Promise.resolve(raw({ '@type': 'messages', total_count: 1, messages: [null] }));
    return Promise.reject(new Error(`Unexpected command ${command.type}`));
  } };
  const forward = new forwarding.ForwardMessagesUseCase(gateway), send = new sending.SendMessageUseCase(gateway);
  let state = Object.assign(new actions.ChatForwardModeState(), { isForwardingMessages: true, sourceChatId: -55, messageIds: ['100'], title: 'source', preview: 'preview' });
  let draft = 'comment', busy = false, operation = 0, feedback = 0, revision = 0;
  const live = { target: 7, lifecycle: 1, forwardAllowed: true, textAllowed: true, active: true, editing: '0', attachments: [] };
  const host = { canSendNewMessages: () => live.active && live.forwardAllowed, getActiveChatId: () => live.target, getLifecycleToken: () => live.lifecycle, getForwardModeState: () => state, getForwardUseCase: () => live.active && live.forwardAllowed ? forward : undefined, getSendUseCase: () => live.active && live.textAllowed ? send : undefined,
    isSendingMessage: () => busy, setSendingMessage: value => { busy = value; if (value) operation++; }, getSendOperationToken: () => operation, hasActiveChatState: () => live.active,
    getDraftText: () => draft, getComposerInputRevision: () => revision, setDraftText: value => { revision++; draft = value; }, clearReplyMode() {}, clearEditMode() {}, clearForwardMode: () => { state = new actions.ChatForwardModeState(); },
    setForwardMode: (ids, sourceChatId, title, preview) => { state = Object.assign(new actions.ChatForwardModeState(), { isForwardingMessages: true, messageIds: ids, sourceChatId, title, preview }); },
    getEditingMessageId: () => live.editing, getPendingAttachmentUris: () => live.attachments, isNearBottom: () => false, scrollToBottomSoon() {},
    getChatUIContext: () => ({ getPromptAction: () => ({ showToast: () => { feedback++; } }) }) };
  return { commands, host, live, forward, draft: () => draft, busy: () => busy, feedback: () => feedback };
}
test('unforwardable selection is rejected before its comment is sent', async () => {
  const f = deniedForwardFixture(); new actions.ChatMessageActionsController().handleForwardMessages('comment', f.host);
  for (let i = 0; i < 6; i++) await tick();
  assert.deepEqual(f.commands.filter(c => c.type === 'sendMessage' || c.type === 'forwardMessages'), [], 'no mutating request before eligibility');
  assert.equal(f.draft(), 'comment'); assert.equal(f.busy(), false);
  assert.equal(f.feedback(), 1);
});
const properties = (f = true, c = true, s = true) => raw({ '@type': 'messageProperties', can_be_forwarded: f, can_be_copied: c, can_be_copied_to_secret_chat: s });
const target = (type = 'chatTypePrivate', id = 7) => raw({ '@type': 'chat', id, type: { '@type': type } });
const params = (ids = ['1048576'], copy = false) => Object.assign(new forwarding.ForwardMessagesParams(), { chatId: 7, fromChatId: -55, messageIds: ids, sendCopy: copy });
function useCaseFixture(options = {}) {
  const commands = [];
  const uc = new forwarding.ForwardMessagesUseCase({ send(command) {
    commands.push(command);
    if (options.send) { const value = options.send(command, commands); if (value !== undefined) return value; }
    if (command.type === 'getChat') return Promise.resolve(Object.hasOwn(options, 'target') ? options.target : target());
    if (command.type === 'getMessageProperties') return Promise.resolve(Object.hasOwn(options, 'properties') ? options.properties : properties());
    if (command.type === 'forwardMessages') return Promise.resolve(raw({ '@type': 'messages', messages: command.payload.messageIds.map((_, index) => ({ '@type': 'message', id: 1000 + index, chat_id: 7 })) }));
    throw new Error('unexpected command ' + command.type);
  } });
  return { uc, commands, mutations: () => commands.filter(c => c.type === 'forwardMessages') };
}
for (const [name, ids, copy, type, flags, allowed] of [
  ['server requires F not C', ['1048576'], false, 'chatTypePrivate', [true, false, false], true],
  ['server cannot substitute C for F', ['1048576'], false, 'chatTypePrivate', [false, true, true], false],
  ['explicit copy permits C without F', ['1048576'], true, 'chatTypePrivate', [false, true, false], true],
  ['explicit copy cannot substitute F', ['1048576'], true, 'chatTypePrivate', [true, false, false], false],
  ['secret target forces S despite no copy', ['1048576'], false, 'chatTypeSecret', [true, true, false], false],
  ['secret S permits forced copy', ['1048576'], false, 'chatTypeSecret', [false, true, true], true],
  ['local forces C', ['1048578'], false, 'chatTypePrivate', [true, false, false], false],
  ['local permits C without F', ['1048578'], false, 'chatTypePrivate', [false, true, false], true],
  ['unsent forces C', ['1048577'], false, 'chatTypePrivate', [false, true, false], true],
  ['large server ID remains exact', ['2251799812636672'], false, 'chatTypeSupergroup', [true, false, false], true],
  ['all false source denied', ['1048576'], false, 'chatTypeBasicGroup', [false, false, false], false],
]) test(name, async () => {
  const f = useCaseFixture({ target: target(type), properties: properties(...flags) });
  if (allowed) await f.uc.execute(params(ids, copy)); else await assert.rejects(f.uc.execute(params(ids, copy)));
  assert.equal(f.mutations().length, allowed ? 1 : 0);
  assert.equal(f.commands[0].type, 'getChat'); assert.equal(f.commands[1].type, 'getMessageProperties');
  assert.equal(f.commands[1].payload.chatId, -55); assert.equal(f.commands[1].payload.messageId, ids[0]);
});
for (const value of [false, 'true', 1, null, undefined]) test(`strict source flag rejects ${String(value)}`, async () => {
  const f = useCaseFixture({ properties: raw({ '@type': 'messageProperties', can_be_forwarded: value, can_be_copied: true, can_be_copied_to_secret_chat: true }) }); await assert.rejects(f.uc.execute(params())); assert.equal(f.mutations().length, 0);
});
for (const value of [raw({ '@type': 'error', code: 400, message: 'Message not found' }), raw({ '@type': 'messageProperties', nested: { can_be_forwarded: true } }), { '@type': 'messageProperties', can_be_forwarded: true }, raw({ '@type': 'other', can_be_forwarded: true })]) test('wrong/nested/plain properties fail closed', async () => {
  const f = useCaseFixture({ properties: value }); await assert.rejects(f.uc.execute(params())); assert.equal(f.mutations().length, 0);
});
for (const value of [target('chatTypePrivate', 8), target('unknown'), raw({ '@type': 'chat', id: '7', type: { '@type': 'chatTypePrivate' } }), raw({ '@type': 'chat', nested: { id: 7, type: { '@type': 'chatTypePrivate' } } }), { '@type': 'chat', id: 7, type: { '@type': 'chatTypePrivate' } }]) test('target identity/type must be exact', async () => {
  const f = useCaseFixture({ target: value }); await assert.rejects(f.uc.execute(params())); assert.equal(f.commands.length, 1); assert.equal(f.mutations().length, 0);
});
test('one denied source rejects full batch before any forward', async () => {
  const f = useCaseFixture({ send: c => c.type === 'getMessageProperties' ? Promise.resolve(properties(c.payload.messageId !== '2097152')) : undefined });
  await assert.rejects(f.uc.execute(params(['3145728', '2097152', '1048576']))); assert.equal(f.mutations().length, 0);
  assert.deepEqual(f.commands.filter(c => c.type === 'getMessageProperties').map(c => c.payload.messageId), ['1048576', '2097152']);
});
test('input IDs/options snapshot survives asynchronous target read', async () => {
  let release; const f = useCaseFixture({ send: c => c.type === 'getChat' ? new Promise(resolve => { release = resolve; }) : undefined });
  const input = params(['2097152', '1048576']); const pending = f.uc.execute(input); input.messageIds[0] = '3145728'; input.chatId = 8; input.sendCopy = true;
  release(target()); await pending; assert.deepEqual(f.mutations()[0].payload.messageIds, ['1048576', '2097152']); assert.equal(f.mutations()[0].payload.chatId, 7); assert.equal(f.mutations()[0].payload.sendCopy, false);
});
for (const readType of ['getChat', 'getMessageProperties']) test(`dispatch cancelled during ${readType}`, async () => {
  let release, allowed = true; const f = useCaseFixture({ send: c => c.type === readType ? new Promise(resolve => { release = resolve; }) : undefined });
  const pending = f.uc.execute(params(), () => allowed); const rejected = assert.rejects(pending); await tick(); allowed = false; release(readType === 'getChat' ? target() : properties()); await rejected; assert.equal(f.mutations().length, 0);
});
for (const readType of ['getChat', 'getMessageProperties']) test(`read failure ${readType} never mutates`, async () => {
  const f = useCaseFixture({ send: c => c.type === readType ? Promise.reject(new Error('offline')) : undefined }); await assert.rejects(f.uc.execute(params())); assert.equal(f.mutations().length, 0);
});
test('copy options strict and removeCaption ignored without explicit copy', async () => {
  const f = useCaseFixture(); const p = params(); p.removeCaption = true; await f.uc.execute(p); assert.equal(f.mutations()[0].payload.removeCaption, false);
  p.sendCopy = true; await f.uc.execute(p); assert.equal(f.mutations()[1].payload.removeCaption, true);
  p.sendCopy = 'true'; assert.throws(() => f.uc.prepare(p)); p.sendCopy = true; p.removeCaption = 1; assert.throws(() => f.uc.prepare(p));
});
test('serializer keeps exact int53 source ID as numeric JSON field', () => {
  const cmd = C.createGetMessagePropertiesCommand(-55, '2251799812636672'); const result = serializer.serializeCommand(cmd);
  assert.equal(result.method, 'getMessageProperties'); const json = serializer.buildTdlibRequestJson(result.method, result.params);
  assert.deepEqual(JSON.parse(json), { '@type': 'getMessageProperties', chat_id: -55, message_id: 2251799812636672 });
  assert.ok(json.includes('"message_id":2251799812636672'));
});
test('successful comment path checks source twice, before each mutation', async () => {
  const f = deniedForwardFixture({ send: c => c.type === 'getMessageProperties' ? Promise.resolve(properties()) : c.type === 'forwardMessages' ? Promise.resolve(raw({ '@type': 'messages', messages: [{ '@type': 'message', id: 1000, chat_id: 7 }] })) : undefined });
  new actions.ChatMessageActionsController().handleForwardMessages('comment', f.host); for (let i = 0; i < 6; i++) await tick();
  assert.deepEqual(f.commands.map(c => c.type), ['getChat', 'getMessageProperties', 'sendMessage', 'getChat', 'getMessageProperties', 'forwardMessages']); assert.equal(f.draft(), ''); assert.equal(f.busy(), false);
});
test('source loses eligibility after accepted comment: no forward or comment replay', async () => {
  let readCount = 0; const f = deniedForwardFixture({ send: c => c.type === 'getMessageProperties' ? Promise.resolve(properties(true, ++readCount === 1, false)) : undefined });
  new actions.ChatMessageActionsController().handleForwardMessages('comment', f.host); for (let i = 0; i < 6; i++) await tick();
  assert.equal(f.commands.filter(c => c.type === 'sendMessage').length, 1); assert.equal(f.commands.filter(c => c.type === 'forwardMessages').length, 0); assert.equal(f.draft(), ''); assert.equal(f.host.getForwardModeState().isForwardingMessages, true); assert.equal(f.busy(), false);
});
for (const change of ['forwardAllowed', 'textAllowed', 'active', 'target', 'lifecycle']) test(`controller pre-comment cancellation: ${change}`, async () => {
  let release; const f = deniedForwardFixture({ send: c => c.type === 'getMessageProperties' ? new Promise(resolve => { release = resolve; }) : undefined });
  new actions.ChatMessageActionsController().handleForwardMessages('comment', f.host); await tick(); assert.equal(typeof release, 'function');
  f.live[change] = change === 'target' ? 8 : change === 'lifecycle' ? 2 : false; release(properties()); for (let i = 0; i < 6; i++) await tick();
  assert.equal(f.commands.filter(c => ['sendMessage', 'forwardMessages'].includes(c.type)).length, 0);
});
test('new draft not overwritten when denied asynchronous preflight resolves', async () => {
  let release; const f = deniedForwardFixture({ send: c => c.type === 'getMessageProperties' ? new Promise(resolve => { release = resolve; }) : undefined });
  new actions.ChatMessageActionsController().handleForwardMessages('comment', f.host); await tick(); f.host.setDraftText('new intent'); release(properties(false, false, false));
  for (let i = 0; i < 6; i++) await tick(); assert.equal(f.draft(), 'new intent'); assert.equal(f.busy(), false); assert.equal(f.host.getForwardModeState().isForwardingMessages, false);
});
for (const change of ['forwardAllowed', 'active', 'target', 'lifecycle']) test(`second preflight cancelled after comment: ${change}`, async () => {
  let release, reads = 0; const f = deniedForwardFixture({ send: c => c.type === 'getMessageProperties' ? (++reads === 1 ? Promise.resolve(properties()) : new Promise(resolve => { release = resolve; })) : undefined });
  new actions.ChatMessageActionsController().handleForwardMessages('comment', f.host); await tick(); assert.equal(typeof release, 'function');
  assert.equal(f.commands.filter(c => c.type === 'sendMessage').length, 1);
  f.live[change] = change === 'target' ? 8 : change === 'lifecycle' ? 2 : false; release(properties()); for (let i = 0; i < 6; i++) await tick();
  assert.equal(f.commands.filter(c => c.type === 'forwardMessages').length, 0); assert.equal(f.draft(), '');
});
test('actual page revokes forward capability with absent account state', () => {
  const f = groupFixture(); f.p.accountStore = undefined; assert.equal(f.p.getForwardUseCase(-55, ['101']), undefined);
});
// Execute the unchanged Hypium suite bodies on the host. This is not a device run.
const nativeStart = tests.length;
load('../../ohosTest/ets/test/ForwardEligibility.test.ets', {
  ...C, ...td, ...forwarding, ...sending, ...actions, ...serializer,
  describe: (_name, body) => body(), it: (name, _flags, body) => test(`native: ${name}`, body),
  expect: value => ({ assertEqual: expected => assert.equal(value, expected) })
}).forwardEligibilityTest();
assert.equal(tests.length - nativeStart, 25, 'all native suite bodies registered');
let done = false;
(async () => { let passed = 0, failed = 0; for (const t of tests) {
  let timeout;
  try {
    // A removed cancellation gate may leave an intentionally held fixture read
    // pending. Report that as a failure, not an unfinished/silently dropped suite.
    await Promise.race([Promise.resolve().then(t.run), new Promise((_resolve, reject) => {
      timeout = setTimeout(() => reject(new Error('Test did not settle within 3000ms')), 3000);
    })]); passed++;
  } catch (e) { failed++; console.error('FAIL', t.name, e.message); }
  finally { clearTimeout(timeout); }
  }
  done = true; if (mutant) assert.ok(mutations > 0); console.log(JSON.stringify({ passed, failed, nativeBodiesThroughHost: tests.length - nativeStart, mutant, mutations, sources })); process.exitCode = failed ? 1 : 0;
})().catch(e => { done = true; console.error(e); process.exitCode = 2; });
process.on('beforeExit', () => { if (!done) process.exitCode = 2; });
