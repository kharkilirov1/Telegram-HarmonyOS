import { TdObject } from '../models/TdTypes';

export enum EventId {
  // Auth
  AUTH_STATE_CHANGED = 1,

  // Dialogs / Chat list
  DIALOGS_UPDATED = 10,
  DIALOG_DELETED = 11,

  // Messages
  NEW_MESSAGE = 20,
  MESSAGES_LOADED = 21,
  MESSAGE_EDITED = 22,
  MESSAGE_DELETED = 23,
  MESSAGES_READ = 24,
  MESSAGE_SEND_SUCCEEDED = 25,
  MESSAGE_SEND_FAILED = 26,

  // Users
  USER_STATUS_UPDATED = 30,
  USER_INFO_UPDATED = 31,

  // Chat actions
  CHAT_ACTION_UPDATED = 35,

  // Files
  FILE_DOWNLOAD_PROGRESS = 40,
  FILE_DOWNLOAD_COMPLETED = 41,

  // Contacts
  CONTACTS_UPDATED = 45,

  // Calls
  CALLS_UPDATED = 46,
  CALL_STATE_UPDATED = 47,

  // Connection
  CONNECTION_STATE_CHANGED = 50,

  // Pinned messages
  PINNED_MESSAGE_UPDATED = 52,

  // Stories
  STORIES_UPDATED = 55,
  STORY_DELETED = 56,

  // Errors (for end-to-end AppError display)
  APP_ERROR = 60,
}

export type EventHandler = (args?: TdObject) => void;

export class NotificationCenter {
  private static instance: NotificationCenter | null = null;
  private observers: Map<EventId, EventHandler[]> = new Map();

  private constructor() {}

  static getInstance(): NotificationCenter {
    if (!NotificationCenter.instance) {
      NotificationCenter.instance = new NotificationCenter();
    }
    return NotificationCenter.instance;
  }

  addObserver(eventId: EventId, handler: EventHandler): void {
    const list = this.observers.get(eventId) || [];
    list.push(handler);
    this.observers.set(eventId, list);
  }

  removeObserver(eventId: EventId, handler: EventHandler): void {
    const list = this.observers.get(eventId);
    if (list) {
      const idx = list.indexOf(handler);
      if (idx >= 0) {
        list.splice(idx, 1);
      }
    }
  }

  post(eventId: EventId, args?: TdObject): void {
    const list = this.observers.get(eventId);
    if (list) {
      for (const handler of list) {
        handler(args);
      }
    }
  }
}
