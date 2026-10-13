import { describe, it, expect } from '@ohos/hypium';
import {
  createCancelDownloadFileCommand,
  createDeleteMessagesCommand,
  createDownloadFileCommand,
  createEditMessageTextCommand,
  createEditMessageCaptionCommand,
  createForwardMessagesCommand,
  createGetFavoriteStickersCommand,
  createGetPremiumStickersCommand,
  createGetInstalledCustomEmojiSetsCommand,
  createGetTrendingCustomEmojiSetsCommand,
  createGetChatPinnedMessageCommand,
  createGetMessageCommand,
  createGetSupergroupFullInfoCommand,
  createGetBasicGroupFullInfoCommand,
  createGetRepliedMessageCommand,
  createGetChatHistoryCommand,
  createLoadChatsCommand,
  createLoadActiveStoriesCommand,
  createAddChatToListCommand,
  createJoinChatCommand,
  createPinChatMessageCommand,
  createPrivateChatCommand,
  createImportContactsCommand,
  createNewBasicGroupChatCommand,
  createNewSupergroupChatCommand,
  createRequestPasswordRecoveryCommand,
  createSendMediaMessageCommand,
  createSendMessageCommand,
  createSearchCallMessagesCommand,
  createSearchChatsOnServerCommand,
  createSearchContactsCommand,
  createSearchPublicChatsCommand,
  createSearchChatMembersCommand,
  createGetSupergroupMembersCommand,
  createSearchEmojisCommand,
  createSearchCustomEmojiStickersCommand,
  createSearchRegularStickersCommand,
  createGetOptionCommand,
  createSearchPublicChatCommand,
  createGetInlineQueryResultsCommand,
  createSendInlineQueryResultCommand,
  createSetChatDraftCommand,
  createSetChatMuteCommand,
  createToggleChatPinnedCommand,
  createToggleChatIsMarkedAsUnreadCommand,
  createViewMessagesCommand,
  EditMessageEntity,
  EditMessageLinkPreviewOptions,
  CustomEmojiTextEntity,
  ImportedContactInput
} from '../../../main/ets/core/model/AppCommand';
import {
  buildTdlibRequestJson,
  SerializedCommand,
  serializeCommand
} from '../../../main/ets/infra/td/serialization/CommandSerializer';
import { TdObject } from '../../../main/ets/models/TdTypes';

/**
 * Unit tests for CommandSerializer.
 * Covers the handler-dispatch refactor without requiring native TDLib.
 */
