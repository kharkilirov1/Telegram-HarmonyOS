import { describe, it, expect } from '@ohos/hypium';
import { AppState, Chat, ChatTypingInfo, User } from '../../../main/ets/core/model/AppState';
import {
  CHAT_ACTIVITY_TTL_MS,
  ChatSubtitlePresentation,
  chatSubtitlePresentation,
  typingActivityRemainingMs
} from '../../../main/ets/ui/pages/chat/ChatTopBarPresentation';
import { chatActivityRefreshDelay } from '../../../main/ets/ui/pages/chat/ChatRouteActivationCoordinator';
import { TgChatTopBarSubtitleMode } from '../../../main/ets/ui/tg_ui/atoms/TgChatTopBar';
import { localized } from '../../../main/ets/core/utils/AppResource';

// Focused contract for the chat header subtitle: one derivation point feeds
// typing, presence and member-count states, and the typing state owns an 8s
// deadline so it can expire without another store change.
const PRIVATE_CHAT_ID = 91001;
const GROUP_CHAT_ID = 91002;
const FOREIGN_CHAT_ID = 91003;
const PEER_USER_ID = 501;
const GROUP_SENDER_ID = 502;
const ACTIVITY_START_MS = 1_000_000;

function typingLabel(): string {
  return localized($r('app.string.typing').id, 'typing…');
}

function onlineLabel(): string {
  return localized($r('app.string.online').id, 'online');
}

function buildPrivateState(): AppState {
  const state = new AppState();
  // The connection override owns the subtitle while the session is not ready.
  state.connection.status = 'ready';
  const user = new User();
  user.id = PEER_USER_ID;
  user.firstName = 'Alice';
  user.username = 'alice';
  user.status = 'online';
  state.users.users.set(PEER_USER_ID, user);

  const chat = new Chat();
  chat.id = PRIVATE_CHAT_ID;
  chat.type = 'private';
  chat.peerUserId = PEER_USER_ID;
  chat.title = 'Alice';
  state.chats.chats.set(PRIVATE_CHAT_ID, chat);
  return state;
}

function buildGroupState(memberCount: number, senderUserId: number): AppState {
  const state = new AppState();
  state.connection.status = 'ready';
  if (senderUserId > 0) {
    const sender = new User();
    sender.id = senderUserId;
    sender.firstName = 'Bob';
    sender.username = 'bob';
    state.users.users.set(senderUserId, sender);
  }

  const chat = new Chat();
  chat.id = GROUP_CHAT_ID;
  chat.type = 'supergroup';
  chat.peerUserId = 0;
  chat.supergroupId = 7001;
  chat.memberCount = memberCount;
  chat.title = 'Fixture group';
  state.chats.chats.set(GROUP_CHAT_ID, chat);
  return state;
}

function typingInfo(senderUserId: number, actionType: string, timestamp: number): ChatTypingInfo {
  const info = new ChatTypingInfo();
  info.senderUserId = senderUserId;
  info.actionType = actionType;
  info.timestamp = timestamp;
  return info;
}

function subtitleAt(state: AppState, chatId: number, now: number): ChatSubtitlePresentation {
  return chatSubtitlePresentation(state.chats.chats.get(chatId), state, chatId, (): number => now);
}

