// ChatSearchBar — per-chat search panel extracted from ChatDetailPage
// Reference: Telegram iOS ChatSearchBar, Android ChatSearchView

import { MessagesController } from '../../controllers/MessagesController';
import { ChatService } from '../../services/ChatService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Message } from '../../models/Message';

@ComponentV2
export struct ChatSearchBar {
  @Param chatId: number = 0;
  @Event onClose: () => void = () => {};
  @Event onScrollToMessage: (messageId: number) => void = () => {};

  @Local searchQuery: string = '';
  @Local searchResults: Message[] = [];
  @Local currentSearchIndex: number = -1;
  @Local isSearching: boolean = false;
  @Local searchSenderId: number = 0;
  @Local searchSenderName: string = '';
  @Local searchFilter: string = '';
  @Local showSearchFilters: boolean = false;
  @Local showSenderInput: boolean = false;
  @Local searchFromDate: number = 0;

  private searchTimer: number = 0;

  build() {
    Column() {
      // Search input row
      Row() {
        Image($r('app.media.ic_back'))
          .width(20).height(20)
          .fillColor($r('app.color.text_secondary'))
          .accessibilityText($r('app.string.accessibility_back'))
          .onClick(() => { this.onClose(); })

        TextInput({ text: this.searchQuery, placeholder: $r('app.string.search_in_chat') })
          .layoutWeight(1)
          .height(36)
          .margin({ left: 8, right: 8 })
          .backgroundColor($r('app.color.search_bar_bg'))
          .borderRadius(18)
          .fontSize(15)
          .onChange((value: string) => {
            this.searchQuery = value;
            if (value.length > 0) {
              this.performChatSearch(value);
            } else {
              this.searchResults = [];
              this.currentSearchIndex = -1;
            }
          })

        if (this.isSearching) {
          LoadingProgress()
            .width(20).height(20)
            .color($r('app.color.telegram_blue'))
        } else if (this.searchResults.length > 0) {
          Text(`${this.currentSearchIndex + 1}/${this.searchResults.length}`)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ right: 4 })

          Image($r('app.media.ic_arrow_up'))
            .width(20).height(20)
            .fillColor($r('app.color.telegram_blue'))
            .accessibilityText($r('app.string.search_previous_result'))
            .onClick(() => { this.navigateSearchResult(-1); })

          Image($r('app.media.ic_arrow_down'))
            .width(20).height(20)
            .fillColor($r('app.color.telegram_blue'))
            .margin({ left: 4 })
            .accessibilityText($r('app.string.search_next_result'))
            .onClick(() => { this.navigateSearchResult(1); })
        }

        // Toggle filter chips visibility
        Image($r('app.media.ic_more'))
          .width(20).height(20)
          .fillColor(this.showSearchFilters
            ? $r('app.color.telegram_blue')
            : $r('app.color.text_secondary'))
          .margin({ left: 4 })
          .accessibilityText($r('app.string.accessibility_more'))
          .onClick(() => {
            this.showSearchFilters = !this.showSearchFilters;
            if (!this.showSearchFilters) {
              this.showSenderInput = false;
            }
          })
      }
      .width('100%')
      .height(48)
      .padding({ left: 12, right: 12 })

