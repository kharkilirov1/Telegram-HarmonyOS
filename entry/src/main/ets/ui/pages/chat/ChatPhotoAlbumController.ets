// Existing native photo selection -> one account/route-owned album mutation.
import { localized } from '../../../core/utils/AppResource';
import { SendMediaMessageParams, SendMediaMessageUseCase } from '../../../domain/usecases/sendMediaMessage';
import { SendMediaAlbumError, SendMediaAlbumParams } from '../../../domain/usecases/sendMediaAlbum';
import { CustomEmojiTextEntity } from '../../../core/model/AppCommand';
import { AppError, isSilentTdlibError, isWriteOutcomeUnknown } from '../../../core/model/AppError';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';

const MAX_CONSUMED_PHOTO_URIS = 128;

export interface ChatPhotoAlbumHost {
  canSendNewMessages(sendKind?: string): boolean;
  getActiveChatId(): number;
  getLifecycleToken(): number;
  getChatUIContext(): UIContext;
  getSendMediaUseCase(mediaKind?: string): SendMediaMessageUseCase | undefined;
  isSendingMessage(): boolean;
  setSendingMessage(value: boolean): void;
  getSendOperationToken(): number;
  getComposerInputRevision(): number;
  hasActiveChatState(): boolean;
  isEditModeActive(): boolean;
  isForwardModeActive(): boolean;
  getDraftText(): string;
  setDraftText(value: string): void;
  setDraftSelection(start: number, end: number): void;
  setCustomEmojiEntities(value: CustomEmojiTextEntity[]): void;
  setEmojiPanelVisible(value: boolean): void;
  getReplyToMessageId(): string;
  clearReplyMode(): void;
  getPendingAttachmentUris(): string[];
  getPendingAttachmentKind(): string;
  clearPendingAttachmentState(): void;
  isNearBottom(): boolean;
  scrollToBottomSoon(): void;
}

class PhotoAlbumAttempt {
  chatId: number = 0;
  lifecycle: number = 0;
  operation: number = 0;
  inputRevision: number = 0;
  uris: string[] = [];
  draftText: string = '';
  caption: string = '';
  replyToMessageId: string = '0';
  mediaUseCase?: SendMediaMessageUseCase;
  wasNearBottom: boolean = false;
}

class PhotoConsumptionMark {
  uris: string[] = [];
  overflow: boolean = false;
}

export class ChatPhotoAlbumController {
  private consumedChatId: number = 0;
  private consumedLifecycle: number = 0;
  private consumedMediaUseCase?: SendMediaMessageUseCase;
  private readonly consumedUriCounts: Map<string, number> = new Map<string, number>();
  private consumedOverflow: number = 0;

  handleSend(caption: string, host: ChatPhotoAlbumHost,
    prepareLocalPath: (uri: string) => Promise<string>, discardPreparedPath: (path: string) => void): void {
    const mediaUseCase = host.getSendMediaUseCase('photo');
    const uris = host.getPendingAttachmentUris();
    if (host.isSendingMessage() || host.getActiveChatId() === 0 || mediaUseCase === undefined ||
      !host.hasActiveChatState() || host.isEditModeActive() || host.isForwardModeActive() ||
      host.getPendingAttachmentKind() !== 'photo' || uris.length < 1 || uris.length > 10 ||
      !host.canSendNewMessages('photo')) return;
    const attempt = new PhotoAlbumAttempt();
    attempt.chatId = host.getActiveChatId();
    attempt.lifecycle = host.getLifecycleToken();
    attempt.inputRevision = host.getComposerInputRevision();
    attempt.uris = uris.slice();
    attempt.draftText = host.getDraftText();
    attempt.caption = caption;
    attempt.replyToMessageId = host.getReplyToMessageId();
    attempt.mediaUseCase = mediaUseCase;
    attempt.wasNearBottom = host.isNearBottom();
    host.setEmojiPanelVisible(false);
    host.setSendingMessage(true);
    attempt.operation = host.getSendOperationToken();
    this.runSend(attempt, host, prepareLocalPath, discardPreparedPath);
  }

