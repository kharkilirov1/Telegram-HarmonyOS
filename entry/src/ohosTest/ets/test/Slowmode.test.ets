import { describe, it, expect } from '@ohos/hypium';
import { AppState, Chat, createInitialAppState } from '../../../main/ets/core/model/AppState';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { GroupAccessDto, GroupMemberRole, GroupSendPermissionsDto } from '../../../main/ets/core/model/dto/GroupAccessDto';
import { appReducer } from '../../../main/ets/core/reducers/index';
import { AppStore } from '../../../main/ets/core/store/AppStore';
import { registerChatHandlers } from '../../../main/ets/core/events/normalizers/ChatNormalizer';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { ChatScreenSession } from '../../../main/ets/ui/pages/chat/ChatScreenSession';
import { ChatScreenViewState } from '../../../main/ets/ui/pages/chat/ChatScreenViewState';
import { CustomEmojiTextEntity } from '../../../main/ets/core/model/AppCommand';
import { SendMessageUseCase } from '../../../main/ets/domain/usecases/sendMessage';
import { SendMediaMessageUseCase } from '../../../main/ets/domain/usecases/sendMediaMessage';
import { ChatComposerController, ChatComposerControllerHost } from '../../../main/ets/ui/pages/chat/ChatComposerController';
import { ForwardMessagesUseCase } from '../../../main/ets/domain/usecases/forwardMessages';
import { TgAttachmentRecentItem } from '../../../main/ets/ui/tg_ui/atoms/TgAttachmentSheet';
import { WriteGateway, settleWrites } from './WritePathErrors.test';

export class SlowmodePreparation {
  kind: string;
  uri: string;
  path: string;
  resolve?: (value: string) => void;
  constructor(kind: string, uri: string, index: number) {
    this.kind = kind; this.uri = uri; this.path = '/fixture/slowmode-' + index.toString();
  }
}
export class SlowmodeComposer extends ChatComposerController {
  preparations: SlowmodePreparation[] = [];
  discarded: string[] = [];
  deferPreparation: boolean = false;
  recentLoads: number = 0;
  async loadRecentAttachmentMedia(_host: ChatComposerControllerHost): Promise<TgAttachmentRecentItem[]> {
    this.recentLoads++; return [];
  }
  protected preparePickedAttachmentLocalPath(kind: string, uri: string, _host: ChatComposerControllerHost): Promise<string> {
    const item = new SlowmodePreparation(kind, uri, this.preparations.length); this.preparations.push(item);
    if (!this.deferPreparation) return Promise.resolve(item.path);
    return new Promise<string>((resolve) => { item.resolve = resolve; });
  }
  protected discardPreparedAttachment(path: string): void { this.discarded.push(path); }
}

export class SlowmodeFixture {
  store: AppStore;
  page: ChatScreenSession;
  gateway: WriteGateway = new WriteGateway();
  composer: SlowmodeComposer = new SlowmodeComposer();
  constructor(role: GroupMemberRole = 'member', type: 'supergroup' | 'group' | 'private' = 'supergroup',
    view: ChatScreenViewState = new ChatScreenViewState(), uiContextCallback?: () => UIContext, session?: ChatScreenSession) {
    const state: AppState = createInitialAppState();
    const chat = new Chat(); chat.id = 42; chat.type = type; chat.supergroupId = 77; chat.basicGroupId = 77;
    chat.canSendBasicMessages = true;
    chat.sendPermissions = GroupSendPermissionsDto.fromTd(TdObject.fromJSON(
      '{"can_send_basic_messages":true,"can_send_audios":true,"can_send_documents":true,' +
      '"can_send_photos":true,"can_send_videos":true,"can_send_video_notes":true,' +
      '"can_send_voice_notes":true,"can_send_polls":true,"can_send_other_messages":true}'));
    const access = new GroupAccessDto(); access.groupId = 77; access.role = role; access.isMember = true;
    access.kind = type === 'group' ? 'basicGroup' : 'supergroup'; access.isActive = true;
    state.chats.chats.set(42, chat);
    if (type === 'group') state.chats.basicGroupAccess.set(77, access);
    else state.chats.supergroupAccess.set(77, access);
    this.store = new AppStore(appReducer, state, false);
    this.page = session ?? new ChatScreenSession(view, (): UIContext => {
      if (uiContextCallback !== undefined) return uiContextCallback();
      throw new Error('No UI presentation is expected in this policy callback');
    }, () => undefined);
    this.page.accountStore = this.store.createScope(); this.page.activeChatId = 42;
    this.page.sendUseCase = new SendMessageUseCase(this.gateway);
    this.page.sendMediaUseCase = new SendMediaMessageUseCase(this.gateway);
    this.page.forwardUseCase = new ForwardMessagesUseCase(this.gateway);
    this.page.composerCtrl = this.composer;
    this.page.composerAllowedKinds = ['text', 'audio', 'document', 'photo', 'video', 'videoNote', 'voice', 'poll', 'other'];
    this.page.composerDraftText = '\uD83D\uDE00 preserved draft';
    this.page.customEmojiDraftEntities = [new CustomEmojiTextEntity(0, 2, '123')];
    this.page.composerSelectionStart = 2; this.page.composerSelectionEnd = 4; this.page.replyToMessageId = '55';
  }

