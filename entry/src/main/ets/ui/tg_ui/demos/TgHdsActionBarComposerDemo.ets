import { LengthMetrics } from '@kit.ArkUI';
import { ActionBarButton, ActionBarStyle, HdsActionBar } from '@kit.UIDesignKit';
import { TgComposerEmojiPanel } from '../atoms/TgComposerEmojiPanel';
import { TgUiTokens } from '../tokens/TgUiTokens';

const MODE_NORMAL: string = 'normal';
const MODE_REPLY: string = 'reply';
const MODE_EDIT: string = 'edit';
const MODE_FORWARD: string = 'forward';
const MODE_ATTACHMENT: string = 'attachment';
const MODE_SLOW: string = 'slow';
const MODE_RECORDING: string = 'recording';

const DEMO_PRIMARY_WIDTH: number = 216;
const DEMO_ACTION_HEIGHT: number = 48;
const DEMO_INPUT_LINE_HEIGHT: number = 20;
const DEMO_MAX_VISIBLE_LINES: number = 4;
const DEMO_PAGE_TOP_INSET: number = 48;
const DEMO_PAGE_BOTTOM_INSET: number = 24;

@Entry
@Preview({ title: 'HdsActionBar Composer Capability' })
@ComponentV2
struct TgHdsActionBarComposerDemo {
  @Local private mode: string = MODE_NORMAL;
  @Local private draft: string = '';
  @Local private showAuxPanel: boolean = false;
  @Local private lastAction: string = 'none';
  private attachActionButton: ActionBarButton = new ActionBarButton({
    id: 'm2c-attach-action',
    baseIcon: $r('sys.symbol.plus'),
    accessibilityText: 'Attachment',
    hoverTips: 'Attachment',
    onClick: (): void => {
      this.selectMode(MODE_ATTACHMENT);
      this.lastAction = 'attach';
    }
  });
  private rightActionButton: ActionBarButton = new ActionBarButton({
    id: 'm2c-right-action',
    baseIcon: $r('sys.symbol.mic_fill'),
    accessibilityText: 'Microphone',
    hoverTips: 'Microphone',
    onClick: (): void => {
      this.handleRightAction();
    }
  });

  private isAccessoryMode(): boolean {
    return this.mode === MODE_REPLY || this.mode === MODE_EDIT ||
      this.mode === MODE_FORWARD || this.mode === MODE_ATTACHMENT;
  }

  private lineCount(): number {
    const count = this.draft.length === 0 ? 1 : this.draft.split('\n').length;
    return Math.max(1, Math.min(DEMO_MAX_VISIBLE_LINES, count));
  }

  private inputHeight(): number {
    return TgUiTokens.COMPOSER_MIN_CAPSULE_HEIGHT +
      (this.lineCount() - 1) * DEMO_INPUT_LINE_HEIGHT;
  }

  private primaryContentHeight(): number {
    if (this.mode === MODE_RECORDING) {
      return DEMO_ACTION_HEIGHT;
    }
    return this.inputHeight() +
      (this.isAccessoryMode() ? TgUiTokens.COMPOSER_ACCESSORY_MIN_HEIGHT : 0);
  }

  private actionBarHeight(): number {
    return Math.max(DEMO_ACTION_HEIGHT, this.primaryContentHeight() + TgUiTokens.SPACE_8);
  }

  private accessoryTitle(): string {
    if (this.mode === MODE_REPLY) {
      return 'Reply to Alex';
    }
    if (this.mode === MODE_EDIT) {
      return 'Edit message';
    }
    if (this.mode === MODE_FORWARD) {
      return 'Forward 2 messages';
    }
    return 'Photo selected';
  }

  private accessoryPreview(): string {
    if (this.mode === MODE_REPLY) {
      return 'The original message stays visible';
    }
    if (this.mode === MODE_EDIT) {
      return 'Original text before editing';
    }
    if (this.mode === MODE_FORWARD) {
      return 'Alex: Photo, Maria: Voice message';
    }
    return 'IMG_0042.JPG';
  }

  private rightActionIcon(): ResourceStr {
    if (this.mode === MODE_RECORDING) {
      return $r('sys.symbol.xmark');
    }
    if (this.mode === MODE_SLOW) {
      return $r('sys.symbol.stopwatch_fill');
    }
    if (this.draft.trim().length > 0) {
      return $r('sys.symbol.play_fill');
    }
    return $r('sys.symbol.mic_fill');
  }

