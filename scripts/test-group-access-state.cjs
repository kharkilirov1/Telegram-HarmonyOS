// Node >=24. Actual TdObject/parser, DTO factory, ALL normalizer registrations,
// EventNormalizer, chatsReducer, state clones, invariants and AppStore reset/queue.
// Read-only host execution: no SDK/build, native TDLib, device, network or accounts.
// Imports are explicitly wired after type stripping; only hilog is replaced.
// Other domains are registered, not normalized. --combined also checks the parent-owned
// appReducer routing. This is not an ArkTS compile or selector/UI/hydration witness.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '../entry/src/main/ets');
const sources = {};
function load(relative, deps = {}) {
  const source = fs.readFileSync(path.join(root, relative), 'utf8');
  sources[relative] = createHash('sha256').update(source).digest('hex');
  const names = [...source.matchAll(/^export\s+(?:default\s+)?(?:class|function|const|enum)\s+(\w+)/gm)].map(m => m[1]);
  const code = source.replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/^export\s+\{[^}]*\};?\s*/gm, '')
    .replace(/^export\s+default\s+\w+;\s*/gm, '')
    .replace(/^export\s+(?:default\s+)?/gm, '');
  const js = stripTypeScriptTypes(code, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), `${js}\nreturn {${names.join(',')}};`)(...Object.values(deps));
}
const errors = [];
const hilog = { info() {}, debug() {}, warn() {}, error(...args) { errors.push(args); } };
const td = load('models/td/common/index.ets');
const accessors = load('core/utils/tdAccessors.ets', td);
const C = load('core/model/AppCommand.ets');
const A = load('core/model/AppState.ets');
// Absence is an explicit RED assertion, not a fake implementation or load error.
const groupPath = 'core/model/dto/GroupAccessDto.ets';
const G = fs.existsSync(path.join(root, groupPath)) ? load(groupPath, { ...td, ...accessors }) : {};
const chatDtos = load('core/model/dto/ChatDto.ets', { ...td, ...accessors, ...C, ...G, hilog });
const E = load('core/model/AppEvent.ets', { ...chatDtos, ...G });
const clones = load('core/utils/stateClone.ets', { ...A, ...C, ...G });
const { chatsReducer } = load('core/reducers/chatsReducer.ets', {
  ...A, ...E, ...G, ...clones, ...accessors, DtoChatType: chatDtos.ChatType
});
const registrations = {};
for (const file of fs.readdirSync(path.join(root, 'core/events/normalizers')).filter(f => f.endsWith('.ets'))) {
  const domain = load('core/events/normalizers/' + file, { ...td, ...accessors, ...chatDtos, ...G, ...E, hilog });
  for (const [name, value] of Object.entries(domain)) {
    if (/^register\w+Handlers$/.test(name)) registrations[name] = value;
  }
}
const { EventNormalizerImpl } = load('core/events/EventNormalizer.ets', { ...registrations, ...accessors, hilog });
const invariants = load('core/invariants/assertInvariants.ets', { ...A, ...accessors, hilog });
const { AppStore } = load('core/store/AppStore.ets', { ...A, ...invariants, hilog });
const tests = [];
const test = (name, run) => tests.push({ name, run });
const raw = value => td.TdObject.fromJSON(JSON.stringify(value));
const status = (type, extra = {}) => ({ '@type': 'chatMemberStatus' + type, ...extra });
const group = (kind, memberStatus, id = 77) => ({ '@type': kind, id, is_active: true, status: memberStatus });
const shapes = [
  ['supergroup', false], ['supergroup', true], ['basicGroup', false], ['basicGroup', true]
];
const wrap = (kind, value, wrapped) => !wrapped ? value : kind === 'supergroup'
  ? { '@type': 'updateSupergroup', supergroup: value }
  : { '@type': 'updateBasicGroup', basic_group: value };
