// H5 contract: Devices / active sessions.
// TDLib: session (td_api.tl:8294), getActiveSessions = Sessions (:13755), terminateSession (:13758).
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '..');
const main = path.join(root, 'entry/src/main/ets') + path.sep;
const read = (relative) => fs.readFileSync(main + relative, 'utf8').replaceAll('\r\n', '\n');

function load(relative, deps = {}) {
  const text = read(relative);
  const names = [...text.matchAll(/^export\s+(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)].map((match) => match[1]);
  const code = text.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+/gm, '')
    .replace(/^@ObservedV2\s*\n/gm, '').replace(/^(\s*)@Trace\s+/gm, '$1');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(code, { mode: 'transform' }) + `\nreturn {${names.join(',')}};`)(...Object.values(deps));
}

const hilog = { info() {}, debug() {}, warn() {}, error() {} };
const { TdObject } = load('models/td/common/index.ets');
const C = load('core/model/AppCommand.ets');
const errors = load('core/model/AppError.ets');
const D = load('core/model/dto/SessionDto.ets', { TdObjectType: TdObject });
const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...C, TdObject, hilog });

function sessionJsonRaw(id, overrides = {}) {
  const base = {
    '@type': 'session',
    id: '__ID__',
    is_current: false,
    is_password_pending: false,
    is_unconfirmed: false,
    can_accept_secret_chats: true,
    can_accept_calls: true,
    type: { '@type': 'sessionTypeAndroid' },
    api_id: 2040,
    application_name: 'Telegram',
    application_version: '11.0',
    is_official_application: true,
    device_model: 'Pixel 8',
    platform: 'Android',
    system_version: '15',
    log_in_date: 1700000000,
    last_active_date: 1700000500,
    ip_address: '203.0.113.5',
    country: 'RU',
    region: '',
    ...overrides
  };
  // Keep the id lexeme bare digits: TDLib writes int64 as a JSON number, and TdObject preserves
  // the exact raw lexeme; routing it through JSON.parse would round it to the nearest double.
  return JSON.stringify(base).replace('"__ID__"', id);
}

// DTO parse: exact int64 id, flags, text fields, malformed input rejected --------------------------
{
  const parsed = D.createSessionInfoFromTd(TdObject.fromJSON(sessionJsonRaw('9007199254740993')));
  assert.ok(parsed, 'a session object parses');
  assert.equal(parsed.id, '9007199254740993', 'int64 id must survive the JSON number');
  assert.equal(parsed.isCurrent, false);
  assert.equal(parsed.deviceModel, 'Pixel 8');
  assert.equal(parsed.platform, 'Android');
  assert.equal(parsed.applicationName, 'Telegram');
  assert.equal(parsed.ipAddress, '203.0.113.5');
  assert.equal(parsed.country, 'RU');
  assert.equal(parsed.lastActiveDate, 1700000500);

  const current = D.createSessionInfoFromTd(TdObject.fromJSON(sessionJsonRaw('9007199254740993', {
    is_current: true, is_password_pending: true, device_model: ''
  })));
  assert.equal(current.isCurrent, true);
  assert.equal(current.isPasswordPending, true);
  assert.equal(current.deviceModel, '', 'a missing device model stays empty, the page localizes it');

  assert.equal(D.createSessionInfoFromTd(TdObject.fromJSON('{"@type":"session"}')), undefined,
    'a session without id is rejected');
  assert.equal(D.createSessionInfoFromTd(TdObject.fromJSON('{"@type":"user","id":1}')), undefined);

  const listJson = '{"@type":"sessions","sessions":[' + sessionJsonRaw('9007199254740993') + ',' +
    sessionJsonRaw('42', { is_current: true }) + ',null]}';
  const list = D.createSessionInfoListFromTd(TdObject.fromJSON(listJson));
  assert.deepEqual(list.map((item) => item.id), ['9007199254740993', '42'],
    'null entries and duplicates are skipped, order follows TDLib');
  assert.equal(list[1].isCurrent, true);

  assert.deepEqual(D.createSessionInfoListFromTd(TdObject.fromJSON('{"@type":"ok"}')), [],
    'a non-sessions payload yields nothing');
}