  private rightActionLabel(): string {
    if (this.mode === MODE_RECORDING) {
      return 'Stop synthetic recording';
    }
    if (this.mode === MODE_SLOW) {
      return 'Slow mode';
    }
    return this.draft.trim().length > 0 ? 'Send' : 'Microphone';
  }

  private handleRightAction(): void {
    if (this.mode === MODE_SLOW) {
      return;
    }
    if (this.mode === MODE_RECORDING) {
      this.mode = MODE_NORMAL;
      this.lastAction = 'recording stopped by click';
      this.syncRightActionButton();
      return;
    }
    if (this.draft.trim().length > 0) {
      this.lastAction = `send: ${this.draft}`;
      this.draft = '';
      this.syncRightActionButton();
      return;
    }
    this.mode = MODE_RECORDING;
    this.lastAction = 'recording started by click';
    this.syncRightActionButton();
  }

  private syncRightActionButton(): void {
    this.rightActionButton.baseIcon = this.rightActionIcon();
    this.rightActionButton.enabled = this.mode !== MODE_SLOW;
    this.rightActionButton.accessibilityText = this.rightActionLabel();
    this.rightActionButton.hoverTips = this.rightActionLabel();
  }

  private startButtons(): ActionBarButton[] {
    return [this.attachActionButton];
  }

  private endButtons(): ActionBarButton[] {
    return [this.rightActionButton];
  }

  private selectMode(mode: string): void {
    this.mode = mode;
    this.lastAction = `mode: ${mode}`;
    if (mode === MODE_EDIT && this.draft.length === 0) {
      this.draft = 'Existing message';
    }
    this.syncRightActionButton();
  }

  @Builder
  private modeButton(mode: string, label: string) {
    Button(label)
      .height(32)
      .fontSize(TgUiTokens.FONT_META_SIZE)
      .fontColor(this.mode === mode ? Color.White : TgUiTokens.COLOR_TEXT_TITLE)
      .backgroundColor(this.mode === mode
        ? TgUiTokens.COMPOSER_ACTION_ACTIVE : TgUiTokens.COLOR_BG_SECONDARY)
      .borderRadius(TgUiTokens.RADIUS_12)
      .onClick(() => {
        this.selectMode(mode);
      })
  }

