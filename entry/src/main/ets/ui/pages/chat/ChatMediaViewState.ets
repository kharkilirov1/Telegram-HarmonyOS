import { MediaGalleryItem } from '../../../models/MediaGalleryItem';
import { StickerPackSticker } from '../../../domain/usecases/stickerPack';

// Page-owned presentation state. Keep this instance stable for its route lifetime.
@ObservedV2
export class ChatMediaViewState {
  @Trace activeVoiceMessageId: string = '0';
  @Trace activeVoiceProgress: number = 0;
  @Trace activeVoicePlaying: boolean = false;
  @Trace activeAudioMessageId: string = '0';
  @Trace activeAudioProgress: number = 0;
  @Trace activeAudioPlaying: boolean = false;
  @Trace pendingMediaDownloadVersion: number = 0;
  @Trace showMediaGallery: boolean = false;
  @Trace galleryItems: MediaGalleryItem[] = [];
  @Trace galleryInitialIndex: number = 0;
  @Trace galleryCurrentIndex: number = 0;
  @Trace gallerySourceMessageId: string = '0';
  // F6: pack card for the visible sticker; '0' hides the card.
  @Trace stickerPackSetId: string = '0';
  // F6: the loaded pack, so the viewer can page through it instead of the chat media list.
  @Trace stickerPackStickers: StickerPackSticker[] = [];
  // -1 while the viewer pages chat media; >= 0 is the current sticker inside the pack.
  @Trace stickerPackPagingIndex: number = -1;
  @Trace stickerPackTitle: string = '';
  @Trace stickerPackInstalled: boolean = false;
  @Trace stickerPackBusy: boolean = false;
}
