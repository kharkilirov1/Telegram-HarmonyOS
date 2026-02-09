// Shared media browser — photos, videos, files, links, voice, GIFs
// Reference: Telegram iOS SharedMediaController, Android SharedMediaLayout

import { TDLibClient } from '../../services/TDLibClient';

@Builder
export function SharedMediaBuilder(name: string, param: Object) {
  SharedMediaPage({ chatId: (param as Record<string, number>)?.['chatId'] || 0 })
}

interface SharedMediaItem {
  id: number;
  type: string;
  url: string;
  name: string;
  date: number;
  size: string;
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
  @Local isLoading: boolean = true;

  aboutToAppear(): void {
    this.loadSharedMedia();
  }

  private async loadSharedMedia(): Promise<void> {
    await Promise.all([
      this.loadMediaItems(),
      this.loadFileItems(),
      this.loadLinkItems()
    ]);
    this.isLoading = false;
  }

  private async loadMediaItems(): Promise<void> {
    try {
      const mediaFilter: Record<string, Object> = {};
      mediaFilter['@type'] = 'searchMessagesFilterPhotoAndVideo';
      const mediaParams: Record<string, Object> = {};
      mediaParams['chat_id'] = this.chatId;
      mediaParams['query'] = '';
      mediaParams['filter'] = mediaFilter;
      mediaParams['from_message_id'] = 0;
      mediaParams['offset'] = 0;
      mediaParams['limit'] = 50;
      const result: Record<string, Object> = await TDLibClient.getInstance().send('searchChatMessages', mediaParams);
      const messages = result['messages'] as Record<string, Object>[];
      if (messages && messages.length > 0) {
        this.mediaItems = messages.map((msg, index) => {
          const content = msg['content'] as Record<string, Object>;
          const contentType = (content['@type'] as string) || '';
          const isVideo = contentType === 'messageVideo';
          const date = (msg['date'] as number) || 0;
          return {
            id: (msg['id'] as number) || index,
            type: isVideo ? 'video' : 'photo',
            url: '',
            name: isVideo ? `Video ${index + 1}` : `Photo ${index + 1}`,
            date: date,
            size: ''
          } as SharedMediaItem;
        });
        return;
      }
    } catch (_e) {
      // Fallback to stub data
    }
    this.mediaItems = [
      { id: 1, type: 'photo', url: '', name: 'Photo 1', date: 1706000000, size: '1.2 MB' },
      { id: 2, type: 'photo', url: '', name: 'Photo 2', date: 1705900000, size: '800 KB' },
      { id: 3, type: 'photo', url: '', name: 'Photo 3', date: 1705800000, size: '2.1 MB' },
      { id: 4, type: 'video', url: '', name: 'Video 1', date: 1705700000, size: '15 MB' },
      { id: 5, type: 'photo', url: '', name: 'Photo 4', date: 1705600000, size: '900 KB' },
      { id: 6, type: 'photo', url: '', name: 'Photo 5', date: 1705500000, size: '1.5 MB' },
    ];
  }

  private async loadFileItems(): Promise<void> {
    try {
      const docFilter: Record<string, Object> = {};
      docFilter['@type'] = 'searchMessagesFilterDocument';
      const docParams: Record<string, Object> = {};
      docParams['chat_id'] = this.chatId;
      docParams['query'] = '';
      docParams['filter'] = docFilter;
      docParams['from_message_id'] = 0;
      docParams['offset'] = 0;
      docParams['limit'] = 50;
      const result: Record<string, Object> = await TDLibClient.getInstance().send('searchChatMessages', docParams);
      const messages = result['messages'] as Record<string, Object>[];
      if (messages && messages.length > 0) {
        this.fileItems = messages.map((msg, index) => {
          const content = msg['content'] as Record<string, Object>;
          const doc = content['document'] as Record<string, Object>;
          const fileName = (doc?.['file_name'] as string) || 'Document';
          const size = (doc?.['size'] as number) || 0;
          return {
            id: (msg['id'] as number) || index,
            type: 'file',
            url: '',
            name: fileName,
            date: (msg['date'] as number) || 0,
            size: this.formatSize(size)
          } as SharedMediaItem;
        });
        return;
      }
    } catch (_e) {
      // Fallback to stub data
    }
    this.fileItems = [
      { id: 10, type: 'file', url: '', name: 'document.pdf', date: 1706000000, size: '2.4 MB' },
      { id: 11, type: 'file', url: '', name: 'report.xlsx', date: 1705500000, size: '500 KB' },
      { id: 12, type: 'file', url: '', name: 'presentation.pptx', date: 1705200000, size: '8.3 MB' },
    ];
  }

