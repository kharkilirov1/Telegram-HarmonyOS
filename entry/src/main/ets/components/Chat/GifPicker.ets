// GIF picker panel with trending and search
// Reference: Telegram iOS GifPanelController, Android GifAdapter

interface GifItem {
  id: number;
  title: string;
  aspectRatio: number;
}

@ComponentV2
export struct GifPicker {
  @Param onGifSelected: (gifId: number) => void = () => {};
  @Local searchText: string = '';
  @Local isSearching: boolean = false;

  // Stub trending GIFs
  private readonly trendingGifs: GifItem[] = [
    { id: 1, title: 'Hello', aspectRatio: 1.5 },
    { id: 2, title: 'Thank You', aspectRatio: 1.2 },
    { id: 3, title: 'Applause', aspectRatio: 1.0 },
    { id: 4, title: 'Dancing', aspectRatio: 0.8 },
    { id: 5, title: 'Funny Cat', aspectRatio: 1.3 },
    { id: 6, title: 'Mind Blown', aspectRatio: 1.0 },
    { id: 7, title: 'Thumbs Up', aspectRatio: 1.1 },
    { id: 8, title: 'Celebrate', aspectRatio: 1.4 },
    { id: 9, title: 'Shocked', aspectRatio: 0.9 },
    { id: 10, title: 'Laughing', aspectRatio: 1.2 },
    { id: 11, title: 'Sad', aspectRatio: 1.0 },
    { id: 12, title: 'Heart', aspectRatio: 1.0 },
  ];

  // Common search suggestions
  private readonly suggestions: string[] = [
    'hello', 'thanks', 'applause', 'dance', 'cat', 'dog',
    'love', 'happy', 'sad', 'excited', 'thumbs up', 'party'
  ];

  build() {
    Column() {
      // Search bar
      Row() {
        Search({ placeholder: $r('app.string.search_gifs'), value: this.searchText })
          .layoutWeight(1)
          .height(32)
          .onChange((value: string) => {
            this.searchText = value;
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor($r('app.color.background_primary'))

      // Quick suggestion chips
      if (this.searchText.length === 0) {
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.suggestions, (suggestion: string) => {
              Text(suggestion)
                .fontSize(13)
                .fontColor($r('app.color.telegram_blue'))
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .borderRadius(12)
                .backgroundColor($r('app.color.glass_card_bg'))
                .onClick(() => {
                  this.searchText = suggestion;
                })
            }, (suggestion: string) => suggestion)
          }
          .padding({ left: 12, right: 12 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(32)
      }

      // GIF grid — staggered 2-column layout
      Grid() {
        ForEach(this.trendingGifs, (gif: GifItem) => {
          GridItem() {
            Stack({ alignContent: Alignment.BottomStart }) {
              Column()
                .width('100%')
                .height(80 + (gif.aspectRatio - 1.0) * 40)
                .backgroundColor('#E0E0E0')
                .borderRadius(8)

              // GIF label
              Text('GIF')
                .fontSize(10)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.time_overlay'))
                .borderRadius(3)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .margin({ left: 4, bottom: 4 })
            }
            .onClick(() => {
              this.onGifSelected(gif.id);
            })
          }
        }, (gif: GifItem) => gif.id.toString())
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(4)
      .rowsGap(4)
      .width('100%')
      .height(180)
      .padding(4)
      .backgroundColor($r('app.color.background_primary'))
    }
    .width('100%')
  }
}
