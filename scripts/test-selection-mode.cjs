// S5b (C9) contract: message-selection mode.
//  - the model lives in ChatTimelineViewState and the coordinator owns enter/toggle/clear;
//  - copy/forward/delete reuse the existing controllers so TDLib paths and fences stay single-sourced;
//  - the actions menu gains "Select", the page swaps the composer for the selection bar, and rows
//    toggle instead of running media taps while the mode is on.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '..');
const main = path.join(root, 'entry/src/main/ets') + path.sep;
const read = (relative) => fs.readFileSync(main + relative, 'utf8').replaceAll('\r\n', '\n');

function load(relative, deps = {}) {
  const text = read(relative);
  const names = [...text.matchAll(/^export\s+(?:default\s+)?(?:async\s+)?(?:class|function|enum|const)\s+(\w+)/gm)]
    .map((match) => match[1]);
  const code = text.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export\s+(?:default\s+)?/gm, '')
    .replace(/^@ObservedV2\s*\n/gm, '').replace(/^(\s*)@Trace\s+/gm, '$1');
  return new Function(...Object.keys(deps), stripTypeScriptTypes(code, { mode: 'transform', sourceUrl: relative }) +
    `\nreturn {${names.join(',')}};`)(...Object.values(deps));
}

const localized = (_id, fallback) => fallback;
const coordinator = load('ui/pages/chat/ChatMessagePopupCoordinator.ets', {
  localized,
  $r: (id) => ({ id }),
  TgUiTokens: new Proxy(function () { return 0; }, { get: () => 0 })
});

function entry(id, text, extra = {}) {
  return {
    kind: 'message',
    message: Object.assign({
      messageId: String(id), text, caption: '', senderName: 'Ann', isOutgoing: false
    }, extra)
  };
}

function makeHost(entries, initialIds = []) {
  const calls = { copied: [], forwarded: [], deleted: [], closed: 0 };
  const host = {
    messageActionsGeneration: 0,
    selectionActive: initialIds.length > 0,
    selectedMessageIds: initialIds.slice(),
    dataSource: { getAllEntries: () => entries },
    closeMessageActions() { calls.closed++; host.messageActionsGeneration++; },
    getActiveChatId: () => 7,
    messageActionsCtrl: {
      copyMessageText: (text) => calls.copied.push(text),
      startForwardMessages: (ids, author, preview, chatId) => calls.forwarded.push({ ids, author, preview, chatId }),
      handleDeleteMessages: (ids) => calls.deleted.push(ids)
    }
  };
  return { host, calls };
}

const entries = [
  entry(100, 'first'),
  entry(101, '', { caption: 'caption only' }),
  entry(102, ''),
  entry(103, 'last')
];

// Enter: closes the actions popup, activates the mode, selects the pressed message -----------------
{
  const { host, calls } = makeHost(entries);
  coordinator.enterMessageSelection(host, '101');
  assert.equal(host.selectionActive, true);
  assert.deepEqual(host.selectedMessageIds, ['101']);
  assert.equal(calls.closed, 1, 'the actions popup must close when selection starts');
  assert.ok(host.messageActionsGeneration > 0, 'stale popup work must be fenced');
  coordinator.enterMessageSelection(host, '');
  assert.deepEqual(host.selectedMessageIds, ['101'], 'an empty id cannot change the selection');
}

// Toggle: adds, removes, and leaves the mode when the last message is deselected -------------------
{
  const { host } = makeHost(entries);
  coordinator.enterMessageSelection(host, '100');
  coordinator.toggleMessageSelection(host, '101');
  assert.deepEqual(host.selectedMessageIds, ['100', '101']);
  coordinator.toggleMessageSelection(host, '100');
  assert.deepEqual(host.selectedMessageIds, ['101']);
  coordinator.toggleMessageSelection(host, '101');
  assert.deepEqual(host.selectedMessageIds, []);
  assert.equal(host.selectionActive, false, 'empty selection exits the mode');
  coordinator.toggleMessageSelection(host, '102');
  assert.deepEqual(host.selectedMessageIds, [], 'toggles are ignored while the mode is off');
}

// Title and clear ---------------------------------------------------------------------------------
{
  const { host } = makeHost(entries, ['100', '101']);
  assert.equal(coordinator.selectionTitle(host), '2 selected');
  coordinator.clearMessageSelection(host);
  assert.equal(host.selectionActive, false);
  assert.deepEqual(host.selectedMessageIds, []);
  assert.equal(coordinator.selectionTitle(host), '');
}

// Copy: timeline order, blank texts skipped, mode cleared -----------------------------------------
{
  const { host, calls } = makeHost(entries, ['103', '100', '101', '102']);
  coordinator.copySelectedMessages(host);
  assert.deepEqual(calls.copied, ['first\ncaption only\nlast']);
  assert.deepEqual(host.selectedMessageIds, [], 'copy leaves selection mode');
  const empty = makeHost([entry(200, '')], ['200']);
  coordinator.copySelectedMessages(empty.host);
  assert.deepEqual(empty.calls.copied, [], 'nothing to copy keeps the clipboard untouched');
}

