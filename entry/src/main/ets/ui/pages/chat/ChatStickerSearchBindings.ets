// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { StickerCellVO } from '../../tg_ui/atoms/TgComposerStickerPanel';
import { ChatStickerSearchController, ChatStickerSearchHost } from './ChatStickerSearchController';
import { StickerPanelUseCase, StickerPanelEntry } from '../../../domain/usecases/stickerPanel';

export interface ChatStickerSearchBindingsPort extends ChatStickerSearchHost {
  activeStickerTabId: string;
  showComposerStickerPanel: boolean;
  stickerPanelUseCase?: StickerPanelUseCase;
  stickerSearchCtrl: ChatStickerSearchController;
  stickerSearchItems: StickerCellVO[];
  stickerSearchLoading: boolean;
  emojiSearchLanguageCodes(): string[];
  toStickerCellVO(entry: StickerPanelEntry): StickerCellVO;
}

export function resetStickerSearchState(host: ChatStickerSearchBindingsPort): void {
    host.stickerSearchCtrl.reset(host);
  }

export function handleStickerSearchQueryChange(host: ChatStickerSearchBindingsPort, query: string): void {
    host.stickerSearchCtrl.handleSearchQueryChange(query, host);
  }

export function getStickerSearchUseCase(host: ChatStickerSearchBindingsPort): StickerPanelUseCase | undefined {
    return host.stickerPanelUseCase;
  }

export function isStickerSearchPanelActive(host: ChatStickerSearchBindingsPort): boolean {
    return host.showComposerStickerPanel && host.activeStickerTabId !== 'gifs';
  }

export function getStickerSearchLanguageCodes(host: ChatStickerSearchBindingsPort): string[] {
    return host.emojiSearchLanguageCodes();
  }

export function toStickerSearchCell(host: ChatStickerSearchBindingsPort, entry: StickerPanelEntry): StickerCellVO {
    return host.toStickerCellVO(entry);
  }

export function setStickerSearchItems(host: ChatStickerSearchBindingsPort, items: StickerCellVO[]): void {
    host.stickerSearchItems = items;
  }

export function setStickerSearchLoading(host: ChatStickerSearchBindingsPort, value: boolean): void {
    host.stickerSearchLoading = value;
  }
