// God-file gate: no ArkTS file may grow past its recorded budget.
//
// The project rule (AGENTS.md, "No god files") is that a file stays a single narrow concern. Several legacy
// files are already above the cap; they are listed with their exact current size, so any growth fails and
// every split is locked in automatically. A file that is split below the cap must lose its entry.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const HARD_CAP = 900;
const WARN_AT = 600;

// Legacy files above the cap, pinned to their size at the time the rule was introduced.
const LEGACY_BUDGETS = {
  'core/model/AppCommand.ets': 2599,
  'ui/pages/chatlist/ChatListPage.ets': 1780,
  'infra/td/serialization/CommandSerializer.ets': 1665,
  'ui/tg_ui/tokens/TgUiTokens.ets': 1632,
  'ui/tg_ui/molecules/TgMessageRouter.ets': 1582,
  'ui/pages/chat/ChatTimelineVO.ets': 1524,
  'ui/tg_ui/atoms/TgComposerInput.ets': 1517,
  'models/td/common/index.ets': 1224,
  'ui/pages/MainTabsPage.ets': 1202,
  'ui/pages/profile/TgProfilePage.ets': 1168,
  'infra/td/gateway/TdGateway.ets': 1084,
  'core/model/dto/MessageDto.ets': 1018,
  'ui/pages/chat/ChatMessageActionsController.ets': 870,
  'ui/pages/settings/TgChatFoldersPage.ets': 863,
  'ui/pages/profile/TgProfileMembersPage.ets': 813,
  'ui/pages/compose/TgComposePage.ets': 803,
  'domain/usecases/loadChatHistory.ets': 802,
  'ui/tg_ui/atoms/TgChatTopBar.ets': 788,
  'core/model/AppState.ets': 724,
  'ui/pages/chat/GlobalMediaPlayback.ets': 712,
  'ui/tg_ui/atoms/TgMediaGalleryPage.ets': 646,
  'ui/pages/settings/TgEditProfilePage.ets': 643,
  'ui/pages/chat/ChatActionsCoordinator.ets': 613,
  'app/bootstrap/AppCoreRuntime.ets': 602
};

// A trailing newline does not open a new line, so the final empty element is not counted.
function lineCount(source) {
  const normalized = source.replaceAll('\r\n', '\n');
  return normalized.endsWith('\n') ? normalized.split('\n').length - 1 : normalized.split('\n').length;
}

function listArkTsFiles(directory) {
  const result = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      result.push(...listArkTsFiles(full));
    } else if (entry.isFile() && entry.name.endsWith('.ets')) {
      result.push(full);
    }
  }
  return result;
}

function main() {
  const files = listArkTsFiles(root)
    .map((file) => ({
      relative: path.relative(root, file).split(path.sep).join('/'),
      lines: lineCount(fs.readFileSync(file, 'utf8'))
    }))
    .sort((left, right) => right.lines - left.lines);

  const violations = [];
  const ratchets = [];
  for (const file of files) {
    const budget = LEGACY_BUDGETS[file.relative];
    const limit = budget === undefined ? HARD_CAP : budget;
    if (file.lines > limit) {
      violations.push(`${file.relative}: ${file.lines} lines, budget ${limit} (append to an owner module or split)`);
    }
    if (budget !== undefined) {
      assert.ok(file.lines > WARN_AT, `${file.relative} is below the warn line; drop its legacy budget entry`);
      if (file.lines < budget) {
        ratchets.push(`${file.relative}: ${budget} -> ${file.lines}`);
        LEGACY_BUDGETS[file.relative] = file.lines;
      }
    }
  }
  assert.deepEqual(violations, [], 'no file may grow past its budget');

  // A file present in the budget map must exist, otherwise a rename silently loses the ratchet.
  for (const relative of Object.keys(LEGACY_BUDGETS)) {
    assert.ok(files.some((file) => file.relative === relative), `legacy budget points at a missing file: ${relative}`);
  }

  // Every large file is pinned: an unpinned file above the warn line would otherwise grow to the cap unnoticed.
  const unpinned = files.filter((file) => file.lines > WARN_AT && LEGACY_BUDGETS[file.relative] === undefined);
  assert.deepEqual(unpinned.map((file) => `${file.relative}: ${file.lines}`), [],
    `files above ${WARN_AT} lines need a budget entry`);
  assert.ok(files.some((file) => file.lines <= HARD_CAP), 'the scan must see ordinary files');

  if (ratchets.length > 0) {
    console.log('shrank (update LEGACY_BUDGETS):\n' + ratchets.join('\n'));
  }
  console.log(`PASS god-file budgets: ${files.length} files, cap ${HARD_CAP}, ${Object.keys(LEGACY_BUDGETS).length} legacy entries`);
}

main();
