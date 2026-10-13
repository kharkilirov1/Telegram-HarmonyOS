// Actual parser -> registered normalizers -> combined reducer -> scoped store.
// Native test bodies use a Hypium host adapter; no native TDLib/device/network.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const sources = {};
function load(file, deps = {}) {
  let src = fs.readFileSync(path.join(root, file), 'utf8');
  sources[file] = createHash('sha256').update(src).digest('hex');
  if (process.argv.includes('--mutant=alias') && file === 'core/utils/stateClone.ets') {
    assert.ok(src.includes('access.permissions?.clone()'), 'clone mutant did not engage');
    src = src.replace('access.permissions?.clone()', 'access.permissions');
  }
  if (process.argv.includes('--mutant=legacy-status') && file === 'core/model/dto/GroupAccessDto.ets') {
    assert.ok(src.includes("td.getTopLevelObjectStrict('status')"), 'status mutant did not engage');
    src = src.replace("td.getTopLevelObjectStrict('status')", "td.getObject('status')")
      .replaceAll('.getTopLevelStringStrict(', '.getString(');
  }
  const names = [...src.matchAll(/^export\s+(?:default\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map(m => m[1]);
  const js = stripTypeScriptTypes(src.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s+default\s+\w+;\s*/gm, '').replace(/^export\s+(?:default\s+)?/gm, ''), { mode: 'transform' });
  return new Function(...Object.keys(deps), js + `;return {${names.join(',')}};`)(...Object.values(deps));
}
const errors = [];
const hilog = { info() {}, warn() {}, debug() {}, error(...args) { errors.push(args); } };
const td = load('models/td/common/index.ets');
const accessors = load('core/utils/tdAccessors.ets', td);
const A = load('core/model/AppState.ets'), C = load('core/model/AppCommand.ets');
const D = load('core/model/dto/ChatDto.ets', { ...td, ...accessors, ...C, hilog });
const G = load('core/model/dto/GroupAccessDto.ets', { ...td, ...accessors });
const E = load('core/model/AppEvent.ets', { ...D, ...G });
const clones = load('core/utils/stateClone.ets', { ...A, ...C, ...G });
const { chatsReducer } = load('core/reducers/chatsReducer.ets', { ...A, ...E, ...clones, ...accessors, DtoChatType: D.ChatType });
const unused = () => { throw Error('Unexpected other-domain reducer'); };
const { appReducer } = load('core/reducers/index.ets', { chatsReducer, authReducer: unused,
  messagesReducer: unused, filesReducer: unused, usersReducer: unused, accentColorsReducer: unused });
const registrations = {};
for (const file of fs.readdirSync(path.join(root, 'core/events/normalizers')).filter(f => f.endsWith('.ets'))) {
  const exports = load('core/events/normalizers/' + file, { ...td, ...accessors, ...D, ...G, ...E, hilog });
  for (const [name, fn] of Object.entries(exports)) if (/^register\w+Handlers$/.test(name)) registrations[name] = fn;
}
const { EventNormalizerImpl } = load('core/events/EventNormalizer.ets', { ...registrations, ...accessors, hilog });
const { AppStore } = load('core/store/AppStore.ets', { ...A, hilog });
const { LoadChatAccessUseCase } = load('domain/usecases/loadChatAccess.ets', { ...td, ...G, ...E, ...C });
const { selectChatInputPanel } = load('ui/pages/chat/ChatInputPanelPolicy.ets');
const raw = value => td.TdObject.fromJSON(JSON.stringify(value));
const parse = value => G.createGroupAccessDtoFromTd(raw(value), 'supergroup');
const status = (type, fields = {}) => ({ '@type': 'chatMemberStatus' + type, ...fields });
const group = s => ({ '@type': 'supergroup', id: 77, status: s });
const restricted = permissions => group(status('Restricted', { is_member: true, permissions }));
const tests = [];
const test = (name, run) => tests.push({ name, run });
const fields = {
  can_send_basic_messages: 'canSendBasicMessages', can_send_audios: 'canSendAudios',
  can_send_documents: 'canSendDocuments', can_send_photos: 'canSendPhotos', can_send_videos: 'canSendVideos',
  can_send_video_notes: 'canSendVideoNotes', can_send_voice_notes: 'canSendVoiceNotes',
  can_send_polls: 'canSendPolls', can_send_other_messages: 'canSendOtherMessages'
};
for (const [key, field] of Object.entries(fields)) {
  for (const value of [true, false]) test(`${key}: preserves literal ${value}`, () => {
    const access = parse(restricted({ [key]: value }));
    assert.ok(access?.permissions, 'restricted permissions were dropped');
    assert.equal(access.permissions[field], value);
    for (const other of Object.values(fields).filter(f => f !== field)) assert.equal(access.permissions[other], false);
  });
  for (const value of ['true', 'false', 1, null, {}, []]) test(`${key}: malformed ${JSON.stringify(value)} denies`, () => {
    const access = parse(restricted({ [key]: value, nested: { [key]: true } }));
    assert.ok(access?.permissions, 'restricted permissions were dropped');
    assert.equal(access.permissions[field], false);
  });
  test(`${key}: nested true cannot shadow explicit false`, () => {
    const access = parse(restricted({ nested: { [key]: true }, [key]: false }));
    assert.ok(access?.permissions, 'restricted permissions were dropped');
    assert.equal(access.permissions[field], false);
  });
}
for (const value of [undefined, null, [], true, 'permissions']) test(`invalid permissions ${JSON.stringify(value)} stays unknown`, () => {
  assert.equal(parse(restricted(value)).permissions, undefined);
});
test('nested-only permission object is not authority', () => {
  const value = group(status('Restricted', { is_member: true, nested: { permissions: { can_send_photos: true } } }));
  assert.equal(parse(value).permissions, undefined);
});
test('strict type ignores a poisoned legacy cache', () => {
  const value = raw({ nested: { '@type': 'chatMemberStatusCreator' }, '@type': 'chatMemberStatusBanned' });
  value.getString('@type');
  assert.equal(typeof value.getTopLevelStringStrict, 'function', 'strict string accessor missing');
  assert.equal(value.getTopLevelStringStrict('@type'), 'chatMemberStatusBanned');
});
for (const value of [undefined, null, 1, {}, []]) test(`strict string rejects ${JSON.stringify(value)}`, () => {
  const data = raw({ nested: { '@type': 'chatMemberStatusCreator' }, '@type': value });
  assert.equal(typeof data.getTopLevelStringStrict, 'function', 'strict string accessor missing');
  assert.equal(data.getTopLevelStringStrict('@type'), undefined);
});
test('nested status cannot create access', () => {
  assert.equal(parse({ '@type': 'supergroup', id: 77, nested: { status: status('Creator', { is_member: true }) } }), undefined);
});
test('direct banned status beats nested creator status', () => {
  const access = parse({ '@type': 'supergroup', id: 77,
    nested: { status: status('Creator', { is_member: true }) }, status: status('Banned') });
  assert.equal(access?.role, 'banned');
});
test('nested @type in status cannot grant creator rights', () => {
  const access = parse(group({ nested: { '@type': 'chatMemberStatusCreator' }, '@type': 'chatMemberStatusBanned', is_member: true }));
  assert.equal(access?.role, 'banned');
});
test('nested-only status type is rejected', () => {
  assert.equal(parse(group({ nested: { '@type': 'chatMemberStatusCreator' }, is_member: true })), undefined);
});
for (const role of ['Creator', 'Restricted']) test(`${role}: nested membership cannot override explicit false`, () => {
  assert.equal(parse(group(status(role, { nested: { is_member: true }, is_member: false }))).isMember, false);
});
for (const rights of [undefined, { nested: { can_post_messages: true, can_edit_messages: true } },
  { nested: { can_post_messages: true, can_edit_messages: true }, can_post_messages: false, can_edit_messages: false }]) {
  test(`nested administrator fields deny: ${JSON.stringify(rights)}`, () => {
    const access = parse(group(status('Administrator', { nested: { rights: { can_post_messages: true } }, rights })));
    assert.equal(access.canPostMessages, false); assert.equal(access.canEditMessages, false);
  });
}
for (const [kind, wrapper, updateType] of [['supergroup', 'supergroup', 'updateSupergroup'], ['basicGroup', 'basic_group', 'updateBasicGroup']]) {
  test(`${kind}: update wrapper cannot borrow nested group`, () => {
    const n = new EventNormalizerImpl();
    assert.equal(n.normalize(raw({ '@type': updateType,
      nested: { [wrapper]: { '@type': kind, is_active: true, id: 77, status: status('Creator', { is_member: true }) } } })).length, 0);
  });
  test(`${kind}: live direct group wins over nested group`, () => {
    const events = new EventNormalizerImpl().normalize(raw({ '@type': updateType,
      nested: { [wrapper]: { '@type': kind, is_active: true, id: 77, status: status('Creator', { is_member: true }) } },
      [wrapper]: { '@type': kind, id: 77, is_active: true, status: status('Banned') } }));
    assert.equal(events.length, 1); assert.equal(events[0].access.role, 'banned');
  });
}
test('registered update -> combined reducer deep-clones every permission', async () => {
  const store = new AppStore(appReducer, A.createInitialAppState(), false);
  const permissions = Object.fromEntries(Object.keys(fields).map(key => [key, true]));
  const events = new EventNormalizerImpl().normalize(raw({ '@type': 'updateSupergroup', supergroup: restricted(permissions) }));
  assert.equal(events.length, 1); assert.ok(events[0].access.permissions, 'normalizer dropped restrictions');
  await store.dispatchBatch(events);
  const stored = store.getState().chats.supergroupAccess.get(77);
  assert.ok(stored.permissions, 'store dropped restrictions');
  assert.notEqual(stored.permissions, events[0].access.permissions, 'producer aliases stored nested permissions');
  for (const field of Object.values(fields)) {
    assert.equal(stored.permissions[field], true);
    events[0].access.permissions[field] = false;
    assert.equal(stored.permissions[field], true);
  }
  const before = store.getState();
  await store.dispatchBatch(new EventNormalizerImpl().normalize(raw(group(status('Member')))));
  assert.equal(store.getState().chats.supergroupAccess.get(77).permissions, undefined);
  assert.equal(before.chats.supergroupAccess.get(77).permissions.canSendPhotos, true);
});
test('late hydration cannot overwrite newer live individual rights', async () => {
  const store = new AppStore(appReducer, A.createInitialAppState(), false);
  let resolve; const pending = new Promise(r => { resolve = r; });
  const gateway = { send: () => pending };
  const useCase = new LoadChatAccessUseCase(store, gateway);
  const request = useCase.load('supergroup', 77);
  await Promise.resolve();
  await store.dispatchBatch(new EventNormalizerImpl().normalize(raw(restricted({ can_send_photos: false }))));
  const before = store.getState().chats.supergroupAccess.get(77);
  resolve(raw(restricted({ can_send_photos: true })));
  await request;
  assert.equal(store.getState().chats.supergroupAccess.get(77), before);
  assert.ok(before.permissions, 'live restricted payload was dropped');
  assert.equal(before.permissions.canSendPhotos, false);
});
test('direct hydration retains rights and old account scope cannot restore them after reset', async () => {
  const store = new AppStore(appReducer, A.createInitialAppState(), false);
  const useCase = new LoadChatAccessUseCase(store, { send: async () => raw(restricted({ can_send_voice_notes: true })) });
  await useCase.load('supergroup', 77);
  assert.ok(store.getState().chats.supergroupAccess.get(77)?.permissions, 'hydration dropped permissions');
  assert.equal(store.getState().chats.supergroupAccess.get(77).permissions.canSendVoiceNotes, true);
  await store.resetStateQueued(); await useCase.load('supergroup', 77);
  assert.equal(store.getState().chats.supergroupAccess.size, 0);
});
if (fs.existsSync(path.join(root, '../../ohosTest/ets/test/GroupPermissionPayload.test.ets'))) {
  const { groupPermissionPayloadTest } = load('../../ohosTest/ets/test/GroupPermissionPayload.test.ets', {
    ...A, ...G, ...clones, ...td, EventNormalizerImpl, appReducer, AppStore, selectChatInputPanel,
    describe: (_name, run) => run(), it: (name, _flags, run) => test('ohosTest: ' + name, run),
    expect: actual => ({ assertEqual: expected => assert.equal(actual, expected) })
  });
  groupPermissionPayloadTest();
}
let finished = false;
process.on('beforeExit', () => { if (!finished) { console.error('Unresolved harness work'); process.exitCode = 1; } });
(async () => {
  let passed = 0, failed = 0;
  for (const t of tests) {
    try { await t.run(); passed++; } catch (e) { failed++; console.error('FAIL', t.name, e.message); }
  }
  if (errors.length) { failed++; console.error('Unexpected production errors', errors); }
  finished = true; console.log(JSON.stringify({ passed, failed, sources })); process.exitCode = failed ? 1 : 0;
})().catch(e => { finished = true; console.error(e); process.exitCode = 1; });
