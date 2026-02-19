// MessageLruCache - LRU cache для сообщений с ограничением памяти
// Huawei Best Practice: использовать LRU для предотвращения memory leaks
// Референс: util.LRUCache из @kit.ArkTS

import { util } from '@kit.ArkTS';
import { Message, MessageId, ChatId } from '../model/AppState';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x000C;
const TAG = 'MessageLruCache';

// Константы для настройки cache
const DEFAULT_MAX_MESSAGES_PER_CHAT = 500;
const DEFAULT_MAX_TOTAL_MESSAGES = 10000;

/**
 * Конфигурация LRU cache для сообщений.
 */
export class MessageCacheConfig {
  maxMessagesPerChat: number = DEFAULT_MAX_MESSAGES_PER_CHAT;
  maxTotalMessages: number = DEFAULT_MAX_TOTAL_MESSAGES;
}

/**
 * Статистика cache для мониторинга.
 */
export class MessageCacheStats {
  totalMessages: number = 0;
  chatsCount: number = 0;
  hits: number = 0;
  misses: number = 0;
  evictions: number = 0;
}

/**
 * LRU Cache для сообщений одного чата.
 * Huawei Best Practice: использовать util.LRUCache для управления памятью.
 */
export class ChatMessageCache {
  private cache: util.LRUCache<string, Message>;
  private chatId: ChatId;
  private evictionCount: number = 0;

  constructor(chatId: ChatId, capacity: number = DEFAULT_MAX_MESSAGES_PER_CHAT) {
    this.chatId = chatId;
    this.cache = new util.LRUCache<string, Message>(capacity);
  }

  get(messageId: MessageId): Message | undefined {
    return this.cache.get(messageId);
  }

  put(messageId: MessageId, message: Message): void {
    // LRUCache автоматически вытеснит старые записи при превышении capacity
    const oldLength = this.cache.length;
    this.cache.put(messageId, message);
    if (this.cache.length === oldLength && !this.cache.contains(messageId)) {
      this.evictionCount++;
    }
  }

  remove(messageId: MessageId): Message | undefined {
    return this.cache.remove(messageId);
  }

  has(messageId: MessageId): boolean {
    return this.cache.contains(messageId);
  }

  size(): number {
    return this.cache.length;
  }

  getEvictionCount(): number {
    return this.evictionCount;
  }

  clear(): void {
    this.cache.clear();
  }

  /**
   * Получить все сообщения как Map.
   * Внимание: создаёт копию для безопасности.
   */
  getAllAsMap(): Map<MessageId, Message> {
    const result = new Map<MessageId, Message>();
    const keys = this.cache.keys();
    for (const key of keys) {
      const value = this.cache.get(key);
      if (value !== undefined) {
        result.set(key, value);
      }
    }
    return result;
  }

  /**
   * Создать новый cache из Map (для миграции со старой структуры).
   */
  static fromMap(chatId: ChatId, messagesMap: Map<MessageId, Message>,
    capacity: number = DEFAULT_MAX_MESSAGES_PER_CHAT): ChatMessageCache {
    const cache = new ChatMessageCache(chatId, capacity);

    // Сортируем по timestamp чтобы новые сообщения остались в cache
    const sorted: Array<Message> = [];
    messagesMap.forEach((msg: Message) => {
      sorted.push(msg);
    });
    sorted.sort((a: Message, b: Message) => a.timestamp - b.timestamp);

    // Добавляем от старых к новым — новые будут в начале LRU
    for (const msg of sorted) {
      cache.put(msg.id, msg);
    }

    return cache;
  }
}

/**
 * Глобальный менеджер LRU cache для всех сообщений.
 */
export class MessageCacheManager {
  private chatCaches: Map<ChatId, ChatMessageCache> = new Map();
  private config: MessageCacheConfig;
  private stats: MessageCacheStats = new MessageCacheStats();

  constructor(config?: MessageCacheConfig) {
    this.config = config || new MessageCacheConfig();
  }

  /**
   * Получить сообщение из cache.
   */
  getMessage(chatId: ChatId, messageId: MessageId): Message | undefined {
    const chatCache = this.chatCaches.get(chatId);
    if (!chatCache) {
      this.stats.misses++;
      return undefined;
    }

    const message = chatCache.get(messageId);
    if (message) {
      this.stats.hits++;
    } else {
      this.stats.misses++;
    }
    return message;
  }

