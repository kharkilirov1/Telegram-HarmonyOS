// D20 contract: chat auto-delete timer (getChat → message_auto_delete_time, setChatMessageAutoDeleteTime),
// the presets screen, the Manage entry and the Chat → DTO plumbing.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(root);

async function main() {
  const hilog = { info() {}, warn() {}, error() {}, debug() {} };
  const { TdObject } = load('models/td/common/index.ets', ['TdObject']);
  const C = load('core/model/AppCommand.ets',
    ['createGetChatCommand', 'createSetChatMessageAutoDeleteTimeCommand',
      'SetChatMessageAutoDeleteTimePayload', 'AppCommand']);
  const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
  const serializer = load('infra/td/serialization/CommandSerializer.ets',
    ['serializeCommand', 'buildTdlibRequestJson'], { ...C, TdObject, hilog });
  const U = load('domain/usecases/chatAutoDelete.ets',
    ['ChatAutoDeleteUseCase', 'createChatAutoDeleteUseCase', 'isValidAutoDeleteSeconds',
      'AUTO_DELETE_PRESETS', 'MAX_AUTO_DELETE_SECONDS'],
    { ...C, ...errors, hilog, TdObject });

  // Presets and validation -------------------------------------------------------------------------
  assert.deepEqual(U.AUTO_DELETE_PRESETS, [0, 3600, 86400, 7 * 86400, 30 * 86400]);
  assert.equal(U.isValidAutoDeleteSeconds(0), true);
  assert.equal(U.isValidAutoDeleteSeconds(3600), true);
  assert.equal(U.isValidAutoDeleteSeconds(-1), false);
  assert.equal(U.isValidAutoDeleteSeconds(1.5), false);
  assert.equal(U.isValidAutoDeleteSeconds(U.MAX_AUTO_DELETE_SECONDS + 1), false);

  // Load and save through the gateway ---------------------------------------------------------------
  const sent = [];
  const useCase = new U.ChatAutoDeleteUseCase({
    send: (command) => {
      sent.push(command);
      if (command.type === 'getChat') {
        return Promise.resolve(TdObject.fromJSON(
          '{"@type":"chat","id":42,"title":"Group","message_auto_delete_time":86400}'));
      }
      return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}'));
    }
  });
  assert.equal(await useCase.load(42), 86400);
  assert.equal(sent.at(-1).type, 'getChat');

  await useCase.set(42, 7 * 86400);
  assert.equal(sent.at(-1).type, 'setChatMessageAutoDeleteTime');
  assert.equal(sent.at(-1).payload.chatId, 42);
  assert.equal(sent.at(-1).payload.seconds, 7 * 86400);
  const wire = JSON.parse(serializer.buildTdlibRequestJson('setChatMessageAutoDeleteTime',
    serializer.serializeCommand(sent.at(-1)).params));
  assert.equal(wire.chat_id, 42);
  assert.equal(wire.message_auto_delete_time, 7 * 86400);

  const sentBefore = sent.length;
  await assert.rejects(() => useCase.load(0), /Invalid chatId/);
  await assert.rejects(() => useCase.set(-1, 3600), /Invalid chatId/);
  await assert.rejects(() => useCase.set(42, -3600), /Invalid auto-delete time/);
  await assert.rejects(() => useCase.set(42, 1.5), /Invalid auto-delete time/);
  assert.equal(sent.length, sentBefore, 'invalid input never reaches the gateway');
  await assert.rejects(() => new U.ChatAutoDeleteUseCase(
    { send: () => Promise.reject(new Error('native status')) }).load(42),
    /Failed to load auto-delete timer/);
  await assert.rejects(() => new U.ChatAutoDeleteUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')) }).load(42),
    /Unsupported chat response/);
  await assert.rejects(() => new U.ChatAutoDeleteUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"chat","id":1}')) }).load(42),
    /Chat has no auto-delete timer/);
  await assert.rejects(() => new U.ChatAutoDeleteUseCase(
    { send: () => Promise.reject(new Error('native status')) }).set(42, 0),
    /Failed to save auto-delete timer/);

  // Model plumbing ---------------------------------------------------------------------------------
  const model = read('core/model/AppState.ets');
  assert.match(model, /messageAutoDeleteTime: number = 0;/);
  const dto = read('core/model/dto/ChatDto.ets');
  assert.match(dto, /messageAutoDeleteTime: number = 0;/);
  assert.match(dto, /getTopLevelNumberStrict\('message_auto_delete_time'\)/);
  const reducer = read('core/reducers/chatsReducer.ets');
  assert.match(reducer, /chat\.messageAutoDeleteTime = dto\.messageAutoDeleteTime;/);

  // Screen, route, submenu and labels --------------------------------------------------------------
  const screen = read('ui/pages/chat/TgChatAutoDeletePage.ets');
  assert.match(screen, /export function TgChatAutoDeletePageBuilder\(\)/);
  assert.match(screen, /createChatAutoDeleteUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(screen, /useCase\.load\(this\.chatId\)/);
  assert.match(screen, /useCase\.set\(this\.chatId, seconds\)/);
  assert.match(screen, /ForEach\(AUTO_DELETE_PRESETS/);
  assert.match(screen, /this\.currentSeconds = previous;/, 'a rejected write restores the value');

  const routes = JSON.parse(fs.readFileSync(
    path.join(root, '../resources/base/profile/route_map.json'), 'utf8'));
  const route = routes.routerMap.find((item) => item.name === 'TgChatAutoDeletePage');
  assert.ok(route, 'TgChatAutoDeletePage is registered');
  assert.equal(route.buildFunction, 'TgChatAutoDeletePageBuilder');

  const actions = read('ui/pages/chat/ChatActionsCoordinator.ets');
  assert.match(actions, /ChatMenuAction\.Permissions, ChatMenuAction\.AutoDelete,\n      ChatMenuAction\.Scheduled\];/);
  assert.match(actions,
    /text: localized\(\$r\('app\.string\.chat_actions_auto_delete'\)\.id, 'Auto-Delete'\), color: normal \};/);
  assert.match(actions, /this\.host\.openAutoDelete\(chatId\)/);
  assert.match(actions, /openAutoDelete\(chatId: number\): void \{/);
  const nav = read('ui/pages/chat/chatAdminNavigation.ets');
  assert.match(nav, /openAutoDeleteScreen/);
  assert.match(nav, /pushPathByName\('TgChatAutoDeletePage', new ChatAutoDeleteRouteParams\(chatId\)\)/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, '../resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['chat_actions_auto_delete', 'auto_delete_title', 'auto_delete_current',
      'auto_delete_off', 'auto_delete_1h', 'auto_delete_1d', 'auto_delete_1w', 'auto_delete_1m',
      'auto_delete_loading', 'auto_delete_failed', 'auto_delete_save_failed']) {
      assert.ok(strings.string.some((entry) => entry.name === name), name + ' exists in ' + locale);
    }
  }

  console.log('PASS chat auto-delete contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