  async updateFullInfo(expires: string = '10.5', my: number = 0, threshold: number = 0, groupId: number = 77): Promise<void> {
    const handlers = new Map<string, (events: AnyAppEvent[], update: TdObject) => void>();
    registerChatHandlers(handlers);
    const events: AnyAppEvent[] = [];
    const handler = handlers.get('updateSupergroupFullInfo');
    if (handler === undefined) throw new Error('Existing full-info update handler missing');
    handler(events, TdObject.fromJSON('{"@type":"updateSupergroupFullInfo","supergroup_id":' + groupId.toString() +
      ',"supergroup_full_info":{"@type":"supergroupFullInfo","slow_mode_delay":30,"slow_mode_delay_expires_in":' +
      expires + ',"my_boost_count":' + my.toString() + ',"unrestrict_boost_count":' + threshold.toString() + '}}'));
    await this.store.dispatchBatch(events);
  }
}

export function expectSlowmodeInputPreserved(f: SlowmodeFixture): void {
  expect(f.page.composerDraftText).assertEqual('\uD83D\uDE00 preserved draft');
  expect(f.page.replyToMessageId).assertEqual('55');
  expect(f.page.customEmojiDraftEntities.length).assertEqual(1);
  expect(f.page.customEmojiDraftEntities[0].customEmojiId).assertEqual('123');
  expect(f.page.composerSelectionStart).assertEqual(2); expect(f.page.composerSelectionEnd).assertEqual(4);
  expect(f.gateway.trace.length).assertEqual(0);
}

