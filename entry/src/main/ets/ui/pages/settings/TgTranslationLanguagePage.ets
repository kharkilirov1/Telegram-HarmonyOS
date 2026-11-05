// D24: app-wide translation language picker (Settings). iOS keeps the target outside the chat menu, so a
// single row here changes every chat that has no own choice.

import { localized } from '../../../core/utils/AppResource';
import {
  SUPPORTED_TRANSLATION_LANGUAGES,
  translationLanguageLabel,
  translationLanguagePreferences
} from '../../../domain/usecases/translationLanguage';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';

export class TranslationLanguageRouteParams {
  selectedCode: string = '';
}

@ComponentV2
export struct TgTranslationLanguagePage {
  @Local private selected: string = '';
  private pageStack: NavPathStack = new NavPathStack();
  private topBarInset: number = 0;

  aboutToAppear(): void {
    this.selected = translationLanguagePreferences.globalDefault();
    this.topBarInset = 0;
  }

  private choose(code: string): void {
    if (translationLanguagePreferences.setGlobalDefault(code)) {
      this.selected = code;
      this.pageStack.pop();
    }
  }

  build() {
    NavDestination() {
      Column() {
        TgChatTopBar({
          title: localized($r('app.string.translation_language_title').id, 'Translation Language'),
          subtitle: '',
          topInset: this.topBarInset,
          showMoreAction: false,
          onBackPress: (): void => {
            this.pageStack.pop();
          }
        })
        List() {
          ForEach(SUPPORTED_TRANSLATION_LANGUAGES, (code: string) => {
            ListItem() {
              Row() {
                Text(translationLanguageLabel(code))
                  .fontSize(TgUiTokens.SETTINGS_ROW_TITLE_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                  .layoutWeight(1)
                if (this.selected === code) {
                  Text('✓')
                    .fontSize(TgUiTokens.SETTINGS_ROW_TITLE_SIZE)
                    .fontColor(TgUiTokens.MSG_LINK_INCOMING)
                }
              }
              .width('100%')
              .height(TgUiTokens.SETTINGS_ROW_HEIGHT)
              .padding({
                left: TgUiTokens.SETTINGS_SECTION_SIDE_INSET,
                right: TgUiTokens.SETTINGS_SECTION_SIDE_INSET
              })
              .alignItems(VerticalAlign.Center)
              .onClick((): void => {
                this.choose(code);
              })
            }
          }, (code: string) => code)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext): void => {
      this.pageStack = context.pathStack;
    })
  }
}

@Builder
export function TgTranslationLanguagePageBuilder() {
  TgTranslationLanguagePage()
}
