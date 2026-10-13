import { TgPhotoSelectionPreview, resolvePhotoSelectionPreviewColor } from '../atoms/TgPhotoSelectionPreview';
import { TgUiTokens } from '../tokens/TgUiTokens';

@Preview({ title: 'Selected photo preview' })
@ComponentV2
export struct TgPhotoSelectionPreviewDemo {
  @Param sampleUris: string[] = [];
  @Param missingUri: string = '';

  @Builder
  private caseBlock(label: string, uris: string[], disabled: boolean, width: number, key: string) {
    Column({ space: TgUiTokens.SPACE_8 }) {
      Text(label).fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(resolvePhotoSelectionPreviewColor(this.getUIContext(), TgUiTokens.COLOR_TEXT_TITLE_RESOURCE_NAME))
      TgPhotoSelectionPreview({ uris: uris, disabled: disabled, idPrefix: 'photo-preview-demo-' + key })
    }
    .width(width)
    .padding(TgUiTokens.SPACE_8)
  }

  build() {
    Scroll() {
      Column({ space: TgUiTokens.SPACE_16 }) {
        Text('Host supplies original local sample images; no account or picker required.')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(resolvePhotoSelectionPreviewColor(this.getUIContext(), TgUiTokens.COLOR_TEXT_TITLE_RESOURCE_NAME))
        this.caseBlock('01 single', this.sampleUris.slice(0, 1), false, TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 'single')
        this.caseBlock('02 pair', this.sampleUris.slice(0, 2), false, TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 'pair')
        this.caseBlock('03 three', this.sampleUris.slice(0, 3), false, TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 'three')
        this.caseBlock('04 maximum ten', this.sampleUris.slice(0, 10), false, TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 'ten')
        this.caseBlock('05 narrow', this.sampleUris.slice(0, 3), false, TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH, 'narrow')
        this.caseBlock('06 sending / denied', this.sampleUris.slice(0, 3), true, TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 'disabled')
        this.caseBlock('07 unavailable', this.missingUri.length > 0 ? [this.missingUri] : [], false,
          TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 'missing')
        this.caseBlock('08 empty', [], false, TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, 'empty')
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(resolvePhotoSelectionPreviewColor(this.getUIContext(), TgUiTokens.COLOR_BG_PRIMARY_RESOURCE_NAME))
  }
}
