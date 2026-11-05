// D26: contact card actions — the address-book write, the card's buttons and their wiring to the page port.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');
const readResource = (relative) =>
  fs.readFileSync(path.join(root, '..', 'resources', relative), 'utf8').replaceAll('\r\n', '\n');

function load(relative, names, deps = {}) {
  const source = read(relative)
    .replace(/^import\s[\s\S]*?;\s*/gm, '')
    .replace(/^export\s*\{[^}]*\};?\s*/gm, '')
    .replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(source, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), js + '\nreturn {' + names.join(',') + '};')(...Object.values(deps));
}

async function main() {
  // Address-book write -----------------------------------------------------------------------------
  const hilog = { info() {} };
  const added = [];
  let failAdd = false;
  const contact = {
    async addContact(card) {
      added.push(card);
      if (failAdd) throw new Error('denied');
    }
  };
  const D = load('infra/contacts/DeviceContacts.ets',
    ['saveContactToDevice', 'CONTACT_WRITE_PERMISSIONS', 'toPickedContact', 'splitContactName'], {
      hilog,
      contact,
      Permissions: class Permissions {}
    });
  assert.deepEqual(D.CONTACT_WRITE_PERMISSIONS, ['ohos.permission.WRITE_CONTACTS']);
  assert.equal(await D.saveContactToDevice('', '', '+1 555 0100'), false, 'a card needs a name');
  assert.equal(await D.saveContactToDevice('Ann', 'Lee', '   '), false, 'a card needs a number');
  assert.equal(added.length, 0, 'invalid cards never reach the address book');
  assert.equal(await D.saveContactToDevice('Ann', 'Lee', '+1 555 0100'), true);
  assert.equal(added[0].phoneNumbers[0].phoneNumber, '+1 555 0100');
  assert.equal(added[0].name.fullName, 'Ann Lee');
  assert.equal(added[0].name.givenName, 'Ann');
  assert.equal(added[0].name.familyName, 'Lee');
  assert.equal(await D.saveContactToDevice('Ann', '', '+1 555 0100'), true);
  assert.equal(added[1].name.fullName, 'Ann');
  failAdd = true;
  assert.equal(await D.saveContactToDevice('Ann', 'Lee', '+1 555 0100'), false, 'a refused write is false');

  // Card buttons -----------------------------------------------------------------------------------
  const bubble = read('ui/tg_ui/atoms/TgContactBubble.ets');
  assert.match(bubble, /@Event onMessagePress: \(\) => void = \(\) => \{\};/);
  assert.match(bubble, /@Event onAddContactPress: \(\) => void = \(\) => \{\};/);
  assert.match(bubble, /localized\(\$r\('app\.string\.contact_card_message'\)\.id, 'Message'\)/);
  assert.match(bubble, /localized\(\$r\('app\.string\.contact_card_add'\)\.id, 'Add Contact'\)/);
  assert.match(bubble, /if \(this\.contactUserId > 0\) \{\n              this\.onMessagePress\(\);/);
  assert.match(bubble, /if \(this\.phoneNumber\.length > 0\) \{\n              this\.onAddContactPress\(\);/);
  assert.match(bubble, /TgUiTokens\.CONTACT_CARD_ACTION_HEIGHT/);

  const tokens = read('ui/tg_ui/tokens/TgUiTokens.ets');
  assert.match(tokens, /static readonly CONTACT_CARD_ACTION_HEIGHT: number = 33;/);

  const router = read('ui/tg_ui/molecules/TgMessageRouter.ets');
  assert.match(router, /@Event onContactMessagePress: \(\) => void = \(\) => \{\};/);
  assert.match(router, /onMessagePress: \(\): void => this\.onContactMessagePress\(\)/);

  const row = read('ui/pages/chat/TgChatTimelineRow.ets');
  assert.match(row, /onContactMessagePress: \(\): void => \{\n      this\.bindings\.openContactProfile\(this\.entry\.message\.contactUserId\);/);
  assert.match(row, /this\.bindings\.addContactCard\(this\.entry\.message\.contactFirstName, this\.entry\.message\.contactLastName,/);

  const ports = read('ui/pages/chat/ChatScreenViewPorts.ets');
  assert.match(ports, /openContactProfile\(userId: number\): void;/);
  assert.match(ports, /addContactCard\(firstName: string, lastName: string, phoneNumber: string\): void;/);

  const bindings = read('ui/pages/chat/ChatScreenViewBindings.ets');
  assert.match(bindings, /openContactProfile\(userId: number\): void \{ this\.session\.openContactProfile\(userId\); \}/);
  assert.match(bindings, /this\.session\.addContactCard\(firstName, lastName, phoneNumber\);/);
  // The page-contract gate requires the callbacks to be Session delegates.
  const session = read('ui/pages/chat/ChatScreenSession.ets');
  assert.match(session, /openContactProfile\(userId: number\): void \{ delegateOpenContactProfile\(this, userId\); \}/);
  assert.match(session, /addContactCard\(firstName: string, lastName: string, phoneNumber: string\): void \{ delegateAddContactCard\(this, firstName, lastName, phoneNumber\); \}/);
  const actions = read('ui/pages/chat/ChatContactCardActions.ets');
  assert.match(actions, /export function openContactProfile\(host: ChatContactCardPort, userId: number\): void \{/);
  assert.match(actions, /host\.pageStack\.pushPathByName\(PROFILE_ROUTE, new ProfileRouteParams\(0, userId\)\);/);
  assert.match(actions, /export function addContactCard\(host: ChatContactCardPort, firstName: string, lastName: string,/);
  assert.match(actions, /requestPermissionsFromUser\(context, CONTACT_WRITE_PERMISSIONS\)/);
  assert.match(actions, /saveContactToDevice\(firstName, lastName, phoneNumber\)/);
  assert.match(actions, /contact_card_add_denied/);
  assert.match(actions, /contact_card_added/);
  assert.match(actions, /contact_card_add_failed/);
  assert.ok(session.split('\n').length <= 500, 'the session owner stays within the line budget');

  // Manifest permission ----------------------------------------------------------------------------
  const manifest = fs.readFileSync(path.join(root, '..', 'module.json5'), 'utf8');
  assert.match(manifest, /"name": "ohos\.permission\.WRITE_CONTACTS"/);
  assert.match(manifest, /\$string:permission_contacts_reason/);

  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(readResource(`${locale}/element/string.json`)).string;
    for (const name of ['contact_card_message', 'contact_card_add', 'contact_card_add_denied',
      'contact_card_added', 'contact_card_add_failed', 'permission_contacts_reason']) {
      assert.ok(strings.find((item) => item.name === name), `${locale} ships ${name}`);
    }
  }

  console.log('PASS contact card actions contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
