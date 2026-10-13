// ChatComposerController — composer input, emoji panel, attachment picker and media-send preparation.
// TgChatScreenPage keeps @Local fields for ArkUI reactivity; this controller owns behavior.

import { picker } from '@kit.CoreFileKit';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { dataSharePredicates } from '@kit.ArkData';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { SendMessageUseCase } from '../../../domain/usecases/sendMessage';
import { SendMediaMessageUseCase } from '../../../domain/usecases/sendMediaMessage';
import { TgAttachmentRecentItem } from '../../tg_ui/atoms/TgAttachmentSheet';
import { CustomEmojiTextEntity } from '../../../core/model/AppCommand';
import {
  replaceDraftSelection
} from '../../tg_ui/utils/TgCustomEmojiDraftPolicy';

import { ChatPhotoAlbumController, ChatPhotoAlbumHost } from './ChatPhotoAlbumController';
import { ChatAttachmentFilePreparer } from './ChatAttachmentFilePreparer';
import { ChatTextSendController, ChatTextSendHost } from './ChatTextSendController';
import { ChatSequentialMediaController, ChatSequentialMediaHost } from './ChatSequentialMediaController';

const DOMAIN = 0x0021;
const TAG = 'ChatComposerController';
const RECENT_ATTACHMENT_LIMIT = 24;
export interface ChatComposerControllerHost extends ChatTextSendHost, ChatSequentialMediaHost {
  getActiveChatId(): number;
  getLifecycleToken(): number;
  getChatUIContext(): UIContext;
  getSendUseCase(): SendMessageUseCase | undefined;
  getSendMediaUseCase(mediaKind?: string): SendMediaMessageUseCase | undefined;
  isSendingMessage(): boolean;
  setSendingMessage(value: boolean): void;
  getSendOperationToken(): number;
  hasActiveChatState(): boolean;
  isEditModeActive(): boolean;
  isForwardModeActive(): boolean;
  submitEditMessage(text: string): void;
  submitForwardMessages(commentText: string): void;
  getDraftText(): string;
  setDraftText(value: string): void;
  getDraftSelectionStart(): number;
  getDraftSelectionEnd(): number;
  setDraftSelection(start: number, end: number): void;
  getCustomEmojiEntities(): CustomEmojiTextEntity[];
  setCustomEmojiEntities(value: CustomEmojiTextEntity[]): void;
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
  private pickerGeneration: number = 0;
  private readonly attachmentFiles: ChatAttachmentFilePreparer = new ChatAttachmentFilePreparer();
  private readonly photoAlbums: ChatPhotoAlbumController = new ChatPhotoAlbumController();
  private readonly textSender: ChatTextSendController = new ChatTextSendController();
  private readonly sequentialMedia: ChatSequentialMediaController = new ChatSequentialMediaController();
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

