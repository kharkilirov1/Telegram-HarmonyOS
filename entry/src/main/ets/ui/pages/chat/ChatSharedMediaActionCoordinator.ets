// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { TextEntity } from '../../../core/model/AppState';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { timelineEntryContainsMessageId } from './ChatTimelineVO';
import { PendingSharedMediaAction } from './PendingSharedMediaActionSignal';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';

export interface ChatSharedMediaActionCoordinatorPort {
  activeChatId: number;
  dataSource: ChatTimelineDataSource;
  pendingSharedMediaAction: PendingSharedMediaAction | undefined;
  executeSharedMediaAction(action: PendingSharedMediaAction): boolean;
  fulfillPendingSharedMediaAction(): void;
  handleDocumentTap(documentPath: string, documentFileId: number, mimeType: string, messageId?: string): void;
  handleMediaGalleryOpen(messageId: string): void;
  handleVoiceTap(messageId: string, voicePath: string, voiceFileId: number): void;
  jumpToMessageId(messageId: string): void;
  normalizeSharedMediaLink(value: string): string;
  openSharedMediaLink(value: string): boolean;
  resolveEntityLink(text: string, entities: TextEntity[]): string;
  scheduleLifecycleTask(delayMs: number, task: () => void): void;
  getUIContext(): UIContext;
}

export function normalizeSharedMediaLink(host: ChatSharedMediaActionCoordinatorPort, value: string): string {
    const link = value.trim();
    return link.startsWith('www.') ? 'https://' + link : link;
  }

export function resolveEntityLink(host: ChatSharedMediaActionCoordinatorPort, text: string, entities: TextEntity[]): string {
    for (let i = 0; i < entities.length; i++) {
      const entity = entities[i];
      if (entity.type === 'textUrl' && entity.url.trim().length > 0) {
        return host.normalizeSharedMediaLink(entity.url);
      }
      if (entity.type === 'url') {
        const offset = Math.max(0, entity.offset);
        const target = text.substring(offset, Math.min(text.length, offset + Math.max(0, entity.length)));
        if (target.trim().length > 0) {
          return host.normalizeSharedMediaLink(target);
        }
      }
    }
    return '';
  }

export function openSharedMediaLink(host: ChatSharedMediaActionCoordinatorPort, value: string): boolean {
    const link = host.normalizeSharedMediaLink(value);
    if (link.length === 0) {
      return false;
    }
    try {
      const context = host.getUIContext().getHostContext() as common.UIAbilityContext;
      context.openLink(link)
        .catch((error: Object): void => {
          hilog.warn(DOMAIN, TAG, 'Shared Media link open failed: %{public}s', String(error));
        });
      return true;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Shared Media link dispatch failed: %{public}s', String(error));
      return false;
    }
  }

export function executeSharedMediaAction(host: ChatSharedMediaActionCoordinatorPort, action: PendingSharedMediaAction): boolean {
    if (action.kind === 'link' && host.openSharedMediaLink(action.linkUrl)) {
      return true;
    }
    const entries = host.dataSource.getAllEntries();
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      if (entry.kind !== 'message' || !timelineEntryContainsMessageId(entry, action.messageId)) {
        continue;
      }
      const message = entry.message;
      if (action.kind === 'media') {
        if (message.contentType === 'photo' || message.contentType === 'photoAlbum' ||
          message.contentType === 'video' || message.contentType === 'animation' ||
          message.contentType === 'videoNote') {
          host.handleMediaGalleryOpen(action.messageId);
          return true;
        }
        return false;
      }
      if (action.kind === 'file' && message.contentType === 'document') {
        host.handleDocumentTap(message.documentPath, message.documentFileId, message.mimeType, message.messageId);
        return true;
      }
      if (action.kind === 'voice' && message.contentType === 'voice') {
        host.handleVoiceTap(message.messageId, message.voicePath, message.voiceFileId);
        return true;
      }
      if (action.kind === 'link') {
        let link = message.linkPreviewUrl;
        if (link.trim().length === 0) {
          link = host.resolveEntityLink(message.text, message.textEntities);
        }
        if (link.trim().length === 0) {
          link = host.resolveEntityLink(message.caption, message.captionEntities);
        }
        return host.openSharedMediaLink(link);
      }
      return false;
    }
    return false;
  }

export function fulfillPendingSharedMediaAction(host: ChatSharedMediaActionCoordinatorPort): void {
    const action = host.pendingSharedMediaAction;
    if (!action || action.chatId !== host.activeChatId) {
      return;
    }
    if (host.executeSharedMediaAction(action)) {
      host.pendingSharedMediaAction = undefined;
    }
  }

export function beginSharedMediaAction(host: ChatSharedMediaActionCoordinatorPort, action: PendingSharedMediaAction): void {
    if (action.chatId !== host.activeChatId || action.messageId === '0') {
      return;
    }
    host.pendingSharedMediaAction = action;
    if (action.kind === 'link' && action.linkUrl.trim().length > 0) {
      host.fulfillPendingSharedMediaAction();
      return;
    }
    host.jumpToMessageId(action.messageId);
    host.scheduleLifecycleTask(16, (): void => {
      host.fulfillPendingSharedMediaAction();
    });
  }
