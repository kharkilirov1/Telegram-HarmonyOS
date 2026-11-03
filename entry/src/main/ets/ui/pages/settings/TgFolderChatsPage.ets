// TgFolderChatsPage — pick the chats included in a chat folder (B7 / S13d).
// iOS counterpart: ChatFolderEditController's chat selection grid. This page is a flat searchable-free
// list with checkboxes: the folder editor owns saving, the page only returns selected ids.

import { common } from '@kit.AbilityKit';
import { localized } from '../../../core/utils/AppResource';
import { AppState, Chat } from '../../../core/model/AppState';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { selectOrderedChats } from '../../../domain/selectors/chatSelectors';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';
import {
  FolderChatSelectionResult,
  FolderChatSelectionRouteParams
} from './folderChatSelectionRoute';

@Builder
export function TgFolderChatsPageBuilder() {
  TgFolderChatsPage();
}

@ComponentV2
export struct TgFolderChatsPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private chats: Chat[] = [];
  @Local private selected: Set<number> = new Set<number>();
  @Local private folderTitle: string = '';
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;

  private storeUnsubscribe?: () => void;

  aboutToAppear(): void {
    this.pageLifecycleToken += 1;
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.topBarTotalHeight = computeTopBarHeight(context);
      this.topBarInset = this.topBarTotalHeight - TgUiTokens.TOP_BAR_HEIGHT;
    } catch (_error) {
      this.topBarTotalHeight = TgUiTokens.TOP_BAR_HEIGHT;
      this.topBarInset = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
    }
    const params = this.pageStack.getParamByName('TgFolderChatsPage') as Object[];
    const routeParams: FolderChatSelectionRouteParams | undefined = params.length > 0
      ? params[0] as FolderChatSelectionRouteParams : undefined;
    if (routeParams !== undefined) {
      this.folderTitle = routeParams.folderTitle;
      for (const chatId of routeParams.selectedChatIds) {
        this.selected.add(chatId);
      }
    }
    try {
      const store = getAppCoreRuntime().getStore();
      this.refreshChats(store.getState());
      this.storeUnsubscribe = store.subscribe((state: AppState): void => {
        this.refreshChats(state);
      });
    } catch (_error) {
      this.chats = [];
    }
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    if (this.storeUnsubscribe !== undefined) {
      this.storeUnsubscribe();
      this.storeUnsubscribe = undefined;
    }
  }

  private pageLifecycleToken: number = 0;

  private refreshChats(state: AppState): void {
    this.chats = selectOrderedChats(state);
  }

  private chatTitle(chat: Chat): string {
    if (chat.title.length > 0) {
      return chat.title;
    }
    try {
      const state = getAppCoreRuntime().getStore().getState();
      const user = state.users.users.get(chat.peerUserId);
      if (user !== undefined) {
        const full = `${user.firstName} ${user.lastName}`.trim();
        if (full.length > 0) {
          return full;
        }
      }
    } catch (_error) {
      return '';
    }
    return '';
  }

  private toggle(chatId: number): void {
    if (this.selected.has(chatId)) {
      this.selected.delete(chatId);
    } else {
      this.selected.add(chatId);
    }
    // A Set mutation is not observable; replace it so the row state refreshes.
    this.selected = new Set<number>(this.selected);
  }

  private save(): void {
    const result = new FolderChatSelectionResult();
    for (const chatId of this.selected) {
      if (Number.isSafeInteger(chatId) && chatId > 0) {
        result.selectedChatIds.push(chatId);
      }
    }
    this.pageStack.pop(result, true);
  }

  build() {
    NavDestination() {
      Column() {
      Stack({ alignContent: Alignment.Top }) {
        List() {
          if (this.chats.length === 0) {
            ListItem() {
              Text(localized($r('app.string.folder_chats_empty').id, 'No chats yet'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: TgUiTokens.SPACE_24 })
            }
          } else {
            ForEach(this.chats, (chat: Chat) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(this.chatTitle(chat))
                      .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                      .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Checkbox({ name: 'folder_chat_' + chat.id.toString() })
                    .select(this.selected.has(chat.id))
                    .selectedColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
                    .onChange((): void => {
                      this.toggle(chat.id);
                    })
                }
                .width('100%')
                .height(52)
                .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
                .onClick(() => {
                  this.toggle(chat.id);
                })
              }
            }, (chat: Chat) => chat.id.toString())
          }
          ListItem() {
            Column().height(80)
          }
        }
        .width('100%')
        .height('100%')
        .contentStartOffset(this.topBarTotalHeight)
        .scrollBar(BarState.Off)
        .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)

        TgChatTopBar({
          topInset: this.topBarInset,
          title: this.folderTitle.length > 0
            ? this.folderTitle
            : localized($r('app.string.folder_chats_title').id, 'Folder Chats'),
          subtitle: `${this.selected.size}`,
          onBackPress: (): void => {
            this.pageStack.pop();
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      Row() {
        Button(localized($r('app.string.folder_chats_save').id, 'Done'))
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .width('100%')
          .height(44)
          .onClick(() => {
            this.save();
          })
      }
      .width('100%')
      .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8,
        bottom: TgUiTokens.SPACE_16 })
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    }
    .hideTitleBar(true)
  }
}
