// Test-only SDK projection: compile Hypium callbacks and their mounted fixtures
// together in the main Resource namespace. Never modifies the source checkout.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const files = root => fs.readdirSync(root, { withFileTypes: true }).flatMap(e =>
  e.isDirectory() ? files(path.join(root, e.name)) : [path.join(root, e.name)]);
function projectWitness(source, project, receiptPath) {
  source = fs.realpathSync(source); project = fs.realpathSync(project);
  const nested = (a, b) => a === b || b.startsWith(a + path.sep);
  assert(!nested(source, project) && !nested(project, source), 'Projection requires separate source and SDK directories');
  assert(!fs.existsSync(path.join(project, '.git')), 'SDK projection must not be a git checkout');
  const read = (root, p) => fs.readFileSync(path.join(root, p));
  const app = JSON.parse(read(project, 'AppScope/app.json5')).app;
  assert(/^com\.telegram\.harmonyos\.(slowmode|nativevalidation)[0-9]{8}$/.test(app.bundleName), 'Requires isolated verification bundle');
  const config = read(project, 'entry/src/main/ets/services/ConfigLocal.ets').toString();
  assert(/TELEGRAM_API_ID:\s*number\s*=\s*0\s*;/.test(config) && /TELEGRAM_API_HASH:\s*string\s*=\s*["']["']\s*;/.test(config), 'Requires dummy API credentials');
  const main = 'entry/src/main';
  for (const file of files(path.join(source, main))) {
    const rel = path.relative(source, file).split(path.sep).join('/');
    if (rel === main + '/module.json5' || rel === main + '/resources/base/profile/main_pages.json' || rel === main + '/ets/services/ConfigLocal.ets') continue;
    assert(read(project, rel).equals(read(source, rel)), 'Production drift: ' + rel);
  }
  const abilityPath = 'entry/src/ohosTest/ets/testability/TestAbility.ets';
  const pagePath = 'entry/src/ohosTest/ets/testability/pages/Index.ets';
  const ability = read(source, abilityPath).toString();
  const page = read(source, pagePath).toString();
  assert(ability.includes('export default class TestAbility extends UIAbility') && ability.includes('Hypium.hypiumTest(abilityDelegator, abilityDelegatorArguments, testsuite)'), 'Missing strict Hypium bootstrap');
  assert(ability.includes("from '../test/List.test'") && ability.includes("loadContent('testability/pages/Index'"), 'Unexpected TestAbility paths');
  const generatedAbility = ability.replace("from '../test/List.test'", "from '../../../ohosTest/ets/test/List.test'")
    .replace("from '../../../main/ets/core/model/UIStateModels'", "from '../core/model/UIStateModels'")
    .replace("from './components/SlowmodeFixture'", "from '../../../ohosTest/ets/testability/components/SlowmodeFixture'")
    .replace("loadContent('testability/pages/Index'", "loadContent('pages/NativeValidationFixture'");
  const generatedPage = page.replaceAll("from '../../../../main/ets/", "from '../")
    .replace("from '../ChatScreenDecompositionFixture'", "from '../../../ohosTest/ets/testability/ChatScreenDecompositionFixture'")
    .replaceAll("from '../components/", "from '../../../ohosTest/ets/testability/components/");
  assert(!generatedPage.includes("../../../../main/ets/"), 'Unrelocated main-source import in witness page');
  assert(!generatedAbility.includes('AppCoreRuntime') && !generatedAbility.includes("loadContent('ui/pages/login"), 'Test ability must not bootstrap an account');
  const module = JSON.parse(read(source, main + '/module.json5'));
  assert(!module.module.abilities.some(a => a.name === 'TestAbility'), 'Source already contains validation ability');
  module.module.abilities.push({ name: 'TestAbility', srcEntry: './ets/entryability/NativeValidationAbility.ets',
    description: '$string:ability_desc', icon: '$media:app_layered_image', label: '$string:ability_label',
    startWindowIcon: '$media:app_icon_transparent', startWindowBackground: '$color:start_window_background', exported: false });
  const pages = JSON.parse(read(source, main + '/resources/base/profile/main_pages.json'));
  pages.src.push('pages/NativeValidationFixture');
  const updates = new Map();
  for (const file of files(path.join(source, 'entry/src/ohosTest'))) {
    const rel = path.relative(source, file).split(path.sep).join('/'); updates.set(rel, fs.readFileSync(file));
  }
  updates.set(main + '/ets/entryability/NativeValidationAbility.ets', Buffer.from(generatedAbility));
  updates.set(main + '/ets/pages/NativeValidationFixture.ets', Buffer.from(generatedPage));
  updates.set(main + '/module.json5', Buffer.from(JSON.stringify(module, null, 2) + '\n'));
  updates.set(main + '/resources/base/profile/main_pages.json', Buffer.from(JSON.stringify(pages, null, 2) + '\n'));
  assert(!fs.existsSync(receiptPath), 'Refuse to overwrite projection receipt');
  const beforeDir = receiptPath + '.before'; assert(!fs.existsSync(beforeDir), 'Refuse to overwrite before-images');
  const plan = [...updates].map(([rel, bytes]) => { const target = path.join(project, rel);
    return { rel, bytes, before: fs.existsSync(target) ? fs.readFileSync(target) : null }; });
  fs.mkdirSync(beforeDir, { recursive: true });
  for (const row of plan) if (row.before !== null) {
    const backup = path.join(beforeDir, row.rel); fs.mkdirSync(path.dirname(backup), { recursive: true }); fs.writeFileSync(backup, row.before, { flag: 'wx' });
  }
  for (const row of plan) {
    const target = path.join(project, row.rel);
    assert(row.before === null ? !fs.existsSync(target) : fs.readFileSync(target).equals(row.before), 'Concurrent change: ' + row.rel);
    fs.mkdirSync(path.dirname(target), { recursive: true }); fs.writeFileSync(target, row.bytes);
  }
  const receipt = { source, project, bundle: app.bundleName, module: 'entry', ability: 'TestAbility',
    sourceAbilitySha256: hash(Buffer.from(ability)), sourcePageSha256: hash(Buffer.from(page)),
    sourceProductionPreserved: true, sharedCallbackFixtureCompilation: true,
    paths: plan.map(r => ({ path: r.rel, beforeSha256: r.before === null ? null : hash(r.before), afterSha256: hash(r.bytes) })) };
  fs.writeFileSync(receiptPath, JSON.stringify(receipt, null, 2) + '\n', { flag: 'wx' });
  return receipt;
}
module.exports = { projectWitness };
if (require.main === module) {
  const args = process.argv.slice(2); const value = key => args[args.indexOf(key) + 1];
  for (const key of ['--source', '--project', '--receipt']) assert(args.includes(key) && value(key), 'Missing ' + key);
  const receipt = projectWitness(value('--source'), value('--project'), value('--receipt'));
  console.log(JSON.stringify({ bundle: receipt.bundle, module: receipt.module, ability: receipt.ability, files: receipt.paths.length }));
}