const key = kind => kind === 'supergroup' ? 'supergroupAccess' : 'basicGroupAccess';
const values = access => {
  assert.ok(access, 'known access must exist');
  return [access.role, access.isMember, access.canPostMessages, access.canEditMessages];
};
const parse = (value, kind) => {
  assert.equal(typeof G.createGroupAccessDtoFromTd, 'function', 'missing group access factory');
  return G.createGroupAccessDtoFromTd(raw(value), kind);
};
const normalizeOne = (normalizer, value) => {
  const events = normalizer.normalize(raw(value));
  assert.equal(events.length, 1, 'exactly one event per valid group/chat payload');
  return events[0];
};
const reduceGroup = (state, kind, memberStatus, wrapped = true, id = 77) => {
  const event = normalizeOne(new EventNormalizerImpl(), wrap(kind, group(kind, memberStatus, id), wrapped));
  assert.equal(event.type, 'groupAccessUpdated');
  return chatsReducer(state, event);
};
const matrix = [
  ['creator member', status('Creator', { is_member: true }), ['creator', true, true, true]],
  ['creator left', status('Creator', { is_member: false }), ['creator', false, false, false]],
  ['posting admin', status('Administrator', { rights: { can_post_messages: true, can_edit_messages: false } }), ['administrator', true, true, false]],
  ['editing admin', status('Administrator', { rights: { can_post_messages: false, can_edit_messages: true } }), ['administrator', true, false, true]],
  ['full admin', status('Administrator', { rights: { can_post_messages: true, can_edit_messages: true } }), ['administrator', true, true, true]],
  ['nonposting admin', status('Administrator', { rights: { can_post_messages: false, can_edit_messages: false } }), ['administrator', true, false, false]],
  ['admin missing rights denies posting', status('Administrator'), ['administrator', true, false, false]],
  ['member', status('Member'), ['member', true, false, false]],
  ['restricted member', status('Restricted', { is_member: true, permissions: { can_send_basic_messages: true } }), ['restricted', true, false, false]],
  ['restricted nonmember', status('Restricted', { is_member: false }), ['restricted', false, false, false]],
  ['left', status('Left'), ['left', false, false, false]],
  ['banned', status('Banned'), ['banned', false, false, false]]
];

for (const [name, json, expected] of [
  ['integer', '{"id":51}', 51],
  ['fractional primitive retained', '{"id":51.5}', 51.5],
  ['int53 maximum', '{"id":9007199254740991}', Number.MAX_SAFE_INTEGER],
  ['numeric exponent retained', '{"id":5.1e2}', 510],
  ['numeric string is not a number', '{"id":"51"}', undefined],
  ['boolean is not a number', '{"id":true}', undefined],
  ['null is not a number', '{"id":null}', undefined],
  ['missing', '{}', undefined],
  ['nested only', '{"nested":{"id":51}}', undefined],
  ['nested before direct', '{"nested":{"id":7},"id":51}', 51],
  ['nested string before direct', '{"nested":{"id":"7"},"id":51}', 51],
  ['array root', '[{"id":51}]', undefined],
  ['null root', 'null', undefined],
  ['malformed JSON', '{"id":51', undefined]
]) {
  test(`strict wrapper accessor / ${name}`, () => {
    const value = td.TdObject.fromJSON(json);
    assert.equal(typeof value.getTopLevelNumberStrict, 'function', 'missing strict top-level primitive accessor');
    assert.equal(value.getTopLevelNumberStrict('id'), expected);
  });
}
test('strict wrapper accessor ignores cached fallback values without changing legacy getters', () => {
  const value = raw({ nested: { id: 7 }, id: 51.5 });
  assert.equal(value.getTopLevelNumber('id'), 51, 'legacy behavior remains unchanged');
  assert.equal(typeof value.getTopLevelNumberStrict, 'function');
  assert.equal(value.getTopLevelNumberStrict('id'), 51.5, 'strict read uses raw primitive, not the cached truncation');
  assert.equal(value.get('id'), '51', 'strict read does not rewrite legacy caches');
  const missing = raw({ nested: { id: 51 } });
  assert.equal(missing.getTopLevelNumber('id'), 51, 'legacy nested fallback is not globally rewritten');
  assert.equal(missing.getTopLevelNumberStrict('id'), undefined);
});

