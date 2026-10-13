// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { fileUri } from '@kit.CoreFileKit';
import { filePreview } from '@kit.PreviewKit';
import { ChatTimelineEntryVO } from './ChatTimelineVO';
import { MediaContentType } from './VoicePlaybackController';
import { MediaPlaybackPageHandle } from './GlobalMediaPlayback';
import { PendingMediaOpenIntent, PendingMediaOpenKind, PendingMediaOpenResolution, resolvePendingMediaOpenIntent } from './PendingMediaOpenIntent';
import { localized } from '../../../core/utils/AppResource';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common, Want, wantConstant } from '@kit.AbilityKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';

export interface ChatMediaOpenCoordinatorPort {
  activeChatId: number;
  locallyListenedVoiceIds: Set<string>;
  mediaPlaybackHandle?: MediaPlaybackPageHandle;
  pageLifecycleToken: number;
  pendingMediaOpenIntent: PendingMediaOpenIntent;
  clearPendingMediaOpenIntent(fileId: number): void;
  getCurrentMediaPlaybackHandle(): MediaPlaybackPageHandle | undefined;
  handleAudioTap(audioPath: string, audioFileId: number, mimeType: string, messageId?: string): void;
  handleVoiceTap(messageId: string, voicePath: string, voiceFileId: number): void;
  openDocumentFile(documentPath: string, mimeType: string): void;
  publishNowPlayingMeta(messageId: string, contentType: MediaContentType): void;
  rememberPendingMediaOpenIntent(kind: PendingMediaOpenKind, fileId: number, messageId: string, mimeType?: string): void;
  requestMediaDownload(fileId: number, messageId?: string): void;
  setupMediaPlaybackController(): void;
  getUIContext(): UIContext;
}

export function rememberPendingMediaOpenIntent(host: ChatMediaOpenCoordinatorPort, kind: PendingMediaOpenKind, fileId: number, messageId: string,
    mimeType: string = ''): void {
    host.pendingMediaOpenIntent.set(kind, fileId, messageId, mimeType, host.activeChatId, host.pageLifecycleToken);
  }

export function clearPendingMediaOpenIntent(host: ChatMediaOpenCoordinatorPort, fileId: number): void {
    if (host.pendingMediaOpenIntent.matchesFile(fileId)) {
      host.pendingMediaOpenIntent.reset();
    }
  }

export function fulfillPendingMediaOpenIntent(host: ChatMediaOpenCoordinatorPort, entries: ChatTimelineEntryVO[]): void {
    const resolution: PendingMediaOpenResolution | undefined =
      resolvePendingMediaOpenIntent(host.pendingMediaOpenIntent, entries, host.activeChatId, host.pageLifecycleToken);
    if (!resolution) {
      return;
    }
    host.pendingMediaOpenIntent.reset();
    if (resolution.kind === 'document') {
      host.openDocumentFile(resolution.path, resolution.mimeType);
      return;
    }
    if (resolution.kind === 'audio') {
      host.handleAudioTap(resolution.path, resolution.fileId, resolution.mimeType, resolution.messageId);
      return;
    }
    host.handleVoiceTap(resolution.messageId, resolution.path, resolution.fileId);
  }

export function handleVoiceTap(host: ChatMediaOpenCoordinatorPort, messageId: string, voicePath: string, voiceFileId: number): void {
    if (host.mediaPlaybackHandle === undefined) host.setupMediaPlaybackController();
    const handle = host.getCurrentMediaPlaybackHandle();
    if (handle === undefined) return;
    if (voicePath.trim().length === 0) {
      if (voiceFileId > 0) {
        host.rememberPendingMediaOpenIntent('voice', voiceFileId, messageId);
        host.requestMediaDownload(voiceFileId);
      }
      return;
    }
    host.clearPendingMediaOpenIntent(voiceFileId);
    host.locallyListenedVoiceIds.add(messageId);
    host.publishNowPlayingMeta(messageId, 'voice');
    handle.toggle(messageId, voicePath, 'voice')
      .catch((_error: Object) => {});
  }

export function openAudioFile(host: ChatMediaOpenCoordinatorPort, audioPath: string, mimeType: string): void {
    if (audioPath.trim().length === 0) {
      return;
    }
    try {
      const context = host.getUIContext().getHostContext() as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: audioPath,
        type: mimeType.trim().length > 0 ? mimeType : 'audio/*',
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION |
          wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION
      };
      context.startAbility(want)
        .catch((_error: Object) => {});
    } catch (_error) {}
  }

