// TgMessageRouter — routes contentType to the correct bubble atom.
// Phase C.1-6 molecule. No visual output of its own.

import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgMessageBubbleBase } from '../atoms/TgMessageBubbleBase';
import { TgPhotoBubble } from '../atoms/TgPhotoBubble';
import { TgVideoBubble } from '../atoms/TgVideoBubble';
import { TgDocumentRow } from '../atoms/TgDocumentRow';
import { TgVoiceBubble } from '../atoms/TgVoiceBubble';
import { TgStickerView } from '../atoms/TgStickerView';

@ComponentV2
export struct TgMessageRouter {
  // ── Routing ──
  @Param contentType: string = 'text';

  // ── Common ──
  @Param isOutgoing: boolean = false;
  @Param containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH;

  // ── Text / fallback ──
  @Param text: string = '';
  @Param isEmojiOnly: boolean = false;
  @Param forceBreakAll: boolean = false;

  // ── Caption (photo, video) ──
  @Param caption: string = '';

  // ── Photo ──
  @Param photoPath: string = '';
  @Param photoWidth: number = 0;
  @Param photoHeight: number = 0;

  // ── Video / Animation ──
  @Param videoThumbPath: string = '';
  @Param videoPath: string = '';
  @Param videoDuration: number = 0;
  @Param videoWidth: number = 0;
  @Param videoHeight: number = 0;

  // ── Document / Audio ──
  @Param fileName: string = '';
  @Param fileSize: number = 0;
  @Param mimeType: string = '';

  // ── Voice ──
  @Param voiceDuration: number = 0;
  @Param voiceWaveform: string = '';
  @Param isVoiceListened: boolean = false;

  // ── Sticker ──
  @Param stickerPath: string = '';
  @Param stickerWidth: number = 0;
  @Param stickerHeight: number = 0;
  @Param isAnimatedSticker: boolean = false;
  @Param isVideoSticker: boolean = false;

  build() {
    if (this.contentType === 'photo') {
      TgPhotoBubble({
        photoPath: this.photoPath,
        caption: this.caption,
        isOutgoing: this.isOutgoing,
        containerWidth: this.containerWidth,
        photoWidth: this.photoWidth,
        photoHeight: this.photoHeight
      })
    } else if (this.contentType === 'video') {
      TgVideoBubble({
        thumbnailPath: this.videoThumbPath,
        videoPath: this.videoPath,
        durationSec: this.videoDuration,
        caption: this.caption,
        isOutgoing: this.isOutgoing,
        containerWidth: this.containerWidth,
        videoWidth: this.videoWidth,
        videoHeight: this.videoHeight
      })
    } else if (this.contentType === 'animation') {
      TgVideoBubble({
        thumbnailPath: this.videoThumbPath,
        videoPath: this.videoPath,
        durationSec: this.videoDuration,
        caption: this.caption,
        isOutgoing: this.isOutgoing,
        containerWidth: this.containerWidth,
        videoWidth: this.videoWidth,
        videoHeight: this.videoHeight
      })
    } else if (this.contentType === 'videoNote') {
      TgVideoBubble({
        thumbnailPath: this.videoThumbPath,
        videoPath: this.videoPath,
        durationSec: this.videoDuration,
        caption: this.caption,
        isOutgoing: this.isOutgoing,
        containerWidth: this.containerWidth,
        videoWidth: this.videoWidth,
        videoHeight: this.videoHeight
      })
    } else if (this.contentType === 'document') {
      TgDocumentRow({
        fileName: this.fileName,
        fileSize: this.fileSize,
        mimeType: this.mimeType,
        isOutgoing: this.isOutgoing,
        containerWidth: this.containerWidth
      })
    } else if (this.contentType === 'audio') {
      TgDocumentRow({
        fileName: this.fileName.length > 0 ? this.fileName : this.caption,
        fileSize: this.fileSize,
        mimeType: this.mimeType,
        isOutgoing: this.isOutgoing,
        containerWidth: this.containerWidth
      })
    } else if (this.contentType === 'voice') {
      TgVoiceBubble({
        durationSec: this.voiceDuration,
        waveform: this.voiceWaveform,
        isOutgoing: this.isOutgoing,
        isListened: this.isVoiceListened,
        containerWidth: this.containerWidth
      })
    } else if (this.contentType === 'sticker') {
      TgStickerView({
        stickerPath: this.stickerPath,
        isOutgoing: this.isOutgoing,
        isAnimatedSticker: this.isAnimatedSticker,
        isVideoSticker: this.isVideoSticker,
        stickerWidth: this.stickerWidth,
        stickerHeight: this.stickerHeight,
        containerWidth: this.containerWidth
      })
    } else {
      TgMessageBubbleBase({
        text: this.text,
        isOutgoing: this.isOutgoing,
        isEmojiOnly: this.isEmojiOnly,
        forceBreakAll: this.forceBreakAll,
        containerWidth: this.containerWidth
      })
    }
  }
}
