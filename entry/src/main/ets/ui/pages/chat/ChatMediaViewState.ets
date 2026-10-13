import { MediaGalleryItem } from '../../../models/MediaGalleryItem';

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
}
