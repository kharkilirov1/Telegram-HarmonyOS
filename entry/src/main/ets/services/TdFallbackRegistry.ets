// TdFallbackRegistry — centralized tracking of unknown/unhandled TDLib types
// Reference: Both Telegram iOS and Android log unknown update types for telemetry
// This replaces scattered silent drops with a single registry that:
//   1. Logs the first occurrence of each unknown type (avoids log spam)
//   2. Tracks hit counts for prioritizing future implementation
//   3. Distinguishes "known but unimplemented" from "truly unknown"

import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'TdFallbackRegistry';
const DOMAIN = 0x0001;

interface FallbackEntry {
  firstSeen: number;
  count: number;
  category: 'update' | 'content' | 'other';
  note: string;
}

export class TdFallbackRegistry {
  private static instance: TdFallbackRegistry | null = null;
  private entries: Map<string, FallbackEntry> = new Map();

  // Known-but-unimplemented types: logged at debug level, not warn
  private knownUnimplemented: Set<string> = new Set([
    // Updates we intentionally skip for now
    'updateOption',
    'updateAuthorizationState',
    'updateConnectionState',
    'updateSelectedBackground',
    'updateFileGenerationStart',
    'updateFileGenerationStop',
    'updateCall',
    'updateFile',
    'updateChatTheme',
    'updateChatPermissions',
    'updateChatDraftMessage',
    'updateChatHasScheduledMessages',
    'updateChatOnlineMemberCount',
    'updateBasicGroup',
    'updateSupergroup',
    'updateSupergroupFullInfo',
    'updateBasicGroupFullInfo',
    'updateChatReadOutbox',
    'updateMessageSendSucceeded',
    'updateMessageSendFailed',
    'updateChatUnreadMentionCount',
    'updateChatUnreadReactionCount',
    'updateChatIsMarkedAsUnread',
    'updateChatBlockList',
    'updateChatFolders',
    'updateStory',
    'updateChatActiveStories',
    'updateStoryListChatCount',
    // Additional unimplemented update types can be listed here as needed
  ]);

  private constructor() {}

  static getInstance(): TdFallbackRegistry {
    if (!TdFallbackRegistry.instance) {
      TdFallbackRegistry.instance = new TdFallbackRegistry();
    }
    return TdFallbackRegistry.instance;
  }

  /**
   * Record an unhandled type. Logs on first occurrence.
   * @param type - The TDLib @type string
   * @param category - Where it was encountered
   */
  recordUnhandled(type: string, category: 'update' | 'content' | 'other'): void {
    const existing = this.entries.get(type);
    if (existing) {
      existing.count++;
      return;
    }

    const isKnown = this.knownUnimplemented.has(type);
    const entry: FallbackEntry = {
      firstSeen: Date.now(),
      count: 1,
      category: category,
      note: isKnown ? 'known-unimplemented' : 'unknown'
    };
    this.entries.set(type, entry);

    // Log first occurrence: warn for truly unknown, debug for known-unimplemented
    if (isKnown) {
      hilog.debug(DOMAIN, TAG, 'Unhandled %{public}s (known): %{public}s', category, type);
    } else {
      hilog.warn(DOMAIN, TAG, 'Unknown %{public}s type: %{public}s', category, type);
    }
  }

  /**
   * Get summary of all recorded fallbacks for debugging.
   */
  getSummary(): string {
    if (this.entries.size === 0) return 'No unhandled types recorded';

    const lines: string[] = [];
    this.entries.forEach((entry: FallbackEntry, type: string) => {
      lines.push(`  ${type} [${entry.category}] x${entry.count} (${entry.note})`);
    });
    return `Unhandled types (${this.entries.size}):\n${lines.join('\n')}`;
  }

  /**
   * Get count of truly unknown (not in knownUnimplemented set) types seen.
   */
  getUnknownCount(): number {
    let count = 0;
    this.entries.forEach((entry: FallbackEntry) => {
      if (entry.note === 'unknown') {
        count++;
      }
    });
    return count;
  }

  /**
   * Reset all recorded entries (useful for testing).
   */
  reset(): void {
    this.entries.clear();
  }
}