  /**
   * Добавить или обновить сообщение в cache.
   */
  putMessage(chatId: ChatId, message: Message): void {
    let chatCache = this.chatCaches.get(chatId);
    if (!chatCache) {
      chatCache = new ChatMessageCache(chatId, this.config.maxMessagesPerChat);
      this.chatCaches.set(chatId, chatCache);
      this.stats.chatsCount++;
    }

    const oldSize = chatCache.size();
    chatCache.put(message.id, message);
    const newSize = chatCache.size();

    if (newSize > oldSize) {
      this.stats.totalMessages++;
    }

    // Проверяем глобальный лимит
    this.enforceGlobalLimit();
  }

  /**
   * Удалить сообщение из cache.
   */
  removeMessage(chatId: ChatId, messageId: MessageId): void {
    const chatCache = this.chatCaches.get(chatId);
    if (chatCache) {
      const removed = chatCache.remove(messageId);
      if (removed) {
        this.stats.totalMessages--;
      }

      // Удаляем пустой cache
      if (chatCache.size() === 0) {
        this.chatCaches.delete(chatId);
        this.stats.chatsCount--;
      }
    }
  }

  /**
   * Получить все сообщения чата как Map.
   */
  getChatMessages(chatId: ChatId): Map<MessageId, Message> {
    const chatCache = this.chatCaches.get(chatId);
    if (!chatCache) {
      return new Map<MessageId, Message>();
    }
    return chatCache.getAllAsMap();
  }

  /**
   * Импортировать сообщения из Map (для миграции).
   */
  importChatMessages(chatId: ChatId, messages: Map<MessageId, Message>): void {
    const cache = ChatMessageCache.fromMap(chatId, messages, this.config.maxMessagesPerChat);
    this.chatCaches.set(chatId, cache);
    this.stats.totalMessages += cache.size();
    this.stats.chatsCount = this.chatCaches.size;
  }

  /**
   * Получить статистику cache.
   */
  getStats(): MessageCacheStats {
    const stats = new MessageCacheStats();
    stats.totalMessages = this.stats.totalMessages;
    stats.chatsCount = this.chatCaches.size;
    stats.hits = this.stats.hits;
    stats.misses = this.stats.misses;
    stats.evictions = this.stats.evictions;
    return stats;
  }

  /**
   * Принудительное применение глобального лимита.
   * Удаляет наименее активные чаты при превышении лимита.
   */
  private enforceGlobalLimit(): void {
    if (this.stats.totalMessages <= this.config.maxTotalMessages) {
      return;
    }

    hilog.warn(DOMAIN, TAG, 'Global message limit exceeded: %{public}d > %{public}d, evicting...',
      this.stats.totalMessages, this.config.maxTotalMessages);

    // Собираем чаты с количеством сообщений
    const chatSizes: Array<[ChatId, number]> = [];
    this.chatCaches.forEach((cache: ChatMessageCache, chatId: ChatId) => {
      chatSizes.push([chatId, cache.size()]);
    });

    // Сортируем по размеру (меньшие чаты удаляем первыми)
    // ArkTS: используем явный компаратор без индексированного доступа
    chatSizes.sort((a: [ChatId, number], b: [ChatId, number]): number => {
      const aSize = a[1] as number;
      const bSize = b[1] as number;
      return aSize - bSize;
    });

    // Удаляем чаты пока не достигнем лимита
    for (let i = 0; i < chatSizes.length; i++) {
      if (this.stats.totalMessages <= this.config.maxTotalMessages * 0.8) {
        break;  // Освободили достаточно (80% от лимита)
      }

      const entry = chatSizes[i];
      const chatId = entry[0] as ChatId;
      const chatCache = this.chatCaches.get(chatId);
      if (chatCache) {
        const evicted = chatCache.size();
        this.stats.totalMessages -= evicted;
        this.stats.evictions += evicted;
        this.chatCaches.delete(chatId);
        this.stats.chatsCount--;
        hilog.info(DOMAIN, TAG, 'Evicted chat %{public}d with %{public}d messages', chatId, evicted);
      }
    }
  }

  /**
   * Очистить весь cache.
   */
  clear(): void {
    this.chatCaches.clear();
    this.stats = new MessageCacheStats();
  }
}

// Singleton instance
let cacheManager: MessageCacheManager | null = null;

/**
 * Получить глобальный менеджер cache сообщений.
 */
export function getMessageCacheManager(config?: MessageCacheConfig): MessageCacheManager {
  if (!cacheManager) {
    cacheManager = new MessageCacheManager(config);
  }
  return cacheManager;
}

/**
 * Сбросить глобальный менеджер cache (для тестов).
 */
export function resetMessageCacheManager(): void {
  if (cacheManager) {
    cacheManager.clear();
  }
  cacheManager = null;
}
