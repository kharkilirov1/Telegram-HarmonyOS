import { describe, it, expect } from '@ohos/hypium';
import { ChatService } from '../../../main/ets/services/ChatService';

/**
 * Unit tests for ChatService — singleton pattern and service structure.
 * ChatService methods are async TDLib wrappers; we test the singleton
 * contract and method existence.
 */

export default function chatServiceTest() {
  describe('ChatService', () => {

    // -----------------------------------------------------------------------
    // Singleton
    // -----------------------------------------------------------------------
    describe('singleton', () => {

      it('should return the same instance', 0, () => {
        const a = ChatService.getInstance();
        const b = ChatService.getInstance();
        expect(a === b).assertTrue();
      });

      it('should not be null', 0, () => {
        const instance = ChatService.getInstance();
        expect(instance !== null).assertTrue();
        expect(instance !== undefined).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // API surface — ensure methods exist (type-safety)
    // -----------------------------------------------------------------------
    describe('API surface', () => {

      it('should have createPrivateChat method', 0, () => {
        const service = ChatService.getInstance();
        expect(typeof service.createPrivateChat).assertEqual('function');
      });

      it('should have createNewBasicGroupChat method', 0, () => {
        const service = ChatService.getInstance();
        expect(typeof service.createNewBasicGroupChat).assertEqual('function');
      });

      it('should have createNewSupergroupChat method', 0, () => {
        const service = ChatService.getInstance();
        expect(typeof service.createNewSupergroupChat).assertEqual('function');
      });

      it('should have searchChats method', 0, () => {
        const service = ChatService.getInstance();
        expect(typeof service.searchChats).assertEqual('function');
      });

      it('should have muteChat method', 0, () => {
        const service = ChatService.getInstance();
        expect(typeof service.muteChat).assertEqual('function');
      });

      it('should have unmuteChat method', 0, () => {
        const service = ChatService.getInstance();
        expect(typeof service.unmuteChat).assertEqual('function');
      });

      it('should have pinChat method', 0, () => {
        const service = ChatService.getInstance();
        expect(typeof service.pinChat).assertEqual('function');
      });

      it('should have unpinChat method', 0, () => {
        const service = ChatService.getInstance();
        expect(typeof service.unpinChat).assertEqual('function');
      });

      it('should have deleteChatHistory method', 0, () => {
        const service = ChatService.getInstance();
        expect(typeof service.deleteChatHistory).assertEqual('function');
      });

      it('should have markChatAsRead method', 0, () => {
        const service = ChatService.getInstance();
        expect(typeof service.markChatAsRead).assertEqual('function');
      });

      it('should have forwardMessages method', 0, () => {
        const service = ChatService.getInstance();
        expect(typeof service.forwardMessages).assertEqual('function');
      });

      it('should have searchChatMessages method', 0, () => {
        const service = ChatService.getInstance();
        expect(typeof service.searchChatMessages).assertEqual('function');
      });

      it('should have addChatMembers method', 0, () => {
        const service = ChatService.getInstance();
        expect(typeof service.addChatMembers).assertEqual('function');
      });

      it('should have setSupergroupUsername method', 0, () => {
        const service = ChatService.getInstance();
        expect(typeof service.setSupergroupUsername).assertEqual('function');
      });
    });
  });
}
