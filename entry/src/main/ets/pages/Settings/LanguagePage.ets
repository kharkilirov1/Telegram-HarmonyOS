// Language settings page — select app language
// Reference: Telegram iOS LanguageSelectionController, Android LanguageSelectActivity

import { PreferencesService } from '../../services/PreferencesService';
import { i18n } from '@kit.LocalizationKit';

@Builder
export function LanguageBuilder(name: string, param: Object) {
  LanguagePage()
}

interface LanguageItem {
  code: string;
  name: string;
  nativeName: string;
  isOfficial: boolean;
}

@ComponentV2
export struct LanguagePage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Local searchText: string = '';
  @Local selectedLanguage: string = 'en';

  private languages: LanguageItem[] = [
    { code: 'en', name: 'English', nativeName: 'English', isOfficial: true },
    { code: 'ru', name: 'Russian', nativeName: 'Русский', isOfficial: true },
    { code: 'zh', name: 'Chinese (Simplified)', nativeName: '简体中文', isOfficial: true },
    { code: 'es', name: 'Spanish', nativeName: 'Español', isOfficial: true },
    { code: 'de', name: 'German', nativeName: 'Deutsch', isOfficial: true },
    { code: 'fr', name: 'French', nativeName: 'Français', isOfficial: true },
    { code: 'it', name: 'Italian', nativeName: 'Italiano', isOfficial: true },
    { code: 'pt', name: 'Portuguese (Brazil)', nativeName: 'Português (Brasil)', isOfficial: true },
    { code: 'ko', name: 'Korean', nativeName: '한국어', isOfficial: true },
    { code: 'ja', name: 'Japanese', nativeName: '日本語', isOfficial: true },
    { code: 'ar', name: 'Arabic', nativeName: 'العربية', isOfficial: true },
    { code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', isOfficial: true },
    { code: 'tr', name: 'Turkish', nativeName: 'Türkçe', isOfficial: true },
    { code: 'nl', name: 'Dutch', nativeName: 'Nederlands', isOfficial: true },
    { code: 'pl', name: 'Polish', nativeName: 'Polski', isOfficial: true },
    { code: 'uk', name: 'Ukrainian', nativeName: 'Українська', isOfficial: true },
    { code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia', isOfficial: false },
    { code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu', isOfficial: false },
    { code: 'th', name: 'Thai', nativeName: 'ภาษาไทย', isOfficial: false },
    { code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt', isOfficial: false },
    { code: 'fa', name: 'Persian', nativeName: 'فارسی', isOfficial: false },
    { code: 'uz', name: 'Uzbek', nativeName: 'O\'zbekcha', isOfficial: false }
  ];

  aboutToAppear(): void {
    void this.loadSelectedLanguage();
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .padding(12)
            .onClick(() => this.navPathStack.pop())

          Text($r('app.string.settings_language'))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })

          Blank()
        }
        .width('100%')
        .height(48)
        .padding({ left: 12, right: 12 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })
        .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 24, bottomRight: 24 })
        .shadow({ radius: 8, color: $r('app.color.shadow_color'), offsetY: 2 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        // Search bar
        Row() {
          Image($r('app.media.ic_search'))
            .width(18).height(18)
            .fillColor($r('app.color.text_secondary'))
            .margin({ right: 8 })

          TextInput({ placeholder: $r('app.string.search_placeholder'), text: this.searchText })
            .fontSize(16)
            .layoutWeight(1)
            .backgroundColor(Color.Transparent)
            .onChange((value: string) => { this.searchText = value; })
        }
        .width('100%')
        .height(40)
        .padding({ left: 12, right: 12 })
        .margin({ left: 16, right: 16, top: 8, bottom: 8 })
        .backgroundColor($r('app.color.search_bar_bg'))
        .borderRadius(10)

        // Language list
        Scroll() {
          Column() {
            // Official languages section
            Text($r('app.string.language_official_section'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 32, top: 8, bottom: 6 })

            Column() {
              ForEach(this.getFilteredLanguages(true), (lang: LanguageItem, index: number) => {
                if (index > 0) {
                  Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })
                }
                this.languageRow(lang)
              }, (lang: LanguageItem) => lang.code)
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Blank().height(24)

            // Unofficial languages section
            Text($r('app.string.language_unofficial_section'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ left: 32, bottom: 6 })

            Column() {
              ForEach(this.getFilteredLanguages(false), (lang: LanguageItem, index: number) => {
                if (index > 0) {
                  Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 52 })
                }
                this.languageRow(lang)
              }, (lang: LanguageItem) => lang.code)
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(24)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 12, right: 12 })

            Blank().height(40)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
    }
    .hideTitleBar(true)
  }

  @Builder
  languageRow(lang: LanguageItem) {
    Row() {
      Column() {
        Text(lang.nativeName)
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
        Text(lang.name)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 1 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (lang.code === this.selectedLanguage) {
        Image($r('app.media.ic_check_single'))
          .width(20).height(20)
          .fillColor($r('app.color.telegram_blue'))
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.selectedLanguage = lang.code;
      void this.persistSelectedLanguage(lang.code);
    })
  }

  private getFilteredLanguages(official: boolean): LanguageItem[] {
    const query = this.searchText.toLowerCase();
    return this.languages.filter(lang =>
      lang.isOfficial === official &&
      (query.length === 0 ||
       lang.name.toLowerCase().includes(query) ||
       lang.nativeName.toLowerCase().includes(query) ||
       lang.code.includes(query))
    );
  }

  private async loadSelectedLanguage(): Promise<void> {
    this.selectedLanguage = await PreferencesService.getInstance().getAppLanguage();
  }

  private async persistSelectedLanguage(code: string): Promise<void> {
    await PreferencesService.getInstance().setAppLanguage(code);
    this.applyLanguage(code);
  }

  private applyLanguage(code: string): void {
    try {
      i18n.System.setAppPreferredLanguage(this.mapLanguageCode(code));
    } catch (_e) {
      // Keep persisted value; language will be applied on next app start.
    }
  }

  private mapLanguageCode(code: string): string {
    switch (code) {
      case 'zh':
        return 'zh-Hans';
      case 'pt':
        return 'pt-BR';
      default:
        return code;
    }
  }
}