export default function commandSerializerTest() {
  describe('CommandSerializer', () => {

    describe('dispatch handlers', () => {
      it('should serialize simple auth and list commands', 0, () => {
        const recovery = serializeCommand(createRequestPasswordRecoveryCommand());
        expect(recovery.method).assertEqual('requestAuthenticationPasswordRecovery');

        const loadChats = serializeCommand(createLoadChatsCommand(35));
        expect(loadChats.method).assertEqual('loadChats');
        expect(loadChats.params.getNumber('limit')).assertEqual(35);
        expect(loadChats.params.getString('_chat_list_json')).assertEqual('{"@type":"chatListMain"}');

        const loadArchive = serializeCommand(createLoadChatsCommand(50, 'archive'));
        expect(loadArchive.method).assertEqual('loadChats');
        expect(loadArchive.params.getNumber('limit')).assertEqual(50);
        expect(loadArchive.params.getString('_chat_list_json')).assertEqual('{"@type":"chatListArchive"}');

        const loadStories = serializeCommand(createLoadActiveStoriesCommand());
        expect(loadStories.method).assertEqual('loadActiveStories');
        expect(loadStories.params.getString('_story_list_json')).assertEqual('{"@type":"storyListMain"}');

        const unarchive = serializeCommand(createAddChatToListCommand(123, 'main'));
        expect(unarchive.method).assertEqual('addChatToList');
        expect(unarchive.params.getNumber('chat_id')).assertEqual(123);
        expect(unarchive.params.getString('_chat_list_json')).assertEqual('{"@type":"chatListMain"}');
      });

      it('should serialize both group full-info requests with their TDLib ids', 0, () => {
        const supergroup = serializeCommand(createGetSupergroupFullInfoCommand(777));
        expect(supergroup.method).assertEqual('getSupergroupFullInfo');
        expect(supergroup.params.getNumber('supergroup_id')).assertEqual(777);

        const basicGroup = serializeCommand(createGetBasicGroupFullInfoCommand(90));
        expect(basicGroup.method).assertEqual('getBasicGroupFullInfo');
        expect(basicGroup.params.getNumber('basic_group_id')).assertEqual(90);
      });

      it('should serialize createPrivateChat with force=false by default', 0, () => {
        const standard = serializeCommand(createPrivateChatCommand(42));
        expect(standard.method).assertEqual('createPrivateChat');
        expect(standard.params.getNumber('user_id')).assertEqual(42);
        expect(standard.params.getBool('force')).assertFalse();

        const forced = serializeCommand(createPrivateChatCommand(42, true));
        expect(forced.method).assertEqual('createPrivateChat');
        expect(forced.params.getBool('force')).assertTrue();
      });

      it('should serialize the three typed Compose peer-search sources', 0, () => {
        const contacts = serializeCommand(createSearchContactsCommand('alice', 17));
        expect(contacts.method).assertEqual('searchContacts');
        expect(contacts.params.getString('query')).assertEqual('alice');
        expect(contacts.params.getNumber('limit')).assertEqual(17);

        const known = serializeCommand(createSearchChatsOnServerCommand('alice', 19));
        expect(known.method).assertEqual('searchChatsOnServer');
        expect(known.params.getString('query')).assertEqual('alice');
        expect(known.params.getNumber('limit')).assertEqual(19);

        const global = serializeCommand(createSearchPublicChatsCommand('alice'));
        expect(global.method).assertEqual('searchPublicChats');
        expect(global.params.getString('query')).assertEqual('alice');
      });

      it('should serialize contact, group and channel creation contracts', 0, () => {
        const imported = serializeCommand(createImportContactsCommand([
          new ImportedContactInput('+123', 'Ali"ce', 'Smith')
        ]));
        expect(imported.method).assertEqual('importContacts');
        expect(imported.params.getString('_contacts_json'))
          .assertEqual('[{"@type":"importedContact","phone_number":"+123",' +
            '"first_name":"Ali\\"ce","last_name":"Smith","note":null}]');
        const importRequest = buildTdlibRequestJson(imported.method, imported.params);
        expect(importRequest.indexOf('"contacts":[{"@type":"importedContact"') >= 0).assertTrue();
        expect(importRequest.indexOf('"note":null') >= 0).assertTrue();

        const group = serializeCommand(createNewBasicGroupChatCommand([11, 12], 'Group', 0));
        expect(group.method).assertEqual('createNewBasicGroupChat');
        expect(group.params.getString('_user_ids_json')).assertEqual('[11,12]');
        expect(group.params.getString('title')).assertEqual('Group');
        expect(group.params.getNumber('message_auto_delete_time')).assertEqual(0);

        const channel = serializeCommand(createNewSupergroupChatCommand(
          'Channel', false, true, 'Description', 0, false
        ));
        expect(channel.method).assertEqual('createNewSupergroupChat');
        expect(channel.params.getBool('is_forum')).assertFalse();
        expect(channel.params.getBool('is_channel')).assertTrue();
        expect(channel.params.getString('_location_json')).assertEqual('null');
        expect(channel.params.getBool('for_import')).assertFalse();
      });

      it('should serialize chat mutation commands', 0, () => {
        const mute = serializeCommand(createSetChatMuteCommand(100, 3600));
        expect(mute.method).assertEqual('setChatNotificationSettings');
        expect(mute.params.getNumber('chat_id')).assertEqual(100);
        expect(mute.params.getString('_notification_settings_json')
          .indexOf('"mute_for":3600') >= 0).assertTrue();

        const pin = serializeCommand(createToggleChatPinnedCommand(100, true));
        expect(pin.method).assertEqual('toggleChatIsPinned');
        expect(pin.params.getNumber('chat_id')).assertEqual(100);
        expect(pin.params.getBool('is_pinned')).assertTrue();
        expect(pin.params.getString('_chat_list_json')).assertEqual('{"@type":"chatListMain"}');

        const archivePin = serializeCommand(createToggleChatPinnedCommand(100, true, 'archive'));
        expect(archivePin.params.getString('_chat_list_json')).assertEqual('{"@type":"chatListArchive"}');

        const unread = serializeCommand(createToggleChatIsMarkedAsUnreadCommand(100, true));
        expect(unread.method).assertEqual('toggleChatIsMarkedAsUnread');
        expect(unread.params.getBool('is_marked_as_unread')).assertTrue();
      });

      it('should serialize joinChat with chat_id (td_api.tl:12010)', 0, () => {
        const join = serializeCommand(createJoinChatCommand(-1001234567890));
        expect(join.method).assertEqual('joinChat');
        expect(join.params.getNumber('chat_id')).assertEqual(-1001234567890);
      });

      it('should serialize chat draft with reply_to object and explicit clear', 0, () => {
        // draftMessage.reply_to is an InputMessageReplyTo OBJECT (td_api.tl 2997);
        // the old flat reply_to_message_id field is silently dropped by TDLib
        const withReply = serializeCommand(createSetChatDraftCommand(100, 'draft "text"', '555'));
        expect(withReply.method).assertEqual('setChatDraftMessage');
        expect(withReply.params.getNumber('chat_id')).assertEqual(100);
        const draftJson = withReply.params.getString('_draft_message_json');
        expect(draftJson.indexOf('"@type":"draftMessage"') >= 0).assertTrue();
        expect(draftJson.indexOf('"reply_to":{"@type":"inputMessageReplyToMessage","message_id":555}') >= 0)
          .assertTrue();
        expect(draftJson.indexOf('draft \\"text\\"') >= 0).assertTrue();

        const noReply = serializeCommand(createSetChatDraftCommand(100, 'plain', '0'));
        expect(noReply.params.getString('_draft_message_json').indexOf('reply_to') < 0).assertTrue();

        const cleared = serializeCommand(createSetChatDraftCommand(100, '   ', '555'));
        expect(cleared.params.getString('_draft_message_json')).assertEqual('null');
      });

      it('should serialize message send with reply raw json', 0, () => {
        const serialized = serializeCommand(createSendMessageCommand(200, 'hello "world"', '99'));

        expect(serialized.method).assertEqual('sendMessage');
        expect(serialized.params.getNumber('chat_id')).assertEqual(200);
        const content = serialized.params.getString('_input_message_content_json');
        expect(content.indexOf('"@type":"inputMessageText"') >= 0).assertTrue();
        expect(content.indexOf('hello \\"world\\"') >= 0).assertTrue();
        expect(serialized.params.getString('_reply_to_json'))
          .assertEqual('{"@type":"inputMessageReplyToMessage","message_id":99}');
      });

      it('should preserve custom emoji int64 entities in messages and drafts', 0, () => {
        const entity = new CustomEmojiTextEntity(2, 2, '5368324170671202286');
        const serialized = serializeCommand(createSendMessageCommand(200, 'x 😀', '0', [entity]));
        const content = serialized.params.getString('_input_message_content_json');
        expect(content.indexOf('"@type":"textEntityTypeCustomEmoji"') >= 0).assertTrue();
        expect(content.indexOf('"offset":2,"length":2') >= 0).assertTrue();
        expect(content.indexOf('"custom_emoji_id":5368324170671202286') >= 0).assertTrue();

        const draft = serializeCommand(createSetChatDraftCommand(200, 'x 😀', '0', [entity]));
        expect(draft.params.getString('_draft_message_json')
          .indexOf('"custom_emoji_id":5368324170671202286') >= 0).assertTrue();
      });

      it('should serialize media send as TDLib sendMessage content', 0, () => {
        const serialized = serializeCommand(createSendMediaMessageCommand(
          200,
          'photo',
          '/data/storage/el2/base/files/p.jpg',
          'caption',
          '88'
        ));

        expect(serialized.method).assertEqual('sendMessage');
        const content = serialized.params.getString('_input_message_content_json');
        expect(content.indexOf('"@type":"inputMessagePhoto"') >= 0).assertTrue();
        expect(content.indexOf('"@type":"inputFileLocal"') >= 0).assertTrue();
        expect(content.indexOf('/data/storage/el2/base/files/p.jpg') >= 0).assertTrue();
        expect(content.indexOf('"caption"') >= 0).assertTrue();
        expect(serialized.params.getString('_reply_to_json'))
          .assertEqual('{"@type":"inputMessageReplyToMessage","message_id":88}');
      });

      it('should serialize a recorded M4A as TDLib inputMessageVoiceNote', 0, () => {
        const serialized = serializeCommand(createSendMediaMessageCommand(
          200,
          'voice',
          '/data/storage/el2/base/files/tg_voice_1.m4a',
          '',
          '88',
          7,
          ''
        ));

        expect(serialized.method).assertEqual('sendMessage');
        const content = serialized.params.getString('_input_message_content_json');
        expect(content.indexOf('"@type":"inputMessageVoiceNote"') >= 0).assertTrue();
        expect(content.indexOf('"duration":7') >= 0).assertTrue();
        expect(content.indexOf('"waveform":""') >= 0).assertTrue();
        expect(content.indexOf('tg_voice_1.m4a') >= 0).assertTrue();
      });

      it('should serialize edit/delete/forward/pin message commands', 0, () => {
        const edit = serializeCommand(createEditMessageTextCommand(1, '900', 'new text'));
        expect(edit.method).assertEqual('editMessageText');
        expect(edit.params.getString('_message_id_json')).assertEqual('900');
        expect(edit.params.getString('_input_message_content_json').indexOf('new text') >= 0).assertTrue();

        const deleteMessages = serializeCommand(createDeleteMessagesCommand(1, ['900', '901'], true));
        expect(deleteMessages.method).assertEqual('deleteMessages');
        expect(deleteMessages.params.getString('_message_ids_json')).assertEqual('[900,901]');
        expect(deleteMessages.params.getBool('revoke')).assertTrue();

        const forward = serializeCommand(createForwardMessagesCommand(2, 1, ['900'], true, false));
        expect(forward.method).assertEqual('forwardMessages');
        expect(forward.params.getNumber('chat_id')).assertEqual(2);
        expect(forward.params.getNumber('from_chat_id')).assertEqual(1);
        expect(forward.params.getString('_message_ids_json')).assertEqual('[900]');
        expect(forward.params.getBool('send_copy')).assertTrue();

        const pin = serializeCommand(createPinChatMessageCommand(1, '900', true, true));
        expect(pin.method).assertEqual('pinChatMessage');
        expect(pin.params.getString('_message_id_json')).assertEqual('900');
        expect(pin.params.getBool('disable_notification')).assertTrue();
        expect(pin.params.getBool('only_for_self')).assertTrue();
      });

      it('should serialize nonempty editMessageCaption with exact text and above flag', 0, () => {
        const text = '  Подпись "quoted" \\\nline\r\ttab  ';
        const aboveFlags: boolean[] = [false, true];
        for (const above of aboveFlags) {
          const command = createEditMessageCaptionCommand(-1001234567890, '900', text, above);
          expect(command.type).assertEqual('editMessageCaption');
          expect(command.payload.caption).assertEqual(text);
          expect(command.payload.showCaptionAboveMedia).assertEqual(above);
          const edit = serializeCommand(command);
          expect(edit.method).assertEqual('editMessageCaption');
          expect(edit.params.get('show_caption_above_media')).assertEqual(above);
          const json = buildTdlibRequestJson(edit.method, edit.params);
          const request = TdObject.fromJSON(json);
          expect(request.getTopLevelStringStrict('@type')).assertEqual('editMessageCaption');
          expect(request.getTopLevelBooleanStrict('show_caption_above_media')).assertEqual(above);
          const caption = request.getTopLevelObjectStrict('caption');
          expect(caption?.getTopLevelStringStrict('@type')).assertEqual('formattedText');
          expect(caption?.getTopLevelStringStrict('text')).assertEqual(text);
          expect(caption?.getTopLevelObjectArrayStrict('entities')?.length).assertEqual(0);
          expect(json.indexOf('"reply_markup"') < 0).assertTrue();
          expect(json.indexOf('"input_message_content"') < 0).assertTrue();
          expect(json.indexOf('"_caption_json"') < 0).assertTrue();
        }
      });

      it('should serialize empty editMessageCaption without losing either above flag', 0, () => {
        const aboveFlags: boolean[] = [false, true];
        for (const above of aboveFlags) {
          const command = createEditMessageCaptionCommand(1, '900', '', above);
          expect(command.payload.caption).assertEqual('');
          expect(command.payload.showCaptionAboveMedia).assertEqual(above);
          const edit = serializeCommand(command);
          expect(edit.method).assertEqual('editMessageCaption');
          expect(edit.params.get('show_caption_above_media')).assertEqual(above);
          const json = buildTdlibRequestJson(edit.method, edit.params);
          const request = TdObject.fromJSON(json);
          const caption = request.getTopLevelObjectStrict('caption');
          expect(caption?.getTopLevelStringStrict('@type')).assertEqual('formattedText');
          expect(caption?.getTopLevelStringStrict('text')).assertEqual('');
          expect(caption?.getTopLevelObjectArrayStrict('entities')?.length).assertEqual(0);
          expect(request.getTopLevelBooleanStrict('show_caption_above_media')).assertEqual(above);
          expect(json.indexOf('"reply_markup"') < 0).assertTrue();
          expect(json.indexOf('"input_message_content"') < 0).assertTrue();
        }
      });

      it('should preserve numeric safe IDs in editMessageCaption wire JSON', 0, () => {
        const edit = serializeCommand(createEditMessageCaptionCommand(
          -9007199254740991, '9007199254740991', 'caption', false
        ));
        expect(edit.method).assertEqual('editMessageCaption');
        expect(edit.params.get('chat_id')).assertEqual(-9007199254740991);
        expect(edit.params.getString('_message_id_json')).assertEqual('9007199254740991');
        const request = TdObject.fromJSON(buildTdlibRequestJson(edit.method, edit.params));
        expect(request.getTopLevelNumberStrict('chat_id')).assertEqual(-9007199254740991);
        expect(request.getTopLevelNumberStrict('message_id')).assertEqual(9007199254740991);
      });

      it('should preserve full server entity types and UTF-16 ranges in both edit commands', 0, () => {
        const text = 'name 😀 code url';
        const entities: EditMessageEntity[] = [
          new EditMessageEntity(0, 4, '{"@type":"textEntityTypeBold"}'),
          new EditMessageEntity(0, 4, '{"@type":"textEntityTypeMentionName","user_id":9007199254740991}'),
          new EditMessageEntity(5, 2, '{"@type":"textEntityTypeCustomEmoji","custom_emoji_id":"5368324170671202286"}'),
          new EditMessageEntity(8, 4, '{"@type":"textEntityTypePreCode","language":"typescript"}'),
          new EditMessageEntity(13, 3, '{"@type":"textEntityTypeTextUrl","url":"https://example.test/?a=\\\"b\\\""}')
        ];
        const edits: SerializedCommand[] = [
          serializeCommand(createEditMessageTextCommand(1, '900', text, entities)),
          serializeCommand(createEditMessageCaptionCommand(1, '900', text, true, entities))
        ];
        for (const edit of edits) {
          const request = TdObject.fromJSON(buildTdlibRequestJson(edit.method, edit.params));
          const formatted = edit.method === 'editMessageCaption'
            ? request.getTopLevelObjectStrict('caption')
            : request.getTopLevelObjectStrict('input_message_content')?.getTopLevelObjectStrict('text');
          expect(formatted?.getTopLevelStringStrict('text')).assertEqual(text);
          const actual = formatted?.getTopLevelObjectArrayStrict('entities');
          expect(actual?.length).assertEqual(entities.length);
          for (let i = 0; i < entities.length; i++) {
            expect(actual?.[i]?.getTopLevelStringStrict('@type')).assertEqual('textEntity');
            expect(actual?.[i]?.getTopLevelNumberStrict('offset')).assertEqual(entities[i].offset);
            expect(actual?.[i]?.getTopLevelNumberStrict('length')).assertEqual(entities[i].length);
          }
          expect(actual?.[0]?.getTopLevelObjectStrict('type')?.getTopLevelStringStrict('@type'))
            .assertEqual('textEntityTypeBold');
          expect(actual?.[1]?.getTopLevelObjectStrict('type')?.getTopLevelNumberStrict('user_id'))
            .assertEqual(9007199254740991);
          expect(actual?.[2]?.getTopLevelObjectStrict('type')?.getTopLevelStringStrict('custom_emoji_id'))
            .assertEqual('5368324170671202286');
          expect(actual?.[3]?.getTopLevelObjectStrict('type')?.getTopLevelStringStrict('language'))
            .assertEqual('typescript');
          expect(actual?.[4]?.getTopLevelObjectStrict('type')?.getTopLevelStringStrict('url'))
            .assertEqual('https://example.test/?a="b"');
        }
      });

      it('should preserve signed int64 custom emoji IDs as exact strings', 0, () => {
        const ids: string[] = ['-9223372036854775808', '9223372036854775807', '-1'];
        for (const id of ids) {
          const entity = new EditMessageEntity(0, 2,
            '{"@type":"textEntityTypeCustomEmoji","custom_emoji_id":"' + id + '"}');
          const edit = serializeCommand(createEditMessageCaptionCommand(1, '900', '😀', true, [entity]));
          const request = TdObject.fromJSON(buildTdlibRequestJson(edit.method, edit.params));
          const actual = request.getTopLevelObjectStrict('caption')?.getTopLevelObjectArrayStrict('entities');
          expect(actual?.[0]?.getTopLevelObjectStrict('type')?.getTopLevelStringStrict('custom_emoji_id'))
            .assertEqual(id);
        }
      });

      it('should snapshot edit entities and preview options without mutating callers', 0, () => {
        const entity = new EditMessageEntity(0, 4, '{"@type":"textEntityTypeBold"}');
        const entities: EditMessageEntity[] = [entity];
        const preview = new EditMessageLinkPreviewOptions(true, 'https://example.test', true, false, true);
        const text = createEditMessageTextCommand(1, '900', 'text', entities, preview);
        const caption = createEditMessageCaptionCommand(1, '900', 'text', false, entities);
        expect(text.payload.entities === entities).assertFalse();
        expect(text.payload.entities[0] === entity).assertFalse();
        expect(caption.payload.entities[0] === entity).assertFalse();
        expect(text.payload.linkPreviewOptions === preview).assertFalse();
        entity.offset = 99;
        entity.typeJson = '{"@type":"textEntityTypeItalic"}';
        entities.length = 0;
        preview.url = 'changed';
        preview.isDisabled = false;
        const serializedText = serializeCommand(text);
        const serializedCaption = serializeCommand(caption);
        const textSnapshot = buildTdlibRequestJson(serializedText.method, serializedText.params);
        const captionSnapshot = buildTdlibRequestJson(serializedCaption.method, serializedCaption.params);
        expect(textSnapshot.indexOf('"@type":"textEntityTypeBold"') >= 0).assertTrue();
        expect(captionSnapshot.indexOf('"@type":"textEntityTypeBold"') >= 0).assertTrue();
        const content = TdObject.fromJSON(textSnapshot).getTopLevelObjectStrict('input_message_content');
        expect(content?.getTopLevelObjectStrict('link_preview_options')?.getTopLevelStringStrict('url'))
          .assertEqual('https://example.test');
        expect(content?.getTopLevelObjectStrict('link_preview_options')?.getTopLevelBooleanStrict('is_disabled'))
          .assertEqual(true);
        expect(entity.offset).assertEqual(99);
        expect(preview.url).assertEqual('changed');
        text.payload.entities[0].offset = 8;
        caption.payload.entities[0].typeJson = '{}';
        expect(buildTdlibRequestJson(serializedText.method, serializedText.params)).assertEqual(textSnapshot);
        expect(buildTdlibRequestJson(serializedCaption.method, serializedCaption.params)).assertEqual(captionSnapshot);
      });

      it('should serialize all explicit link preview options inside inputMessageText', 0, () => {
        const flags: boolean[] = [false, true];
        for (const flag of flags) {
          const url = 'https://example.test/?q="quoted"\nnext';
          const options = new EditMessageLinkPreviewOptions(flag, url, !flag, flag, !flag);
          const edit = serializeCommand(createEditMessageTextCommand(1, '900', 'text', [], options));
          const request = TdObject.fromJSON(buildTdlibRequestJson(edit.method, edit.params));
          const content = request.getTopLevelObjectStrict('input_message_content');
          expect(content?.getTopLevelStringStrict('@type')).assertEqual('inputMessageText');
          expect(content?.getTopLevelBooleanStrict('clear_draft')).assertEqual(true);
          const preview = content?.getTopLevelObjectStrict('link_preview_options');
          expect(preview?.getTopLevelStringStrict('@type')).assertEqual('linkPreviewOptions');
          expect(preview?.getTopLevelStringStrict('url')).assertEqual(url);
          expect(preview?.getTopLevelBooleanStrict('is_disabled')).assertEqual(flag);
          expect(preview?.getTopLevelBooleanStrict('force_small_media')).assertEqual(!flag);
          expect(preview?.getTopLevelBooleanStrict('force_large_media')).assertEqual(flag);
          expect(preview?.getTopLevelBooleanStrict('show_above_text')).assertEqual(!flag);
        }
      });

      it('should retain the exact default edit text path when optional formatting is absent', 0, () => {
        const edit = serializeCommand(createEditMessageTextCommand(1, '900', 'text'));
        expect(edit.params.getString('_input_message_content_json')).assertEqual(
          '{"@type":"inputMessageText","text":{"@type":"formattedText","text":"text","entities":[]},"clear_draft":true}'
        );
        const defaults = new EditMessageLinkPreviewOptions();
        expect(defaults.isDisabled).assertEqual(false);
        expect(defaults.url).assertEqual('');
        expect(defaults.forceSmallMedia).assertEqual(false);
        expect(defaults.forceLargeMedia).assertEqual(false);
        expect(defaults.showAboveText).assertEqual(false);
      });

      it('should reject invalid edit entity ranges instead of silently stripping formatting', 0, () => {
        const typeJson = '{"@type":"textEntityTypeBold"}';
        const invalid: EditMessageEntity[] = [
          new EditMessageEntity(-1, 1, typeJson), new EditMessageEntity(0.5, 1, typeJson),
          new EditMessageEntity(0, 0, typeJson), new EditMessageEntity(0, -1, typeJson),
          new EditMessageEntity(0, 1.5, typeJson), new EditMessageEntity(0, 5, typeJson),
          new EditMessageEntity(4, 1, typeJson), new EditMessageEntity(NaN, 1, typeJson),
          new EditMessageEntity(0, Infinity, typeJson)
        ];
        for (const entity of invalid) {
          let textRejected = false;
          let captionRejected = false;
          try { serializeCommand(createEditMessageTextCommand(1, '900', 'text', [entity])); }
          catch (error) { textRejected = error instanceof Error && error.message === 'Invalid edit message entity range'; }
          try { serializeCommand(createEditMessageCaptionCommand(1, '900', 'text', false, [entity])); }
          catch (error) { captionRejected = error instanceof Error && error.message === 'Invalid edit message entity range'; }
          expect(textRejected).assertTrue();
          expect(captionRejected).assertTrue();
        }
      });

      it('should reject malformed or nonliteral entity types before raw JSON expansion', 0, () => {
        const invalid: string[] = [
          '', 'null', '[]', '{"nested":{"@type":"textEntityTypeBold"}}',
          '{"@type":7}', '{"@type":"sendMessage"}', '{"@type":"textEntityType"}',
          '{"@type":"textEntityTypeBold"},"injected":true',
          '{"@type":"textEntityTypeCustomEmoji","custom_emoji_id":"0"}',
          '{"@type":"textEntityTypeCustomEmoji","custom_emoji_id":"9223372036854775808"}',
          '{"@type":"textEntityTypeCustomEmoji","custom_emoji_id":"-9223372036854775809"}',
          '{"@type":"textEntityTypeCustomEmoji","custom_emoji_id":5368324170671202286}'
        ];
        for (const typeJson of invalid) {
          const entity = new EditMessageEntity(0, 1, typeJson);
          let rejected = false;
          try {
            serializeCommand(createEditMessageTextCommand(1, '900', 'text', [entity]));
          } catch (error) {
            rejected = error instanceof Error && error.message === 'Invalid edit message entity type';
          }
          expect(rejected).assertTrue();
        }
      });

      it('should serialize getMessage with numeric safe IDs', 0, () => {
        const command = createGetMessageCommand(-9007199254740991, '9007199254740991');
        expect(command.type).assertEqual('getMessage');
        expect(command.payload.chatId).assertEqual(-9007199254740991);
        expect(command.payload.messageId).assertEqual('9007199254740991');
        const message = serializeCommand(command);
        expect(message.method).assertEqual('getMessage');
        expect(message.params.get('chat_id')).assertEqual(-9007199254740991);
        expect(message.params.getString('_message_id_json')).assertEqual('9007199254740991');
        const request = TdObject.fromJSON(buildTdlibRequestJson(message.method, message.params));
        expect(request.getTopLevelStringStrict('@type')).assertEqual('getMessage');
        expect(request.getTopLevelNumberStrict('chat_id')).assertEqual(-9007199254740991);
        expect(request.getTopLevelNumberStrict('message_id')).assertEqual(9007199254740991);
      });

      it('should serialize history/view/download commands', 0, () => {
        const pinned = serializeCommand(createGetChatPinnedMessageCommand(-100123));
        expect(pinned.method).assertEqual('getChatPinnedMessage');
        expect(pinned.params.getNumber('chat_id')).assertEqual(-100123);

        const replied = serializeCommand(createGetRepliedMessageCommand(-100123, '9007199254740991'));
        expect(replied.method).assertEqual('getRepliedMessage');
        expect(replied.params.getNumber('chat_id')).assertEqual(-100123);
        expect(replied.params.getString('_message_id_json')).assertEqual('9007199254740991');

        const history = serializeCommand(createGetChatHistoryCommand(1, '700', -10, 50, true));
        expect(history.method).assertEqual('getChatHistory');
        expect(history.params.getString('_from_message_id_json')).assertEqual('700');
        expect(history.params.getNumber('offset')).assertEqual(-10);
        expect(history.params.getBool('only_local')).assertTrue();

        const view = serializeCommand(createViewMessagesCommand(1, ['700', '701']));
        expect(view.method).assertEqual('viewMessages');
        expect(view.params.getString('_message_ids_json')).assertEqual('[700,701]');
        expect(view.params.getBool('force_read')).assertTrue();

        const download = serializeCommand(createDownloadFileCommand(42, 5, true));
        expect(download.method).assertEqual('downloadFile');
        expect(download.params.getNumber('file_id')).assertEqual(42);
        expect(download.params.getNumber('priority')).assertEqual(5);
        expect(download.params.getBool('synchronous')).assertTrue();

        const cancel = serializeCommand(createCancelDownloadFileCommand(42, true));
        expect(cancel.method).assertEqual('cancelDownloadFile');
        expect(cancel.params.getBool('only_if_pending')).assertTrue();

        const favorites = serializeCommand(createGetFavoriteStickersCommand());
        expect(favorites.method).assertEqual('getFavoriteStickers');

        const premium = serializeCommand(createGetPremiumStickersCommand(120));
        expect(premium.method).assertEqual('getPremiumStickers');
        expect(premium.params.getNumber('limit')).assertEqual(100);

        const customEmoji = serializeCommand(createGetInstalledCustomEmojiSetsCommand());
        expect(customEmoji.method).assertEqual('getInstalledStickerSets');
        expect(customEmoji.params.getString('_sticker_type_json'))
          .assertEqual('{"@type":"stickerTypeCustomEmoji"}');

        const trendingCustomEmoji = serializeCommand(createGetTrendingCustomEmojiSetsCommand(-4, 120));
        expect(trendingCustomEmoji.method).assertEqual('getTrendingStickerSets');
        expect(trendingCustomEmoji.params.getString('_sticker_type_json'))
          .assertEqual('{"@type":"stickerTypeCustomEmoji"}');
        expect(trendingCustomEmoji.params.getNumber('offset')).assertEqual(0);
        expect(trendingCustomEmoji.params.getNumber('limit')).assertEqual(100);
      });

      it('should serialize call search using TDLib offset pagination', 0, () => {
        const calls = serializeCommand(createSearchCallMessagesCommand('opaque-offset', 40, true));
        expect(calls.method).assertEqual('searchCallMessages');
        expect(calls.params.getString('offset')).assertEqual('opaque-offset');
        expect(calls.params.getNumber('limit')).assertEqual(40);
        expect(calls.params.getBool('only_missed')).assertTrue();
        expect(calls.params.getString('_from_message_id_json')).assertEqual('');
      });

      it('should serialize generic member search and pageable supergroup members', 0, () => {
        const search = serializeCommand(createSearchChatMembersCommand(-1001, 'alice', 250, 'members'));
        expect(search.method).assertEqual('searchChatMembers');
        expect(search.params.getNumber('chat_id')).assertEqual(-1001);
        expect(search.params.getString('query')).assertEqual('alice');
        expect(search.params.getNumber('limit')).assertEqual(200);
        expect(search.params.getString('_filter_json'))
          .assertEqual('{"@type":"chatMembersFilterMembers"}');

        const page = serializeCommand(createGetSupergroupMembersCommand(77, -5, 120, 'administrators'));
        expect(page.method).assertEqual('getSupergroupMembers');
        expect(page.params.getNumber('supergroup_id')).assertEqual(77);
        expect(page.params.getNumber('offset')).assertEqual(0);
        expect(page.params.getNumber('limit')).assertEqual(120);
        expect(page.params.getString('_filter_json'))
          .assertEqual('{"@type":"supergroupMembersFilterAdministrators"}');
      });

      it('should serialize Unicode and custom emoji keyword search', 0, () => {
        const unicode = serializeCommand(createSearchEmojisCommand('кот', ['ru-RU', 'en-US']));
        expect(unicode.method).assertEqual('searchEmojis');
        expect(unicode.params.getString('text')).assertEqual('кот');
        expect(unicode.params.getString('_input_language_codes_json'))
          .assertEqual('["ru-RU","en-US"]');

        const custom = serializeCommand(createSearchCustomEmojiStickersCommand(
          'кот', ['ru-RU', 'en-US'], '🐱 🐈', 3, 120));
        expect(custom.method).assertEqual('searchStickers');
        expect(custom.params.getString('_sticker_type_json'))
          .assertEqual('{"@type":"stickerTypeCustomEmoji"}');
        expect(custom.params.getString('emojis')).assertEqual('🐱 🐈');
        expect(custom.params.getNumber('offset')).assertEqual(3);
        expect(custom.params.getNumber('limit')).assertEqual(100);

        const regular = serializeCommand(createSearchRegularStickersCommand(
          'кот', ['ru-RU', 'en-US'], '', -2, 120));
        expect(regular.method).assertEqual('searchStickers');
        expect(regular.params.getString('_sticker_type_json'))
          .assertEqual('{"@type":"stickerTypeRegular"}');
        expect(regular.params.getString('query')).assertEqual('кот');
        expect(regular.params.getString('_input_language_codes_json'))
          .assertEqual('["ru-RU","en-US"]');
        expect(regular.params.getNumber('offset')).assertEqual(0);
        expect(regular.params.getNumber('limit')).assertEqual(100);
      });

      it('should serialize GIF inline search and send without int64 precision loss', 0, () => {
        const option = serializeCommand(createGetOptionCommand('animation_search_bot_username'));
        expect(option.method).assertEqual('getOption');
        expect(option.params.getString('name')).assertEqual('animation_search_bot_username');

        const publicChat = serializeCommand(createSearchPublicChatCommand('gif'));
        expect(publicChat.method).assertEqual('searchPublicChat');
        expect(publicChat.params.getString('username')).assertEqual('gif');

        const inline = serializeCommand(createGetInlineQueryResultsCommand(77, 100, 'cats', 'next'));
        expect(inline.method).assertEqual('getInlineQueryResults');
        expect(inline.params.getNumber('bot_user_id')).assertEqual(77);
        expect(inline.params.getString('_user_location_json')).assertEqual('null');
        expect(inline.params.getString('offset')).assertEqual('next');

        const send = serializeCommand(createSendInlineQueryResultCommand(
          100, '5368324170671202286', 'result-1', true));
        expect(send.method).assertEqual('sendInlineQueryResultMessage');
        expect(send.params.getString('_query_id_json')).assertEqual('5368324170671202286');
        expect(send.params.getString('_topic_id_json')).assertEqual('null');
        expect(send.params.getBool('hide_via_bot')).assertTrue();
      });
    });

    describe('buildTdlibRequestJson', () => {
      it('should expand _field_json values as raw nested json', 0, () => {
        const serialized = serializeCommand(createSendMessageCommand(1, 'hello', '500'));
        const json = buildTdlibRequestJson(serialized.method, serialized.params);

        expect(json.indexOf('"@type":"sendMessage"') >= 0).assertTrue();
        expect(json.indexOf('"chat_id":1') >= 0).assertTrue();
        expect(json.indexOf('"input_message_content":{"@type":"inputMessageText"') >= 0).assertTrue();
        expect(json.indexOf('"reply_to":{"@type":"inputMessageReplyToMessage","message_id":500}') >= 0)
          .assertTrue();
      });

      it('should serialize primitive params', 0, () => {
        const params = new TdObject();
        params.setString('query', 'a "quote"');
        params.setNumber('limit', 20);
        params.setBool('only_local', false);

        const json = buildTdlibRequestJson('searchChatMessages', params);
        expect(json.indexOf('"@type":"searchChatMessages"') >= 0).assertTrue();
        expect(json.indexOf('"query":"a \\"quote\\""') >= 0).assertTrue();
        expect(json.indexOf('"limit":20') >= 0).assertTrue();
        expect(json.indexOf('"only_local":false') >= 0).assertTrue();
      });

      it('should keep unknown command safe', 0, () => {
        const command = new SerializedCommand();
        expect(command.method).assertEqual('');
        expect(command.params.isEmpty()).assertTrue();
      });
    });
  });
}