// Forward: same controller path as a single message, ids in timeline order ------------------------
{
  const { host, calls } = makeHost(entries, ['103', '100']);
  coordinator.forwardSelectedMessages(host);
  assert.equal(calls.forwarded.length, 1);
  assert.deepEqual(calls.forwarded[0].ids, ['100', '103']);
  assert.equal(calls.forwarded[0].author, 'Ann');
  assert.equal(calls.forwarded[0].preview, 'first');
  assert.equal(calls.forwarded[0].chatId, 7);
  assert.deepEqual(host.selectedMessageIds, []);
}

// Delete: one confirmation flow for the whole selection ------------------------------------------
{
  const { host, calls } = makeHost(entries, ['100', '101']);
  coordinator.deleteSelectedMessages(host);
  assert.deepEqual(calls.deleted, [['100', '101']]);
  assert.deepEqual(host.selectedMessageIds, []);
}

// Multi-delete confirmation names the selection size (one dialog, honest title) --------------------
async function checkCountDialog() {
  const DeleteController = load('ui/pages/chat/ChatDeleteMessageController.ets', {
    TgUiTokens: new Proxy(function () { return 0; }, { get: () => 0 }),
    localized: (_id, fallback) => fallback,
    $r: (id) => ({ id }),
    DeleteMessagesParams: class {},
    DeleteMessagesEligibilityError: class extends Error {},
    DeleteMessagesAvailability: class {},
    DeleteMessagesUseCase: class {},
    promptAction: { Button: class {} }
  });
  const dialogs = [];
  const host = {
    getChatUIContext: () => ({
      getPromptAction: () => ({
        showDialog: (options) => {
          dialogs.push(options);
          return Promise.resolve({ index: 0 });
        }
      })
    })
  };
  const confirmation = new DeleteController.NativeDeleteMessageConfirmation();
  const availability = { forSelf: true, forEveryone: false };
  await confirmation.confirm(availability, host, () => true, 1);
  await confirmation.confirm(availability, host, () => true, 7);
  assert.equal(dialogs[0].title, 'Delete message?', 'a single message keeps the original title');
  assert.equal(dialogs[1].title, 'Delete 7 messages?', 'the dialog names the selection size');
  assert.equal(dialogs[1].message, 'This action cannot be undone.');
}

