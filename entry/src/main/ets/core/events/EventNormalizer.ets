// EventNormalizer — thin coordinator that dispatches TDLib updates to domain normalizers
// Each domain (Auth, Chat, Message, User) has its own normalizer file in ./normalizers/
// Adding new features = new normalizer file + register call here. No switch growth.

import { AnyAppEvent } from '../model/AppEvent';
import { TdObject } from '../../models/TdTypes';
import { tdGetString } from '../utils/tdAccessors';
import { registerAuthHandlers } from './normalizers/AuthNormalizer';
import { registerChatHandlers } from './normalizers/ChatNormalizer';
import { registerMessageHandlers } from './normalizers/MessageNormalizer';
import { registerUserHandlers } from './normalizers/UserNormalizer';
import { registerFileHandlers } from './normalizers/FileNormalizer';
import { registerAccentColorHandlers } from './normalizers/AccentColorNormalizer';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'EventNormalizer';

export interface EventNormalizer {
  normalize(update: TdObject): AnyAppEvent[];
  getStats(): NormalizerStats;
}

export class NormalizerStats {
  totalUpdates: number = 0;
  normalizedEvents: number = 0;
  droppedUpdates: number = 0;
  byUpdateType: Map<string, number> = new Map<string, number>();
}

export class EventNormalizerImpl implements EventNormalizer {
  private stats: NormalizerStats = new NormalizerStats();
  private handlers: Map<string, (events: AnyAppEvent[], update: TdObject) => void> = new Map();

  constructor() {
    // Register domain normalizers — each adds its handlers to the map
    registerAuthHandlers(this.handlers);
    registerChatHandlers(this.handlers);
    registerMessageHandlers(this.handlers);
    registerUserHandlers(this.handlers);
    registerFileHandlers(this.handlers);
    registerAccentColorHandlers(this.handlers);

    hilog.info(DOMAIN, TAG, 'Registered %{public}d update handlers', this.handlers.size);
  }

  normalize(update: TdObject): AnyAppEvent[] {
    this.stats.totalUpdates++;

    if (!update || typeof update !== 'object') {
      return [];
    }

    const type = tdGetString(update, '@type');
    if (!type) {
      return [];
    }

    // Update statistics
    const currentCount = this.stats.byUpdateType.get(type) || 0;
    this.stats.byUpdateType.set(type, currentCount + 1);

    const events: AnyAppEvent[] = [];

    try {
      const handler = this.handlers.get(type);
      if (handler) {
        handler(events, update);
      } else {
        this.stats.droppedUpdates++;
      }
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Failed to normalize %{public}s: %{public}s', type, err.message);
    }

    this.stats.normalizedEvents += events.length;
    return events;
  }

  getStats(): NormalizerStats {
    const statsCopy = new NormalizerStats();
    statsCopy.totalUpdates = this.stats.totalUpdates;
    statsCopy.normalizedEvents = this.stats.normalizedEvents;
    statsCopy.droppedUpdates = this.stats.droppedUpdates;
    this.stats.byUpdateType.forEach((value: number, key: string) => {
      statsCopy.byUpdateType.set(key, value);
    });
    return statsCopy;
  }
}

// Singleton instance
let instance: EventNormalizer | null = null;

export function getEventNormalizer(): EventNormalizer {
  if (!instance) {
    instance = new EventNormalizerImpl();
  }
  return instance;
}
