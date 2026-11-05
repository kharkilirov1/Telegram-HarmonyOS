// I6: story reactions — chosen-reaction parsing, commands and serialization, use cases, viewer row.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

const { createLoader } = require('./lib/ets-load.cjs');
const load = createLoader(root);

async function main() {
  // Chosen reaction parsing through the shared reaction-type helper --------------------------------
  const M = load('core/model/dto/MessageDto.ets', ['parseReactionTypeKey'], {
    tdGetString: (object, key) => (object && typeof object[key] === 'string' ? object[key] : ''),
    tdGetInt64: (object, key) => (object && object[key] !== undefined ? String(object[key]) : '0'),
    tdGetNumber: (object, key) => (object && typeof object[key] === 'number' ? object[key] : 0),
    tdGetBoolean: () => false,
    tdGetObject: () => undefined,
    tdGetArray: () => []
  });
  assert.equal(M.parseReactionTypeKey({ '@type': 'reactionTypeEmoji', emoji: '👍' }), 'emoji:👍');
  assert.equal(M.parseReactionTypeKey({ '@type': 'reactionTypeCustomEmoji', custom_emoji_id: 123 }), 'custom:123');
  assert.equal(M.parseReactionTypeKey(undefined), '');

  const storyDto = read('core/model/dto/StoryDto.ets');
  assert.match(storyDto, /chosenReactionKey: string = '';/);
  const normalizer = read('core/events/normalizers/StoryNormalizer.ets');
  assert.match(normalizer, /import \{ parseReactionTypeKey \} from '\.\.\/\.\.\/model\/dto\/MessageDto';/);
  assert.match(normalizer, /dto\.chosenReactionKey = parseReactionTypeKey\(tdGetObject\(story, 'chosen_reaction_type'\)\);/);

  // Commands ---------------------------------------------------------------------------------------
  const C = load('core/model/AppCommand.ets',
    ['SetStoryReactionCommand', 'SetStoryReactionPayload', 'createSetStoryReactionCommand',
      'GetStoryAvailableReactionsCommand', 'createGetStoryAvailableReactionsCommand'], {});
  const setCommand = C.createSetStoryReactionCommand(345, 12, 'emoji:❤');
  assert.ok(setCommand instanceof C.SetStoryReactionCommand);
  assert.equal(setCommand.type, 'setStoryReaction');
  assert.equal(setCommand.payload.posterChatId, 345);
  assert.equal(setCommand.payload.storyId, 12);
  assert.equal(setCommand.payload.reactionKey, 'emoji:❤');
  assert.equal(setCommand.payload.updateRecentReactions, true);
  const removeCommand = C.createSetStoryReactionCommand(345, 12, '');
  assert.equal(removeCommand.payload.reactionKey, '');
  const available = C.createGetStoryAvailableReactionsCommand(6);
  assert.ok(available instanceof C.GetStoryAvailableReactionsCommand);
  assert.equal(available.type, 'getStoryAvailableReactions');
  assert.equal(available.payload.rowSize, 6);
  const defaultRow = new C.GetStoryAvailableReactionsCommand();
  assert.equal(defaultRow.payload.rowSize, 12);
  const commandSource = read('core/model/AppCommand.ets');
  assert.match(commandSource, /  \| SetStoryReactionCommand/);
  assert.match(commandSource, /  \| GetStoryAvailableReactionsCommand/);

  // Serializer -------------------------------------------------------------------------------------
  const serializer = read('infra/td/serialization/CommandSerializer.ets');
  assert.match(serializer, /COMMAND_SERIALIZATION_HANDLERS\.set\('setStoryReaction', serializeSetStoryReaction\);/);
  assert.match(serializer, /COMMAND_SERIALIZATION_HANDLERS\.set\('getStoryAvailableReactions', serializeGetStoryAvailableReactions\);/);
  assert.match(serializer, /function buildReactionTypeJsonObject\(key: string\): string \{/);
  assert.match(serializer, /parts\.push\(buildReactionTypeJsonObject\(key\)\);/);
  assert.match(serializer, /result\.method = 'setStoryReaction';/);
  assert.match(serializer, /result\.params\.setString\('story_poster_chat_id', cmd\.payload\.posterChatId\.toString\(\)\);/);
  assert.match(serializer, /result\.params\.setNumber\('story_id', cmd\.payload\.storyId\);/);
  assert.match(serializer, /const reactionJson = cmd\.payload\.reactionKey\.length > 0/);
  assert.match(serializer, /: 'null';/, 'an empty key removes the reaction');
  assert.match(serializer, /result\.params\.setString\('_reaction_type_json', reactionJson\);/);
  assert.match(serializer, /result\.params\.setBool\('update_recent_reactions', cmd\.payload\.updateRecentReactions\);/);
  assert.match(serializer, /result\.method = 'getStoryAvailableReactions';/);
  assert.match(serializer, /result\.params\.setNumber\('row_size', cmd\.payload\.rowSize\);/);

  // The message reaction helper keeps its validation.
  assert.match(serializer, /throw new Error\('Invalid reaction emoji key'\);/);
  assert.match(serializer, /test\(customEmojiId\)/);

  // Use cases --------------------------------------------------------------------------------------
  const setUseCase = read('domain/usecases/setStoryReaction.ets');
  assert.match(setUseCase, /export class SetStoryReactionUseCase \{/);
  assert.match(setUseCase, /async execute\(posterChatId: number, storyId: number, reactionKey: string,\n    currentKey: string\): Promise<boolean> \{/);
  assert.match(setUseCase, /const nextKey = reactionKey === currentKey \? '' : reactionKey;/);
  assert.match(setUseCase, /await this\.gateway\.send\(createSetStoryReactionCommand\(posterChatId, storyId, nextKey\)\);/);
  assert.match(setUseCase, /if \(posterChatId === 0 \|\| storyId <= 0\) \{/);

  const availableUseCase = read('domain/usecases/getStoryAvailableReactions.ets');
  assert.match(availableUseCase, /export class GetStoryAvailableReactionsUseCase \{/);
  assert.match(availableUseCase, /const DEFAULT_ROW_SIZE = 6;/);
  assert.match(availableUseCase, /await this\.gateway\.send\(\n        createGetStoryAvailableReactionsCommand\(rowSize\)\)/);
  assert.match(availableUseCase, /return parseAvailableReactions\(response\);/);
  assert.match(availableUseCase, /return empty;/);

  // Viewer -----------------------------------------------------------------------------------------
  const page = read('ui/pages/stories/TgStoryViewerPage.ets');
  assert.match(page, /@Local private reactionKeys: string\[\] = \[\];/);
  assert.match(page, /private availableReactionsUseCase\?: GetStoryAvailableReactionsUseCase;/);
  assert.match(page, /private setReactionUseCase\?: SetStoryReactionUseCase;/);
  assert.match(page, /this\.reactionKeys = snapshot\.top\.slice\(0, 6\);/);
  assert.match(page, /private reactionLabel\(key: string\): string \{/);
  assert.match(page, /return key\.substring\('emoji:'\.length\);/);
  assert.match(page, /private toggleReaction\(key: string\): void \{/);
  assert.match(page, /useCase\.execute\(this\.chatId, storyId, key, currentKey\)/);
  assert.match(page, /updated\.chosenReactionKey = key === currentKey \? '' : key;/);
  assert.match(page, /private buildReactionRow\(\) \{/);
  assert.match(page, /ForEach\(this\.reactionKeys/);
  assert.match(page, /this\.story\.chosenReactionKey === key/);
  assert.match(page, /if \(this\.reactionKeys\.length > 0\) \{\n\s+this\.buildReactionRow\(\)/);

  // Tokens -----------------------------------------------------------------------------------------
  const tokens = read('ui/tg_ui/tokens/TgUiTokens.ets');
  for (const name of ['STORY_REACTION_EMOJI_SIZE', 'STORY_REACTION_CHIP_RADIUS', 'STORY_REACTION_CHIP_BG',
    'STORY_REACTION_CHOSEN_BG']) {
    assert.match(tokens, new RegExp('static readonly ' + name + ':'), name + ' is a token');
  }

  console.log('PASS story reaction contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