  @Builder
  private accessoryPanel() {
    Row({ space: TgUiTokens.SPACE_8 }) {
      Column({ space: TgUiTokens.COMPOSER_ACCESSORY_TEXT_GAP }) {
        Text(this.accessoryTitle())
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(TgUiTokens.COMPOSER_ACTION_ACTIVE)
          .maxLines(1)
        Text(this.accessoryPreview())
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('×')
        .width(TgUiTokens.COMPOSER_REPLY_CLOSE_SIZE)
        .height(TgUiTokens.COMPOSER_REPLY_CLOSE_SIZE)
        .backgroundColor(Color.Transparent)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .onClick(() => {
          this.mode = MODE_NORMAL;
          this.lastAction = 'accessory closed';
          this.syncRightActionButton();
        })
    }
    .width('100%')
    .height(TgUiTokens.COMPOSER_ACCESSORY_MIN_HEIGHT)
    .padding({ left: TgUiTokens.SPACE_8, right: TgUiTokens.SPACE_8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private recordingContent() {
    Row({ space: TgUiTokens.SPACE_8 }) {
      Circle()
        .width(TgUiTokens.SPACE_8)
        .height(TgUiTokens.SPACE_8)
        .backgroundColor(Color.Red)
      Text('00:07  Recording — click stop')
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(DEMO_ACTION_HEIGHT)
    .padding({ left: TgUiTokens.SPACE_12, right: TgUiTokens.SPACE_8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private primaryComposer() {
    Column() {
      if (this.mode === MODE_RECORDING) {
        this.recordingContent()
      } else {
        if (this.isAccessoryMode()) {
          this.accessoryPanel()
        }
        TextArea({ text: this.draft, placeholder: 'Message' })
          .id('m2c-composer-input')
          .width('100%')
          .height(this.inputHeight())
          .maxLines(DEMO_MAX_VISIBLE_LINES)
          .fontSize(TgUiTokens.COMPOSER_TEXT_SIZE)
          .fontColor(TgUiTokens.COMPOSER_TEXT)
          .placeholderColor(TgUiTokens.COMPOSER_PLACEHOLDER)
          .backgroundColor(Color.Transparent)
          .border({ width: 0 })
          .padding({
            left: TgUiTokens.COMPOSER_TEXT_PADDING_LEFT,
            right: TgUiTokens.SPACE_8,
            top: TgUiTokens.COMPOSER_TEXT_PADDING_TOP,
            bottom: TgUiTokens.COMPOSER_TEXT_PADDING_BOTTOM
          })
          .enabled(this.mode !== MODE_SLOW)
          .onChange((value: string) => {
            this.draft = value;
            this.syncRightActionButton();
          })
      }
    }
    .width(DEMO_PRIMARY_WIDTH)
    .height(this.primaryContentHeight())
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private fakeTimeline() {
    Column({ space: TgUiTokens.SPACE_8 }) {
      Blank()
        .layoutWeight(1)
      Text('Native HDS host + custom Telegram content')
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
      Text('Synthetic timeline message')
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .padding(TgUiTokens.SPACE_12)
        .backgroundColor(TgUiTokens.COLOR_BG_SECONDARY)
        .borderRadius(TgUiTokens.RADIUS_12)
        .alignSelf(ItemAlign.End)
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
  }

  build() {
    Column({ space: TgUiTokens.SPACE_8 }) {
      Text('M2c HdsActionBar composer capability')
        .fontSize(TgUiTokens.FONT_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .width('100%')

      Scroll() {
        Row({ space: TgUiTokens.SPACE_6 }) {
          this.modeButton(MODE_NORMAL, 'Normal')
          this.modeButton(MODE_REPLY, 'Reply')
          this.modeButton(MODE_EDIT, 'Edit')
          this.modeButton(MODE_FORWARD, 'Forward')
          this.modeButton(MODE_ATTACHMENT, 'Attach')
          this.modeButton(MODE_SLOW, 'Slow')
          this.modeButton(MODE_RECORDING, 'Record')
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)

      Row({ space: TgUiTokens.SPACE_6 }) {
        Button('Text')
          .height(30)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .onClick(() => {
            this.mode = MODE_NORMAL;
            this.draft = 'Ready to send';
            this.lastAction = 'text preset';
            this.syncRightActionButton();
          })
        Button('Multiline')
          .height(30)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .onClick(() => {
            this.mode = MODE_NORMAL;
            this.draft = 'Line one\nLine two\nLine three\nLine four';
            this.lastAction = 'multiline preset';
            this.syncRightActionButton();
          })
        Button(this.showAuxPanel ? 'Hide panel' : 'Emoji panel')
          .height(30)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .onClick(() => {
            this.showAuxPanel = !this.showAuxPanel;
            this.lastAction = this.showAuxPanel ? 'emoji panel shown' : 'emoji panel hidden';
          })
        Button('Clear')
          .height(30)
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .onClick(() => {
            this.mode = MODE_NORMAL;
            this.draft = '';
            this.lastAction = 'cleared';
            this.syncRightActionButton();
          })
      }
      .width('100%')

      this.fakeTimeline()

      Text(`mode=${this.mode}; bar=${this.actionBarHeight()}vp; lastAction=${this.lastAction}`)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_META)
        .width('100%')
        .maxLines(2)

      if (this.showAuxPanel) {
        TgComposerEmojiPanel({
          title: 'Recent',
          stickersTitle: 'Stickers',
          onEmojiSelected: (emoji: string): void => {
            this.draft += emoji;
            this.lastAction = `emoji: ${emoji}`;
            this.syncRightActionButton();
          },
          onStickerPress: (): void => {
            this.lastAction = 'sticker panel requested';
          }
        })
      }

      HdsActionBar({
        primaryButtonBuilder: (): void => this.primaryComposer(),
        primaryButtonBuilderWidth: LengthMetrics.vp(DEMO_PRIMARY_WIDTH),
        startButtons: this.startButtons(),
        endButtons: this.endButtons(),
        actionBarStyle: new ActionBarStyle({
          height: LengthMetrics.vp(this.actionBarHeight()),
          innerSpace: LengthMetrics.vp(TgUiTokens.COMPOSER_ELEMENT_GAP),
          startSpace: LengthMetrics.vp(TgUiTokens.SPACE_6),
          endSpace: LengthMetrics.vp(TgUiTokens.SPACE_6),
          margin: LengthMetrics.vp(TgUiTokens.SPACE_4)
        }),
        isExpand: true
      })
        .id('m2c-hds-action-bar')
    }
    .width('100%')
    .height('100%')
    .padding({
      left: TgUiTokens.SPACE_12,
      right: TgUiTokens.SPACE_12,
      top: DEMO_PAGE_TOP_INSET,
      bottom: DEMO_PAGE_BOTTOM_INSET
    })
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
  }
}