test('DTO defaults deny access without inventing membership', () => {
  assert.equal(typeof G.GroupAccessDto, 'function', 'missing typed DTO');
  const access = new G.GroupAccessDto();
  assert.deepEqual(values(access), ['unknown', false, false, false]);
  assert.equal(access.groupId, 0);
  assert.equal(access.kind, 'supergroup');
});
for (const kind of ['supergroup', 'basicGroup']) {
  for (const [name, memberStatus, expected] of matrix) {
    test(`parser / ${kind} / ${name}`, () => {
      const access = parse(group(kind, memberStatus), kind);
      assert.ok(access instanceof G.GroupAccessDto);
      assert.deepEqual(values(access), expected);
      assert.equal(access.kind, kind);
      assert.equal(access.groupId, 77);
    });
  }
  test(`parser / ${kind} / reads only nested administrator rights`, () => {
    const access = parse(group(kind, status('Administrator', {
      can_post_messages: true, can_edit_messages: true,
      rights: { can_post_messages: false, can_edit_messages: true }
    })), kind);
    assert.deepEqual(values(access), ['administrator', true, false, true]);
  });
  test(`parser / ${kind} / malformed boolean rights cannot grant access`, () => {
    const access = parse(group(kind, status('Administrator', {
      rights: { can_post_messages: 'true', can_edit_messages: 1 }
    })), kind);
    assert.deepEqual(values(access), ['administrator', true, false, false]);
  });
  for (const id of [0, -77, 'not-an-id', Number.MAX_SAFE_INTEGER + 1]) {
    test(`parser / ${kind} / rejects invalid group id ${id}`, () => {
      assert.equal(parse(group(kind, status('Member'), id), kind), undefined);
    });
  }
  test(`parser / ${kind} / fractional top-level ID is rejected, never truncated`, () => {
    assert.equal(parse(group(kind, status('Member'), 51.5), kind), undefined);
  });
  test(`parser / ${kind} / nested ID cannot stand in for a missing top-level ID`, () => {
    assert.equal(parse({ '@type': kind, is_active: true, nested: { id: 51 }, status: status('Member') }, kind), undefined);
  });
  test(`parser / ${kind} / int53 JSON string is rejected instead of coerced`, () => {
    assert.equal(parse(group(kind, status('Member'), '51'), kind), undefined);
  });
  test(`parser / ${kind} / valid int53 numeric ID above int32 retains exact value`, () => {
    assert.equal(parse(group(kind, status('Member'), 4503599627370495), kind).groupId, 4503599627370495);
  });
  test(`parser / ${kind} / nested ID cannot shadow a valid top-level numeric ID`, () => {
    for (const nestedId of [7, 7.5, 'nested', '7']) {
      assert.equal(parse({ '@type': kind, is_active: true, nested: { id: nestedId }, id: 51, status: status('Member') }, kind).groupId, 51);
    }
  });
  test(`parser / ${kind} / mismatched object kind is not an access update`, () => {
    assert.equal(parse(group(kind === 'supergroup' ? 'basicGroup' : 'supergroup', status('Member')), kind), undefined);
  });
}

test('all domain registrations contain each of the four group routes exactly once', () => {
  const counts = new Map();
  class Registry extends Map {
    set(name, handler) {
      counts.set(name, (counts.get(name) || 0) + 1);
      return super.set(name, handler);
    }
  }
  const handlers = new Registry();
  for (const register of Object.values(registrations)) register(handlers);
  for (const type of ['updateSupergroup', 'supergroup', 'updateBasicGroup', 'basicGroup']) {
    assert.equal(counts.get(type), 1, `${type} must not be missing or overwritten by another normalizer`);
    assert.equal(typeof handlers.get(type), 'function');
  }
});

