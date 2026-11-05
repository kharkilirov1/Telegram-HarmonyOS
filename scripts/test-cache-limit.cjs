// H4 contract: "Maximum cache size" limit on the Data and Storage screen.
// TDLib: optimizeStorage (td_api.tl:14444) with size/ttl/count; -1 keeps a TDLib default.
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
const S = load('core/model/dto/StorageStatisticsDto.ets', { TdObjectType: TdObject, TdObject, hilog });
const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...C, TdObject, hilog });
const storage = load('domain/usecases/loadStorageStatistics.ets',
  { ...C, ...errors, hilog, TdObject, ...S });

async function mainCheck() {
  // Clear-cache keeps the old zeroed request.
  const clearWire = JSON.parse(serializer.buildTdlibRequestJson('optimizeStorage',
    serializer.serializeCommand(C.createOptimizeStorageCommand()).params));
  assert.equal(clearWire.size, 0);
  assert.equal(clearWire.ttl, 0);
  assert.equal(clearWire.count, 0);

  // Limit request carries the byte limit and TDLib defaults for the other limits.
  const payload = new C.OptimizeStoragePayload();
  payload.size = 1024 * 1024 * 1024;
  payload.ttl = -1;
  payload.count = -1;
  payload.immunityDelay = -1;
  const limitWire = JSON.parse(serializer.buildTdlibRequestJson('optimizeStorage',
    serializer.serializeCommand(C.createOptimizeStorageCommand(payload)).params));
  assert.equal(limitWire.size, 1073741824);
  assert.equal(limitWire.ttl, -1);
  assert.equal(limitWire.count, -1);
  assert.equal(limitWire.immunity_delay, -1);
  assert.deepEqual(limitWire.file_types, []);
  assert.deepEqual(limitWire.chat_ids, []);
  assert.equal(limitWire.return_deleted_file_statistics, false);

  const sent = [];
  const gateway = {
    send: (command) => {
      sent.push(command);
      return Promise.resolve(TdObject.fromJSON('{"@type":"storageStatistics","size":"0","count":0,' +
        '"by_chat":[]}'));
    }
  };
  const useCase = new storage.LoadStorageStatisticsUseCase(gateway);

  assert.equal(await useCase.enforceCacheLimit(0), false, 'unlimited sends nothing');
  assert.equal(sent.length, 0);
  assert.equal(await useCase.enforceCacheLimit(536870912), true);
  assert.equal(sent.at(-1).type, 'optimizeStorage');
  assert.equal(sent.at(-1).payload.size, 536870912);
  assert.equal(sent.at(-1).payload.ttl, -1);
  await assert.rejects(() => useCase.enforceCacheLimit(-1), /Invalid cache limit/);
  await assert.rejects(() => useCase.enforceCacheLimit(1.5), /Invalid cache limit/);
  assert.equal(sent.length, 1, 'invalid limits never reach the gateway');
  await assert.rejects(() => new storage.LoadStorageStatisticsUseCase(
    { send: () => Promise.reject(new Error('native status')) }).enforceCacheLimit(1024),
    /Failed to apply the cache limit/);

  // Formatting used in the row/menu labels.
  assert.equal(S.formatStorageBytes(256 * 1024 * 1024), '256 MB');
  assert.equal(S.formatStorageBytes(1024 * 1024 * 1024), '1 GB');
  assert.equal(S.formatStorageBytes(0), '0 B');

  const autoSent = [];
  const autoUseCase = new storage.LoadStorageStatisticsUseCase({ send: (command) => {
    autoSent.push(command);
    return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}'));
  } });
  assert.equal(await autoUseCase.autoEnforce(2048, 1024), false);
  assert.equal(autoSent.length, 0, 'usage below the limit sends nothing');
  assert.equal(await autoUseCase.autoEnforce(2048, 4096), true);
  assert.equal(autoSent.length, 1);
  assert.equal(autoSent.at(-1).type, 'optimizeStorage');
  const autoWire = JSON.parse(serializer.buildTdlibRequestJson('optimizeStorage',
    serializer.serializeCommand(autoSent.at(-1)).params));
  assert.equal(autoWire.size, 2048, 'the limit is the size TDLib keeps');
  assert.equal(autoWire.ttl, -1, 'an unset TTL stays -1: only the size bound applies');
  assert.equal(autoWire.count, -1);
}

