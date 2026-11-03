// H4 contract: Settings → Data and Storage → Auto-Download.
// TDLib: autoDownloadSettings (td_api.tl:8979), autoDownloadSettingsPresets (:8985),
// getAutoDownloadSettingsPresets (:14462), setAutoDownloadSettings (:14465).
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
const D = load('core/model/dto/AutoDownloadSettingsDto.ets', { TdObjectType: TdObject });
const serializer = load('infra/td/serialization/CommandSerializer.ets', { ...C, TdObject, hilog });

const PRESETS_JSON = '{"@type":"autoDownloadSettingsPresets",' +
  '"low":{"@type":"autoDownloadSettings","is_auto_download_enabled":false,' +
  '"max_photo_file_size":0,"max_video_file_size":0,"max_other_file_size":0,"video_upload_bitrate":0,' +
  '"preload_large_videos":false,"preload_next_audio":false,"preload_stories":false,' +
  '"use_less_data_for_calls":true},' +
  '"medium":{"@type":"autoDownloadSettings","is_auto_download_enabled":true,' +
  '"max_photo_file_size":10485760,"max_video_file_size":1048576,"max_other_file_size":1048576,' +
  '"video_upload_bitrate":2000000,"preload_large_videos":false,"preload_next_audio":true,' +
  '"preload_stories":true,"use_less_data_for_calls":false},' +
  '"high":{"@type":"autoDownloadSettings","is_auto_download_enabled":true,' +
  '"max_photo_file_size":10485760,"max_video_file_size":15728640,"max_other_file_size":3145728,' +
  '"video_upload_bitrate":4000000,"preload_large_videos":true,"preload_next_audio":true,' +
  '"preload_stories":true,"use_less_data_for_calls":false}}';

// DTO: every preset field is read exactly ---------------------------------------------------------
{
  const presets = D.createAutoDownloadPresetsFromTd(TdObject.fromJSON(PRESETS_JSON));
  assert.equal(presets.hasPresets, true);
  assert.equal(presets.low.isAutoDownloadEnabled, false);
  assert.equal(presets.low.useLessDataForCalls, true);
  assert.equal(presets.medium.maxPhotoFileSize, 10485760);
  assert.equal(presets.medium.preloadNextAudio, true);
  assert.equal(presets.high.maxVideoFileSize, 15728640);
  assert.equal(presets.high.preloadLargeVideos, true);
  assert.equal(presets.high.videoUploadBitrate, 4000000);

  assert.equal(D.selectAutoDownloadPreset(presets, 'low').isAutoDownloadEnabled, false);
  assert.equal(D.selectAutoDownloadPreset(presets, 'medium').maxOtherFileSize, 1048576);
  assert.equal(D.selectAutoDownloadPreset(presets, 'high').maxOtherFileSize, 3145728);

  const empty = D.createAutoDownloadPresetsFromTd(TdObject.fromJSON('{"@type":"autoDownloadSettingsPresets"}'));
  assert.equal(empty.hasPresets, false, 'a presets payload without presets is not usable');
  assert.equal(D.createAutoDownloadPresetsFromTd(TdObject.fromJSON('{"@type":"ok"}')).hasPresets, false);
}

// Commands and wire shapes -----------------------------------------------------------------------
{
  const presetsWire = serializer.serializeCommand(C.createGetAutoDownloadSettingsPresetsCommand());
  assert.equal(presetsWire.method, 'getAutoDownloadSettingsPresets');
  assert.equal(serializer.buildTdlibRequestJson(presetsWire.method, presetsWire.params),
    '{"@type":"getAutoDownloadSettingsPresets"}');

  const presets = D.createAutoDownloadPresetsFromTd(TdObject.fromJSON(PRESETS_JSON));
  const high = D.selectAutoDownloadPreset(presets, 'high');
  const payload = new C.SetAutoDownloadSettingsPayload();
  payload.networkType = 'mobileRoaming';
  payload.isAutoDownloadEnabled = high.isAutoDownloadEnabled;
  payload.maxPhotoFileSize = high.maxPhotoFileSize;
  payload.maxVideoFileSize = high.maxVideoFileSize;
  payload.maxOtherFileSize = high.maxOtherFileSize;
  payload.videoUploadBitrate = high.videoUploadBitrate;
  payload.preloadLargeVideos = high.preloadLargeVideos;
  payload.preloadNextAudio = high.preloadNextAudio;
  payload.preloadStories = high.preloadStories;
  payload.useLessDataForCalls = high.useLessDataForCalls;

  const wire = JSON.parse(serializer.buildTdlibRequestJson('setAutoDownloadSettings',
    serializer.serializeCommand(C.createSetAutoDownloadSettingsCommand(payload)).params));
  assert.deepEqual(wire.type, { '@type': 'networkTypeMobileRoaming' });
  assert.equal(wire.settings['@type'], 'autoDownloadSettings');
  assert.equal(wire.settings.is_auto_download_enabled, true);
  assert.equal(wire.settings.max_photo_file_size, 10485760);
  assert.equal(wire.settings.max_video_file_size, 15728640);
  assert.equal(wire.settings.max_other_file_size, 3145728);
  assert.equal(wire.settings.video_upload_bitrate, 4000000);
  assert.equal(wire.settings.preload_large_videos, true);
  assert.equal(wire.settings.preload_next_audio, true);
  assert.equal(wire.settings.preload_stories, true);
  assert.equal(wire.settings.use_less_data_for_calls, false);

  for (const [network, type] of [['mobile', 'networkTypeMobile'], ['wifi', 'networkTypeWiFi'],
    ['other', 'networkTypeOther'], ['none', 'networkTypeNone']]) {
    const raw = JSON.parse(serializer.buildTdlibRequestJson('setAutoDownloadSettings',
      serializer.serializeCommand(C.createSetAutoDownloadSettingsCommand(
        Object.assign(new C.SetAutoDownloadSettingsPayload(), { networkType: network }))).params));
    assert.equal(raw.type['@type'], type, network + ' maps to ' + type);
  }
}