    this.textSender.handleSend(text, host);
  }

  handleAttachmentMenuItemPress(index: number, host: ChatComposerControllerHost): void {
    host.setEmojiPanelVisible(false);
    switch (index) {
      case 0:
        this.openPhotoAttachmentPicker(host.getSendMediaUseCase('photo') !== undefined ? 'photo' : 'video', host);
        break;
      case 1:
        this.openCameraAttachmentPicker(host);
        break;
      case 2:
        this.openDocumentAttachmentPicker(host);
        break;
      default:
        break;
    }
  }

  async loadRecentAttachmentMedia(host: ChatComposerControllerHost): Promise<TgAttachmentRecentItem[]> {
    let fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> | undefined = undefined;
    try {
      if (!await this.requestReadMediaPermission(host)) {
        return [];
      }
      const context = host.getChatUIContext().getHostContext() as common.UIAbilityContext;
      const accessHelper = photoAccessHelper.getPhotoAccessHelper(context);
      const predicates = new dataSharePredicates.DataSharePredicates();
      predicates.orderByDesc(photoAccessHelper.PhotoKeys.DATE_ADDED);
      const fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: [photoAccessHelper.PhotoKeys.DATE_ADDED],
        predicates: predicates
      };
      fetchResult = await accessHelper.getAssets(fetchOptions);
      const count = Math.min(fetchResult.getCount(), RECENT_ATTACHMENT_LIMIT);
      const result: TgAttachmentRecentItem[] = [];
      for (let index = 0; index < count; index++) {
        const asset = await fetchResult.getObjectByPosition(index);
        result.push(new TgAttachmentRecentItem(
          asset.uri,
          asset.displayName,
          asset.photoType === photoAccessHelper.PhotoType.VIDEO
        ));
      }
      return result;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Recent attachment load failed: %{public}s', String(error));
      return [];
    } finally {
      if (fetchResult !== undefined) {
        fetchResult.close();
      }
    }
  }

  handleRecentAttachmentPress(item: TgAttachmentRecentItem, host: ChatComposerControllerHost): void {
    const kind = item.isVideo ? 'video' : 'photo';
    const title = item.isVideo
      ? localized($r('app.string.video').id, 'Video')
      : localized($r('app.string.photo').id, 'Photo');
    this.setPendingAttachment(kind, title, [item.uri], host);
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
      'Hold the microphone to record'));
  }

  handleEmojiSelected(emoji: string, host: ChatComposerControllerHost): void {
    if (host.getActiveChatId() === 0 || emoji.length === 0) {
      return;
    }
    const change = replaceDraftSelection(
      host.getDraftText(),
      host.getDraftSelectionStart(),
      host.getDraftSelectionEnd(),
      emoji,
      host.getCustomEmojiEntities()
    );
    host.setCustomEmojiEntities(change.entities);
    host.setDraftText(change.text);
    host.setDraftSelection(change.caretOffset, change.caretOffset);
  }

  handleCustomEmojiSelected(emoji: string, customEmojiId: string, host: ChatComposerControllerHost): void {
    if (host.getActiveChatId() === 0 || emoji.length === 0 || customEmojiId === '0') {
      return;
    }
    const change = replaceDraftSelection(
      host.getDraftText(),
      host.getDraftSelectionStart(),
      host.getDraftSelectionEnd(),
      emoji,
      host.getCustomEmojiEntities(),
      customEmojiId
    );
    host.setCustomEmojiEntities(change.entities);
    host.setDraftText(change.text);
    host.setDraftSelection(change.caretOffset, change.caretOffset);
  }

  handleStickerPress(host: ChatComposerControllerHost): void {
    this.showPendingToast(host, localized($r('app.string.composer_stickers_unavailable').id,
      'Stickers are not available yet'));
  }

  clearPendingAttachment(host: ChatComposerControllerHost): void {
    if (host.getPendingAttachmentKind() === 'photo' && !this.canEditPendingPhotos(host)) return;
    host.clearPendingAttachmentState();
  }

  removePendingPhoto(uri: string, host: ChatComposerControllerHost): void {
    if (!this.canEditPendingPhotos(host)) return;
    const uris = host.getPendingAttachmentUris();
    const index = uris.indexOf(uri);
    if (index < 0) return;
    const next = uris.slice();
    next.splice(index, 1);
    if (next.length === 0) {
      host.clearPendingAttachmentState();
    } else {
      this.setPendingAttachment('photo', localized($r('app.string.photo').id, 'Photo'), next, host);
    }
  }

  movePendingPhoto(uri: string, direction: number, host: ChatComposerControllerHost): void {
    if (!this.canEditPendingPhotos(host) || (direction !== -1 && direction !== 1)) return;
    const uris = host.getPendingAttachmentUris();
    const index = uris.indexOf(uri);
    const target = index + direction;
    if (index < 0 || target < 0 || target >= uris.length) return;
    const next = uris.slice();
    next.splice(index, 1);
    next.splice(target, 0, uri);
    this.setPendingAttachment('photo', localized($r('app.string.photo').id, 'Photo'), next, host);
  }

  private canEditPendingPhotos(host: ChatComposerControllerHost): boolean {
    return !host.isSendingMessage() && host.getActiveChatId() !== 0 && host.hasActiveChatState() &&
      !host.isEditModeActive() && !host.isForwardModeActive() &&
      host.getPendingAttachmentKind() === 'photo' && host.getSendMediaUseCase('photo') !== undefined;
  }

  private handleSendPendingAttachment(caption: string, host: ChatComposerControllerHost): void {
    const mediaKind = host.getPendingAttachmentKind();
    if (mediaKind.length === 0) return;
    const useCase = host.getSendMediaUseCase(mediaKind);
    const chatId = host.getActiveChatId();
    const attachmentUris = host.getPendingAttachmentUris();
    if (host.isSendingMessage() || chatId === 0 || !useCase || attachmentUris.length === 0) {
      return;
    }

    if (mediaKind === 'photo') {
      try {
        const fileContext = host.getChatUIContext().getHostContext() as common.UIAbilityContext;
        this.photoAlbums.handleSend(caption, host, (uri: string): Promise<string> =>
          this.attachmentFiles.prepare('photo', uri, fileContext),
          (path: string): void => this.discardPreparedAttachment(path));
      } catch (_error) {
        this.showPendingToast(host, localized($r('app.string.composer_media_send_failed').id, 'Could not send media'));
      }
      return;
    }

    this.sequentialMedia.handleSend(caption, host,
      (kind: string, uri: string): Promise<string> => this.preparePickedAttachmentLocalPath(kind, uri, host),
      (path: string): void => this.discardPreparedAttachment(path),
      (uris: string[]): void => {
        if (uris.length === 0) host.clearPendingAttachmentState();
        else this.setPendingAttachment(mediaKind, mediaKind === 'video'
          ? localized($r('app.string.video').id, 'Video')
          : localized($r('app.string.document_label').id, 'Document'), uris, host);
      });
  }

  private showPendingToast(host: ChatComposerControllerHost, message: string): void {
    try {
      host.getChatUIContext().getPromptAction().showToast({ message: message, duration: 1500 });
    } catch (_error) {
      // Composer auxiliary actions are non-critical; ignore toast failures.
    }
  }

  private async requestReadMediaPermission(host: ChatComposerControllerHost): Promise<boolean> {
    const context = host.getChatUIContext().getHostContext() as common.UIAbilityContext;
    const result = await abilityAccessCtrl.createAtManager()
      .requestPermissionsFromUser(context, ['ohos.permission.READ_IMAGEVIDEO']);
    return result.authResults.length > 0 && result.authResults[0] === 0;
  }

  private async openPhotoAttachmentPicker(kind: string, host: ChatComposerControllerHost): Promise<void> {
    const mediaUseCase = host.getSendMediaUseCase(kind);
    if (mediaUseCase === undefined || host.isSendingMessage() ||
      host.isEditModeActive() || host.isForwardModeActive()) return;
    const lifecycleToken = host.getLifecycleToken();
    const chatId = host.getActiveChatId();
    const inputRevision = host.getComposerInputRevision();
    const generation = ++this.pickerGeneration;
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result = await photoPicker.select({
        MIMEType: kind === 'video'
          ? photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE
          : photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 10,
        isSearchSupported: true,
        isPhotoTakingSupported: true
      });
      if (!this.isPhotoPickerContextActive(host, lifecycleToken, chatId, generation, mediaUseCase, inputRevision, kind) ||
        result.photoUris.length === 0) {
        return;
      }
      const title = kind === 'video'
        ? localized($r('app.string.video').id, 'Video')
        : localized($r('app.string.photo').id, 'Photo');
      this.setPendingAttachment(kind, title, result.photoUris, host);
    } catch (error) {
      if (this.isPhotoPickerContextActive(host, lifecycleToken, chatId, generation, mediaUseCase, inputRevision, kind)) {
        this.handleAttachmentPickerError(error, host);
      }
    }
  }

  private isPhotoPickerContextActive(host: ChatComposerControllerHost, lifecycleToken: number,
    chatId: number, generation: number, mediaUseCase: SendMediaMessageUseCase, inputRevision: number, kind: string): boolean {
    return this.isPickerContextActive(host, lifecycleToken, chatId, generation) &&
      host.getSendMediaUseCase(kind) === mediaUseCase && host.getComposerInputRevision() === inputRevision &&
      !host.isSendingMessage() && !host.isEditModeActive() && !host.isForwardModeActive();
  }

  private async openCameraAttachmentPicker(host: ChatComposerControllerHost): Promise<void> {
    if (host.isSendingMessage() || host.isEditModeActive() || host.isForwardModeActive()) return;
    const photoUseCase = host.getSendMediaUseCase('photo');
    const videoUseCase = host.getSendMediaUseCase('video');
    const mediaTypes: cameraPicker.PickerMediaType[] = [];
    if (photoUseCase !== undefined) mediaTypes.push(cameraPicker.PickerMediaType.PHOTO);
    if (videoUseCase !== undefined) mediaTypes.push(cameraPicker.PickerMediaType.VIDEO);
    if (mediaTypes.length === 0) return;
    const lifecycleToken = host.getLifecycleToken();
    const chatId = host.getActiveChatId();
    const inputRevision = host.getComposerInputRevision();
    const generation = ++this.pickerGeneration;
    try {
      const context = host.getChatUIContext().getHostContext() as common.UIAbilityContext;
      const profile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
        videoDuration: 300
      };
      const result = await cameraPicker.pick(context, mediaTypes, profile);
      if (!this.isCameraPickerContextActive(host, lifecycleToken, chatId, generation,
        photoUseCase, videoUseCase, inputRevision)) return;
      if (result === undefined) {
        this.showPendingToast(host, localized($r('app.string.composer_attachment_unavailable').id,
          'Attachment picker is not available yet'));
        return;
      }
      if (result.resultCode !== 0 || result.resultUri.length === 0) {
        return;
      }
      if (result.mediaType !== cameraPicker.PickerMediaType.PHOTO && result.mediaType !== cameraPicker.PickerMediaType.VIDEO) return;
      const kind = result.mediaType === cameraPicker.PickerMediaType.VIDEO ? 'video' : 'photo';
      if ((kind === 'photo' ? photoUseCase : videoUseCase) === undefined) return;
      const title = kind === 'video'
        ? localized($r('app.string.video').id, 'Video')
        : localized($r('app.string.photo').id, 'Photo');
      this.setPendingAttachment(kind, title, [result.resultUri], host);
    } catch (error) {
      if (this.isCameraPickerContextActive(host, lifecycleToken, chatId, generation,
        photoUseCase, videoUseCase, inputRevision)) this.handleAttachmentPickerError(error, host);
    }
  }

  private isCameraPickerContextActive(host: ChatComposerControllerHost, lifecycleToken: number,
    chatId: number, generation: number, photoUseCase: SendMediaMessageUseCase | undefined,
    videoUseCase: SendMediaMessageUseCase | undefined, inputRevision: number): boolean {
    return this.isPickerContextActive(host, lifecycleToken, chatId, generation) &&
      host.getSendMediaUseCase('photo') === photoUseCase && host.getSendMediaUseCase('video') === videoUseCase &&
      host.getComposerInputRevision() === inputRevision && !host.isSendingMessage() &&
      !host.isEditModeActive() && !host.isForwardModeActive();
  }

  private async openDocumentAttachmentPicker(host: ChatComposerControllerHost): Promise<void> {
    const mediaUseCase = host.getSendMediaUseCase('document');
    if (mediaUseCase === undefined || host.isSendingMessage() ||
      host.isEditModeActive() || host.isForwardModeActive()) return;
    const lifecycleToken = host.getLifecycleToken();
    const chatId = host.getActiveChatId();
    const inputRevision = host.getComposerInputRevision();
    const generation = ++this.pickerGeneration;
    try {
      const documentOptions = new picker.DocumentSelectOptions();
      documentOptions.maxSelectNumber = 10;
      const documentPicker = new picker.DocumentViewPicker();
      const result: string[] = await documentPicker.select(documentOptions);
      if (!this.isPhotoPickerContextActive(host, lifecycleToken, chatId, generation,
        mediaUseCase, inputRevision, 'document') || !result || result.length === 0) {
        return;
      }
      this.setPendingAttachment('document',
        localized($r('app.string.document_label').id, 'Document'),
        result,
        host);
    } catch (error) {
      if (this.isPhotoPickerContextActive(host, lifecycleToken, chatId, generation,
        mediaUseCase, inputRevision, 'document')) this.handleAttachmentPickerError(error, host);
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

  private isPickerContextActive(host: ChatComposerControllerHost, lifecycleToken: number,
    chatId: number, generation: number): boolean {
    return generation === this.pickerGeneration && lifecycleToken === host.getLifecycleToken() &&
      chatId === host.getActiveChatId() && host.hasActiveChatState();
  }

  private setPendingAttachment(
    kind: string,
    title: string,
    uris: string[],
    host: ChatComposerControllerHost
  ): void {
    if (host.getSendMediaUseCase(kind) === undefined) return;
    const selection = kind === 'photo' ? Array.from(new Set<string>(uris)) : uris.slice();
    if (selection.length === 0 || (kind === 'photo' && selection.length > 10)) return;
    host.setPendingAttachmentState(kind, title, this.buildAttachmentPreview(selection), selection);
    host.setEmojiPanelVisible(false);
  }

  protected async preparePickedAttachmentLocalPath(
    kind: string, sourceUri: string, host: ChatComposerControllerHost
  ): Promise<string> {
    const context = host.getChatUIContext().getHostContext() as common.UIAbilityContext;
    return this.attachmentFiles.prepare(kind, sourceUri, context);
  }

  protected discardPreparedAttachment(path: string): void {
    this.attachmentFiles.discard(path);
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

}