// Source contracts --------------------------------------------------------------------------------
const controller = read('ui/pages/chat/ChatMessageActionsController.ets');
assert.match(controller, /new ChatMessageActionItem\('select', localized\(\$r\('app\.string\.action_select'\)\.id, 'Select'\)\)/);
assert.match(controller, /if \(actionId === 'select'\) \{[\s\S]{0,120}host\.enterMessageSelection\(entry\.message\.messageId\)/);
assert.match(controller, /enterMessageSelection\(messageId: string\): void;/,
  'the actions host exposes the selection entry point');
assert.match(controller, /handleDeleteMessages\(messageIds: string\[\], host: ChatMessageActionsHost\): void \{[\s\S]{0,260}requestMany\(messageIds, host\)/);

const deleteController = read('ui/pages/chat/ChatDeleteMessageController.ets');
assert.match(deleteController, /request\(messageId: string, host: ChatDeleteMessageHost\): void \{\s*this\.requestMany\(\[messageId\], host\);/,
  'single and multi delete share one flow');
assert.match(deleteController, /useCase\.getAvailability\(chatId, ids, current\)/);
assert.match(deleteController, /params\.messageIds = ids;/);

const page = read('ui/pages/chat/TgChatScreenPage.ets');
assert.match(page, /if \(this\.view\.timeline\.selectionActive\) \{[\s\S]{0,120}TgSelectionPanel\(\{/);
assert.match(page, /TgSelectionPanel\(\{[\s\S]{0,420}onCopy:[\s\S]{0,200}onForward:[\s\S]{0,200}onDelete:/,
  'all three actions are wired');

const row = read('ui/pages/chat/TgChatTimelineRow.ets');
assert.match(row, /\.enabled\(!this\.timeline\.selectionActive\)/,
  'the bubble subtree must not run its own taps while selecting');
assert.match(row, /\.onClick\(\(\) => \{\s*if \(this\.timeline\.selectionActive\) \{\s*this\.bindings\.toggleMessageSelection\(this\.entry\.message\.messageId\);/);
assert.match(row, /private buildSelectionIndicator\(\)/);
assert.match(row, /SELECTION_CHECK_GLYPH/);

const session = read('ui/pages/chat/ChatScreenSession.ets');
for (const method of ['enterMessageSelection', 'toggleMessageSelection', 'clearMessageSelection',
  'selectionTitle', 'copySelectedMessages', 'forwardSelectedMessages', 'deleteSelectedMessages']) {
  assert.ok(session.includes(`${method}(`), `session must delegate ${method}`);
}
const ports = read('ui/pages/chat/ChatScreenViewPorts.ets');
assert.match(ports, /toggleMessageSelection\(messageId: string\): void;/);
assert.match(ports, /selectionActive\(\): boolean;/);

const state = read('ui/pages/chat/ChatTimelineViewState.ets');
assert.match(state, /@Trace selectionActive: boolean = false;/);
assert.match(state, /@Trace selectedMessageIds: string\[\] = \[\];/);
const context = read('ui/pages/chat/ChatScreenContext.ets');
assert.match(context, /get selectionActive\(\): boolean \{ return this\.view\.timeline\.selectionActive; \}/);
assert.match(context, /set selectedMessageIds\(value: string\[\]\) \{ this\.view\.timeline\.selectedMessageIds = value; \}/);

assert.ok(fs.existsSync(path.join(main, 'ui/tg_ui/molecules/TgSelectionPanel.ets')));
assert.ok(fs.existsSync(path.join(main, 'ui/tg_ui/spec/TgSelectionPanel.md')), 'panel needs a passport');
assert.ok(fs.existsSync(path.join(main, 'ui/tg_ui/demos/TgSelectionPanelDemo.ets')), 'panel needs a demo');
const tokens = read('ui/tg_ui/tokens/TgUiTokens.ets');
// iOS tints the selected bubble/row; a check lane alone is not enough feedback.
assert.match(tokens, /SELECTION_ROW_TINT: Resource = \$r\('app\.color\.selection_row_tint'\)/);
assert.match(row, /\.backgroundColor\(this\.timeline\.selectionActive && this\.isSelected\(\) \?/,
  'the selected row is tinted while selection mode is on');
for (const [file, locale] of [['base', 'light'], ['dark', 'dark']]) {
  const colors = JSON.parse(fs.readFileSync(
    path.join(root, `entry/src/main/resources/${file}/element/color.json`), 'utf8'));
  const entry = colors.color.find((item) => item.name === 'selection_row_tint');
  assert.ok(entry && entry.value.length > 0, `selection_row_tint exists (${locale})`);
}
// The dialog title now names the selection size.
const deleteSource = read('ui/pages/chat/ChatDeleteMessageController.ets');
assert.match(deleteSource, /messageCount > 1 \?/);
assert.match(deleteSource, /delete_messages_count/);
assert.match(deleteSource, /messageCount\.toString\(\)/);
assert.match(deleteSource, /confirm\(availability, host, current, ids\.length\)/,
  'the controller passes the selection size into the confirmation');

for (const token of ['SELECTION_PANEL_HEIGHT', 'SELECTION_PANEL_BG', 'SELECTION_PANEL_BUTTON_SIZE',
  'SELECTION_PANEL_BUTTON_ICON_SIZE', 'SELECTION_PANEL_COPY_ICON', 'SELECTION_PANEL_COPY_GLYPH',
    'SELECTION_CHECK_LANE_WIDTH',
  'SELECTION_CHECK_GLYPH']) {
  assert.ok(tokens.includes(token), `missing token ${token}`);
  // C9 copy icon: the panel renders the SVG asset instead of a text glyph.
  const panelSource = fs.readFileSync(path.join(root,
    'entry/src/main/ets/ui/tg_ui/molecules/TgSelectionPanel.ets'), 'utf8');
  assert.match(panelSource, /buildIconButton\(TgUiTokens\.SELECTION_PANEL_COPY_ICON/);
  assert.ok(!panelSource.includes('buildGlyphButton(TgUiTokens.SELECTION_PANEL_COPY_GLYPH'),
    'copy no longer uses the text glyph');
  assert.ok(fs.existsSync(path.join(root,
    'entry/src/main/resources/base/media/ic_selection_copy.svg')), 'copy icon asset exists');
  assert.match(fs.readFileSync(path.join(root, 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets'), 'utf8'),
    /SELECTION_PANEL_COPY_ICON: Resource = \$r\('app\.media\.ic_selection_copy'\);/);
}
// iOS parity: the bar is an input-panel row of 40x40 buttons, not full-height text buttons.
assert.match(tokens, /SELECTION_PANEL_HEIGHT: number = 40;/);
assert.match(tokens, /SELECTION_PANEL_BUTTON_SIZE: number = 40;/);
const panelSource = read('ui/tg_ui/molecules/TgSelectionPanel.ets');
assert.match(panelSource, /Button\(\{ type: ButtonType\.Circle \}\)/, 'actions are circular buttons with native press feedback');
assert.match(panelSource, /backgroundBlurStyle\(TgGlassPolicy\.composerBlurStyle\(\)\)/, 'panel and buttons are glass');
assert.ok(!panelSource.includes('SELECTION_PANEL_ACTION_TEXT_SIZE'), 'text-button tokens are gone');
for (const [locale, expected] of Object.entries({
  base: ['%d selected', 'Select'],
  ru_RU: ['%d выбрано', 'Выбрать'],
  zh_CN: ['已选择 %d', '选择']
})) {
  const strings = JSON.parse(fs.readFileSync(
    path.join(root, `entry/src/main/resources/${locale}/element/string.json`), 'utf8'));
  const count = strings.string.find((item) => item.name === 'selection_count');
  const select = strings.string.find((item) => item.name === 'action_select');
  assert.equal(count?.value, expected[0], `selection_count in ${locale}`);
  assert.equal(select?.value, expected[1], `action_select in ${locale}`);
}

checkCountDialog()
  .then(() => {
    console.log('PASS message selection contract');
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
