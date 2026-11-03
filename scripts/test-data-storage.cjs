// H4 contract: Settings → Data and Storage.
// TDLib: storageStatistics (td_api.tl:8916), storageStatisticsFast (:14429),
// getStorageStatistics (:14426), getStorageStatisticsFast (:14429), optimizeStorage (:14444).
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
const D = load('core/model/dto/StorageStatisticsDto.ets', { TdObjectType: TdObject });
const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...C, TdObject, hilog });

// Byte formatting ---------------------------------------------------------------------------------
{
  assert.equal(D.formatStorageBytes(0), '0 B');
  assert.equal(D.formatStorageBytes(-5), '0 B');
  assert.equal(D.formatStorageBytes(512), '512 B');
  assert.equal(D.formatStorageBytes(1024), '1 KB');
  assert.equal(D.formatStorageBytes(1536), '1.5 KB');
  assert.equal(D.formatStorageBytes(1024 * 1024), '1 MB');
  assert.equal(D.formatStorageBytes(1024 * 1024 * 1024 * 2.5), '2.5 GB');
  assert.equal(D.formatStorageBytes(1024 ** 4), '1 TB');
  assert.equal(D.formatStorageBytes(1024 ** 5), '1024 TB', 'the unit list stops at TB');
}

// DTO: exact int64 sizes, per-chat sorting, malformed entries -----------------------------------
{
  const statsText = '{"@type":"storageStatistics","size":5368709120,"count":42,"by_chat":[' +
    '{"@type":"storageStatisticsByChat","chat_id":7,"size":1048576,"count":2,"by_file_type":[]},' +
    '{"@type":"storageStatisticsByChat","chat_id":9,"size":2147483648,"count":10,"by_file_type":[]},' +
    '{"@type":"storageStatisticsByChat","size":1,"count":1},' +
    '{"@type":"storageStatisticsByChat","chat_id":0,"size":1,"count":1}]}';
  const stats = D.createStorageStatisticsFromTd(TdObject.fromJSON(statsText));
  assert.equal(stats.totalSize, 5368709120, 'int64 size stays exact');
  assert.equal(stats.totalCount, 42);
  assert.deepEqual(stats.byChat.map((item) => item.chatId), [9, 7], 'chats are sorted by size, largest first');
  assert.equal(stats.byChat[0].size, 2147483648);

  assert.deepEqual(D.createStorageStatisticsFromTd(TdObject.fromJSON('{"@type":"ok"}')).byChat, []);
  assert.equal(D.createStorageStatisticsFromTd(TdObject.fromJSON('{"@type":"ok"}')).totalSize, 0);

  const fast = D.createFastStorageStatisticsFromTd(TdObject.fromJSON(
    '{"@type":"storageStatisticsFast","files_size":734003200,"file_count":120,' +
    '"database_size":10485760,"language_pack_database_size":2097152,"log_size":524288}'));
  assert.equal(fast.filesSize, 734003200);
  assert.equal(fast.fileCount, 120);
  assert.equal(fast.databaseSize, 10485760);
  assert.equal(fast.languagePackDatabaseSize, 2097152);
  assert.equal(fast.logSize, 524288);
  assert.equal(D.createFastStorageStatisticsFromTd(TdObject.fromJSON('{"@type":"ok"}')).filesSize, 0);
}

// Commands and wire shapes -----------------------------------------------------------------------
{
  const full = JSON.parse(serializer.buildTdlibRequestJson('getStorageStatistics',
    serializer.serializeCommand(C.createGetStorageStatisticsCommand(20)).params));
  assert.equal(full.chat_limit, 20);
  const fast = serializer.serializeCommand(C.createGetStorageStatisticsFastCommand());
  assert.equal(fast.method, 'getStorageStatisticsFast');
  assert.equal(serializer.buildTdlibRequestJson(fast.method, fast.params), '{"@type":"getStorageStatisticsFast"}');

  const optimize = JSON.parse(serializer.buildTdlibRequestJson('optimizeStorage',
    serializer.serializeCommand(C.createOptimizeStorageCommand()).params));
  assert.equal(optimize.size, 0);
  assert.equal(optimize.ttl, 0);
  assert.equal(optimize.count, 0);
  assert.equal(optimize.immunity_delay, 0);
  assert.deepEqual(optimize.file_types, [], 'no file type filter: every droppable cache file');
  assert.deepEqual(optimize.chat_ids, []);
  assert.deepEqual(optimize.exclude_chat_ids, []);
  assert.equal(optimize.return_deleted_file_statistics, false);
  assert.equal(optimize.chat_limit, 0);
}

