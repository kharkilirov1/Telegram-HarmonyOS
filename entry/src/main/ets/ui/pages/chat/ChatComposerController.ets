// ChatComposerController — composer input, emoji panel, attachment picker and media-send preparation.
// TgChatScreenPage keeps @Local fields for ArkUI reactivity; this controller owns behavior.

import { fileIo, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { localized } from '../../../core/utils/AppResource';
import { SendMessageParams, SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import {
  SendMediaMessageParams,
  SendMediaMessageUseCase
} from '../../../domain/usecases/sendMediaMessage';

const DOMAIN = 0x0021;
const TAG = 'ChatComposerController';

export interface ChatComposerControllerHost {
  getActiveChatId(): number;
  getLifecycleToken(): number;
  getChatUIContext(): UIContext;
  getSendUseCase(): SendMessageUseCase | undefined;
  getSendMediaUseCase(): SendMediaMessageUseCase | undefined;
  isSendingMessage(): boolean;
  setSendingMessage(value: boolean): void;
  isEditModeActive(): boolean;
  isForwardModeActive(): boolean;
  submitEditMessage(text: string): void;
  submitForwardMessages(commentText: string): void;
  getDraftText(): string;
  setDraftText(value: string): void;
  setEmojiPanelVisible(value: boolean): void;
  getEmojiPanelVisible(): boolean;
  getReplyToMessageId(): string;
  clearReplyMode(): void;
  getPendingAttachmentUris(): string[];
  getPendingAttachmentKind(): string;
  setPendingAttachmentState(kind: string, title: string, preview: string, uris: string[]): void;
  clearPendingAttachmentState(): void;
  isNearBottom(): boolean;
  scrollToBottomSoon(): void;
}

export class ChatComposerController {
  handleSendMessage(text: string, host: ChatComposerControllerHost): void {
    if (host.isEditModeActive()) {
      host.submitEditMessage(text);
      return;
    }
    if (host.isForwardModeActive()) {
      host.submitForwardMessages(text);
      return;
    }
    if (host.getPendingAttachmentUris().length > 0) {
      this.handleSendPendingAttachment(text, host);
      return;
    }

    const useCase = host.getSendUseCase();
    const chatId = host.getActiveChatId();
    if (host.isSendingMessage() || chatId === 0 || !useCase) {
      return;
    }

    host.setEmojiPanelVisible(false);
    host.setSendingMessage(true);

    const params = new SendMessageParams();
    params.chatId = chatId;
    params.text = text;
    const replyToMessageId = host.getReplyToMessageId();
    if (replyToMessageId !== '0') {
      params.replyToMessageId = replyToMessageId;
    }

    const sentText = text;
    host.setDraftText('');
    host.clearReplyMode();

    const wasNearBottom = host.isNearBottom();
    const lifecycleToken: number = host.getLifecycleToken();
    useCase.execute(params)
      .then(() => {
        if (!this.isSendContextActive(host, lifecycleToken, useCase, chatId)) {
          return;
        }
        if (wasNearBottom) {
          host.scrollToBottomSoon();
        }
      })
      .catch((err: Error) => {
        if (!this.isSendContextActive(host, lifecycleToken, useCase, chatId)) {
          return;
        }
        if (host.getDraftText().trim().length === 0 && host.getActiveChatId() === params.chatId) {
          host.setDraftText(sentText);
        }
        hilog.error(DOMAIN, TAG, 'Send failed: %{public}s', err.message);
      })
      .finally(() => {
        if (!this.isSendContextActive(host, lifecycleToken, useCase, chatId)) {
          return;
        }
        host.setSendingMessage(false);
      });
  }

  handleAttachPress(host: ChatComposerControllerHost): void {
    host.setEmojiPanelVisible(false);
    const buttons: promptAction.Button[] = [
      { text: localized($r('app.string.photo').id, 'Photo'), color: TgUiTokens.COLOR_TEXT_TITLE },
      { text: localized($r('app.string.video').id, 'Video'), color: TgUiTokens.COLOR_TEXT_TITLE },
      { text: localized($r('app.string.document_label').id, 'Document'), color: TgUiTokens.COLOR_TEXT_TITLE }
    ];
    const actions: (() => void)[] = [
      () => {
        this.openPhotoAttachmentPicker('photo', host);
      },
      () => {
        this.openPhotoAttachmentPicker('video', host);
      },
      () => {
        this.openDocumentAttachmentPicker(host);
      }
    ];
    const lifecycleToken: number = host.getLifecycleToken();
    const chatId: number = host.getActiveChatId();
    host.getChatUIContext().getPromptAction().showActionMenu({
      title: '',
      buttons: buttons as [promptAction.Button, promptAction.Button?, promptAction.Button?,
        promptAction.Button?, promptAction.Button?, promptAction.Button?]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      if (lifecycleToken !== host.getLifecycleToken() || host.getActiveChatId() !== chatId) {
        return;
      }
      if (result.index >= 0 && result.index < actions.length) {
        actions[result.index]();
      }
    }).catch((_: Error) => {
      // User dismissed — no action needed.
    });
  }

  handleEmojiPress(host: ChatComposerControllerHost): void {
    if (host.getActiveChatId() === 0) {
      return;
    }
    host.setEmojiPanelVisible(!host.getEmojiPanelVisible());
  }

  handleVoicePress(host: ChatComposerControllerHost): void {
    host.setEmojiPanelVisible(false);
    this.showPendingToast(host, localized($r('app.string.composer_voice_unavailable').id,
      'Voice recording is not available yet'));
  }

  handleEmojiSelected(emoji: string, host: ChatComposerControllerHost): void {
    if (host.getActiveChatId() === 0 || emoji.length === 0) {
      return;
    }
    host.setDraftText(`${host.getDraftText()}${emoji}`);
  }

  handleStickerPress(host: ChatComposerControllerHost): void {
    this.showPendingToast(host, localized($r('app.string.composer_stickers_unavailable').id,
      'Stickers are not available yet'));
  }

  clearPendingAttachment(host: ChatComposerControllerHost): void {
    host.clearPendingAttachmentState();
  }

  private handleSendPendingAttachment(caption: string, host: ChatComposerControllerHost): void {
    const useCase = host.getSendMediaUseCase();
    const chatId = host.getActiveChatId();
    const attachmentUris = host.getPendingAttachmentUris();
    if (host.isSendingMessage() || chatId === 0 || !useCase || attachmentUris.length === 0) {
      return;
    }

    const sourceUri = attachmentUris[0];
    const mediaKind = host.getPendingAttachmentKind().length > 0 ? host.getPendingAttachmentKind() : 'document';
    const replyToMessageId = host.getReplyToMessageId();
    const wasNearBottom = host.isNearBottom();
    const lifecycleToken: number = host.getLifecycleToken();

    host.setEmojiPanelVisible(false);
    host.setSendingMessage(true);

    this.preparePickedAttachmentLocalPath(mediaKind, sourceUri, host)
      .then((localPath: string) => {
        if (!this.isMediaSendContextActive(host, lifecycleToken, useCase, chatId)) {
          return Promise.resolve();
        }

        const params = new SendMediaMessageParams();
        params.chatId = chatId;
        params.mediaKind = mediaKind;
        params.localPath = localPath;
        params.caption = caption;
        if (replyToMessageId !== '0') {
          params.replyToMessageId = replyToMessageId;
        }
        return useCase.execute(params);
      })
      .then(() => {
        if (!this.isMediaSendContextActive(host, lifecycleToken, useCase, chatId)) {
          return;
        }
        host.setDraftText('');
        host.clearPendingAttachmentState();
        host.clearReplyMode();
        if (wasNearBottom) {
          host.scrollToBottomSoon();
        }
      })
      .catch((err: Error) => {
        if (!this.isMediaSendContextActive(host, lifecycleToken, useCase, chatId)) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Media send failed: %{public}s', err.message);
        this.showPendingToast(host, localized($r('app.string.composer_media_send_failed').id,
          'Could not send media'));
      })
      .finally(() => {
        if (!this.isMediaSendContextActive(host, lifecycleToken, useCase, chatId)) {
          return;
        }
        host.setSendingMessage(false);
      });
  }

  private showPendingToast(host: ChatComposerControllerHost, message: string): void {
    try {
      host.getChatUIContext().getPromptAction().showToast({ message: message, duration: 1500 });
    } catch (_error) {
      // Composer auxiliary actions are non-critical; ignore toast failures.
    }
  }

  private async openPhotoAttachmentPicker(kind: string, host: ChatComposerControllerHost): Promise<void> {
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result = await photoPicker.select({
        MIMEType: kind === 'video'
          ? photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE
          : photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1,
        isSearchSupported: true,
        isPhotoTakingSupported: true
      });
      if (result.photoUris.length === 0) {
        return;
      }
      const title = kind === 'video'
        ? localized($r('app.string.video').id, 'Video')
        : localized($r('app.string.photo').id, 'Photo');
      this.setPendingAttachment(kind, title, result.photoUris, host);
    } catch (error) {
      this.handleAttachmentPickerError(error, host);
    }
  }

  private async openDocumentAttachmentPicker(host: ChatComposerControllerHost): Promise<void> {
    try {
      const documentOptions = new picker.DocumentSelectOptions();
      documentOptions.maxSelectNumber = 1;
      const documentPicker = new picker.DocumentViewPicker();
      const result: string[] = await documentPicker.select(documentOptions);
      if (!result || result.length === 0) {
        return;
      }
      this.setPendingAttachment('document',
        localized($r('app.string.document_label').id, 'Document'),
        result,
        host);
    } catch (error) {
      this.handleAttachmentPickerError(error, host);
    }
  }

  private handleAttachmentPickerError(error: Object, host: ChatComposerControllerHost): void {
    const message = String(error);
    if (message.toLowerCase().includes('cancel')) {
      return;
    }
    hilog.error(DOMAIN, TAG, 'Attachment picker failed: %{public}s', message);
    this.showPendingToast(host, localized($r('app.string.composer_attachment_unavailable').id,
      'Attachment picker is not available yet'));
  }

  private setPendingAttachment(
    kind: string,
    title: string,
    uris: string[],
    host: ChatComposerControllerHost
  ): void {
    host.setPendingAttachmentState(kind, title, this.buildAttachmentPreview(uris), uris);
    host.setEmojiPanelVisible(false);
  }

  private async preparePickedAttachmentLocalPath(
    kind: string,
    sourceUri: string,
    host: ChatComposerControllerHost
  ): Promise<string> {
    const context = host.getChatUIContext().getHostContext() as common.UIAbilityContext;
    const targetDir = this.ensureComposerSendMediaDir(context);
    const targetPath = `${targetDir}/${this.buildComposerSendMediaFileName(kind, sourceUri)}`;
    let sourceFile: fileIo.File | undefined = undefined;

    try {
      sourceFile = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
      fileIo.copyFileSync(sourceFile.fd, targetPath);
      return targetPath;
    } catch (error) {
      const err = error as Error;
      throw new Error(`Prepare picked attachment failed: ${err.message}`);
    } finally {
      if (sourceFile !== undefined) {
        try {
          fileIo.closeSync(sourceFile);
        } catch (closeError) {
          hilog.warn(DOMAIN, TAG, 'Attachment source close failed: %{public}s', String(closeError));
        }
      }
    }
  }

  private ensureComposerSendMediaDir(context: common.UIAbilityContext): string {
    const targetDir = `${context.filesDir}/composer_send_media`;
    try {
      if (fileIo.accessSync(targetDir)) {
        return targetDir;
      }
    } catch (_error) {
      // Directory does not exist or cannot be accessed; mkdir below will surface real failures.
    }
    try {
      fileIo.mkdirSync(targetDir, true);
    } catch (error) {
      const err = error as Error;
      throw new Error(`Create composer media directory failed: ${err.message}`);
    }
    return targetDir;
  }

  private buildComposerSendMediaFileName(kind: string, sourceUri: string): string {
    const rawName = this.safeAttachmentFileName(this.lastUriSegment(sourceUri));
    const extension = this.attachmentFileExtension(kind, rawName);
    const baseName = this.attachmentFileStem(rawName);
    return `tg_send_${kind}_${Date.now()}_${baseName}${extension}`;
  }

  private safeAttachmentFileName(name: string): string {
    let decoded = name;
    try {
      decoded = decodeURIComponent(name);
    } catch (_error) {
      decoded = name;
    }
    const safe = decoded.replace(/[^A-Za-z0-9._-]/g, '_');
    return safe.length > 0 ? safe.substring(0, 48) : 'attachment';
  }

  private attachmentFileStem(fileName: string): string {
    const dotIndex = fileName.lastIndexOf('.');
    const stem = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    return stem.length > 0 ? stem : 'attachment';
  }

  private attachmentFileExtension(kind: string, fileName: string): string {
    const dotIndex = fileName.lastIndexOf('.');
    if (dotIndex >= 0 && dotIndex < fileName.length - 1 && fileName.length - dotIndex <= 12) {
      return fileName.substring(dotIndex);
    }
    switch (kind) {
      case 'photo':
        return '.jpg';
      case 'video':
        return '.mp4';
      default:
        return '.bin';
    }
  }

  private buildAttachmentPreview(uris: string[]): string {
    if (uris.length === 0) {
      return '';
    }
    const first = this.lastUriSegment(uris[0]);
    if (uris.length === 1) {
      return first;
    }
    return `${first} +${uris.length - 1}`;
  }

  private lastUriSegment(uri: string): string {
    const withoutQuery = uri.split('?')[0];
    const parts = withoutQuery.split('/');
    const last = parts.length > 0 ? parts[parts.length - 1] : uri;
    return last.length > 0 ? last : uri;
  }

  private isSendContextActive(
    host: ChatComposerControllerHost,
    lifecycleToken: number,
    useCase: SendMessageUseCase,
    chatId: number
  ): boolean {
    return lifecycleToken === host.getLifecycleToken() &&
      host.getSendUseCase() === useCase &&
      host.getActiveChatId() === chatId;
  }

  private isMediaSendContextActive(
    host: ChatComposerControllerHost,
    lifecycleToken: number,
    useCase: SendMediaMessageUseCase,
    chatId: number
  ): boolean {
    return lifecycleToken === host.getLifecycleToken() &&
      host.getSendMediaUseCase() === useCase &&
      host.getActiveChatId() === chatId;
  }
}