// Use case: presets first, then apply, with visible failures -------------------------------------
async function checkUseCase() {
  const sent = [];
  let response = TdObject.fromJSON(PRESETS_JSON);
  const gateway = {
    send: (command) => {
      sent.push(command);
      if (command.type === 'getAutoDownloadSettingsPresets') return Promise.resolve(response);
      return Promise.resolve(TdObject.fromJSON('{"@type":"ok"}'));
    }
  };
  const useCase = new (load('domain/usecases/loadAutoDownloadSettings.ets',
    { ...C, ...errors, TdObject, hilog,
      AutoDownloadSettingsDto: D.AutoDownloadSettingsDto,
      AutoDownloadPresetsDto: D.AutoDownloadPresetsDto,
      createAutoDownloadPresetsFromTd: D.createAutoDownloadPresetsFromTd,
      selectAutoDownloadPreset: D.selectAutoDownloadPreset }).LoadAutoDownloadSettingsUseCase)(gateway);

  const presets = await useCase.fetchPresets();
  assert.equal(sent.length, 1);
  assert.equal(sent[0].type, 'getAutoDownloadSettingsPresets');
  assert.equal(presets.hasPresets, true);

  await useCase.applyPreset('mobile', presets, 'medium');
  assert.equal(sent.length, 2);
  assert.equal(sent[1].type, 'setAutoDownloadSettings');
  assert.equal(sent[1].payload.networkType, 'mobile');
  assert.equal(sent[1].payload.maxPhotoFileSize, 10485760, 'the applied payload is the chosen preset');
  assert.equal(sent[1].payload.maxVideoFileSize, 1048576);
  assert.equal(sent[1].payload.preloadLargeVideos, false);

  const empty = D.createAutoDownloadPresetsFromTd(TdObject.fromJSON('{"@type":"ok"}'));
  await assert.rejects(() => useCase.applyPreset('wifi', empty, 'high'), /Presets are unavailable/);
  assert.equal(sent.length, 2, 'applying without presets never reaches the gateway');

  response = TdObject.fromJSON('{"@type":"ok"}');
  const failed = await useCase.fetchPresets();
  assert.equal(failed.hasPresets, false, 'an unexpected payload is not usable presets');

  const failing = { send: () => Promise.reject(new Error('native status')) };
  const failingUseCase = new (load('domain/usecases/loadAutoDownloadSettings.ets',
    { ...C, ...errors, TdObject, hilog,
      AutoDownloadSettingsDto: D.AutoDownloadSettingsDto,
      AutoDownloadPresetsDto: D.AutoDownloadPresetsDto,
      createAutoDownloadPresetsFromTd: D.createAutoDownloadPresetsFromTd,
      selectAutoDownloadPreset: D.selectAutoDownloadPreset }).LoadAutoDownloadSettingsUseCase)(failing);
  await assert.rejects(() => failingUseCase.fetchPresets(), /Failed to load auto-download presets/);
  await assert.rejects(() => failingUseCase.applyPreset('wifi', presets, 'low'),
    /Failed to apply auto-download settings/);
}

// Page, route, storage entry and localizable strings ----------------------------------------------
{
  const page = read('ui/pages/settings/TgAutoDownloadPage.ets');
  assert.match(page, /export function TgAutoDownloadPageBuilder\(\)/);
  assert.match(page, /createLoadAutoDownloadSettingsUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(page, /useCase\.fetchPresets\(\)/);
  assert.match(page, /useCase\.applyPreset\(network, this\.presets, level\)/);
  assert.match(page, /buildNetworkSection\(localized\(\$r\('app\.string\.auto_download_mobile'\)/);
  assert.match(page, /'mobileRoaming'/);
  assert.match(page, /auto_download_note/);

  const routeMap = JSON.parse(fs.readFileSync(
    path.join(root, 'entry/src/main/resources/base/profile/route_map.json'), 'utf8'));
  const route = routeMap.routerMap.find((item) => item.name === 'TgAutoDownloadPage');
  assert.ok(route, 'TgAutoDownloadPage is registered');
  assert.equal(route.buildFunction, 'TgAutoDownloadPageBuilder');

  const storage = read('ui/pages/settings/TgDataStoragePage.ets');
  assert.match(storage, /data_storage_auto_download/);
  assert.match(storage, /pushPathByName\('TgAutoDownloadPage', undefined\)/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, 'entry/src/main/resources', locale, 'element/string.json'), 'utf8'));
    for (const name of ['data_storage_auto_download', 'auto_download_mobile', 'auto_download_roaming',
      'auto_download_wifi', 'auto_download_low', 'auto_download_medium', 'auto_download_high',
      'auto_download_applied', 'auto_download_disabled', 'auto_download_photo_limit',
      'auto_download_video_limit', 'auto_download_loading', 'auto_download_load_failed',
      'auto_download_retry', 'auto_download_note']) {
      const item = strings.string.find((entry) => entry.name === name);
      assert.ok(item && item.value.length > 0, name + ' exists in ' + locale);
    }
  }
}

checkUseCase()
  .then(() => {
    console.log('PASS auto-download contract');
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