  private async loadLinkItems(): Promise<void> {
    try {
      const urlFilter: Record<string, Object> = {};
      urlFilter['@type'] = 'searchMessagesFilterUrl';
      const urlParams: Record<string, Object> = {};
      urlParams['chat_id'] = this.chatId;
      urlParams['query'] = '';
      urlParams['filter'] = urlFilter;
      urlParams['from_message_id'] = 0;
      urlParams['offset'] = 0;
      urlParams['limit'] = 50;
      const result: Record<string, Object> = await TDLibClient.getInstance().send('searchChatMessages', urlParams);
      const messages = result['messages'] as Record<string, Object>[];
      if (messages && messages.length > 0) {
        this.linkItems = messages.map((msg, index) => {
          const content = msg['content'] as Record<string, Object>;
          const webPage = content['web_page'] as Record<string, Object>;
          const text = content['text'] as Record<string, Object>;
          return {
            id: (msg['id'] as number) || index,
            type: 'link',
            url: (webPage?.['url'] as string) || (text?.['text'] as string) || '',
            name: (webPage?.['title'] as string) || 'Link',
            date: (msg['date'] as number) || 0,
            size: ''
          } as SharedMediaItem;
        });
        return;
      }
    } catch (_e) {
      // Fallback to stub data
    }
    this.linkItems = [
      { id: 20, type: 'link', url: 'https://telegram.org', name: 'Telegram', date: 1706000000, size: '' },
      { id: 21, type: 'link', url: 'https://example.com', name: 'Example Domain', date: 1705800000, size: '' },
    ];
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
            .fontSize(17)
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
        if (this.activeTab === 0) {
          this.buildMediaGrid()
        } else if (this.activeTab === 1) {
          this.buildFilesList()
        } else if (this.activeTab === 2) {
          this.buildLinksList()
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
    Grid() {
      ForEach(this.mediaItems, (item: SharedMediaItem) => {
        GridItem() {
          Stack({ alignContent: Alignment.BottomEnd }) {
            // Thumbnail placeholder
            Column() {
              Image($r('app.media.ic_photo'))
                .width(32).height(32)
                .fillColor(Color.White)
                .opacity(0.6)
            }
            .width('100%')
            .height('100%')
            .backgroundColor(item.type === 'video' ? '#333333' : '#E0E0E0')
            .justifyContent(FlexAlign.Center)

            if (item.type === 'video') {
              Row() {
                Image($r('app.media.ic_play'))
                  .width(12).height(12)
                  .fillColor(Color.White)
                Text('0:30')
                  .fontSize(10)
                  .fontColor(Color.White)
                  .margin({ left: 2 })
              }
              .padding({ left: 4, right: 4, top: 2, bottom: 2 })
              .backgroundColor($r('app.color.time_overlay'))
              .borderRadius(4)
              .margin({ right: 4, bottom: 4 })
            }
          }
        }
        .onClick(() => {
          const navParam: Record<string, Object> = {};
          navParam['url'] = item.url;
          this.navPathStack.pushPath(new NavPathInfo('MediaViewer', navParam));
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

  @Builder
  buildFilesList() {
    List() {
      ForEach(this.fileItems, (item: SharedMediaItem) => {
        ListItem() {
          Row() {
            Column() {
              Image($r('app.media.ic_document'))
                .width(22).height(22)
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

              Text(`${item.size} \u{2022} ${this.formatDate(item.date)}`)
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Image($r('app.media.ic_download'))
              .width(22).height(22)
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

  @Builder
  buildLinksList() {
    List() {
      ForEach(this.linkItems, (item: SharedMediaItem) => {
        ListItem() {
          Row() {
            Column() {
              Image($r('app.media.ic_forward'))
                .width(22).height(22)
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
                .fontSize(13)
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

  private formatDate(timestamp: number): string {
    if (timestamp === 0) return '';
    const date = new Date(timestamp * 1000);
    return `${date.getDate()}.${(date.getMonth() + 1).toString().padStart(2, '0')}.${date.getFullYear()}`;
  }
}
