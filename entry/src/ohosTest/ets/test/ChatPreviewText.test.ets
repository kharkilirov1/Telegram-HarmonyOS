import { describe, expect, it } from '@ohos/hypium';
import {
  chatPreviewKindFromBracket,
  chatPreviewKindFromContentType,
  chatPreviewKindFromServiceType,
  chatPreviewKindFromTypingAction
} from '../../../main/ets/ui/pages/chatlist/ChatItemVO';

export default function chatPreviewTextTest() {
  describe('ChatPreviewText', () => {
    it('maps TDLib bracket media placeholders to stable localized kinds', 0, () => {
      expect(chatPreviewKindFromBracket('[Photo]')).assertEqual('photo');
      expect(chatPreviewKindFromBracket('[Photo album]')).assertEqual('album');
      expect(chatPreviewKindFromBracket('[Sticker]')).assertEqual('sticker');
      expect(chatPreviewKindFromBracket('[Voice message]')).assertEqual('voice');
      expect(chatPreviewKindFromBracket('[Unsupported]')).assertEqual('unsupported');
      expect(chatPreviewKindFromBracket('[UnknownFutureType]')).assertEqual('');
    });

    it('maps bracket service placeholders instead of leaking raw type names', 0, () => {
      expect(chatPreviewKindFromBracket('[ChatAddMembers]')).assertEqual('joinedGroup');
      expect(chatPreviewKindFromBracket('[ChatDeleteMember]')).assertEqual('leftGroup');
      expect(chatPreviewKindFromBracket('[PinMessage]')).assertEqual('pinnedMessage');
      expect(chatPreviewKindFromBracket('[ContactRegistered]')).assertEqual('joinedTelegram');
    });

    it('keeps loaded-message content fallbacks aligned with bracket previews', 0, () => {
      expect(chatPreviewKindFromContentType('document')).assertEqual('file');
      expect(chatPreviewKindFromContentType('animation')).assertEqual('gif');
      expect(chatPreviewKindFromContentType('videoNote')).assertEqual('videoNote');
      expect(chatPreviewKindFromContentType('poll')).assertEqual('poll');
      expect(chatPreviewKindFromContentType('futureType')).assertEqual('message');
    });

    it('covers service and volatile typing states without English UI literals', 0, () => {
      expect(chatPreviewKindFromServiceType('messageChatJoinByLink')).assertEqual('joinedGroup');
      expect(chatPreviewKindFromServiceType('messageChatChangePhoto')).assertEqual('chatUpdated');
      expect(chatPreviewKindFromServiceType('messageFutureService')).assertEqual('');
      expect(chatPreviewKindFromTypingAction('uploadingDocument')).assertEqual('sendingFile');
      expect(chatPreviewKindFromTypingAction('recordingVideoNote')).assertEqual('recordingVideoNote');
      expect(chatPreviewKindFromTypingAction('futureAction')).assertEqual('typing');
    });
  });
}
