// Emoji picker panel — categorized grid (reference: Telegram Android EmojiView)

const EMOJI_CATEGORIES: EmojiCategory[] = [
  {
    name: 'Smileys',
    icon: '\u{1F600}',
    emojis: [
      '\u{1F600}', '\u{1F603}', '\u{1F604}', '\u{1F601}', '\u{1F606}', '\u{1F605}',
      '\u{1F602}', '\u{1F923}', '\u{1F60A}', '\u{1F607}', '\u{1F642}', '\u{1F643}',
      '\u{1F609}', '\u{1F60C}', '\u{1F60D}', '\u{1F970}', '\u{1F618}', '\u{1F617}',
      '\u{1F619}', '\u{1F61A}', '\u{1F60B}', '\u{1F61B}', '\u{1F61C}', '\u{1F92A}',
      '\u{1F61D}', '\u{1F911}', '\u{1F917}', '\u{1F92D}', '\u{1F92B}', '\u{1F914}',
      '\u{1F910}', '\u{1F928}', '\u{1F610}', '\u{1F611}', '\u{1F636}', '\u{1F60F}',
      '\u{1F612}', '\u{1F644}', '\u{1F62C}', '\u{1F925}', '\u{1F60C}', '\u{1F614}',
      '\u{1F62A}', '\u{1F924}', '\u{1F634}', '\u{1F637}', '\u{1F912}', '\u{1F915}',
      '\u{1F922}', '\u{1F92E}', '\u{1F927}', '\u{1F975}', '\u{1F976}', '\u{1F974}',
      '\u{1F635}', '\u{1F92F}', '\u{1F920}', '\u{1F973}', '\u{1F978}', '\u{1F60E}',
      '\u{1F913}', '\u{1F9D0}', '\u{1F615}', '\u{1F61F}', '\u{1F641}', '\u{2639}',
      '\u{1F62E}', '\u{1F62F}', '\u{1F632}', '\u{1F633}', '\u{1F97A}', '\u{1F979}'
    ]
  },
  {
    name: 'Gestures',
    icon: '\u{1F44D}',
    emojis: [
      '\u{1F44D}', '\u{1F44E}', '\u{1F44A}', '\u{270A}', '\u{1F91B}', '\u{1F91C}',
      '\u{1F44F}', '\u{1F64C}', '\u{1F450}', '\u{1F932}', '\u{1F91D}', '\u{1F64F}',
      '\u{270D}', '\u{1F485}', '\u{1F933}', '\u{1F4AA}', '\u{1F9B5}', '\u{1F9B6}',
      '\u{1F442}', '\u{1F443}', '\u{1F9E0}', '\u{1F9B7}', '\u{1F9B4}', '\u{1F440}',
      '\u{1F441}', '\u{1F445}', '\u{1F444}', '\u{1F476}', '\u{1F9D2}', '\u{1F466}',
      '\u{1F467}', '\u{1F9D1}', '\u{1F471}', '\u{1F468}', '\u{1F469}', '\u{1F9D4}'
    ]
  },
  {
    name: 'Animals',
    icon: '\u{1F436}',
    emojis: [
      '\u{1F436}', '\u{1F431}', '\u{1F42D}', '\u{1F439}', '\u{1F430}', '\u{1F98A}',
      '\u{1F43B}', '\u{1F43C}', '\u{1F428}', '\u{1F42F}', '\u{1F981}', '\u{1F434}',
      '\u{1F984}', '\u{1F42E}', '\u{1F437}', '\u{1F438}', '\u{1F435}', '\u{1F412}',
      '\u{1F414}', '\u{1F427}', '\u{1F426}', '\u{1F985}', '\u{1F989}', '\u{1F987}',
      '\u{1F43A}', '\u{1F417}', '\u{1F434}', '\u{1F41D}', '\u{1F41B}', '\u{1F98B}',
      '\u{1F40C}', '\u{1F41A}', '\u{1F41E}', '\u{1F997}', '\u{1F577}', '\u{1F982}'
    ]
  },
  {
    name: 'Food',
    icon: '\u{1F34E}',
    emojis: [
      '\u{1F34E}', '\u{1F34F}', '\u{1F350}', '\u{1F34A}', '\u{1F34B}', '\u{1F34C}',
      '\u{1F349}', '\u{1F347}', '\u{1F353}', '\u{1F348}', '\u{1F352}', '\u{1F351}',
      '\u{1F96D}', '\u{1F34D}', '\u{1F965}', '\u{1F95D}', '\u{1F345}', '\u{1F346}',
      '\u{1F951}', '\u{1F966}', '\u{1F955}', '\u{1F33D}', '\u{1F336}', '\u{1F952}',
      '\u{1F96C}', '\u{1F96B}', '\u{1F344}', '\u{1F95C}', '\u{1F330}', '\u{1F35E}',
      '\u{1F950}', '\u{1F956}', '\u{1F968}', '\u{1F96F}', '\u{1F95E}', '\u{1F9C7}'
    ]
  },
  {
    name: 'Travel',
    icon: '\u{1F697}',
    emojis: [
      '\u{1F697}', '\u{1F695}', '\u{1F699}', '\u{1F68C}', '\u{1F68E}', '\u{1F3CE}',
      '\u{1F693}', '\u{1F691}', '\u{1F692}', '\u{1F6F5}', '\u{1F3CD}', '\u{1F6B2}',
      '\u{1F6F4}', '\u{1F6F9}', '\u{1F6FA}', '\u{1F681}', '\u{1F6EB}', '\u{1F6EC}',
      '\u{2708}', '\u{1F680}', '\u{1F6F8}', '\u{1F6A2}', '\u{26F5}', '\u{1F6A4}',
      '\u{1F3E0}', '\u{1F3E2}', '\u{1F3E5}', '\u{1F3EB}', '\u{1F3ED}', '\u{1F3F0}',
      '\u{26EA}', '\u{1F54C}', '\u{1F54D}', '\u{26E9}', '\u{1F5FC}', '\u{1F5FD}'
    ]
  },
  {
    name: 'Objects',
    icon: '\u{2764}',
    emojis: [
      '\u{2764}', '\u{1F49B}', '\u{1F49A}', '\u{1F499}', '\u{1F49C}', '\u{1F5A4}',
      '\u{1F90E}', '\u{1F90D}', '\u{1F494}', '\u{2763}', '\u{1F495}', '\u{1F49E}',
      '\u{1F493}', '\u{1F497}', '\u{1F496}', '\u{1F498}', '\u{1F49D}', '\u{1F49F}',
      '\u{262E}', '\u{271D}', '\u{262A}', '\u{1F549}', '\u{2638}', '\u{2721}',
      '\u{1F52E}', '\u{1F4F0}', '\u{1F3B5}', '\u{1F3B6}', '\u{1F3A4}', '\u{1F3A7}',
      '\u{1F4F1}', '\u{1F4BB}', '\u{1F4F7}', '\u{1F4F9}', '\u{1F4FA}', '\u{1F4FB}'
    ]
  },
  {
    name: 'Flags',
    icon: '\u{1F3C1}',
    emojis: [
      '\u{1F3C1}', '\u{1F6A9}', '\u{1F3F4}', '\u{1F3F3}',
      '\u{1F1FA}\u{1F1F8}', '\u{1F1EC}\u{1F1E7}', '\u{1F1E9}\u{1F1EA}',
      '\u{1F1EB}\u{1F1F7}', '\u{1F1EF}\u{1F1F5}', '\u{1F1F0}\u{1F1F7}',
      '\u{1F1E8}\u{1F1F3}', '\u{1F1F7}\u{1F1FA}', '\u{1F1EE}\u{1F1F3}',
      '\u{1F1E7}\u{1F1F7}', '\u{1F1E8}\u{1F1E6}', '\u{1F1E6}\u{1F1FA}',
      '\u{1F1EE}\u{1F1F9}', '\u{1F1EA}\u{1F1F8}', '\u{1F1F2}\u{1F1FD}',
      '\u{1F1F3}\u{1F1EC}', '\u{1F1E6}\u{1F1F7}', '\u{1F1F9}\u{1F1F7}'
    ]
  }
];