export function openDocumentFile(host: ChatMediaOpenCoordinatorPort, documentPath: string, mimeType: string): void {
    if (documentPath.trim().length === 0) {
      return;
    }
    try {
      const context = host.getUIContext().getHostContext() as common.UIAbilityContext;
      const normalizedMimeType = mimeType.trim().length > 0 ? mimeType : 'application/octet-stream';
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: documentPath,
        type: normalizedMimeType,
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION |
          wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION
      };
      const openExternal = (): void => {
        context.startAbility(want)
          .catch((error: Object): void => {
            hilog.warn(DOMAIN, TAG, 'Document viewer start failed: %{public}s', String(error));
            // Формат без зарегистрированного viewer'а: молчание читается как
            // сломанный тап — показываем честный тост.
            host.getUIContext().getPromptAction().showToast({
              message: localized($r('app.string.document_no_viewer').id, 'No app can open this file'),
              duration: 2000
            });
          });
      };
      const lastSeparator = Math.max(documentPath.lastIndexOf('/'), documentPath.lastIndexOf('\\'));
      const previewInfo: filePreview.PreviewInfo = {
        title: lastSeparator >= 0 ? documentPath.substring(lastSeparator + 1) : 'Document',
        uri: documentPath,
        mimeType: normalizedMimeType
      };
      filePreview.canPreview(context, documentPath)
        .then((supported: boolean): void => {
          if (!supported) {
            openExternal();
            return;
          }
          filePreview.openPreview(context, previewInfo)
            .catch((_error: Object): void => {
              openExternal();
            });
        })
        .catch((_error: Object): void => {
          openExternal();
        });
    } catch (_error) {}
  }

export function handleDocumentTap(host: ChatMediaOpenCoordinatorPort, documentPath: string, documentFileId: number, mimeType: string,
    messageId: string = '0'): void {
    if (documentPath.trim().length === 0) {
      if (documentFileId > 0) {
        host.rememberPendingMediaOpenIntent('document', documentFileId, messageId, mimeType);
        host.requestMediaDownload(documentFileId);
      }
      return;
    }
    host.clearPendingMediaOpenIntent(documentFileId);
    host.openDocumentFile(documentPath, mimeType);
  }

export function handleAudioTap(host: ChatMediaOpenCoordinatorPort, audioPath: string, audioFileId: number, mimeType: string, messageId: string = '0'): void {
    if (host.mediaPlaybackHandle === undefined) host.setupMediaPlaybackController();
    const handle = host.getCurrentMediaPlaybackHandle();
    if (handle === undefined) return;
    if (audioPath.trim().length === 0) {
      if (audioFileId > 0) {
        host.rememberPendingMediaOpenIntent('audio', audioFileId, messageId, mimeType);
        host.requestMediaDownload(audioFileId);
      }
      return;
    }
    host.clearPendingMediaOpenIntent(audioFileId);
    // MediaPlaybackController uses fs.openSync which needs raw sandbox path, not file:// URI.
    // documentPath arrives as file:// URI (needed for Want-based file opening),
    // so convert back to raw path for playback.
    let rawPath = audioPath;
    if (rawPath.startsWith('file://')) {
      try {
        rawPath = new fileUri.FileUri(rawPath).path;
      } catch (_e) {
        rawPath = audioPath;
      }
    }
    host.publishNowPlayingMeta(messageId, 'audio');
    handle.toggle(messageId, rawPath, 'audio')
      .catch((_error: Object) => {});
  }

export function handleAudioSeek(host: ChatMediaOpenCoordinatorPort, messageId: string, progress: number): void {
    const handle = host.getCurrentMediaPlaybackHandle();
    if (!handle || handle.getActiveMessageId() !== messageId) {
      return;
    }
    handle.seekToProgress(progress).catch((_error: Object) => {});
  }

export function handleVoiceSeek(host: ChatMediaOpenCoordinatorPort, messageId: string, progress: number): void {
    const handle = host.getCurrentMediaPlaybackHandle();
    if (!handle || handle.getActiveMessageId() !== messageId) {
      return;
    }
    handle.seekToProgress(progress).catch((_error: Object) => {});
  }
