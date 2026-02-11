// Shared media browser — photos, videos, files, links, voice, GIFs
// Reference: Telegram iOS SharedMediaController, Android SharedMediaLayout

import { ChatService } from '../../services/ChatService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Message, MessageContentType } from '../../models/Message';

@Builder
export function SharedMediaBuilder(name: string, param: Object) {
  SharedMediaPage({ chatId: (param as Record<string, number>)?.['chatId'] || 0 })
}

interface SharedMediaItem {
  id: number;
  messageId: number;
  type: string;
  url: string;
  previewUrl: string;
  name: string;
  date: number;
  size: string;
  duration: number;
  fileId: number;
}

@ComponentV2
export struct SharedMediaPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param chatId: number = 0;

  @Local activeTab: number = 0;
  private readonly tabLabels: Resource[] = [
    $r('app.string.shared_media_tab_media'),
    $r('app.string.shared_media_files'),
    $r('app.string.shared_media_links'),
    $r('app.string.shared_media_voice'),
    $r('app.string.gif')
  ];

  @Local mediaItems: SharedMediaItem[] = [];
  @Local fileItems: SharedMediaItem[] = [];
  @Local linkItems: SharedMediaItem[] = [];
  @Local voiceItems: SharedMediaItem[] = [];
  @Local gifItems: SharedMediaItem[] = [];
  @Local isLoading: boolean = true;

  aboutToAppear(): void {
    void this.loadSharedMedia();
  }

  private async loadSharedMedia(): Promise<void> {
    this.isLoading = true;
    try {
      await Promise.all([
        this.loadMediaItems(),
        this.loadFileItems(),
        this.loadLinkItems(),
        this.loadVoiceItems(),
        this.loadGifItems()
      ]);
    } finally {
      this.isLoading = false;
    }
  }

  private async loadMediaItems(): Promise<void> {
    this.mediaItems = [];
    try {
      const messages: Message[] = await ChatService.getInstance()
        .searchChatMessages(this.chatId, '', 0, 50, 'searchMessagesFilterPhotoAndVideo');
      if (messages && messages.length > 0) {
        this.mediaItems = messages.map((msg: Message, index: number): SharedMediaItem => {
          const isGif = msg.contentType === MessageContentType.ANIMATION;
          const isVideo = msg.contentType === MessageContentType.VIDEO
            || msg.contentType === MessageContentType.VIDEO_NOTE;
          const isMotionMedia = isVideo || isGif;
          const openUrl: string = isMotionMedia
            ? (msg.videoUrl || '')
            : (msg.photoUrl || '');
          const previewUrl: string = msg.photoUrl || msg.videoUrl || '';
          const item: SharedMediaItem = {
            id: msg.id || index,
            messageId: msg.id,
            type: isGif ? 'gif' : (isVideo ? 'video' : 'photo'),
            url: openUrl,
            previewUrl: previewUrl,
            name: msg.fileName || '',
            date: msg.date || 0,
            size: '',
            duration: isVideo ? msg.videoDuration : 0,
            fileId: msg.fileId
          };
          return item;
        });
        return;
      }
    } catch (e) {
      hilog.warn(0x0001, 'SharedMediaPage', 'Failed to load media items');
    }
  }

  private async loadFileItems(): Promise<void> {
    this.fileItems = [];
    try {
      const messages: Message[] = await ChatService.getInstance()
        .searchChatMessages(this.chatId, '', 0, 50, 'searchMessagesFilterDocument');
      if (messages && messages.length > 0) {
        this.fileItems = messages.map((msg: Message, index: number): SharedMediaItem => {
          const item: SharedMediaItem = {
            id: msg.id || index,
            messageId: msg.id,
            type: 'file',
            url: msg.filePath || '',
            previewUrl: '',
            name: msg.fileName || 'Document',
            date: msg.date || 0,
            size: this.formatSize(msg.fileSize),
            duration: 0,
            fileId: msg.fileId
          };
          return item;
        });
        return;
      }
    } catch (e) {
      hilog.warn(0x0001, 'SharedMediaPage', 'Failed to load file items');
    }
  }

  private async loadLinkItems(): Promise<void> {
    this.linkItems = [];
    try {
      const messages: Message[] = await ChatService.getInstance()
        .searchChatMessages(this.chatId, '', 0, 50, 'searchMessagesFilterUrl');
      if (messages && messages.length > 0) {
        this.linkItems = messages.map((msg: Message, index: number): SharedMediaItem => {
          const item: SharedMediaItem = {
            id: msg.id || index,
            messageId: msg.id,
            type: 'link',
            url: msg.text || '',
            previewUrl: '',
            name: msg.text.length > 0 ? msg.text : 'Link',
            date: msg.date || 0,
            size: '',
            duration: 0,
            fileId: 0
          };
          return item;
        });
        return;
      }
    } catch (e) {
      hilog.warn(0x0001, 'SharedMediaPage', 'Failed to load link items');
    }
  }

  private async loadVoiceItems(): Promise<void> {
    this.voiceItems = [];
    try {
      const messages: Message[] = await ChatService.getInstance()
        .searchChatMessages(this.chatId, '', 0, 50, 'searchMessagesFilterVoiceNote');
      if (messages && messages.length > 0) {
        this.voiceItems = messages.map((msg: Message, index: number): SharedMediaItem => {
          const item: SharedMediaItem = {
            id: msg.id || index,
            messageId: msg.id,
            type: 'voice',
            url: msg.filePath || '',
            previewUrl: '',
            name: this.formatVoiceName(msg, index),
            date: msg.date || 0,
            size: this.formatSize(msg.fileSize),
            duration: msg.voiceDuration || 0,
            fileId: msg.fileId
          };
          return item;
        });
        return;
      }
    } catch (e) {
      hilog.warn(0x0001, 'SharedMediaPage', 'Failed to load voice items');
    }
  }

  private async loadGifItems(): Promise<void> {
    this.gifItems = [];
    try {
      const messages: Message[] = await ChatService.getInstance()
        .searchChatMessages(this.chatId, '', 0, 50, 'searchMessagesFilterAnimation');
      if (messages && messages.length > 0) {
        this.gifItems = messages.map((msg: Message, index: number): SharedMediaItem => {
          const item: SharedMediaItem = {
            id: msg.id || index,
            messageId: msg.id,
            type: 'gif',
            url: msg.videoUrl || '',
            previewUrl: msg.photoUrl || msg.videoUrl || '',
            name: msg.fileName || this.getString('gif', 'GIF'),
            date: msg.date || 0,
            size: this.formatSize(msg.fileSize),
            duration: msg.videoDuration || 0,
            fileId: msg.fileId
          };
          return item;
        });
        return;
      }
    } catch (e) {
      hilog.warn(0x0001, 'SharedMediaPage', 'Failed to load GIF items');
    }
  }

  private formatSize(bytes: number): string {
    if (bytes === 0) return '';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .accessibilityText($r('app.string.accessibility_back'))
            .onClick(() => this.navPathStack.pop())

          Text($r('app.string.profile_shared_media'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        // Tabs
        Scroll() {
          Row({ space: 0 }) {
            ForEach(this.tabLabels, (label: Resource, index: number) => {
              Column() {
                Text(label)
                  .fontSize(14)
                  .fontWeight(this.activeTab === index ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(this.activeTab === index
                    ? $r('app.color.telegram_blue')
                    : $r('app.color.text_secondary'))
                  .padding({ left: 16, right: 16, top: 10, bottom: 10 })

                Divider()
                  .strokeWidth(2)
                  .color(this.activeTab === index
                    ? $r('app.color.telegram_blue')
                    : Color.Transparent)
                  .width('80%')
              }
              .onClick(() => { this.activeTab = index; })
            }, (_label: Resource, index: number) => index.toString())
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        Divider().strokeWidth(0.5).color($r('app.color.separator'))

        // Content
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color($r('app.color.telegram_blue'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.activeTab === 0) {
          this.buildMediaGrid()
        } else if (this.activeTab === 1) {
          this.buildFilesList()
        } else if (this.activeTab === 2) {
          this.buildLinksList()
        } else if (this.activeTab === 3) {
          this.buildVoiceList()
        } else if (this.activeTab === 4) {
          this.buildGifGrid()
        } else {
          this.buildEmptyState()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_primary'))
    }
    .hideTitleBar(true)
  }

  @Builder
  buildMediaGrid() {
    if (this.mediaItems.length === 0) {
      this.buildEmptyState()
    } else {
      Grid() {
        ForEach(this.mediaItems, (item: SharedMediaItem) => {
          GridItem() {
            Stack({ alignContent: Alignment.BottomEnd }) {
              if (item.previewUrl.length > 0) {
                Image(item.previewUrl)
                  .alt($r('app.media.ic_photo'))
                  .autoResize(true)
                  .onError(() => {})
                  .width('100%')
                  .height('100%')
                  .objectFit(ImageFit.Cover)
              } else {
                Column() {
                  Image($r('app.media.ic_photo'))
                    .width(32).height(32)
                    .fillColor(Color.White)
                    .opacity(0.6)
                }
                .width('100%')
                .height('100%')
                .backgroundColor(item.type === 'video' ? $r('app.color.video_placeholder_bg') : $r('app.color.placeholder_bg'))
                .justifyContent(FlexAlign.Center)
              }

              if (item.type === 'video') {
                Row() {
                  Image($r('app.media.ic_play'))
                    .width(12).height(12)
                    .fillColor(Color.White)
                  Text(item.duration > 0 ? this.formatDuration(item.duration) : '0:00')
                    .fontSize(10)
                    .fontColor(Color.White)
                    .margin({ left: 2 })
                }
                .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                .backgroundColor($r('app.color.time_overlay'))
                .borderRadius(4)
                .margin({ right: 4, bottom: 4 })
              } else if (item.type === 'gif') {
                Text($r('app.string.gif'))
                  .fontSize(10)
                  .fontColor(Color.White)
                  .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                  .backgroundColor($r('app.color.time_overlay'))
                  .borderRadius(4)
                  .margin({ right: 4, bottom: 4 })
              }
            }
          }
          .onClick(() => {
            this.openMediaItem(item);
          })
        }, (item: SharedMediaItem) => item.id.toString())
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(2)
      .rowsGap(2)
      .width('100%')
      .layoutWeight(1)
      .padding(2)
    }
  }

  @Builder
  buildFilesList() {
    if (this.fileItems.length === 0) {
      this.buildEmptyState()
    } else {
      List() {
        ForEach(this.fileItems, (item: SharedMediaItem) => {
          ListItem() {
            Row() {
              Column() {
                Image($r('app.media.ic_document'))
                  .width(24).height(24)
                  .fillColor(Color.White)
              }
              .width(44).height(44)
              .borderRadius(8)
              .backgroundColor($r('app.color.telegram_blue'))
              .justifyContent(FlexAlign.Center)
              .margin({ right: 12 })

              Column() {
                Text(item.name)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)

                Text(this.formatFileMeta(item))
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Image($r('app.media.ic_download'))
                .width(24).height(24)
                .fillColor($r('app.color.telegram_blue'))
                .accessibilityText($r('app.string.accessibility_download'))
            }
            .width('100%')
            .height(64)
            .padding({ left: 16, right: 16 })
          }
        }, (item: SharedMediaItem) => item.id.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .divider({
        strokeWidth: 0.5,
        color: $r('app.color.separator'),
        startMargin: 72,
        endMargin: 0
      })
    }
  }

  @Builder
  buildLinksList() {
    if (this.linkItems.length === 0) {
      this.buildEmptyState()
    } else {
      List() {
        ForEach(this.linkItems, (item: SharedMediaItem) => {
          ListItem() {
            Row() {
              Column() {
                Image($r('app.media.ic_forward'))
                  .width(24).height(24)
                  .fillColor(Color.White)
              }
              .width(44).height(44)
              .borderRadius(8)
              .backgroundColor($r('app.color.settings_icon_blue'))
              .justifyContent(FlexAlign.Center)
              .margin({ right: 12 })

              Column() {
                Text(item.name)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)

                Text(item.url)
                  .fontSize(14)
                  .fontColor($r('app.color.telegram_blue'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 2 })

                Text(this.formatDate(item.date))
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .height(72)
            .padding({ left: 16, right: 16 })
          }
        }, (item: SharedMediaItem) => item.id.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .divider({
        strokeWidth: 0.5,
        color: $r('app.color.separator'),
        startMargin: 72,
        endMargin: 0
      })
    }
  }

  @Builder
  buildVoiceList() {
    if (this.voiceItems.length === 0) {
      this.buildEmptyState()
    } else {
      List() {
        ForEach(this.voiceItems, (item: SharedMediaItem) => {
          ListItem() {
            Row() {
              Column() {
                Image($r('app.media.ic_play'))
                  .width(20).height(20)
                  .fillColor(Color.White)
              }
              .width(40).height(40)
              .borderRadius(20)
              .backgroundColor($r('app.color.telegram_blue'))
              .justifyContent(FlexAlign.Center)
              .margin({ right: 12 })

              Column() {
                Text(item.name)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)

                Text(this.formatVoiceMeta(item))
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .height(64)
            .padding({ left: 16, right: 16 })
          }
        }, (item: SharedMediaItem) => item.id.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .divider({
        strokeWidth: 0.5,
        color: $r('app.color.separator'),
        startMargin: 72,
        endMargin: 0
      })
    }
  }

  @Builder
  buildGifGrid() {
    if (this.gifItems.length === 0) {
      this.buildEmptyState()
    } else {
      Grid() {
        ForEach(this.gifItems, (item: SharedMediaItem) => {
          GridItem() {
            Stack({ alignContent: Alignment.BottomEnd }) {
              if (item.previewUrl.length > 0) {
                Image(item.previewUrl)
                  .alt($r('app.media.ic_photo'))
                  .autoResize(true)
                  .onError(() => {})
                  .width('100%')
                  .height('100%')
                  .objectFit(ImageFit.Cover)
              } else {
                Column() {
                  Image($r('app.media.ic_photo'))
                    .width(32).height(32)
                    .fillColor(Color.White)
                    .opacity(0.6)
                }
                .width('100%')
                .height('100%')
                .backgroundColor($r('app.color.video_placeholder_bg'))
                .justifyContent(FlexAlign.Center)
              }

              Text($r('app.string.gif'))
                .fontSize(10)
                .fontColor(Color.White)
                .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                .backgroundColor($r('app.color.time_overlay'))
                .borderRadius(4)
                .margin({ right: 4, bottom: 4 })
            }
          }
          .onClick(() => {
            this.openMediaItem(item);
          })
        }, (item: SharedMediaItem) => item.id.toString())
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(2)
      .rowsGap(2)
      .width('100%')
      .layoutWeight(1)
      .padding(2)
    }
  }

  @Builder
  buildEmptyState() {
    Column() {
      Text($r('app.string.shared_media_no_items'))
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  private openMediaItem(item: SharedMediaItem): void {
    if (item.type === 'video' || item.type === 'gif') {
      if (item.url.length > 0) {
        const navParam: Record<string, unknown> = {};
        navParam['videoUrl'] = item.url;
        navParam['duration'] = item.duration;
        this.navPathStack.pushPath(new NavPathInfo('VideoPlayer', navParam));
      } else if (item.previewUrl.length > 0) {
        this.navPathStack.pushPath(new NavPathInfo('MediaViewer', this.buildMediaViewerParam(item.previewUrl, item)));
      }
      return;
    }

    const imageUrl: string = item.url.length > 0 ? item.url : item.previewUrl;
    if (imageUrl.length === 0) {
      return;
    }
    this.navPathStack.pushPath(new NavPathInfo('MediaViewer', this.buildMediaViewerParam(imageUrl, item)));
  }

  private buildMediaViewerParam(url: string, item: SharedMediaItem): Record<string, unknown> {
    const navParam: Record<string, unknown> = {};
    navParam['url'] = url;
    if (item.messageId > 0) {
      navParam['messageId'] = item.messageId;
      navParam['chatId'] = this.chatId;
    }
    return navParam;
  }

  private formatVoiceMeta(item: SharedMediaItem): string {
    const datePart: string = this.formatDate(item.date);
    const durationPart: string = item.duration > 0 ? this.formatDuration(item.duration) : '';
    if (durationPart.length > 0 && item.size.length > 0) {
      return `${durationPart} \u{2022} ${item.size} \u{2022} ${datePart}`;
    }
    if (durationPart.length > 0) {
      return `${durationPart} \u{2022} ${datePart}`;
    }
    if (item.size.length > 0) {
      return `${item.size} \u{2022} ${datePart}`;
    }
    return datePart;
  }

  private formatFileMeta(item: SharedMediaItem): string {
    const datePart: string = this.formatDate(item.date);
    if (item.size.length > 0) {
      return `${item.size} \u{2022} ${datePart}`;
    }
    return datePart;
  }

  private formatVoiceName(message: Message, index: number): string {
    if (message.fileName && message.fileName.length > 0) {
      return message.fileName;
    }
    const template = this.getString('voice_message', 'Voice message');
    return `${template} #${index + 1}`;
  }

  private formatDate(timestamp: number): string {
    if (timestamp === 0) return '';
    const date = new Date(timestamp * 1000);
    return `${date.getDate()}.${(date.getMonth() + 1).toString().padStart(2, '0')}.${date.getFullYear()}`;
  }

  private formatDuration(seconds: number): string {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
  }

  private getString(name: string, fallback: string): string {
    try {
      return getContext(this).resourceManager.getStringByNameSync(name);
    } catch (_e) {
      return fallback;
    }
  }
}
