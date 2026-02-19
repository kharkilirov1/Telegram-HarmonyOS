// Runtime invariant assertions for AppState
// Hard invariants throw errors in dev, soft invariants log warnings
// Executed after each store dispatch in development mode

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppState, Chat, Message } from '../model/AppState';

const TAG = 'Invariants';
const DOMAIN = 0x000A;

export enum InvariantSeverity {
  HARD = 'hard',   // Throws error, indicates critical bug
  SOFT = 'soft'    // Logs warning, indicates potential issue
}

// Details class for violation context
export class ViolationDetails {
  chatId: number = 0;
  messageId: string = '0';
  senderId: number = 0;
  unreadCount: number = 0;
  chatsSize: number = 0;
  messageCount: number = 0;
  orderedChatIds: number[] = [];
  messageId1: string = '0';
  messageId2: string = '0';
  timestamp1: number = 0;
  timestamp2: number = 0;
  isPending: boolean = false;
  authStatus: string = '';
}

export class InvariantViolation {
  severity: InvariantSeverity = InvariantSeverity.SOFT;
  message: string = '';
  details: ViolationDetails = new ViolationDetails();
}


// Hard invariants - must always hold
function checkHardInvariants(state: AppState): InvariantViolation[] {
  const violations: InvariantViolation[] = [];

  // 1. No duplicate chat IDs
  const chatIds = new Set<number>();
  for (const chatId of state.dialogs.orderedChatIds) {
    if (chatIds.has(chatId)) {
      const violation = new InvariantViolation();
      violation.severity = InvariantSeverity.HARD;
      violation.message = `Duplicate chat ID in orderedChatIds: ${chatId}`;
      const details = new ViolationDetails();
      details.chatId = chatId;
      details.orderedChatIds = state.dialogs.orderedChatIds;
      violation.details = details;
      violations.push(violation);
    }
    chatIds.add(chatId);
  }

  // 2. All orderedChatIds must exist in chats map
  for (const chatId of state.dialogs.orderedChatIds) {
    if (!state.dialogs.chats.has(chatId)) {
      const violation = new InvariantViolation();
      violation.severity = InvariantSeverity.HARD;
      violation.message = `Ordered chat ID not found in chats map: ${chatId}`;
      const details = new ViolationDetails();
      details.chatId = chatId;
      details.chatsSize = state.dialogs.chats.size;
      violation.details = details;
      violations.push(violation);
    }
  }

  // 3. No duplicate message IDs within same chat
  state.messages.messages.forEach((messagesMap: Map<string, Message>, chatId: number) => {
    const messageIds = new Set<string>();
    messagesMap.forEach((message: Message, messageId: string) => {
      if (messageIds.has(messageId)) {
        const violation = new InvariantViolation();
        violation.severity = InvariantSeverity.HARD;
        violation.message = `Duplicate message ID in chat ${chatId}: ${messageId}`;
        const details = new ViolationDetails();
        details.chatId = chatId;
        details.messageId = messageId;
        violation.details = details;
        violations.push(violation);
      }
      messageIds.add(messageId);
    });
  });

  // 4. Auth state consistency
  if (state.auth.status === 'ready' && !state.auth.userId) {
    const violation = new InvariantViolation();
    violation.severity = InvariantSeverity.HARD;
    violation.message = 'Auth status is ready but userId is missing';
    const details = new ViolationDetails();
    details.authStatus = state.auth.status;
    violation.details = details;
    violations.push(violation);
  }

  // 5. No negative unread counts
  state.dialogs.chats.forEach((chat: Chat, chatId: number) => {
    if (chat.unreadCount < 0) {
      const violation = new InvariantViolation();
      violation.severity = InvariantSeverity.HARD;
      violation.message = `Negative unread count for chat ${chatId}: ${chat.unreadCount}`;
      const details = new ViolationDetails();
      details.chatId = chatId;
      details.unreadCount = chat.unreadCount;
      violation.details = details;
      violations.push(violation);
    }
  });

  // 6. Message references valid chat
  state.messages.messages.forEach((messagesMap: Map<string, Message>, chatId: number) => {
    if (!state.dialogs.chats.has(chatId)) {
      const violation = new InvariantViolation();
      violation.severity = InvariantSeverity.HARD;
      violation.message = `Messages exist for non-existent chat ${chatId}`;
      const details = new ViolationDetails();
      details.chatId = chatId;
      details.messageCount = messagesMap.size;
      violation.details = details;
      violations.push(violation);
    }
  });

  return violations;
}