export default function slowmodeTest(): void {
  describe('Slowmode', () => {
    it('authoritative full-info cooldown reaches the existing per-kind send gate and preserves input', 0, async () => {
      const f = new SlowmodeFixture(); await f.updateFullInfo();
      const kinds: string[] = ['', 'text', 'photo', 'video', 'document', 'voice', 'audio', 'videoNote', 'poll', 'other', 'attachment'];
      for (const kind of kinds) expect(f.page.canSendNewMessages(kind)).assertEqual(false);
      expect(f.page.composerCanSubmit()).assertEqual(false); expectSlowmodeInputPreserved(f);
    });
    it('zero unrestrict threshold is not a slowmode exemption even for a high boost count', 0, async () => {
      const f = new SlowmodeFixture(); await f.updateFullInfo('10.5', 99, 0);
      expect(f.page.canSendNewMessages('text')).assertEqual(false); expectSlowmodeInputPreserved(f);
    });
    it('a below-threshold booster remains subject to the authoritative cooldown', 0, async () => {
      const f = new SlowmodeFixture(); await f.updateFullInfo('10.5', 2, 3);
      expect(f.page.canSendNewMessages('document')).assertEqual(false); expectSlowmodeInputPreserved(f);
    });
    for (const role of ['creator', 'administrator'] as GroupMemberRole[]) {
      it(role + ' bypasses cooldown without changing the composer or sending', 0, async () => {
        const f = new SlowmodeFixture(role); await f.updateFullInfo();
        expect(f.page.canSendNewMessages('text')).assertEqual(true);
        expect(f.page.canSendNewMessages('attachment')).assertEqual(true); expectSlowmodeInputPreserved(f);
      });
    }
    it('known qualifying positive boost threshold bypasses cooldown without an automatic send', 0, async () => {
      const f = new SlowmodeFixture(); await f.updateFullInfo('10.5', 3, 3);
      expect(f.page.canSendNewMessages('text')).assertEqual(true);
      expect(f.page.canSendNewMessages('attachment')).assertEqual(true); expectSlowmodeInputPreserved(f);
    });
    it('edit-message permission and its submit action bypass new-message cooldown', 0, async () => {
      const f = new SlowmodeFixture(); await f.updateFullInfo();
      f.page.isEditingMessage = true; f.page.editingMessageId = '901';
      expect(f.page.canUseComposer(true)).assertEqual(true);
      expect(f.page.composerCanSubmit()).assertEqual(true); expectSlowmodeInputPreserved(f);
    });
    for (const type of ['group', 'private'] as Array<'group' | 'private'>) {
      it(type + ' ignores unrelated supergroup cooldown metadata', 0, async () => {
        const f = new SlowmodeFixture('member', type); await f.updateFullInfo();
        expect(f.page.canSendNewMessages('text')).assertEqual(true); expectSlowmodeInputPreserved(f);
      });
    }
    it('authoritative zero expiry allows a manual send but never sends automatically', 0, async () => {
      const f = new SlowmodeFixture(); await f.updateFullInfo('0');
      expect(f.page.canSendNewMessages('text')).assertEqual(true); expectSlowmodeInputPreserved(f);
    });
    it('another group update cannot restrict the current group', 0, async () => {
      const f = new SlowmodeFixture(); await f.updateFullInfo('10.5', 0, 0, 78);
      expect(f.page.canSendNewMessages('text')).assertEqual(true); expectSlowmodeInputPreserved(f);
    });
    it('malformed relative duration cannot create an invented cooldown', 0, async () => {
      const f = new SlowmodeFixture(); await f.updateFullInfo('"10.5"');
      expect(f.page.canSendNewMessages('text')).assertEqual(true); expectSlowmodeInputPreserved(f);
    });
    it('the public text controller cannot bypass the existing cooldown gate', 0, async () => {
      const f = new SlowmodeFixture(); await f.updateFullInfo();
      f.composer.handleSendMessage(f.page.composerDraftText, f.page); await settleWrites();
      expect(f.gateway.requests.length).assertEqual(0); expect(f.page.isSending).assertEqual(false);
      expectSlowmodeInputPreserved(f);
    });
    const mediaKinds: string[] = ['photo', 'document', 'video'];
    for (const kind of mediaKinds) {
      it(kind + ' preparation and public dispatch are blocked without clearing existing selection', 0, async () => {
        const f = new SlowmodeFixture(); await f.updateFullInfo();
        f.page.setPendingAttachmentState(kind, kind, kind, ['file:///a', 'file:///b']);
        f.composer.handleSendMessage(f.page.composerDraftText, f.page); await settleWrites();
        expect(f.composer.preparations.length).assertEqual(0); expect(f.gateway.requests.length).assertEqual(0);
        expect(f.page.pendingAttachmentUris.join('|')).assertEqual('file:///a|file:///b');
        expect(f.page.isSending).assertEqual(false); expectSlowmodeInputPreserved(f);
      });
    }
    it('selected photo reorder removal and Cancel remain editable during cooldown', 0, async () => {
      const f = new SlowmodeFixture(); await f.updateFullInfo();
      f.page.setPendingAttachmentState('photo', 'photos', 'photos', ['file:///a', 'file:///b', 'file:///c']);
      f.composer.movePendingPhoto('file:///b', -1, f.page);
      expect(f.page.pendingAttachmentUris.join('|')).assertEqual('file:///b|file:///a|file:///c');
      f.composer.removePendingPhoto('file:///a', f.page);
      expect(f.page.pendingAttachmentUris.join('|')).assertEqual('file:///b|file:///c');
      f.composer.clearPendingAttachment(f.page); expect(f.page.pendingAttachmentUris.length).assertEqual(0);
      expect(f.composer.preparations.length).assertEqual(0); expectSlowmodeInputPreserved(f);
    });
  });
}
