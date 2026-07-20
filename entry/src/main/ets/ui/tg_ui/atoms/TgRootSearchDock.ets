import { KeyboardAvoidMode } from '@kit.ArkUI';
import { TgUiTokens } from '../tokens/TgUiTokens';
import { ROOT_SEARCH_DOCK_CONTROL_SIZE } from '../../utils/RootTabBarGeometry';
import { TgIcon } from './TgIcon';

export const ROOT_CHAT_LIST_SEARCH_INPUT_ID: string = 'tg_root_chat_list_search_input';

@ComponentV2
export struct TgRootSearchDock {
  @Param value: string = '';
  @Param placeholder: string = 'Search';
  @Param closeText: string = 'Close';
  @Param active: boolean = false;
  @Param closing: boolean = false;
  @Param focusRequestRevision: number = 0;

  @Event onActivate: () => void = (): void => {};
  @Event onChange: (value: string) => void = (_: string): void => {};
  @Event onSubmit: (value: string) => void = (_: string): void => {};
  @Event onClose: () => void = (): void => {};

  aboutToAppear(): void {
    if (this.active && !this.closing) {
      this.requestSearchFocus();
    }
  }

  @Monitor('focusRequestRevision')
  private onFocusRequestChanged(_monitor: IMonitor): void {
    if (this.active && !this.closing) {
      this.requestSearchFocus();
    }
  }

  private requestSearchFocusAfterDelay(delayMs: number): void {
    setTimeout(() => {
      if (!this.active || this.closing) {
        return;
      }
      try {
        this.getUIContext().getFocusController().requestFocus(ROOT_CHAT_LIST_SEARCH_INPUT_ID);
      } catch (_error) {
      }
    }, delayMs);
  }

  private requestSearchFocus(): void {
    this.requestSearchFocusAfterDelay(0);
    // HDS performs one final builder/layout pass after the expansion callback.
    // Reassert focus once after that pass so the mounted Search owns editing.
    this.requestSearchFocusAfterDelay(360);
  }

  private ensureKeyboardResize(): void {
    try {
      // Other app surfaces may change this window-wide policy while Search is closed.
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    } catch (_error) {
    }
  }

  private close(): void {
    if (this.closing) {
      return;
    }
    this.onClose();
  }

  @Builder
  private buildCloseAction() {
    Stack({ alignContent: Alignment.Center }) {
      TgIcon({
        src: TgUiTokens.ICON_RES_CLOSE,
        iconSize: TgUiTokens.CHAT_TOP_BAR_ACTION_ICON_SIZE,
        tintColor: TgUiTokens.COLOR_TEXT_TITLE
      })
    }
    .width(ROOT_SEARCH_DOCK_CONTROL_SIZE)
    .height(ROOT_SEARCH_DOCK_CONTROL_SIZE)
    .focusable(!this.closing)
    .focusOnTouch(true)
    .accessibilityGroup(true)
    .accessibilityLevel('yes')
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.closeText)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
    .onClick(() => this.close())
  }

  build() {
    Row() {
      Search({
        value: this.value,
        placeholder: this.placeholder
      })
        .id(ROOT_CHAT_LIST_SEARCH_INPUT_ID)
        .layoutWeight(1)
        .height(ROOT_SEARCH_DOCK_CONTROL_SIZE)
        .focusable(!this.closing)
        .focusOnTouch(true)
        .enableKeyboardOnFocus(true)
        .backgroundColor(Color.Transparent)
        .textFont({
          size: TgUiTokens.SEARCH_BAR_FONT_SIZE,
          weight: FontWeight.Regular
        })
        .fontColor(TgUiTokens.SEARCH_BAR_TEXT_COLOR)
        .placeholderColor(TgUiTokens.SEARCH_BAR_PLACEHOLDER_COLOR)
        .searchIcon({
          src: TgUiTokens.ICON_RES_SEARCH,
          size: TgUiTokens.CHAT_TOP_BAR_ACTION_ICON_SIZE,
          color: TgUiTokens.COLOR_TEXT_TITLE
        })
        .cancelButton({ style: CancelButtonStyle.INPUT })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.ensureKeyboardResize();
          }
        })
        .onFocus(() => {
          if (!this.active) {
            this.onActivate();
          }
        })
        .onChange((value: string) => this.onChange(value))
        .onSubmit((value: string) => this.onSubmit(value))

      if (this.active) {
        this.buildCloseAction()
      }
    }
    .width('100%')
    .height(ROOT_SEARCH_DOCK_CONTROL_SIZE)
    .alignItems(VerticalAlign.Center)
    .enabled(!this.closing)
    .hitTestBehavior(this.closing ? HitTestMode.None : HitTestMode.Default)
    .accessibilityLevel(this.closing ? 'no-hide-descendants' : 'auto')
    .clip(true)
  }
}
