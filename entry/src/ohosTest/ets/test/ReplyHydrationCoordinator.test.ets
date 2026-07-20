import { describe, it, expect } from '@ohos/hypium';
import { Message } from '../../../main/ets/core/model/AppState';
import {
  MAX_REPLY_HYDRATION_PER_SESSION,
  ReplyHydrationCoordinator,
  ReplyHydrationRequest
} from '../../../main/ets/ui/pages/chat/ReplyHydrationCoordinator';

function makeMessage(
  id: string,
  replyToMessageId: string,
  timestamp: number,
  replyToChatId: number = 100
): Message {
  const message = new Message();
  message.id = id;
  message.chatId = 100;
  message.replyToChatId = replyToChatId;
  message.replyToMessageId = replyToMessageId;
  message.timestamp = timestamp;
  return message;
}

export default function replyHydrationCoordinatorTest() {
  describe('ReplyHydrationCoordinator', () => {
    it('queues newest unresolved replies and skips loaded targets', 0, () => {
      const messages = new Map<string, Message>();
      messages.set('10', makeMessage('10', '1', 10));
      messages.set('20', makeMessage('20', '2', 20));
      messages.set('30', makeMessage('30', '3', 30));
      messages.set('3', makeMessage('3', '0', 3));

      const coordinator = new ReplyHydrationCoordinator();
      const requests = coordinator.collect(100, messages, messages, 1);

      expect(requests.length).assertEqual(1);
      expect(requests[0].replyingMessageId).assertEqual('20');
      expect(requests[0].targetMessageId).assertEqual('2');
      expect(requests[0].targetChatId).assertEqual(100);
    });

    it('does not confuse a cross-chat target with the same id in current history', 0, () => {
      const messages = new Map<string, Message>();
      messages.set('2', makeMessage('2', '0', 2));
      messages.set('20', makeMessage('20', '2', 20, 200));
      const coordinator = new ReplyHydrationCoordinator();

      const requests = coordinator.collect(100, messages, messages, 8);
      expect(requests.length).assertEqual(1);
      expect(requests[0].targetChatId).assertEqual(200);
    });

    it('collapses duplicate targets while a request is in flight', 0, () => {
      const messages = new Map<string, Message>();
      messages.set('20', makeMessage('20', '2', 20));
      messages.set('21', makeMessage('21', '2', 21));
      const coordinator = new ReplyHydrationCoordinator();

      const first = coordinator.collect(100, messages, messages, 8);
      expect(first.length).assertEqual(1);
      expect(coordinator.getInFlightCount()).assertEqual(1);

      coordinator.complete(first[0]);
      const retryViaOtherReply = coordinator.collect(100, messages, messages, 8);
      expect(retryViaOtherReply.length).assertEqual(1);
      expect(retryViaOtherReply[0].replyingMessageId).assertEqual('20');
    });

    it('does not request a target after it is inserted into the message map', 0, () => {
      const messages = new Map<string, Message>();
      messages.set('20', makeMessage('20', '2', 20));
      const coordinator = new ReplyHydrationCoordinator();
      const first: ReplyHydrationRequest[] = coordinator.collect(100, messages, messages, 8);
      coordinator.complete(first[0]);
      messages.set('2', makeMessage('2', '0', 2));

      expect(coordinator.collect(100, messages, messages, 8).length).assertEqual(0);
    });

    it('does not scan associated originals as visible reply rows', 0, () => {
      const visibleMessages = new Map<string, Message>();
      visibleMessages.set('20', makeMessage('20', '2', 20));
      const replyLookup = new Map<string, Message>(visibleMessages);
      const associated = makeMessage('2', '1', 2);
      replyLookup.set('100:2', associated);
      const coordinator = new ReplyHydrationCoordinator();

      expect(coordinator.collect(100, visibleMessages, replyLookup, 8).length).assertEqual(0);
      expect(coordinator.getAttemptedCount()).assertEqual(0);
    });

    it('bounds total attempts for one page session', 0, () => {
      const messages = new Map<string, Message>();
      for (let index = 1; index <= MAX_REPLY_HYDRATION_PER_SESSION + 5; index++) {
        messages.set(String(100 + index), makeMessage(String(100 + index), String(index), index));
      }

      const coordinator = new ReplyHydrationCoordinator();
      const requests = coordinator.collect(100, messages, messages, 100);
      expect(requests.length).assertEqual(MAX_REPLY_HYDRATION_PER_SESSION);
      expect(coordinator.getAttemptedCount()).assertEqual(MAX_REPLY_HYDRATION_PER_SESSION);
    });
  });
}