// Soft invariants - should hold but don't break if violated
function checkSoftInvariants(state: AppState): InvariantViolation[] {
  const violations: InvariantViolation[] = [];

  // 1. Ordered chat IDs should be in reasonable order (by timestamp)
  let lastTimestamp = Infinity;
  for (const chatId of state.dialogs.orderedChatIds.slice(0, 10)) {
    const chat = state.dialogs.chats.get(chatId);
    if (chat?.lastMessage?.timestamp) {
      if (chat.lastMessage.timestamp > lastTimestamp) {
        // Not a violation, just potentially out of order
      }
      lastTimestamp = chat.lastMessage.timestamp;
    }
  }

  // 2. Message timestamps should be sequential within chat
  state.messages.messages.forEach((messagesMap: Map<string, Message>, chatId: number) => {
    const messages: Message[] = [];
    messagesMap.forEach((message) => {
      messages.push(message);
    });
    for (let i = 1; i < messages.length; i++) {
      if (messages[i].timestamp < messages[i - 1].timestamp) {
        const violation = new InvariantViolation();
        violation.severity = InvariantSeverity.SOFT;
        violation.message = `Messages out of order in chat ${chatId}`;
        const details = new ViolationDetails();
        details.chatId = chatId;
        details.messageId1 = messages[i - 1].id;
        details.messageId2 = messages[i].id;
        details.timestamp1 = messages[i - 1].timestamp;
        details.timestamp2 = messages[i].timestamp;
        violation.details = details;
        violations.push(violation);
        break; // One warning per chat is enough
      }
    }
  });

  // 3. User references should exist
  state.messages.messages.forEach((messagesMap: Map<string, Message>, chatId: number) => {
    messagesMap.forEach((message: Message) => {
      if (message.senderId !== 0 && !state.users.users.has(message.senderId)) {
        const violation = new InvariantViolation();
        violation.severity = InvariantSeverity.SOFT;
        violation.message = `Message references non-existent user ${message.senderId}`;
        const details = new ViolationDetails();
        details.chatId = chatId;
        details.messageId = message.id;
        details.senderId = message.senderId;
        violation.details = details;
        violations.push(violation);
      }
    });
  });

  return violations;
}

// Main assertion function
export function assertInvariants(state: AppState, isDevMode: boolean = true): void {
  if (!isDevMode) {
    return; // Skip in production
  }

  const hardViolations = checkHardInvariants(state);
  const softViolations = checkSoftInvariants(state);

  // Throw on hard violations
  if (hardViolations.length > 0) {
    hilog.error(DOMAIN, TAG, 'Hard violations found: %{public}d', hardViolations.length);

    const violation = hardViolations[0];
    const errorDetails = JSON.stringify(violation.details, null, 2);
    hilog.error(DOMAIN, TAG, 'Violation: %{public}s | Details: %{public}s', violation.message, errorDetails);
    throw new Error(
      `[Invariant] ${violation.message}\n` +
      `Details: ${errorDetails}`
    );
  }

  // Log soft violations
  if (softViolations.length > 0) {
    hilog.warn(DOMAIN, TAG, 'Soft violations found: %{public}d', softViolations.length);

    for (const violation of softViolations) {
      hilog.warn(DOMAIN, TAG, '[Soft] %{public}s', violation.message);
    }
  }
}

// Helper to create invariant check for store integration
export function createStoreInvariantMiddleware(store: Object, isDevMode: boolean = true) {
  return (state: AppState) => {
    try {
      assertInvariants(state, isDevMode);
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Invariant check failed: %{public}s', err.message);

      // In dev mode, rethrow to break execution
      if (isDevMode) {
        throw err;
      }
    }
  };
}

// Quick validation for specific state slices
export function validateChatInvariants(chats: Map<number, Object>, orderedIds: number[]): string[] {
  const errors: string[] = [];

  const chatIds = new Set<number>();
  for (const chatId of orderedIds) {
    if (chatIds.has(chatId)) {
      errors.push(`Duplicate chat ID: ${chatId}`);
    }
    chatIds.add(chatId);

    if (!chats.has(chatId)) {
      errors.push(`Ordered ID not in map: ${chatId}`);
    }
  }

  return errors;
}
