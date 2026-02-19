// Entity IDs used across the application
// Ensures type safety when referencing chats, users, messages, etc.
// TDLib uses int53 for ChatId/UserId/FileId — we alias number
// TDLib uses int64 for MessageId — we alias string to avoid precision loss

export type ChatId = number;
export type UserId = number;
export type MessageId = string; // TDLib int64 stored as string to avoid precision loss
export type FileId = number;
export type SessionId = number;

export interface EntityId {
  chatId?: ChatId;
  userId?: UserId;
  messageId?: MessageId;
  fileId?: FileId;
  sessionId?: SessionId;
}

// Helper to create entity IDs
export const createChatId = (id: number): ChatId => id;
export const createUserId = (id: number): UserId => id;
export const createMessageId = (id: string | number): MessageId => {
  if (typeof id === 'string') {
    return id;
  }
  return id.toString();
};