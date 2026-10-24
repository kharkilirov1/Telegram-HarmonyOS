// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { TgAttachmentRecentItem } from '../../tg_ui/atoms/TgAttachmentSheet';
import { CustomEmojiCellVO } from '../../tg_ui/atoms/TgComposerEmojiPanel';
import { ChatComposerController, ChatComposerControllerHost } from './ChatComposerController';
import { ChatVoiceRecordingController, ChatVoiceRecordingHost } from './ChatVoiceRecordingController';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';

export interface ChatComposerActionBindingsPort extends ChatComposerControllerHost, ChatVoiceRecordingHost {
  activeStickerTabId: string;
  attachmentRecentItems: TgAttachmentRecentItem[];
  attachmentRecentLoadToken: number;
  attachmentRecentLoading: boolean;
  composerCtrl: ChatComposerController;
  composerDraftText: string;
  composerResizeKeepsBottomAligned: boolean;
  composerSelectionEnd: number;
  composerSelectionStart: number;
  isEditingMessage: boolean;
  showComposerEmojiPanel: boolean;
  showComposerStickerPanel: boolean;
  stickerSettingsOpen: boolean;
  voiceRecordingCtrl: ChatVoiceRecordingController;
  canSendNewMessages(sendKind?: string): boolean;
  canUseComposer(isEditing: boolean, sendKind?: string): boolean;
  handleComposerStickerModePress(): void;
  handleStickerTabSelected(tabId: string): void;
  loadStickerPanelIfNeeded(): void;
  resetGifSearchState(): void;
  resetStickerSearchState(): void;
  scheduleDraftDebounce(): void;
  setEmojiPanelVisible(value: boolean): void;
  setStickerPanelVisible(value: boolean): void;
  shouldKeepTimelineBottomAligned(): boolean;
}

export function setStickerPanelVisible(host: ChatComposerActionBindingsPort, value: boolean): void {
    if (value && !host.canSendNewMessages()) return;
    host.showComposerStickerPanel = value;
    if (!value) {
      host.resetStickerSearchState();
      host.resetGifSearchState();
    }
  }

export function openStickerSettings(host: ChatComposerActionBindingsPort): void {
    host.composerResizeKeepsBottomAligned = host.shouldKeepTimelineBottomAligned();
    host.loadStickerPanelIfNeeded();
    host.setEmojiPanelVisible(false);
    host.setStickerPanelVisible(false);
    host.stickerSettingsOpen = true;
  }

export function handleSendMessage(host: ChatComposerActionBindingsPort, text: string): void {
    if (host.isEditingMessage ? !host.canUseComposer(true) : !host.canSendNewMessages()) return;
    host.composerCtrl.handleSendMessage(text, host);
  }

export function handleComposerAttachPress(host: ChatComposerActionBindingsPort): void {
    if (!host.canSendNewMessages('attachment')) return;
    host.setEmojiPanelVisible(false);
    host.setStickerPanelVisible(false);
  }

export function handleAttachmentMenuOpenChange(host: ChatComposerActionBindingsPort, isOpen: boolean): void {
    if (!isOpen || !host.canSendNewMessages('attachment')) {
      return;
    }
    const token = ++host.attachmentRecentLoadToken;
    host.attachmentRecentLoading = true;
    host.composerCtrl.loadRecentAttachmentMedia(host)
      .then((items: TgAttachmentRecentItem[]) => {
        if (token !== host.attachmentRecentLoadToken) {
          return;
        }
        host.attachmentRecentItems = items;
      })
      .catch((error: Error) => {
        hilog.warn(DOMAIN, TAG, 'Attachment recent UI load failed: %{public}s', error.message);
      })
      .finally(() => {
        if (token === host.attachmentRecentLoadToken) {
          host.attachmentRecentLoading = false;
        }
      });
  }

export function composerKeyboardPanelVisible(host: ChatComposerActionBindingsPort): boolean {
    return host.showComposerEmojiPanel || host.showComposerStickerPanel;
  }