      // Filter chips row
      if (this.showSearchFilters) {
        Scroll() {
          Row({ space: 8 }) {
            this.filterChip($r('app.string.search_filter_all'), '', this.searchFilter === '')
            this.filterChipFrom()
            this.filterChip($r('app.string.search_filter_photos'), 'photo', this.searchFilter === 'photo')
            this.filterChip($r('app.string.search_filter_videos'), 'video', this.searchFilter === 'video')
            this.filterChip($r('app.string.search_filter_files'), 'document', this.searchFilter === 'document')
            this.filterChip($r('app.string.search_filter_links'), 'url', this.searchFilter === 'url')

            // Calendar / date jump chip
            Text($r('app.string.search_jump_to_date'))
              .fontSize(13)
              .fontColor(this.searchFromDate > 0
                ? $r('app.color.search_chip_active_text')
                : $r('app.color.search_chip_text'))
              .backgroundColor(this.searchFromDate > 0
                ? $r('app.color.search_chip_active_bg')
                : $r('app.color.search_chip_bg'))
              .borderRadius(14)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .accessibilityText($r('app.string.search_jump_to_date'))
              .onClick(() => { this.showDatePickerForJump(); })
          }
          .padding({ left: 12, right: 12 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(40)

        // Sender name input
        if (this.showSenderInput) {
          Row() {
            TextInput({
              text: this.searchSenderName,
              placeholder: $r('app.string.search_from_sender')
            })
              .layoutWeight(1)
              .height(36)
              .backgroundColor($r('app.color.search_sender_input_bg'))
              .borderRadius(18)
              .fontSize(14)
              .onChange((value: string) => { this.searchSenderName = value; })
              .onSubmit(() => { this.lookupSenderByName(this.searchSenderName); })

            if (this.searchSenderId > 0) {
              Image($r('app.media.ic_close'))
                .width(18).height(18)
                .fillColor($r('app.color.text_secondary'))
                .margin({ left: 8 })
                .accessibilityText($r('app.string.cancel'))
                .onClick(() => {
                  this.searchSenderId = 0;
                  this.searchSenderName = '';
                  this.showSenderInput = false;
                  if (this.searchQuery.length > 0) {
                    this.performChatSearch(this.searchQuery);
                  }
                })
            }
          }
          .width('100%')
          .height(44)
          .padding({ left: 12, right: 12 })
        }
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_nav_bg'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  filterChip(label: Resource, filterType: string, isActive: boolean) {
    Text(label)
      .fontSize(13)
      .fontColor(isActive
        ? $r('app.color.search_chip_active_text')
        : $r('app.color.search_chip_text'))
      .backgroundColor(isActive
        ? $r('app.color.search_chip_active_bg')
        : $r('app.color.search_chip_bg'))
      .borderRadius(14)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .accessibilityText(label)
      .onClick(() => {
        if (filterType === '') {
          this.searchFilter = '';
          this.searchSenderId = 0;
          this.searchSenderName = '';
          this.showSenderInput = false;
        } else {
          this.searchFilter = this.searchFilter === filterType ? '' : filterType;
        }
        if (this.searchQuery.length > 0) {
          this.performChatSearch(this.searchQuery);
        }
      })
  }

  @Builder
  filterChipFrom() {
    Text(this.searchSenderName.length > 0
      ? `${this.searchSenderName}`
      : $r('app.string.search_filter_from'))
      .fontSize(13)
      .fontColor(this.searchSenderId > 0
        ? $r('app.color.search_chip_active_text')
        : $r('app.color.search_chip_text'))
      .backgroundColor(this.searchSenderId > 0
        ? $r('app.color.search_chip_active_bg')
        : $r('app.color.search_chip_bg'))
      .borderRadius(14)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .accessibilityText($r('app.string.search_filter_from'))
      .onClick(() => { this.showSenderInput = !this.showSenderInput; })
  }

  // --- Search logic ---

  private performChatSearch(query: string): void {
    if (this.searchTimer) {
      clearTimeout(this.searchTimer);
    }
    this.searchTimer = setTimeout(async () => {
      this.isSearching = true;
      try {
        const results = await MessagesController.getInstance()
          .searchChatMessages(this.chatId, query, 0, 50, this.searchSenderId, this.searchFilter);
        this.searchResults = results;
        this.currentSearchIndex = results.length > 0 ? 0 : -1;
        if (results.length > 0) {
          this.onScrollToMessage(results[0].id);
        }
      } catch (e) {
        hilog.warn(0x0001, 'ChatSearchBar', 'Chat search failed: %{public}s', String(e));
        this.searchResults = [];
        this.currentSearchIndex = -1;
      }
      this.isSearching = false;
    }, 300) as number;
  }

  private navigateSearchResult(direction: number): void {
    if (this.searchResults.length === 0) return;
    let newIndex = this.currentSearchIndex + direction;
    if (newIndex < 0) newIndex = this.searchResults.length - 1;
    if (newIndex >= this.searchResults.length) newIndex = 0;
    this.currentSearchIndex = newIndex;
    this.onScrollToMessage(this.searchResults[newIndex].id);
  }

  private showDatePickerForJump(): void {
    DatePickerDialog.show({
      start: new Date(2013, 0, 1),
      end: new Date(),
      selected: this.searchFromDate > 0
        ? new Date(this.searchFromDate * 1000)
        : new Date(),
      lunar: false,
      onDateAccept: (value: Date) => {
        const selectedDate = new Date(value.getFullYear(), value.getMonth(), value.getDate());
        const timestamp = Math.floor(selectedDate.getTime() / 1000);
        this.searchFromDate = timestamp;
        this.jumpToDate(timestamp);
      }
    });
  }

  private async jumpToDate(timestamp: number): Promise<void> {
    try {
      const result = await ChatService.getInstance().getChatMessageByDate(this.chatId, timestamp);
      if (result && result['id']) {
        const messageId = result['id'] as number;
        this.onScrollToMessage(messageId);
      }
    } catch (e) {
      hilog.warn(0x0001, 'ChatSearchBar', 'Failed to jump to date');
    }
  }

  private async lookupSenderByName(name: string): Promise<void> {
    if (name.length === 0) {
      this.searchSenderId = 0;
      return;
    }
    try {
      const result = await ChatService.getInstance().searchChatMembers(this.chatId, name, 10);
      const members = result['members'] as Record<string, Object>[];
      if (members && members.length > 0) {
        const firstMember = members[0];
        const memberId = firstMember['member_id'] as Record<string, Object>;
        if (memberId && memberId['@type'] === 'messageSenderUser') {
          this.searchSenderId = memberId['user_id'] as number || 0;
          this.showSenderInput = false;
          if (this.searchQuery.length > 0) {
            this.performChatSearch(this.searchQuery);
          }
        }
      }
    } catch (e) {
      hilog.warn(0x0001, 'ChatSearchBar', 'Failed to look up sender');
    }
  }
}