  private async runSend(attempt: PhotoAlbumAttempt, host: ChatPhotoAlbumHost,
    prepareLocalPath: (uri: string) => Promise<string>, discardPreparedPath: (path: string) => void): Promise<void> {
    let submitted = false;
    let consumption: PhotoConsumptionMark | undefined = undefined;
    const paths: string[] = [];
    try {
      if (this.isSameSubmittedSelection(attempt)) {
        const response = await host.getChatUIContext().getPromptAction().showDialog({
          title: localized($r('app.string.composer_album_resend_title').id, 'Send these photos again?'),
          message: localized($r('app.string.composer_album_resend_message').id,
            'These photos may already have been sent. Sending again can create duplicates.'),
          buttons: [
            { text: localized($r('app.string.cancel').id, 'Cancel'),
              color: this.dialogButtonColor(host, TgUiTokens.COLOR_TEXT_TITLE_RESOURCE_NAME) },
            { text: localized($r('app.string.composer_album_resend_action').id, 'Send again'),
              color: this.dialogButtonColor(host, TgUiTokens.COLOR_ICON_PRIMARY_RESOURCE_NAME) }
          ]
        });
        if (response.index !== 1 || !this.canSubmit(host, attempt) || !host.canSendNewMessages('photo')) return;
      }
      if (!this.canSubmit(host, attempt) || !host.canSendNewMessages('photo')) return;
      if (!Number.isSafeInteger(attempt.chatId) || attempt.chatId === 0 ||
        typeof attempt.caption !== 'string' || attempt.caption.length > 4096 ||
        typeof attempt.replyToMessageId !== 'string' ||
        (attempt.replyToMessageId !== '0' && (!/^[1-9][0-9]*$/.test(attempt.replyToMessageId) ||
          !Number.isSafeInteger(Number(attempt.replyToMessageId))))) {
        throw new SendMediaAlbumError(false, 'Invalid photo selection input');
      }
      // Every file is prepared before the sole backend mutation. A copy failure
      // cannot leave a partially submitted album or start a sequential fallback.
      for (const uri of attempt.uris) {
        if (!this.canSubmit(host, attempt) || !host.canSendNewMessages('photo')) return;
        const path = await prepareLocalPath(uri);
        paths.push(path);
        if (!this.canSubmit(host, attempt) || !host.canSendNewMessages('photo')) return;
      }
      if (!this.canSubmit(host, attempt) || attempt.mediaUseCase === undefined ||
        !host.canSendNewMessages('photo')) return;
      if (paths.some((path: string) => typeof path !== 'string' || path.trim().length === 0)) {
        throw new SendMediaAlbumError(false, 'Prepared photo path is empty');
      }
      submitted = true;
      // Record before invocation/await: input edits or an explicit busy reset
      // must not bypass protection while the previous outcome is still pending.
      consumption = this.recordConsumption(attempt);
      if (paths.length === 1) {
        const params = new SendMediaMessageParams();
        params.chatId = attempt.chatId;
        params.mediaKind = 'photo';
        params.localPath = paths[0];
        params.caption = attempt.caption;
        params.replyToMessageId = attempt.replyToMessageId;
        await attempt.mediaUseCase.execute(params);
      } else {
        const params = new SendMediaAlbumParams();
        params.chatId = attempt.chatId;
        params.localPaths = paths;
        params.caption = attempt.caption;
        params.replyToMessageId = attempt.replyToMessageId;
        await attempt.mediaUseCase.getPhotoAlbumUseCase().execute(params);
      }
      if (!this.ownsOperation(host, attempt)) return;
      // A changed draft or revoked permission can keep the consumed selection
      // visible. Its next ordinary tap must not silently submit it again.
      if (!this.canSubmit(host, attempt)) return;
      host.setCustomEmojiEntities([]);
      host.setDraftText('');
      host.setDraftSelection(0, 0);
      host.clearPendingAttachmentState();
      host.clearReplyMode();
      if (attempt.wasNearBottom) host.scrollToBottomSoon();
    } catch (error) {
      const albumError = error as SendMediaAlbumError;
      const rejected = error instanceof AppError && error.requestRejected;
      const outcomeUnknown = submitted && !rejected &&
        (isWriteOutcomeUnknown(error) || !(error instanceof SendMediaAlbumError) || albumError.outcomeUnknown);
      if (rejected || (error instanceof SendMediaAlbumError && !albumError.outcomeUnknown)) {
        submitted = false;
        if (consumption !== undefined) this.rollbackConsumption(attempt, consumption);
      }
      if (!this.ownsOperation(host, attempt)) return;
      if (!this.isCurrentOwner(host, attempt)) return;
      if (isSilentTdlibError(error)) return;
      if (outcomeUnknown) {
        // Keep the selection and caption. A future ordinary tap cannot silently
        // repeat this mutation; native confirmation explicitly mentions duplicates.
        await this.showUnknownResult(host);
      } else {
        try {
          host.getChatUIContext().getPromptAction().showToast({
            message: localized($r('app.string.composer_media_send_failed').id, 'Could not send media'),
            duration: 1500
          });
        } catch (_error) {
          // Auxiliary feedback must not retain the busy owner.
        }
      }
    } finally {
      // TDLib may still be uploading after acceptance or an ambiguous reply.
      // Only paths that were never submitted can be deleted here.
      if (!submitted) {
        for (const path of paths) {
          try { discardPreparedPath(path); } catch (_error) {}
        }
      }
      // Permission/input edits may revoke submission, but still release this
      // operation. A newer route/send keeps its own busy owner.
      if (this.ownsOperation(host, attempt)) host.setSendingMessage(false);
    }
  }

