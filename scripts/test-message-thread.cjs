// D11: comment threads. Covers the getMessageThread/getMessageThreadHistory wire, the response
// parsers, the use case validation and the paging contract.

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
  const hilog = { info() {}, warn() {}, error() {}, debug() {} };
  const { TdObject } = load('models/td/common/index.ets', ['TdObject']);
  const accessors = load('core/utils/tdAccessors.ets', ['tdGetArray', 'tdGetInt64', 'tdGetNumber',
    'tdGetObject', 'tdGetString'], { TdObject });
  const C = load('core/model/AppCommand.ets',
    ['createGetMessageThreadCommand', 'createGetMessageThreadHistoryCommand', 'AppCommand',
      'GetMessageThreadCommand', 'GetMessageThreadHistoryCommand']);
  const errors = load('core/model/AppError.ets', ['AppError', 'AppErrorKind']);
  const serializer = load('infra/td/serialization/CommandSerializer.ets',
    ['serializeCommand', 'buildTdlibRequestJson'], { ...C, TdObject, hilog, ...errors });
  const U = load('domain/usecases/messageThread.ets',
    ['MessageThreadUseCase', 'createMessageThreadUseCase', 'createMessageThreadPageFromTd',
      'createMessageThreadHistoryFromTd', 'isValidThreadMessageId', 'MESSAGE_THREAD_MAX_LIMIT',
      'MessageThreadPage', 'MessageThreadComment'],
    { ...C, ...errors, ...accessors, TdObject, hilog });

  // Wire ------------------------------------------------------------------------------------------
  const threadRaw = serializer.buildTdlibRequestJson('getMessageThread',
    serializer.serializeCommand(C.createGetMessageThreadCommand(42, '9007199254740993')).params);
  assert.ok(threadRaw.includes('"@type":"getMessageThread"'));
  assert.ok(threadRaw.includes('"chat_id":42'));
  assert.ok(threadRaw.includes('9007199254740993'), 'the thread message id stays exact');

  const historyRaw = serializer.buildTdlibRequestJson('getMessageThreadHistory',
    serializer.serializeCommand(C.createGetMessageThreadHistoryCommand(42, '9007199254740993',
      '9007199254740994', 0, 50)).params);
  assert.ok(historyRaw.includes('"@type":"getMessageThreadHistory"'));
  assert.ok(historyRaw.includes('9007199254740993'));
  assert.ok(historyRaw.includes('9007199254740994'), 'the paging cursor stays exact');
  assert.ok(historyRaw.includes('"offset":0'));
  assert.ok(historyRaw.includes('"limit":50'));

  // Parsers ---------------------------------------------------------------------------------------
  const thread = U.createMessageThreadPageFromTd(TdObject.fromJSON(JSON.stringify({
    '@type': 'messageThreadInfo', chat_id: -100123456789, message_thread_id: '9007199254740993',
    reply_info: { '@type': 'messageReplyInfo', reply_count: 12, recent_replier_ids: [],
      last_read_inbox_message_id: '5', last_read_outbox_message_id: '0', last_message_id: '7' },
    unread_message_count: 3,
    messages: [{ '@type': 'message', id: '11' }, { '@type': 'message', id: '12' }],
    draft_message: { '@type': 'draftMessage' }
  })));
  assert.equal(thread.chatId, -100123456789);
  assert.equal(thread.threadId, '9007199254740993');
  assert.equal(thread.replyCount, 12);
  assert.equal(thread.unreadCount, 3);
  assert.deepEqual(thread.messageIds, ['11', '12']);

  assert.equal(U.createMessageThreadPageFromTd(TdObject.fromJSON('{"@type":"ok"}')), undefined);
  const emptyThread = U.createMessageThreadPageFromTd(TdObject.fromJSON(JSON.stringify({
    '@type': 'messageThreadInfo', chat_id: 1, message_thread_id: '2',
    reply_info: { '@type': 'messageReplyInfo', reply_count: 0, unread_count: 0 }, messages: []
  })));
  assert.equal(emptyThread.replyCount, 0);
  assert.equal(emptyThread.unreadCount, 0);
  assert.deepEqual(emptyThread.messageIds, []);

  const history = U.createMessageThreadHistoryFromTd(TdObject.fromJSON(JSON.stringify({
    '@type': 'messages', total_count: 40, next_offset: '13',
    messages: [{ '@type': 'message', id: '10' }]
  })));
  assert.equal(history.replyCount, 40);
  assert.equal(history.nextFromMessageId, '13');
  assert.deepEqual(history.messageIds, ['10']);
  assert.equal(U.createMessageThreadHistoryFromTd(TdObject.fromJSON('{"@type":"ok"}')), undefined);

  // Comment rows ----------------------------------------------------------------------------------
  const withComments = U.createMessageThreadHistoryFromTd(TdObject.fromJSON(JSON.stringify({
    '@type': 'messages', total_count: 3, next_offset: '0', messages: [
      { '@type': 'message', id: '21', date: 1700000000, is_outgoing: 0,
        sender_id: { '@type': 'messageSenderUser', user_id: 55 },
        content: { '@type': 'messageText', text: { '@type': 'formattedText', text: 'First comment' } } },
      { '@type': 'message', id: '22', date: 1700000100, is_outgoing: 1,
        sender_id: { '@type': 'messageSenderChat', chat_id: -100777 },
        content: { '@type': 'messageText', text: { '@type': 'formattedText', text: 'Second comment' } } },
      { '@type': 'message', id: '23', date: 0, is_outgoing: 0,
        sender_id: { '@type': 'messageSenderUser', user_id: 0 },
        content: { '@type': 'messagePhoto', caption: { '@type': 'formattedText', text: 'pic' } } }
    ]
  })));
  assert.equal(withComments.comments.length, 3);
  assert.equal(withComments.comments[0].messageId, '21');
  assert.equal(withComments.comments[0].senderUserId, 55);
  assert.equal(withComments.comments[0].date, 1700000000);
  assert.equal(withComments.comments[0].text, 'First comment');
  assert.equal(withComments.comments[0].isOutgoing, false);
  assert.equal(withComments.comments[1].isOutgoing, true);
  assert.equal(withComments.comments[1].senderUserId, 0, 'a chat sender has no user id');
  assert.equal(withComments.comments[2].text, '', 'a photo comment has no text preview');
  assert.deepEqual(withComments.comments.map((row) => row.messageId), ['21', '22', '23']);

  // Page and route --------------------------------------------------------------------------------
  const pageSource = read('ui/pages/chat/TgMessageThreadPage.ets');
  assert.match(pageSource, /export struct TgMessageThreadPage/);
  assert.match(pageSource, /export function TgMessageThreadPageBuilder\(\)/);
  assert.match(pageSource, /createMessageThreadUseCase\(getTdGatewayAdapter\(\)\)/);
  assert.match(pageSource, /useCase\.loadThread\(this\.chatId, this\.messageId\)/);
  assert.match(pageSource, /useCase\.loadHistory\(this\.chatId, this\.messageId, this\.nextCursor, 0, THREAD_PAGE_SIZE\)/);
  assert.match(pageSource, /this\.comments = this\.comments\.concat\(page\.comments\)/);
  assert.match(pageSource, /\.onReachEnd\(\(\) => \{/);
  assert.match(pageSource, /this\.pageLifecycleToken/, 'stale responses are dropped');
  assert.match(pageSource, /comments_empty/);
  assert.match(pageSource, /comments_load_failed/);
  assert.ok(pageSource.split('\n').length <= 500, 'page stays within the owner ceiling');

  const routeParams = read('ui/pages/chat/messageThreadRoute.ets');
  assert.match(routeParams, /export class MessageThreadRouteParams/);
  for (const field of ['chatId', 'messageId', 'title', 'replyCount']) {
    assert.ok(routeParams.includes(field), 'route param ' + field);
  }
  const routes = JSON.parse(fs.readFileSync(
    path.join(root, '../resources/base/profile/route_map.json'), 'utf8'));
  const route = routes.routerMap.find((item) => item.name === 'TgMessageThreadPage');
  assert.ok(route, 'the thread route is registered');
  assert.equal(route.buildFunction, 'TgMessageThreadPageBuilder');
  assert.equal(route.pageSourceFile, 'src/main/ets/ui/pages/chat/TgMessageThreadPage.ets');
  for (const locale of ['base', 'ru_RU', 'zh_CN']) {
    const strings = JSON.parse(fs.readFileSync(
      path.join(root, '../resources/' + locale + '/element/string.json'), 'utf8'));
    for (const name of ['comments_title', 'comments_count', 'comments_empty', 'comments_load_failed']) {
      assert.ok(strings.string.find((item) => item.name === name), locale + ' has ' + name);
    }
  }

  // Id validation ---------------------------------------------------------------------------------
  assert.equal(U.isValidThreadMessageId('9007199254740993'), true);
  assert.equal(U.isValidThreadMessageId('0'), false);
  assert.equal(U.isValidThreadMessageId('-5'), false);
  assert.equal(U.isValidThreadMessageId('x'), false);
  assert.equal(U.MESSAGE_THREAD_MAX_LIMIT, 100);

  // Use case --------------------------------------------------------------------------------------
  const sent = [];
  const useCase = new U.MessageThreadUseCase({
    send: (command) => {
      sent.push(command);
      if (command.type === 'getMessageThread') {
        return Promise.resolve(TdObject.fromJSON(JSON.stringify({
          '@type': 'messageThreadInfo', chat_id: 42, message_thread_id: '100',
          reply_info: { '@type': 'messageReplyInfo', reply_count: 2 },
          unread_message_count: 1,
          messages: [{ '@type': 'message', id: '101' }]
        })));
      }
      return Promise.resolve(TdObject.fromJSON(JSON.stringify({
        '@type': 'messages', total_count: 2, next_offset: '0',
        messages: [{ '@type': 'message', id: '102' }]
      })));
    }
  });

  const loaded = await useCase.loadThread(42, '100');
  assert.equal(sent.at(-1).type, 'getMessageThread');
  assert.equal(loaded.threadId, '100');
  assert.equal(loaded.replyCount, 2);
  assert.equal(loaded.unreadCount, 1);
  assert.deepEqual(loaded.messageIds, ['101']);

  const page = await useCase.loadHistory(42, '100', '0', 0, 50);
  assert.equal(sent.at(-1).type, 'getMessageThreadHistory');
  assert.equal(page.chatId, 42);
  assert.equal(page.threadId, '100');
  assert.deepEqual(page.messageIds, ['102']);
  assert.equal(page.nextFromMessageId, '0');

  const before = sent.length;
  await assert.rejects(() => useCase.loadThread(0, '100'), /Invalid chatId/);
  await assert.rejects(() => useCase.loadThread(42, '0'), /Invalid messageId/);
  await assert.rejects(() => useCase.loadHistory(42, '100', 'x'), /Invalid fromMessageId/);
  await assert.rejects(() => useCase.loadHistory(42, '100', '0', -1), /Invalid offset/);
  await assert.rejects(() => useCase.loadHistory(42, '100', '0', 101), /Invalid offset/);
  await assert.rejects(() => useCase.loadHistory(42, '100', '0', 0, 0), /Invalid limit/);
  await assert.rejects(() => useCase.loadHistory(42, '100', '0', 0, 101), /Invalid limit/);
  assert.equal(sent.length, before, 'invalid input never reaches the gateway');
  await assert.rejects(() => new U.MessageThreadUseCase(
    { send: () => Promise.reject(new Error('native status')) }).loadThread(42, '100'),
    /Failed to load the comments/);
  await assert.rejects(() => new U.MessageThreadUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')) }).loadThread(42, '100'),
    /Unsupported thread response/);
  await assert.rejects(() => new U.MessageThreadUseCase(
    { send: () => Promise.reject(new Error('native status')) }).loadHistory(42, '100'),
    /Failed to load the comments/);
  await assert.rejects(() => new U.MessageThreadUseCase(
    { send: () => Promise.resolve(TdObject.fromJSON('{"@type":"ok"}')) }).loadHistory(42, '100'),
    /Unsupported thread history response/);

  console.log('PASS message thread contract');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