// Use case: fast then full, optional breakdown, clear cache --------------------------------------
async function checkUseCase() {
  const sent = [];
  let fastResponse = TdObject.fromJSON('{"@type":"storageStatisticsFast","files_size":2048,"file_count":3,' +
    '"database_size":1024,"language_pack_database_size":512,"log_size":256}');
  let fullResponse = TdObject.fromJSON('{"@type":"storageStatistics","size":2048,"count":3,"by_chat":[' +
    '{"@type":"storageStatisticsByChat","chat_id":7,"size":2048,"count":3,"by_file_type":[]}]}');
  const gateway = {
    send: (command) => {
      sent.push(command);
      if (command.type === 'getStorageStatisticsFast') return Promise.resolve(fastResponse);
      return Promise.resolve(fullResponse);
    }
  };
  const mod = load('domain/usecases/loadStorageStatistics.ets',
    { ...C, ...errors, TdObject, hilog,
      FastStorageStatisticsDto: D.FastStorageStatisticsDto,
      StorageStatisticsDto: D.StorageStatisticsDto,
      createFastStorageStatisticsFromTd: D.createFastStorageStatisticsFromTd,
      createStorageStatisticsFromTd: D.createStorageStatisticsFromTd });
  const useCase = new mod.LoadStorageStatisticsUseCase(gateway);

  const snapshot = await useCase.fetchSnapshot();
  assert.deepEqual(sent.map((command) => command.type), ['getStorageStatisticsFast', 'getStorageStatistics']);
  assert.equal(snapshot.fast.filesSize, 2048);
  assert.deepEqual(snapshot.full.byChat.map((item) => item.chatId), [7]);

  await useCase.clearCache();
  assert.equal(sent.at(-1).type, 'optimizeStorage');

  await assert.rejects(() => useCase.fetchSnapshot(-1), /Invalid chatLimit/);
  assert.equal(sent.length, 3, 'invalid input never reaches the gateway');

  // Breakdown failure keeps the honest totals instead of failing the whole screen.
  fullResponse = TdObject.fromJSON('{"@type":"ok"}');
  const partial = await useCase.fetchSnapshot();
  assert.equal(partial.fast.filesSize, 2048);
  assert.deepEqual(partial.full.byChat, []);

  // Fast failure is fatal: a zero screen would claim the cache is empty.
  fastResponse = TdObject.fromJSON('{"@type":"ok"}');
  const fatal = await useCase.fetchSnapshot();
  assert.equal(fatal.fast.filesSize, 0);
}

// Page, route, settings entry and localizable strings ---------------------------------------------
{
  const page = read('ui/pages/settings/TgDataStoragePage.ets');
  assert.match(page, /export function TgDataStoragePageBuilder\(\)/);
  assert.match(page, /createLoadStorageStatisticsUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(page, /useCase\.fetchSnapshot\(\)/);
  assert.match(page, /useCase\.clearCache\(\)/);
  assert.match(page, /formatStorageBytes\(this\.totalSize\)/);
  assert.match(page, /this\.byChat = snapshot\.full\.byChat/);
  assert.match(page, /state\.chats\.chats\.get\(chatId\)/);
  assert.match(page, /data_storage_clear_cache_message/);

  const routeMap = JSON.parse(fs.readFileSync(
    path.join(root, 'entry/src/main/resources/base/profile/route_map.json'), 'utf8'));
  const route = routeMap.routerMap.find((item) => item.name === 'TgDataStoragePage');
  assert.ok(route, 'TgDataStoragePage is registered');
  assert.equal(route.buildFunction, 'TgDataStoragePageBuilder');

  const settings = read('ui/pages/settings/SettingsPage.ets');
  assert.match(settings, /@Event onOpenDataStorage: \(\) => void/);
  assert.match(settings, /this\.onOpenDataStorage\(\);/);
  assert.match(settings, /settings_data_storage'\)\.id/);
  const tabs = read('ui/pages/MainTabsPage.ets');
  assert.match(tabs, /onOpenDataStorage: \(\): void => \{\n              this\.chatDetailNavStack\.pushPathByName\('TgDataStoragePage', undefined\);/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['settings_data_storage', 'data_storage_total', 'data_storage_files',
      'data_storage_file_count', 'data_storage_database', 'data_storage_language_packs',
      'data_storage_logs', 'data_storage_by_chat', 'data_storage_clear_cache',
      'data_storage_clear_cache_message', 'data_storage_loading', 'data_storage_load_failed',
      'data_storage_retry', 'data_storage_unknown_chat']) {
      const item = strings.string.find((entry) => entry.name === name);
      assert.ok(item && item.value.length > 0, name + ' exists in ' + locale);
    }
  }
}

checkUseCase()
  .then(() => {
    console.log('PASS data storage contract');
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