for (const [kind, wrapped] of shapes) {
  const label = `${kind} / ${wrapped ? 'update' : 'direct'}`;
  test(`normalizer / ${label} / same DTO factory and typed event`, () => {
    const normalizer = new EventNormalizerImpl();
    const value = group(kind, matrix[2][1]);
    const before = Date.now();
    const event = normalizeOne(normalizer, wrap(kind, value, wrapped));
    assert.equal(event.type, 'groupAccessUpdated');
    assert.ok(event instanceof E.GroupAccessUpdatedEvent);
    assert.ok(event.timestamp >= before && event.timestamp <= Date.now());
    assert.deepEqual(event.access, parse(value, kind));
    assert.deepEqual(values(event.access), ['administrator', true, true, false]);
    assert.equal(normalizer.getStats().droppedUpdates, 0);
    assert.equal(normalizer.getStats().normalizedEvents, 1);
  });
  test(`reducer / ${label} / grant-revoke-membership sequence keeps old snapshots`, () => {
    let state = A.createInitialAppState();
    const snapshots = [];
    for (const [, memberStatus, expected] of matrix) {
      const previous = state;
      state = reduceGroup(state, kind, memberStatus, wrapped);
      assert.notEqual(state, previous);
      assert.notEqual(state.chats[key(kind)], previous.chats[key(kind)]);
      assert.notEqual(state.chats[key(kind)].get(77), previous.chats[key(kind)].get(77), 'real status update changes DTO identity for hydration guards');
      assert.deepEqual(values(state.chats[key(kind)].get(77)), expected);
      assert.equal(state.version, previous.version + 1);
      assert.equal(state.lastEvent.type, 'groupAccessUpdated');
      assert.equal(state.chats.chats.size, 0, 'no chat placeholder is required for group access');
      assert.equal(state.auth, previous.auth, 'unrelated slices retain identity');
      snapshots.push([state, expected]);
    }
    for (const [snapshot, expected] of snapshots) assert.deepEqual(values(snapshot.chats[key(kind)].get(77)), expected);
  });
  for (const [name, memberStatus] of [
    ['missing', undefined], ['null', null], ['empty', {}], ['primitive', 'member'],
    ['unknown variant', { '@type': 'chatMemberStatusFuture' }],
    ['invalid variant', { '@type': 'userStatusOnline' }],
    ['creator missing membership', status('Creator')],
    ['creator invalid membership', status('Creator', { is_member: 'true' })],
    ['restricted missing membership', status('Restricted')]
  ]) {
    test(`normalizer / ${label} / ${name} status cannot erase known access`, () => {
      const state = reduceGroup(A.createInitialAppState(), kind, matrix[2][1]);
      const value = group(kind, memberStatus);
      assert.equal(parse(value, kind), undefined);
      const events = new EventNormalizerImpl().normalize(raw(wrap(kind, value, wrapped)));
      assert.deepEqual(events, []);
      assert.equal(events.reduce(chatsReducer, state), state);
      assert.deepEqual(values(state.chats[key(kind)].get(77)), ['administrator', true, true, false]);
    });
  }
}

