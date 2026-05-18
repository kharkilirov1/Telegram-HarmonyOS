import { TgUiTokens } from '../tokens/TgUiTokens';
import { TgDocumentRow } from '../atoms/TgDocumentRow';

@Preview({ title: 'TgDocumentRow' })
@ComponentV2
export struct TgDocumentRowDemo {
  @Builder
  private caseBlock(label: string, isOutgoing: boolean, fileName: string, fileSize: number, mimeType: string,
    progress: number = -1, isDownloading: boolean = false, documentPath: string = '',
    containerWidth: number = TgUiTokens.MSG_DEMO_BASE_CONTAINER_WIDTH, useConstrainedContainer: boolean = false) {
    Column({ space: TgUiTokens.SPACE_6 }) {
      Text(label)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')

      if (useConstrainedContainer) {
        Row() {
          TgDocumentRow({
            fileName: fileName,
            fileSize: fileSize,
            mimeType: mimeType,
            isOutgoing: isOutgoing,
            documentPath: documentPath,
            downloadProgress: progress,
            isDownloading: isDownloading,
            containerWidth: containerWidth
          })
            .width(containerWidth)
        }
        .width('100%')
      } else {
        TgDocumentRow({
          fileName: fileName,
          fileSize: fileSize,
          mimeType: mimeType,
          isOutgoing: isOutgoing,
          documentPath: documentPath,
          downloadProgress: progress,
          isDownloading: isDownloading,
          containerWidth: containerWidth
        })
      }
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_6,
      bottom: TgUiTokens.SPACE_6
    })
  }

  build() {
    Scroll() {
      Column() {
        Text('TgDocumentRow Demo')
          .fontSize(TgUiTokens.FONT_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            top: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        Text('Phase C.1 / Step 3: document attachment row with file info, transfer status, and optional download progress')
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            bottom: TgUiTokens.SPACE_8
          })

        this.caseBlock('01 incoming PDF', false, 'telegram_porting_checklist.pdf', 2_460_000, 'application/pdf')
        this.caseBlock('02 outgoing DOCX downloaded', true, 'DesignSystemSpec_v2.docx', 842_300,
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document', -1, false, 'file:///demo/DesignSystemSpec_v2.docx')
        this.caseBlock('03 incoming long filename', false,
          'very_very_long_business_contract_final_revision_approved_signed_version_2026-02-26.pdf', 8_761_000, 'application/pdf')
        this.caseBlock('04 outgoing downloading 37%', true, 'lecture_recording.zip', 125_670_000, 'application/zip',
          0.37, true)
        this.caseBlock('05 incoming indeterminate download', false, 'archive_backup.tar', 41_900_000, 'application/x-tar',
          -1, true)
        this.caseBlock('06 incoming downloading 92%', false, 'analytics_dump.csv', 24_300_000, 'text/csv', 0.92, true)
        this.caseBlock('07 outgoing no extension', true, 'Invoice', 53_000, '', -1)
        this.caseBlock('08 narrow container downloading stress', false, 'a_really_long_filename_for_width_stress_test.pptx',
          4_120_000, 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          0.18, true, '', TgUiTokens.MSG_DEMO_NARROW_CONTAINER_WIDTH, true)
      }
      .width('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}