interface EmojiCategory {
  name: string;
  icon: string;
  emojis: string[];
}

@ComponentV2
export struct EmojiPicker {
  @Event onEmojiSelected: (emoji: string) => void = () => {};
  @Local activeCategory: number = 0;

  build() {
    Column() {
      // Category tabs — horizontal row of icons (like Telegram Android)
      Row() {
        ForEach(EMOJI_CATEGORIES, (cat: EmojiCategory, index: number) => {
          Text(cat.icon)
            .fontSize(22)
            .padding({ left: 8, right: 8, top: 6, bottom: 6 })
            .opacity(this.activeCategory === index ? 1.0 : 0.4)
            .onClick(() => { this.activeCategory = index; })
        }, (cat: EmojiCategory) => cat.name)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      .backgroundColor($r('app.color.background_secondary'))

      Divider().strokeWidth(0.5).color($r('app.color.separator'))

      // Emoji grid
      Grid() {
        ForEach(EMOJI_CATEGORIES[this.activeCategory].emojis, (emoji: string) => {
          GridItem() {
            Text(emoji)
              .fontSize(28)
              .textAlign(TextAlign.Center)
              .width('100%')
              .height('100%')
              .onClick(() => { this.onEmojiSelected(emoji); })
          }
        }, (emoji: string) => emoji)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .rowsGap(4)
      .columnsGap(0)
      .width('100%')
      .layoutWeight(1)
      .padding(4)
    }
    .width('100%')
    .height(260)
    .backgroundColor($r('app.color.background_primary'))
  }
}