for (const kind of ['supergroup', 'basicGroup']) {
  for (const groupFirst of [true, false]) {
    test(`ordering / ${kind} / ${groupFirst ? 'group before newChat' : 'newChat before group'}`, () => {
      let state = A.createInitialAppState();
      const normalizer = new EventNormalizerImpl();
      const chat = { '@type': 'chat', id: -10077, title: 'fixture',
        type: kind === 'supergroup' ? { '@type': 'chatTypeSupergroup', supergroup_id: 77, is_channel: true }
          : { '@type': 'chatTypeBasicGroup', basic_group_id: 77 },
        permissions: { '@type': 'chatPermissions', can_send_basic_messages: false } };
      const newChat = normalizeOne(normalizer, { '@type': 'updateNewChat', chat });
      if (groupFirst) state = reduceGroup(state, kind, status('Member'));
      state = chatsReducer(state, newChat);
      if (!groupFirst) state = reduceGroup(state, kind, status('Member'));
      const before = state;
      for (const payload of [
        { '@type': 'updateChatTitle', chat_id: -10077, title: 'renamed' },
        { '@type': 'updateChatReadInbox', chat_id: -10077, unread_count: 3, last_read_inbox_message_id: '123' },
        { '@type': 'updateChatPosition', chat_id: -10077, position: { '@type': 'chatPosition',
          list: { '@type': 'chatListArchive' }, order: '123', is_pinned: false } },
        chat
      ]) {
        state = chatsReducer(state, normalizeOne(normalizer, payload));
        assert.equal(state.chats[key(kind)].get(77), before.chats[key(kind)].get(77),
          'unrelated chat updates must not invalidate a captured group-status hydration guard');
      }
      assert.deepEqual(values(state.chats[key(kind)].get(77)), ['member', true, false, false]);
      assert.deepEqual(values(before.chats[key(kind)].get(77)), ['member', true, false, false]);
      assert.equal(state.chats.chats.get(-10077).canSendBasicMessages, false, 'R4 preserved');
      assert.equal(state.chats.chats.get(-10077)[kind === 'supergroup' ? 'supergroupId' : 'basicGroupId'], 77);
    });
  }
}

