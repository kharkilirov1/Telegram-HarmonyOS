// I6: replying to a story — the payload fields, the reply-object serialization, the use case and the
// viewer's reply bar.

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');

const root = path.resolve(__dirname, '../entry/src/main/ets');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8').replaceAll('\r\n', '\n');

function load(relative, names, deps = {}) {
  const source = read(relative)
    .replace(/^import\s[\s\S]*?;\s*/gm, '')
    .replace(/^export\s*\{[^}]*\};?\s*/gm, '')
    .replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(source, { mode: 'transform', sourceUrl: relative });
  return new Function(...Object.keys(deps), js + '\nreturn {' + names.join(',') + '};')(...Object.values(deps));
}

async function main() {
  // Payload ----------------------------------------------------------------------------------------
  const C = load('core/model/AppCommand.ets',
    ['SendMessagePayload', 'SendMessageCommand', 'createSendMessageCommand'], {});
  const payload = new C.SendMessagePayload();
  assert.equal(payload.replyToStoryPosterChatId, 0);
  assert.equal(payload.replyToStoryId, 0);
  const command = C.createSendMessageCommand(42, 'hello');
  assert.equal(command.payload.chatId, 42);
  assert.equal(command.payload.text, 'hello');
  assert.equal(command.payload.replyToMessageId, '0');

  // Serialization ----------------------------------------------------------------------------------
  const serializer = read('infra/td/serialization/CommandSerializer.ets');
  assert.match(serializer, /function setReplyToStoryJsonIfNeeded\(params: TdObject, posterChatId: number, storyId: number\): boolean \{/);
  assert.match(serializer, /if \(posterChatId === 0 \|\| storyId <= 0\) \{\n    return false;\n  \}/);
  assert.match(serializer, /"@type":"inputMessageReplyToStory","story_poster_chat_id":/);
  assert.match(serializer, /if \(!setReplyToStoryJsonIfNeeded\(result\.params, cmd\.payload\.replyToStoryPosterChatId,\n    cmd\.payload\.replyToStoryId\)\) \{/);
  assert.match(serializer, /    setReplyToJsonIfNeeded\(result\.params, cmd\.payload\.replyToMessageId\);/);
  // The story reply is preferred over the message reply when both are set.

  // Use case against a gateway double ---------------------------------------------------------------
  const hilog = { info() {} };
  class TdObjectFixture {}
  const sent = [];
  let fail = false;
  const gateway = {
    async send(command) {
      sent.push(command);
      if (fail) throw new Error('network');
      return new TdObjectFixture();
    }
  };
  const U = load('domain/usecases/replyToStory.ets',
    ['ReplyToStoryUseCase', 'createReplyToStoryUseCase', 'STORY_REPLY_MAX_LENGTH'], {
      createSendMessageCommand: (chatId, text) => ({ type: 'sendMessage', payload: { chatId, text } }),
      TdObject: TdObjectFixture,
      hilog
    });
  const useCase = new U.ReplyToStoryUseCase(gateway);
  assert.equal(U.STORY_REPLY_MAX_LENGTH, 4096);
  assert.equal(useCase.validate(''), 'Write a reply first');
  assert.equal(useCase.validate('   '), 'Write a reply first');
  assert.equal(useCase.validate('x'.repeat(4097)), 'The reply is too long');
  assert.equal(useCase.validate('nice story'), '');
  assert.equal(await useCase.execute(500, 3, 'nice story'), true);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].payload.chatId, 500);
  assert.equal(sent[0].payload.text, 'nice story');
  assert.equal(sent[0].payload.replyToStoryPosterChatId, 500);
  assert.equal(sent[0].payload.replyToStoryId, 3);
  assert.equal(await useCase.execute(0, 3, 'x'), false);
  assert.equal(await useCase.execute(500, 0, 'x'), false);
  assert.equal(await useCase.execute(500, 3, ''), false);
  assert.equal(sent.length, 1, 'invalid replies never reach the gateway');
  fail = true;
  assert.equal(await useCase.execute(500, 3, 'again'), false);

  // Viewer -----------------------------------------------------------------------------------------
  const page = read('ui/pages/stories/TgStoryViewerPage.ets');
  assert.match(page, /@Local private replyText: string = '';/);
  assert.match(page, /@Local private replySending: boolean = false;/);
  assert.match(page, /private replyUseCase\?: ReplyToStoryUseCase;/);
  assert.match(page, /this\.replyUseCase = createReplyToStoryUseCase\(getTdGatewayAdapter\(\)\);/);
  assert.match(page, /private sendReply\(\): void \{/);
  assert.match(page, /useCase\.execute\(this\.chatId, storyId, this\.replyText\)/);
  assert.match(page, /this\.replyText = '';/);
  assert.match(page, /private buildReplyBar\(\) \{/);
  assert.match(page, /TextInput\(\{ text: this\.replyText, placeholder: localizedText\('Reply privately'\) \}\)/);
  assert.match(page, /maxLength\(STORY_REPLY_MAX_LENGTH\)/);
  assert.match(page, /this\.buildReplyBar\(\)/);

  const tokens = read('ui/tg_ui/tokens/TgUiTokens.ets');
  assert.match(tokens, /static readonly STORY_REPLY_FIELD_RADIUS: number = 18;/);

  console.log('PASS story reply contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
