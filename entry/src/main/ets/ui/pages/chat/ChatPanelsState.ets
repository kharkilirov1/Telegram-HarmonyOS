import { TgAttachmentRecentItem } from '../../tg_ui/atoms/TgAttachmentSheet';
import { CustomEmojiCellVO, CustomEmojiPackTabVO } from '../../tg_ui/atoms/TgComposerEmojiPanel';
import { StickerCellVO, StickerSetTabVO } from '../../tg_ui/atoms/TgComposerStickerPanel';

// Page-owned presentation state. Keep this instance stable for its route lifetime.
@ObservedV2
export class ChatPanelsState {
  @Trace showComposerEmojiPanel: boolean = false;
  @Trace showComposerStickerPanel: boolean = false;
  @Trace stickerSettingsOpen: boolean = false;
  @Trace attachmentRecentItems: TgAttachmentRecentItem[] = [];
  @Trace attachmentRecentLoading: boolean = false;
  @Trace stickerPanelItems: StickerCellVO[] = [];
  @Trace premiumStickerItems: StickerCellVO[] = [];
  @Trace favoriteStickerItems: StickerCellVO[] = [];
  @Trace stickerPanelLoading: boolean = false;
  @Trace stickerSearchItems: StickerCellVO[] = [];
  @Trace stickerSearchLoading: boolean = false;
  @Trace gifSearchItems: StickerCellVO[] = [];
  @Trace gifSearchLoading: boolean = false;
  @Trace gifSearchHasMore: boolean = false;
  @Trace gifSearchPageLoading: boolean = false;
  @Trace stickerSetTabs: StickerSetTabVO[] = [];
  @Trace activeStickerTabId: string = 'recent';
  @Trace customEmojiPanelItems: CustomEmojiCellVO[] = [];
  @Trace customEmojiPanelLoading: boolean = false;
  @Trace customEmojiPackTabs: CustomEmojiPackTabVO[] = [];
  @Trace activeCustomEmojiPackId: string = 'unicode';
  @Trace emojiSearchUnicodeResults: string[] = [];
  @Trace emojiSearchCustomItems: CustomEmojiCellVO[] = [];
  @Trace emojiSearchLoading: boolean = false;
}