test('event factory payload is copied into state, never retained as a writable state DTO', () => {
  const access = parse(group('supergroup', matrix[2][1]), 'supergroup');
  assert.equal(typeof E.createGroupAccessUpdatedEvent, 'function');
  const event = E.createGroupAccessUpdatedEvent(access);
  const before = A.createInitialAppState();
  const after = chatsReducer(before, event);
  const stored = after.chats.supergroupAccess.get(77);
  assert.notEqual(stored, event.access);
  assert.notEqual(stored, access);
  event.access.canPostMessages = false;
  assert.deepEqual(values(stored), ['administrator', true, true, false]);
  assert.equal(before.chats.supergroupAccess.size, 0);
});
const seeded = () => reduceGroup(reduceGroup(A.createInitialAppState(), 'supergroup', matrix[2][1]), 'basicGroup', status('Banned'));
for (const cloneName of ['cloneChatsState', 'cloneStateForChats']) {
  test(`clone / ${cloneName} / independent maps share immutable DTO identity`, () => {
    const state = seeded();
    const copy = cloneName === 'cloneChatsState' ? clones.cloneChatsState(state.chats) : clones.cloneStateForChats(state).chats;
    for (const kind of ['supergroup', 'basicGroup']) {
      const original = state.chats[key(kind)];
      assert.notEqual(copy[key(kind)], original);
      assert.equal(copy[key(kind)].get(77), original.get(77), 'copying a map is not a status update');
    }
    copy.basicGroupAccess.set(77, parse(group('basicGroup', status('Member')), 'basicGroup'));
    copy.supergroupAccess.delete(77);
    assert.deepEqual(values(state.chats.supergroupAccess.get(77)), ['administrator', true, true, false]);
    assert.deepEqual(values(state.chats.basicGroupAccess.get(77)), ['banned', false, false, false]);
  });
}
test('group update preserves other group identities, including the same id in the other namespace', () => {
  const before = reduceGroup(seeded(), 'supergroup', status('Member'), true, 88);
  const after = reduceGroup(before, 'supergroup', matrix[3][1]);
  assert.notEqual(after.chats.supergroupAccess.get(77), before.chats.supergroupAccess.get(77));
  assert.equal(after.chats.supergroupAccess.get(88), before.chats.supergroupAccess.get(88));
  assert.equal(after.chats.basicGroupAccess.get(77), before.chats.basicGroupAccess.get(77));
});
test('unknown DTO events do not replace known access or increment state version', () => {
  const state = seeded();
  const access = new G.GroupAccessDto();
  access.groupId = 77;
  for (const kind of ['supergroup', 'basicGroup']) {
    access.kind = kind;
    assert.equal(chatsReducer(state, E.createGroupAccessUpdatedEvent(access)), state);
  }
});
test('unrelated event retains the whole state and both access registries', () => {
  const state = seeded();
  assert.equal(chatsReducer(state, E.createMyUserResolvedEvent(9)), state);
});
for (const queued of [false, true]) {
  test(`store / ${queued ? 'queued' : 'synchronous'} reset clears both maps and revokes stale account access`, async () => {
    const store = new AppStore(chatsReducer, seeded(), true);
    const oldState = store.getState();
    const stale = store.createScope();
    const event = normalizeOne(new EventNormalizerImpl(), group('supergroup', status('Member')));
    const pending = stale.dispatch(event);
    const reset = queued ? store.resetStateQueued() : store.resetState();
    await reset;
    await pending;
    await stale.dispatch(event);
    assert.equal(store.getState().chats.supergroupAccess.size, 0);
    assert.equal(store.getState().chats.basicGroupAccess.size, 0);
    assert.equal(stale.getState().chats.supergroupAccess.size, 0);
    assert.equal(stale.getState().chats.basicGroupAccess.size, 0);
    assert.equal(oldState.chats.supergroupAccess.size, 1);
    assert.equal(oldState.chats.basicGroupAccess.size, 1);
    await store.createScope().dispatch(event);
    assert.deepEqual(values(store.getState().chats.supergroupAccess.get(77)), ['member', true, false, false]);
    assert.equal(store.getState().chats.basicGroupAccess.size, 0, 'account A basic group never resurfaces');
  });
}
for (const kind of ['supergroup', 'basicGroup']) {
  test(`store / ${kind} / captured identity accepts refresh after chat update but rejects it after live status`, async () => {
    const store = new AppStore(chatsReducer, seeded(), true);
    const normalizer = new EventNormalizerImpl();
    const captured = store.getState().chats[key(kind)].get(77);
    await store.dispatch(normalizeOne(normalizer, { '@type': 'updateChatTitle', chat_id: -10077, title: 'fixture' }));
    const refresh = normalizeOne(normalizer, group(kind, status('Member')));
    await store.dispatch(refresh, () => store.getState().chats[key(kind)].get(77) === captured);
    assert.deepEqual(values(store.getState().chats[key(kind)].get(77)), ['member', true, false, false]);
    const beforeLive = store.getState().chats[key(kind)].get(77);
    await store.dispatch(normalizeOne(normalizer, wrap(kind, group(kind, status('Banned')), true)));
    const liveState = store.getState();
    await store.dispatch(refresh, () => store.getState().chats[key(kind)].get(77) === beforeLive);
    assert.equal(store.getState(), liveState, 'late refresh is rejected after authoritative live status');
    assert.deepEqual(values(store.getState().chats[key(kind)].get(77)), ['banned', false, false, false]);
  });
}
if (process.argv.includes('--combined')) {
  test('parent integration / actual appReducer routes groupAccessUpdated to chatsReducer', () => {
    const { appReducer } = load('core/reducers/index.ets', { chatsReducer });
    const event = normalizeOne(new EventNormalizerImpl(), group('supergroup', matrix[2][1]));
    const state = appReducer(A.createInitialAppState(), event);
    assert.deepEqual(values(state.chats.supergroupAccess.get(77)), ['administrator', true, true, false]);
  });
}
async function main() {
  let failed = 0;
  for (const { name, run } of tests) {
    const priorErrors = errors.length;
    try {
      await run();
      assert.deepEqual(errors.slice(priorErrors), [], 'no swallowed parser/reducer/store errors');
      console.log(`PASS ${name}`);
    } catch (error) {
      failed++;
      console.log(`FAIL ${name}: ${error.stack}`);
      if (errors.length > priorErrors) console.log('PRODUCTION_ERRORS', JSON.stringify(errors.slice(priorErrors)));
    }
  }
  console.log(JSON.stringify({ passed: tests.length - failed, failed, total: tests.length, combined: process.argv.includes('--combined'), sources }));
  process.exitCode = failed ? 1 : 0;
}
main().catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
