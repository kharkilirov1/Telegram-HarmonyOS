// H5 contract: Devices / active sessions.
// TDLib: session (td_api.tl:8294), getActiveSessions = Sessions (:13755), terminateSession (:13758).
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '..');
const main = path.join(root, 'entry/src/main/ets') + path.sep;
const read = (relative) => fs.readFileSync(main + relative, 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(main);

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
  assert.equal(parsed.sessionType, 'sessionTypeAndroid', 'the session type is kept for sectioning');

  const current = D.createSessionInfoFromTd(TdObject.fromJSON(sessionJsonRaw('9007199254740993', {
    is_current: true, is_password_pending: true, device_model: ''
  })));
  assert.equal(current.isCurrent, true);
  assert.equal(current.isPasswordPending, true);
  assert.equal(current.deviceModel, '', 'a missing device model stays empty, the page localizes it');

  assert.equal(D.createSessionInfoFromTd(TdObject.fromJSON('{"@type":"session"}')), undefined,
    'a session without id is rejected');
  assert.equal(D.createSessionInfoFromTd(TdObject.fromJSON('{"@type":"user","id":1}')), undefined);
  const noTypeJson = '{"@type":"session","id":7,"is_current":false,' +
    '"is_password_pending":false,"is_unconfirmed":false,"can_accept_secret_chats":false,' +
    '"can_accept_calls":false,"application_name":"A","application_version":"1",' +
    '"is_official_application":false,"device_model":"M","platform":"P",' +
    '"system_version":"S","ip_address":"1.2.3.4","country":"DE","last_active_date":5}';
  const noType = D.createSessionInfoFromTd(TdObject.fromJSON(noTypeJson));
  assert.equal(noType.sessionType, '', 'a missing type is unknown, not a guessed browser');

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

  const all = C.createTerminateAllOtherSessionsCommand();
  assert.equal(all.type, 'terminateAllOtherSessions');
  const allWire = serializer.serializeCommand(all);
  assert.equal(allWire.method, 'terminateAllOtherSessions');
  assert.equal(serializer.buildTdlibRequestJson(allWire.method, allWire.params),
    '{"@type":"terminateAllOtherSessions"}');
}

// Session sections: browser logins versus app sessions -------------------------------------------
{
  const S = load('domain/selectors/sessionSelectors.ets');
  for (const type of ['sessionTypeChrome', 'sessionTypeSafari', 'sessionTypeFirefox', 'sessionTypeOpera',
    'sessionTypeEdge', 'sessionTypeBrave', 'sessionTypeVivaldi']) {
    assert.equal(S.isWebSession(type), true, type + ' is a web session');
  }
  for (const type of ['sessionTypeAndroid', 'sessionTypeIphone', 'sessionTypeIpad', 'sessionTypeMac',
    'sessionTypeWindows', 'sessionTypeLinux', 'sessionTypeUbuntu', 'sessionTypeUnknown', '']) {
    assert.equal(S.isWebSession(type), false, type + ' is not a web session');
  }

  const make = (id, type, current) => Object.assign(new D.SessionInfoDto(),
    { id: id, sessionType: type, isCurrent: current });
  const sessions = [
    make('1', 'sessionTypeIphone', true),
    make('2', 'sessionTypeChrome', false),
    make('3', 'sessionTypeAndroid', false),
    make('4', 'sessionTypeSafari', false)
  ];
  const sections = S.splitSessionsByKind(sessions);
  assert.deepEqual(sections.active.map((item) => item.id), ['1', '3'], 'app sessions keep TDLib order');
  assert.deepEqual(sections.web.map((item) => item.id), ['2', '4'], 'browser sessions keep TDLib order');

  assert.equal(S.canTerminateOthers(sessions), true);
  assert.equal(S.canTerminateOthers([make('1', 'sessionTypeIphone', true)]), false,
    'nothing to terminate when this is the only session');
  assert.equal(S.canTerminateOthers([]), false);
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

  await useCase.terminateAllOthers();
  assert.equal(sent.length, 3);
  assert.equal(sent[2].type, 'terminateAllOtherSessions');

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
  assert.match(page, /ForEach\(list, \(session: SessionInfoDto\) => \{/);
  assert.match(page, /sessions_current/);
  assert.match(page, /splitSessionsByKind\(sessions\)/);
  assert.match(page, /sessions_active_title/);
  assert.match(page, /sessions_web_title/);
  assert.match(page, /canTerminateOthers\(this\.sessions\)/);
  assert.match(page, /sessions_terminate_all/);
  assert.match(page, /useCase\.terminateAllOthers\(\)/);
  assert.match(page, /private confirmTerminateAll\(\): void \{/);

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
      'sessions_terminate_title', 'sessions_active_title', 'sessions_web_title',
      'sessions_terminate_all', 'sessions_terminate_all_title', 'settings_devices']) {
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