export default function chatHeaderStatusTest() {
  describe('ChatHeaderStatus', () => {
    it('keeps one 8s activity deadline as the single source for typing freshness', 0, () => {
      expect(CHAT_ACTIVITY_TTL_MS).assertEqual(8000);
      const info = typingInfo(PEER_USER_ID, 'typing', ACTIVITY_START_MS);
      expect(typingActivityRemainingMs(info, ACTIVITY_START_MS)).assertEqual(8000);
      expect(typingActivityRemainingMs(info, ACTIVITY_START_MS + 7999)).assertEqual(1);
      expect(typingActivityRemainingMs(info, ACTIVITY_START_MS + 8000)).assertEqual(0);
    });

    it('renders a typing peer as the accent activity subtitle until the deadline', 0, () => {
      const state = buildPrivateState();
      state.chats.typingActions.set(PRIVATE_CHAT_ID,
        typingInfo(PEER_USER_ID, 'typing', ACTIVITY_START_MS));

      const fresh = subtitleAt(state, PRIVATE_CHAT_ID, ACTIVITY_START_MS);
      expect(fresh.mode).assertEqual(TgChatTopBarSubtitleMode.Typing);
      expect(fresh.subtitle).assertEqual(typingLabel());
      // The peer name already owns the title line; a one-to-one subtitle must not
      // repeat it (iOS takes the CloudUser/SecretChat activity branch).
      expect(fresh.subtitle.includes('Alice')).assertFalse();
      expect(fresh.spinner).assertFalse();

      const lastValidFrame = subtitleAt(state, PRIVATE_CHAT_ID, ACTIVITY_START_MS + 7999);
      expect(lastValidFrame.mode).assertEqual(TgChatTopBarSubtitleMode.Typing);
      expect(lastValidFrame.subtitle).assertEqual(typingLabel());

      const expired = subtitleAt(state, PRIVATE_CHAT_ID, ACTIVITY_START_MS + 8000);
      expect(expired.mode).assertEqual(TgChatTopBarSubtitleMode.Online);
      expect(expired.subtitle).assertEqual(onlineLabel());
      expect(expired.isOnline).assertTrue();
    });

    it('rolls the header back to presence when the activity is cancelled', 0, () => {
      const previous = buildPrivateState();
      previous.chats.typingActions.set(PRIVATE_CHAT_ID,
        typingInfo(PEER_USER_ID, 'typing', ACTIVITY_START_MS));
      const cancelled = buildPrivateState();

      const subtitle = subtitleAt(cancelled, PRIVATE_CHAT_ID, ACTIVITY_START_MS + 1);
      expect(subtitle.mode).assertEqual(TgChatTopBarSubtitleMode.Online);
      expect(subtitle.subtitle).assertEqual(onlineLabel());
      // A cancel removes the entry, so no deadline refresh may be scheduled.
      expect(chatActivityRefreshDelay(PRIVATE_CHAT_ID, cancelled, previous, ACTIVITY_START_MS + 1))
        .assertEqual(0);
    });

    it('shows only the sender name for a typing peer in a group', 0, () => {
      const state = buildGroupState(12, GROUP_SENDER_ID);
      state.chats.typingActions.set(GROUP_CHAT_ID,
        typingInfo(GROUP_SENDER_ID, 'typing', ACTIVITY_START_MS));

      const subtitle = subtitleAt(state, GROUP_CHAT_ID, ACTIVITY_START_MS);
      expect(subtitle.subtitle).assertEqual('Bob');
      expect(subtitle.mode).assertEqual(TgChatTopBarSubtitleMode.Typing);
      // iOS takes the group branch (`compactDisplayTitle`) and never appends the
      // one-to-one activity string to a group name.
      expect(subtitle.subtitle.includes(typingLabel())).assertFalse();
    });

    it('degrades to the action label when a group typing sender is not resolvable', 0, () => {
      const state = buildGroupState(12, 0);
      state.chats.typingActions.set(GROUP_CHAT_ID, typingInfo(0, 'typing', ACTIVITY_START_MS));

      const subtitle = subtitleAt(state, GROUP_CHAT_ID, ACTIVITY_START_MS);
      expect(subtitle.subtitle).assertEqual(typingLabel());
      expect(subtitle.mode).assertEqual(TgChatTopBarSubtitleMode.Typing);
    });

    it('schedules exactly one deadline refresh for the open chat activity', 0, () => {
      const previous = buildPrivateState();
      const withActivity = buildPrivateState();
      withActivity.chats.typingActions.set(PRIVATE_CHAT_ID,
        typingInfo(PEER_USER_ID, 'typing', ACTIVITY_START_MS));

      const delay = chatActivityRefreshDelay(PRIVATE_CHAT_ID, withActivity, previous, ACTIVITY_START_MS);
      expect(delay).assertEqual(CHAT_ACTIVITY_TTL_MS);

      // The refresh is derived from the remaining lifetime, not from a second TTL copy.
      expect(chatActivityRefreshDelay(PRIVATE_CHAT_ID, withActivity, previous, ACTIVITY_START_MS + 3000))
        .assertEqual(5000);
      // Consumed once the same activity is observed again.
      expect(chatActivityRefreshDelay(PRIVATE_CHAT_ID, withActivity, withActivity, ACTIVITY_START_MS))
        .assertEqual(0);
      // An already expired activity must not schedule anything.
      const stale = buildPrivateState();
      stale.chats.typingActions.set(PRIVATE_CHAT_ID,
        typingInfo(PEER_USER_ID, 'typing', ACTIVITY_START_MS - 9000));
      expect(chatActivityRefreshDelay(PRIVATE_CHAT_ID, stale, previous, ACTIVITY_START_MS)).assertEqual(0);
    });

    it('ignores activity that does not belong to the open chat', 0, () => {
      const previous = buildGroupState(12, GROUP_SENDER_ID);
      const next = buildGroupState(12, GROUP_SENDER_ID);
      next.chats.typingActions.set(FOREIGN_CHAT_ID,
        typingInfo(PEER_USER_ID, 'typing', ACTIVITY_START_MS));

      expect(next.chats.typingActions.get(GROUP_CHAT_ID) === undefined).assertTrue();
      expect(chatActivityRefreshDelay(GROUP_CHAT_ID, next, previous, ACTIVITY_START_MS)).assertEqual(0);
      expect(chatActivityRefreshDelay(PRIVATE_CHAT_ID, next, previous, ACTIVITY_START_MS)).assertEqual(0);
      // A retired route (no open chat) never schedules header work.
      expect(chatActivityRefreshDelay(0, next, previous, ACTIVITY_START_MS)).assertEqual(0);
    });

    it('expires the header on the scheduled deadline without another store change', 0, () => {
      const previous = buildPrivateState();
      const withActivity = buildPrivateState();
      withActivity.chats.typingActions.set(PRIVATE_CHAT_ID,
        typingInfo(PEER_USER_ID, 'typing', ACTIVITY_START_MS));

      const delay = chatActivityRefreshDelay(PRIVATE_CHAT_ID, withActivity, previous, ACTIVITY_START_MS);
      expect(delay).assertEqual(CHAT_ACTIVITY_TTL_MS);

      // The timer callback re-derives the header from the unchanged state at the
      // deadline; the same state must now read as presence, not as typing.
      const atDeadline = subtitleAt(withActivity, PRIVATE_CHAT_ID, ACTIVITY_START_MS + delay);
      expect(atDeadline.subtitle).assertEqual(onlineLabel());
      expect(atDeadline.mode).assertEqual(TgChatTopBarSubtitleMode.Online);
    });
  });
}