mainCheck().then(() => {
  // Auto-enforcement: only a positive limit that the usage actually exceeds triggers a request.
assert.equal(storage.shouldAutoEnforce(1024, 2048), true);
assert.equal(storage.shouldAutoEnforce(1024, 1024), false, 'equal usage is within the limit');
assert.equal(storage.shouldAutoEnforce(1024, 512), false);
assert.equal(storage.shouldAutoEnforce(0, 4096), false, 'no limit means no enforcement');
assert.equal(storage.shouldAutoEnforce(-1, 4096), false);
assert.equal(storage.shouldAutoEnforce(1024, -5), false);

// H4c: the segmented chart scales to the limit when one is set, otherwise to the total.
const segMod = load('core/model/StorageUsageSegment.ets');
assert.equal(segMod.storageChartScale(4096, 1024), 1024, 'a limit wins over the total');
assert.equal(segMod.storageChartScale(4096, 0), 4096);
assert.equal(segMod.storageChartScale(0, 0), 0);
assert.equal(segMod.storageSegmentPercent(512, 1024), 50);
assert.equal(segMod.storageSegmentPercent(2048, 1024), 100, 'a segment never exceeds the bar');
assert.equal(segMod.storageSegmentPercent(0, 1024), 0);
assert.equal(segMod.storageSegmentPercent(-5, 1024), 0);
assert.equal(segMod.storageSegmentPercent(512, 0), 0);
const segment = new segMod.StorageUsageSegment('Media', 512, 0);
assert.equal(segment.label, 'Media');
assert.equal(segment.bytes, 512);

const page = read('ui/pages/settings/TgDataStoragePage.ets');
  assert.match(page, /@Local private cacheLimitBytes: number = 0;/);
  assert.match(page, /preferences\.getPreferencesSync\(context, \{ name: 'storage_settings' \}\)/);
  assert.match(page, /getSync\('max_cache_bytes', 0\)/);
  assert.match(page, /putSync\('max_cache_bytes', limitBytes\)/);
  assert.match(page, /private selectCacheLimit\(\): void \{/);
  assert.match(page, /256 \* 1024 \* 1024/);
  assert.match(page, /private applyCacheLimit\(limitBytes: number\): void \{/);
  assert.match(page, /useCase\.enforceCacheLimit\(limitBytes\)/);
  assert.match(page, /data_storage_max_cache/);
  assert.match(page, /data_storage_unlimited/);
  assert.match(page, /data_storage_cache_limit_applied/);
// H4 remainder: the usage chart and the automatic enforcement hook.
assert.match(page, /private buildUsageBar\(\) \{/);
assert.match(page, /private usageFillRatio\(\): number \{/);
assert.match(page, /private usageCaption\(\): string \{/);
assert.match(page, /useCase\.autoEnforce\(this\.cacheLimitBytes, this\.totalSize\)/);
assert.match(page, /this\.autoEnforceAttempted/);
assert.match(page, /data_storage_limit_enforced/);
assert.match(page, /this\.buildUsageBar\(\)/);
// H4c: the flat bar is replaced by the segmented chart component.
assert.match(page, /private usageSegments\(\): StorageUsageSegment\[\] \{/);
assert.match(page, /new StorageUsageSegment\(localized\(\$r\('app\.string\.data_storage_files'\)\.id, 'Media files'\)/);
assert.match(page, /scaleBytes: storageChartScale\(this\.totalSize, this\.cacheLimitBytes\)/);
assert.match(page, /TgStorageUsageChart\(\{/);
const chart = read('ui/tg_ui/molecules/TgStorageUsageChart.ets');
assert.match(chart, /export struct TgStorageUsageChart/);
assert.match(chart, /@Param segments: StorageUsageSegment\[\] = \[\];/);
assert.match(chart, /@Param scaleBytes: number = 0;/);
assert.match(chart, /storageSegmentPercent\(segment\.bytes, this\.scaleBytes\)/);
assert.match(chart, /STORAGE_CHART_MEDIA/);
assert.match(chart, /private revealedPercent\(segment: StorageUsageSegment\): number \{/);
assert.match(chart, /\.width\(this\.revealedPercent\(segment\)\.toString\(\) \+ '%'\)/,
  'the segment width is the measured share scaled by the reveal');
assert.match(chart, /revealProgress/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
    for (const [name, expected] of [['data_storage_max_cache', /./], ['data_storage_unlimited', /./],
      ['data_storage_cache_limit_applied', /./]]) {
      const item = strings.string.find((entry) => entry.name === name);
      assert.ok(item && expected.test(item.value), name + ' exists in ' + locale);
    }
  }
  console.log('PASS cache limit contract');
}).catch((error) => {
  console.error(error);
  process.exit(1);
});