  private ownsOperation(host: ChatPhotoAlbumHost, attempt: PhotoAlbumAttempt): boolean {
    return host.getSendOperationToken() === attempt.operation &&
      host.getLifecycleToken() === attempt.lifecycle && host.getActiveChatId() === attempt.chatId;
  }

  private isCurrentOwner(host: ChatPhotoAlbumHost, attempt: PhotoAlbumAttempt): boolean {
    return this.ownsOperation(host, attempt) && host.hasActiveChatState() &&
      host.getSendMediaUseCase('photo') === attempt.mediaUseCase;
  }

  private hasSameInput(host: ChatPhotoAlbumHost, attempt: PhotoAlbumAttempt): boolean {
    const uris = host.getPendingAttachmentUris();
    return host.getComposerInputRevision() === attempt.inputRevision &&
      host.getPendingAttachmentKind() === 'photo' && host.getDraftText() === attempt.draftText &&
      host.getReplyToMessageId() === attempt.replyToMessageId && uris.length === attempt.uris.length &&
      uris.every((uri: string, index: number) => uri === attempt.uris[index]);
  }

  private canSubmit(host: ChatPhotoAlbumHost, attempt: PhotoAlbumAttempt): boolean {
    return this.isCurrentOwner(host, attempt) && this.hasSameInput(host, attempt) &&
      !host.isEditModeActive() && !host.isForwardModeActive();
  }

  private isSameSubmittedSelection(attempt: PhotoAlbumAttempt): boolean {
    return this.matchesConsumedOwner(attempt) && (this.consumedOverflow > 0 ||
      attempt.uris.some((uri: string) => this.consumedUriCounts.has(uri)));
  }

  private matchesConsumedOwner(attempt: PhotoAlbumAttempt): boolean {
    return this.consumedChatId === attempt.chatId && this.consumedLifecycle === attempt.lifecycle &&
      this.consumedMediaUseCase === attempt.mediaUseCase;
  }

  private recordConsumption(attempt: PhotoAlbumAttempt): PhotoConsumptionMark {
    if (!this.matchesConsumedOwner(attempt)) {
      this.consumedChatId = attempt.chatId;
      this.consumedLifecycle = attempt.lifecycle;
      this.consumedMediaUseCase = attempt.mediaUseCase;
      this.consumedUriCounts.clear();
      this.consumedOverflow = 0;
    }
    const mark = new PhotoConsumptionMark();
    for (const uri of attempt.uris) {
      const count = this.consumedUriCounts.get(uri);
      if (count !== undefined || this.consumedUriCounts.size < MAX_CONSUMED_PHOTO_URIS) {
        this.consumedUriCounts.set(uri, (count ?? 0) + 1);
        mark.uris.push(uri);
      } else {
        // Never forget a possibly consumed URI to fit a cache bound. Saturation
        // conservatively asks for confirmation for every subsequent photo send.
        mark.overflow = true;
      }
    }
    if (mark.overflow) this.consumedOverflow++;
    return mark;
  }

  private rollbackConsumption(attempt: PhotoAlbumAttempt, mark: PhotoConsumptionMark): void {
    if (!this.matchesConsumedOwner(attempt)) return;
    for (const uri of mark.uris) {
      const count = this.consumedUriCounts.get(uri);
      if (count === undefined) continue;
      if (count <= 1) this.consumedUriCounts.delete(uri);
      else this.consumedUriCounts.set(uri, count - 1);
    }
    if (mark.overflow) this.consumedOverflow = Math.max(0, this.consumedOverflow - 1);
  }

  private async showUnknownResult(host: ChatPhotoAlbumHost): Promise<void> {
    try {
      await host.getChatUIContext().getPromptAction().showDialog({
        title: localized($r('app.string.composer_album_unknown_title').id, 'Sending result unknown'),
        message: localized($r('app.string.composer_album_unknown_message').id,
          'Check the chat before sending these photos again. They may already have been sent.'),
        buttons: [{ text: localized($r('app.string.done').id, 'Done'),
          color: this.dialogButtonColor(host, TgUiTokens.COLOR_ICON_PRIMARY_RESOURCE_NAME) }]
      });
    } catch (_error) {
      // Unknown outcome remains recorded even when the dialog cannot be shown.
    }
  }

  private dialogButtonColor(host: ChatPhotoAlbumHost, resourceName: string): string {
    const context = host.getChatUIContext().getHostContext();
    if (context === undefined) throw new Error('Native dialog context is unavailable');
    // Numeric IDs differ between HAP modules; prompt color Resources can also
    // lose the current theme. Resolve the named token here and pass explicit ARGB.
    const argb = context.resourceManager.getColorByNameSync(resourceName) >>> 0;
    return '#' + argb.toString(16).padStart(8, '0');
  }
}