// Commands and serializer: getActiveSessions / terminateSession with an exact int64 -----------------
{
  const get = C.createGetActiveSessionsCommand();
  assert.equal(get.type, 'getActiveSessions');
  const getWire = serializer.serializeCommand(get);
  assert.equal(getWire.method, 'getActiveSessions');
  assert.equal(serializer.buildTdlibRequestJson(getWire.method, getWire.params), '{"@type":"getActiveSessions"}');

  const terminate = C.createTerminateSessionCommand('9007199254740993');
  assert.equal(terminate.type, 'terminateSession');
  const terminateWire = JSON.parse(serializer.buildTdlibRequestJson('terminateSession',
    serializer.serializeCommand(terminate).params));
  assert.equal(terminateWire.session_id, 9007199254740993, 'the int64 session id stays exact on the wire');
}

// Use case: fetch parses the response, terminate validates before the gateway ----------------------
async function checkUseCase() {
  const sent = [];
  let nextResponse = TdObject.fromJSON('{"@type":"sessions","sessions":[' + sessionJsonRaw('9007199254740993') + ']}');
  const gateway = {
    send: (command) => {
      sent.push(command);
      return Promise.resolve(nextResponse);
    }
  };
  const useCase = new (load('domain/usecases/loadSessions.ets', { ...C, ...errors, TdObject, hilog,
    SessionInfoDto: D.SessionInfoDto, createSessionInfoListFromTd: D.createSessionInfoListFromTd })
    .LoadSessionsUseCase)(gateway);

  const sessions = await useCase.fetchSessions();
  assert.equal(sent.length, 1);
  assert.equal(sent[0].type, 'getActiveSessions');
  assert.deepEqual(sessions.map((item) => item.id), ['9007199254740993']);

  await useCase.terminate('42');
  assert.equal(sent.length, 2);
  assert.equal(sent[1].type, 'terminateSession');
  assert.equal(sent[1].payload.sessionId, '42');

  for (const bad of ['0', '-1', 'abc', '', '1.5']) {
    await assert.rejects(() => useCase.terminate(bad), /Invalid sessionId/, 'rejects ' + JSON.stringify(bad));
  }
  assert.equal(sent.length, 2, 'invalid ids never reach the gateway');

  nextResponse = TdObject.fromJSON('{"@type":"ok"}');
  assert.deepEqual(await useCase.fetchSessions(), [], 'an unexpected payload is an empty list, not a crash');
}

// Page, route, settings entry and paintable strings ------------------------------------------------
{
  const page = read('ui/pages/settings/TgSessionsPage.ets');
  assert.match(page, /export function TgSessionsPageBuilder\(\)/);
  assert.match(page, /createLoadSessionsUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(page, /useCase\.fetchSessions\(\)/);
  assert.match(page, /useCase\.terminate\(session\.id\)/);
  assert.match(page, /if \(session\.isCurrent\) \{/, 'the current session cannot be terminated here');
  assert.match(page, /promptAction\.showDialog\(/);
  assert.match(page, /ForEach\(this\.sessions, \(session: SessionInfoDto\)/);
  assert.match(page, /sessions_current/);

  const routeMap = JSON.parse(fs.readFileSync(
    path.join(root, 'entry/src/main/resources/base/profile/route_map.json'), 'utf8'));
  const route = routeMap.routerMap.find((item) => item.name === 'TgSessionsPage');
  assert.ok(route, 'TgSessionsPage is registered');
  assert.equal(route.buildFunction, 'TgSessionsPageBuilder');

  const settings = read('ui/pages/settings/SettingsPage.ets');
  assert.match(settings, /@Event onOpenDevices: \(\) => void/);
  assert.match(settings, /this\.onOpenDevices\(\);/);
  const tabs = read('ui/pages/MainTabsPage.ets');
  assert.match(tabs, /onOpenDevices: \(\): void => \{\n              this\.chatDetailNavStack\.pushPathByName\('TgSessionsPage', undefined\);/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['sessions_loading', 'sessions_load_failed', 'sessions_retry', 'sessions_empty',
      'sessions_current', 'sessions_this_device', 'sessions_unknown_device', 'sessions_terminate',
      'sessions_terminate_title', 'settings_devices']) {
      const item = strings.string.find((entry) => entry.name === name);
      assert.ok(item && item.value.length > 0, name + ' exists in ' + locale);
    }
  }
}

checkUseCase()
  .then(() => {
    console.log('PASS sessions contract');
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