export function handleComposerAttachmentMenuItemPress(host: ChatComposerActionBindingsPort, index: number): void {
    if (!host.canSendNewMessages()) return;
    host.composerCtrl.handleAttachmentMenuItemPress(index, host);
  }

export function handleAttachmentRecentPress(host: ChatComposerActionBindingsPort, item: TgAttachmentRecentItem): void {
    if (!host.canSendNewMessages()) return;
    host.composerCtrl.handleRecentAttachmentPress(item, host);
  }

export function handleComposerEmojiPress(host: ChatComposerActionBindingsPort): void {
    host.composerCtrl.handleEmojiPress(host);
  }

export function handleComposerKeyboardModePress(host: ChatComposerActionBindingsPort): void {
    host.setEmojiPanelVisible(false);
    host.setStickerPanelVisible(false);
  }

export function handleComposerVoicePress(host: ChatComposerActionBindingsPort): void {
    if (!host.canSendNewMessages('voice')) return;
    host.composerCtrl.handleVoicePress(host);
  }

export function handleVoiceRecordStart(host: ChatComposerActionBindingsPort): void {
    if (!host.canSendNewMessages('voice')) return;
    host.setEmojiPanelVisible(false);
    host.setStickerPanelVisible(false);
    host.voiceRecordingCtrl.begin(host);
  }

export function handleVoiceRecordSend(host: ChatComposerActionBindingsPort): void {
    host.voiceRecordingCtrl.finishAndSend(host);
  }

export function handleVoiceRecordCancel(host: ChatComposerActionBindingsPort): void {
    host.voiceRecordingCtrl.cancel(host);
  }

export function handleVoiceRecordLock(host: ChatComposerActionBindingsPort): void {
    host.voiceRecordingCtrl.lock(host);
  }

export function handleComposerEmojiSelected(host: ChatComposerActionBindingsPort, emoji: string): void {
    host.composerCtrl.handleEmojiSelected(emoji, host);
    host.scheduleDraftDebounce();
  }

export function handleComposerSelectionChange(host: ChatComposerActionBindingsPort, start: number, end: number): void {
    host.composerSelectionStart = Math.max(0, Math.min(host.composerDraftText.length, start));
    host.composerSelectionEnd = Math.max(0, Math.min(host.composerDraftText.length, end));
  }

export function handleCustomEmojiSelected(host: ChatComposerActionBindingsPort, item: CustomEmojiCellVO): void {
    host.composerCtrl.handleCustomEmojiSelected(item.fallbackEmoji, item.customEmojiId, host);
    host.scheduleDraftDebounce();
  }

export function handleComposerStickerPress(host: ChatComposerActionBindingsPort): void {
    host.handleComposerStickerModePress();
  }

export function handleComposerStickerModePress(host: ChatComposerActionBindingsPort): void {
    host.setEmojiPanelVisible(false);
    host.setStickerPanelVisible(true);
    host.loadStickerPanelIfNeeded();
    if (host.activeStickerTabId === 'gifs') {
      host.resetGifSearchState();
      host.handleStickerTabSelected('recent');
    }
  }

export function handleComposerGifPress(host: ChatComposerActionBindingsPort): void {
    host.setEmojiPanelVisible(false);
    host.setStickerPanelVisible(true);
    host.resetStickerSearchState();
    host.loadStickerPanelIfNeeded();
    host.handleStickerTabSelected('gifs');
  }

export function removePendingPhoto(host: ChatComposerActionBindingsPort, uri: string): void {
  host.composerCtrl.removePendingPhoto(uri, host);
}

export function movePendingPhoto(host: ChatComposerActionBindingsPort, uri: string, direction: number): void {
  host.composerCtrl.movePendingPhoto(uri, direction, host);
}

export function clearPendingAttachment(host: ChatComposerActionBindingsPort): void {
    host.composerCtrl.clearPendingAttachment(host);
  }
