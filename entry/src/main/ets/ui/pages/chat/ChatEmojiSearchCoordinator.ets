// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { fileUri } from '@kit.CoreFileKit';
import { CustomEmojiCellVO } from '../../tg_ui/atoms/TgComposerEmojiPanel';
import { StickerPanelUseCase, StickerPanelEntry, EmojiKeyboardSearchResult } from '../../../domain/usecases/stickerPanel';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';
const EMOJI_SEARCH_DEBOUNCE_MS: number = 250;

export interface ChatEmojiSearchCoordinatorPort {
  emojiSearchCustomItems: CustomEmojiCellVO[];
  emojiSearchDebounceTimerId: number;
  emojiSearchLoading: boolean;
  emojiSearchQuery: string;
  emojiSearchRequestId: number;
  emojiSearchUnicodeResults: string[];
  pageLifecycleToken: number;
  showComposerEmojiPanel: boolean;
  stickerPanelUseCase?: StickerPanelUseCase;
  emojiSearchLanguageCodes(): string[];
  fetchEmojiSearchFiles(cells: CustomEmojiCellVO[], requestId: number): Promise<void>;
  toCustomEmojiCellVO(entry: StickerPanelEntry): CustomEmojiCellVO | undefined;
}

export function emojiSearchLanguageCodes(host: ChatEmojiSearchCoordinatorPort): string[] {
    const codes: string[] = [];
    try {
      const locale = Intl.DateTimeFormat().resolvedOptions().locale;
      if (locale && locale.length > 0) {
        codes.push(locale);
      }
    } catch (_) {
    }
    if (codes.length === 0 || !codes[0].toLowerCase().startsWith('en')) {
      codes.push('en-US');
    }
    return codes;
  }

export function resetEmojiSearchState(host: ChatEmojiSearchCoordinatorPort): void {
    if (host.emojiSearchDebounceTimerId >= 0) {
      clearTimeout(host.emojiSearchDebounceTimerId);
      host.emojiSearchDebounceTimerId = -1;
    }
    host.emojiSearchRequestId++;
    host.emojiSearchQuery = '';
    host.emojiSearchUnicodeResults = [];
    host.emojiSearchCustomItems = [];
    host.emojiSearchLoading = false;
  }

export function handleEmojiSearchQueryChange(host: ChatEmojiSearchCoordinatorPort, query: string): void {
    if (host.emojiSearchDebounceTimerId >= 0) {
      clearTimeout(host.emojiSearchDebounceTimerId);
      host.emojiSearchDebounceTimerId = -1;
    }
    const normalized = query.trim();
    const requestId = ++host.emojiSearchRequestId;
    host.emojiSearchQuery = normalized;
    host.emojiSearchUnicodeResults = [];
    host.emojiSearchCustomItems = [];
    if (normalized.length < 2) {
      host.emojiSearchLoading = false;
      return;
    }
    host.emojiSearchLoading = true;
    const lifecycleToken = host.pageLifecycleToken;
    host.emojiSearchDebounceTimerId = setTimeout(() => {
      host.emojiSearchDebounceTimerId = -1;
      const useCase = host.stickerPanelUseCase;
      if (!useCase || lifecycleToken !== host.pageLifecycleToken ||
        requestId !== host.emojiSearchRequestId || !host.showComposerEmojiPanel) {
        return;
      }
      useCase.searchEmojiKeyboard(normalized, host.emojiSearchLanguageCodes())
        .then((result: EmojiKeyboardSearchResult) => {
          if (lifecycleToken !== host.pageLifecycleToken || requestId !== host.emojiSearchRequestId ||
            normalized !== host.emojiSearchQuery || !host.showComposerEmojiPanel) {
            return;
          }
          const customItems: CustomEmojiCellVO[] = [];
          for (const entry of result.customEmoji) {
            const cell = host.toCustomEmojiCellVO(entry);
            if (cell !== undefined) {
              customItems.push(cell);
            }
          }
          host.emojiSearchUnicodeResults = result.unicodeEmoji;
          host.emojiSearchCustomItems = customItems;
          host.emojiSearchLoading = false;
          host.fetchEmojiSearchFiles(customItems, requestId);
        })
        .catch((error: Error) => {
          if (requestId === host.emojiSearchRequestId) {
            host.emojiSearchLoading = false;
          }
          hilog.warn(DOMAIN, TAG, 'Emoji keyboard search failed: %{public}s', error.message);
        });
    }, EMOJI_SEARCH_DEBOUNCE_MS) as number;
  }

export async function fetchEmojiSearchFiles(host: ChatEmojiSearchCoordinatorPort, cells: CustomEmojiCellVO[], requestId: number): Promise<void> {
    const useCase = host.stickerPanelUseCase;
    if (!useCase) {
      return;
    }
    const lifecycleToken = host.pageLifecycleToken;
    for (const cell of cells) {
      if (lifecycleToken !== host.pageLifecycleToken || requestId !== host.emojiSearchRequestId ||
        !host.showComposerEmojiPanel) {
        return;
      }
      if (cell.thumbPathUri.length === 0 && cell.thumbFileId > 0) {
        const path = await useCase.downloadStickerFile(cell.thumbFileId);
        if (path.length > 0) {
          cell.thumbPathUri = fileUri.getUriFromPath(path);
        }
      }
      if (cell.pathUri.length === 0 && !cell.isAnimated && !cell.isVideo && cell.fileId > 0) {
        const path = await useCase.downloadStickerFile(cell.fileId);
        if (path.length > 0) {
          cell.pathUri = fileUri.getUriFromPath(path);
        }
      }
    }
  }
