// D25: sending the current location — point validation, the location message serialization, the use case and
// the attachment-tile wiring.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');
const readResource = (relative) =>
  fs.readFileSync(path.join(root, '..', 'resources', relative), 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(root);

async function main() {
  // Command ----------------------------------------------------------------------------------------
  const C = load('core/model/AppCommand.ets',
    ['SendLocationCommand', 'SendLocationPayload', 'createSendLocationCommand'], {});
  const command = C.createSendLocationCommand(42, 55.75, 37.62, 25);
  assert.ok(command instanceof C.SendLocationCommand);
  assert.equal(command.type, 'sendLocation');
  assert.equal(command.payload.chatId, 42);
  assert.equal(command.payload.latitude, 55.75);
  assert.equal(command.payload.longitude, 37.62);
  assert.equal(command.payload.horizontalAccuracy, 25);
  assert.equal(C.createSendLocationCommand(42, 1, 2).payload.horizontalAccuracy, 0);
  assert.equal(new C.SendLocationPayload().chatId, 0);
  const commandSource = read('core/model/AppCommand.ets');
  assert.match(commandSource, /\| SendLocationCommand/, 'the command belongs to AnyAppCommand');

  // Serialization ----------------------------------------------------------------------------------
  const serializer = read('infra/td/serialization/CommandSerializer.ets');
  assert.match(serializer, /COMMAND_SERIALIZATION_HANDLERS\.set\('sendLocation', serializeSendLocation\);/);
  assert.match(serializer, /"@type":"inputMessageLocation"/);
  assert.match(serializer, /"live_period":0/);

  // Point validation -------------------------------------------------------------------------------
  const hilog = { info() {} };
  class TdObjectFixture {}
  const U = load('domain/usecases/sendLocation.ets',
    ['SendLocationUseCase', 'createSendLocationUseCase', 'isValidLocationPoint'], {
      createSendLocationCommand: (chatId, latitude, longitude, accuracy) =>
        ({ type: 'sendLocation', payload: { chatId, latitude, longitude, horizontalAccuracy: accuracy } }),
      TdObject: TdObjectFixture,
      hilog
    });
  assert.equal(U.isValidLocationPoint(55.75, 37.62), true);
  assert.equal(U.isValidLocationPoint(-33.9, 151.2), true);
  assert.equal(U.isValidLocationPoint(90, 180), true);
  assert.equal(U.isValidLocationPoint(91, 0), false, 'latitude beyond the pole');
  assert.equal(U.isValidLocationPoint(0, 181), false, 'longitude beyond the meridian');
  assert.equal(U.isValidLocationPoint(0, 0), false, 'null island is a broken reading');
  assert.equal(U.isValidLocationPoint(Number.NaN, 10), false);
  assert.equal(U.isValidLocationPoint(10, Number.POSITIVE_INFINITY), false);

  // Use case against a gateway double ---------------------------------------------------------------
  const sent = [];
  let fail = false;
  const gateway = {
    async send(cmd) {
      sent.push(cmd);
      if (fail) throw new Error('network');
      return new TdObjectFixture();
    }
  };
  const useCase = new U.SendLocationUseCase(gateway);
  assert.equal(await useCase.execute(0, 55.75, 37.62), false, 'no chat means no send');
  assert.equal(await useCase.execute(7, 0, 0), false, 'an invalid point never reaches the gateway');
  assert.equal(sent.length, 0);
  assert.equal(await useCase.execute(7, 55.75, 37.62), true);
  assert.equal(sent[0].payload.latitude, 55.75);
  assert.equal(sent[0].payload.horizontalAccuracy, 0, 'missing accuracy stays zero');
  assert.equal(await useCase.execute(7, 10, 20, -5), true);
  assert.equal(sent[1].payload.horizontalAccuracy, 0, 'a negative accuracy is dropped');
  assert.equal(await useCase.execute(7, 10, 20, 12.5), true);
  assert.equal(sent[2].payload.horizontalAccuracy, 12.5);
  fail = true;
  assert.equal(await useCase.execute(7, 10, 20), false);

  // Device wrapper ---------------------------------------------------------------------------------
  const device = read('infra/location/DeviceLocation.ets');
  assert.match(device, /export const LOCATION_PERMISSIONS: Permissions\[\] = \[/);
  assert.match(device, /'ohos\.permission\.APPROXIMATELY_LOCATION'/);
  assert.match(device, /'ohos\.permission\.LOCATION'/);
  assert.match(device, /export async function getDeviceLocationOnce\(\): Promise<DeviceLocationPoint \| undefined> \{/);
  assert.match(device, /geoLocationManager\.getCurrentLocation\(request\)/);
  assert.match(device, /return undefined;/);

  // Composer wiring --------------------------------------------------------------------------------
  const controller = read('ui/pages/chat/ChatComposerController.ets');
  assert.match(controller, /async sendCurrentLocation\(host: ChatComposerControllerHost\): Promise<void> \{/);
  assert.match(controller, /requestPermissionsFromUser\(context, LOCATION_PERMISSIONS\)/);
  assert.match(controller, /const point: DeviceLocationPoint \| undefined = await getDeviceLocationOnce\(\);/);
  assert.match(controller, /this\.locationRequestInFlight = true;/);
  assert.match(controller, /createSendLocationUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(controller, /composer_location_denied/);
  assert.match(controller, /composer_location_unavailable/);
  assert.match(controller, /composer_location_failed/);
  assert.match(controller, /      case 3:\n        this\.sendCurrentLocation\(host\);\n        break;/);

  const dock = read('ui/pages/chat/TgChatComposerDock.ets');
  assert.match(dock, /this\.bindings\.composerAllows\('document'\), true, false, true/,
    'the location tile (index 3) is enabled');

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(readResource(`${locale}/element/string.json`)).string;
    for (const name of ['composer_location_denied', 'composer_location_unavailable', 'composer_location_failed']) {
      assert.ok(strings.find((item) => item.name === name), `${locale} ships ${name}`);
    }
  }

  console.log('PASS location send contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
