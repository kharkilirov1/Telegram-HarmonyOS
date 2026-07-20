import { TgUiTokens } from '../tokens/TgUiTokens';

@ComponentV2
export struct TgChatBackground {
  @Param showPattern: boolean = true;

  build() {
    Stack() {
      if (this.showPattern) {
        Image($r('app.media.tg_chat_wallpaper_tile'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.ScaleDown)
          .objectRepeat(ImageRepeat.XY)
          .draggable(false)
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TgUiTokens.COLOR_CHAT_WALLPAPER_BASE)
    .hitTestBehavior(HitTestMode.None)
  }
}
