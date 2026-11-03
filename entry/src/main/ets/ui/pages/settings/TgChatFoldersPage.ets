// TgChatFoldersPage — Settings → Chat Folders (B7 / S7b.4).
// iOS counterpart: ChatFolderListController/ChatFolderEditController. TDLib keeps the folder list and
// pushes updateChatFolders; this page only sends create/edit/delete and re-reads AppStore.
// The iOS chat-selection grid and shareable links are not implemented yet (recorded as debt).

import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { localized } from '../../../core/utils/AppResource';
import { AppState, ChatFolderInfo } from '../../../core/model/AppState';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { ChatFolderDraftPayload } from '../../../core/model/AppCommand';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { ChatFolderDto } from '../../../core/model/dto/ChatFolderDto';
import {
  createManageChatFoldersUseCase,
  CHAT_FOLDER_TITLE_MAX_LENGTH,
  ManageChatFoldersUseCase
} from '../../../domain/usecases/manageChatFolders';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x0039;
const TAG = 'TgChatFoldersPage';

@Builder
export function TgChatFoldersPageBuilder() {
  TgChatFoldersPage();
}

@ComponentV2
export struct TgChatFoldersPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private folders: ChatFolderInfo[] = [];
  @Local private editingFolderId: number = 0;
  @Local private draftTitle: string = '';
  @Local private excludeMuted: boolean = false;
  @Local private excludeRead: boolean = false;
  @Local private excludeArchived: boolean = false;
  @Local private includeContacts: boolean = false;
  @Local private includeNonContacts: boolean = false;
  @Local private includeBots: boolean = false;
  @Local private includeGroups: boolean = false;
  @Local private includeChannels: boolean = false;
  @Local private isBusy: boolean = false;
  @Local private isLoadingFolder: boolean = false;
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;

  private manageUseCase?: ManageChatFoldersUseCase;
  private storeUnsubscribe?: () => void;
  private pageLifecycleToken: number = 0;

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
    try {
      this.manageUseCase = createManageChatFoldersUseCase(getTdGatewayAdapter());
      const store = getAppCoreRuntime().getStore();
      this.refreshFolders(store.getState());
      this.storeUnsubscribe = store.subscribe((state: AppState): void => {
        this.refreshFolders(state);
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Folder page init failed: %{public}s', String(error));
    }
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    if (this.storeUnsubscribe !== undefined) {
      this.storeUnsubscribe();
      this.storeUnsubscribe = undefined;
    }
    this.manageUseCase = undefined;
  }

  private refreshFolders(state: AppState): void {
    const editable: ChatFolderInfo[] = [];
    for (const folder of state.chatFilters.folders) {
      if (folder.id > 0) {
        editable.push(folder);
      }
    }
    this.folders = editable;
    // A folder deleted elsewhere must not leave the editor pointing at it.
    if (this.editingFolderId > 0 && !editable.some((folder: ChatFolderInfo): boolean =>
      folder.id === this.editingFolderId)) {
      this.startCreate();
    }
  }

  private startCreate(): void {
    this.editingFolderId = 0;
    this.isLoadingFolder = false;
    this.draftTitle = '';
    this.excludeMuted = false;
    this.excludeRead = false;
    this.excludeArchived = false;
    this.resetIncludeFlags();
  }

  private resetIncludeFlags(): void {
    this.includeContacts = false;
    this.includeNonContacts = false;
    this.includeBots = false;
    this.includeGroups = false;
    this.includeChannels = false;
  }

  private startEdit(folder: ChatFolderInfo): void {
    this.editingFolderId = folder.id;
    this.draftTitle = folder.title;
    this.excludeMuted = false;
    this.excludeRead = false;
    this.excludeArchived = false;
    this.resetIncludeFlags();
    this.loadFolderFlags(folder.id);
  }

  // chatFolderInfo has no flags; getChatFolder returns the whole ChatFolder so a rename keeps them.
  private loadFolderFlags(folderId: number): void {
    const useCase = this.manageUseCase;
    if (useCase === undefined) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isLoadingFolder = true;
    useCase.fetchFolder(folderId)
      .then((folder: ChatFolderDto) => {
        if (token !== this.pageLifecycleToken || this.editingFolderId !== folderId) {
          return;
        }
        this.isLoadingFolder = false;
        this.draftTitle = folder.title;
        this.excludeMuted = folder.excludeMuted;
        this.excludeRead = folder.excludeRead;
        this.excludeArchived = folder.excludeArchived;
        this.includeContacts = folder.includeContacts;
        this.includeNonContacts = folder.includeNonContacts;
        this.includeBots = folder.includeBots;
        this.includeGroups = folder.includeGroups;
        this.includeChannels = folder.includeChannels;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isLoadingFolder = false;
        hilog.warn(DOMAIN, TAG, 'Load folder failed: %{public}s', error.message);
      });
  }

  private buildDraft(): ChatFolderDraftPayload {
    const draft = new ChatFolderDraftPayload();
    draft.title = this.draftTitle;
    draft.excludeMuted = this.excludeMuted;
    draft.excludeRead = this.excludeRead;
    draft.excludeArchived = this.excludeArchived;
    draft.includeContacts = this.includeContacts;
    draft.includeNonContacts = this.includeNonContacts;
    draft.includeBots = this.includeBots;
    draft.includeGroups = this.includeGroups;
    draft.includeChannels = this.includeChannels;
    return draft;
  }

  private save(): void {
    const useCase = this.manageUseCase;
    if (useCase === undefined || this.isBusy) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    const editing = this.editingFolderId;
    this.isBusy = true;
    const work = editing > 0
      ? useCase.editFolder(editing, this.buildDraft())
      : useCase.createFolder(this.buildDraft());
    work.then(() => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.isBusy = false;
      this.toast(editing > 0
        ? localized($r('app.string.folders_saved_toast').id, 'Folder updated')
        : localized($r('app.string.folders_created_toast').id, 'Folder created'));
      this.startCreate();
    }).catch((error: Error) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.isBusy = false;
      this.toast(error.message.length > 0
        ? error.message : localized($r('app.string.folders_failed_toast').id, 'Could not update the folder'));
    });
  }

  private confirmDelete(): void {
    const folderId = this.editingFolderId;
    if (folderId <= 0) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: localized($r('app.string.folders_delete').id, 'Delete Folder'),
      message: localized($r('app.string.folders_delete_confirm').id,
        'Delete this folder? Chats stay in your chat list.'),
      buttons: [
        { text: localized($r('app.string.cancel').id, 'Cancel'), color: TgUiTokens.COLOR_TEXT_PREVIEW },
        { text: localized($r('app.string.folders_delete').id, 'Delete'),
          color: TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index !== 1) {
        return;
      }
      this.deleteFolder(folderId);
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'Delete folder dialog failed: %{public}s', error.message);
    });
  }

  private deleteFolder(folderId: number): void {
    const useCase = this.manageUseCase;
    if (useCase === undefined || this.isBusy) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isBusy = true;
    useCase.deleteFolder(folderId).then(() => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.isBusy = false;
      this.toast(localized($r('app.string.folders_deleted_toast').id, 'Folder deleted'));
      this.startCreate();
    }).catch((error: Error) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.isBusy = false;
      this.toast(error.message.length > 0
        ? error.message : localized($r('app.string.folders_failed_toast').id, 'Could not update the folder'));
    });
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  @Builder
  buildFlagRow(label: string, value: boolean, toggle: () => void) {
    Row() {
      Text(label)
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .onChange((isOn: boolean): void => {
          if (isOn !== value) {
            toggle();
          }
        })
    }
    .width('100%')
    .height(44)
    .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Scroll() {
          Column() {
            Text(localized($r('app.string.folders_list_section').id, 'FOLDERS'))
              .fontSize(TgUiTokens.FONT_META_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_META)
              .width('100%')
              .padding({
                left: TgUiTokens.SPACE_16,
                right: TgUiTokens.SPACE_16,
                top: TgUiTokens.SPACE_12,
                bottom: TgUiTokens.SPACE_4
              })

            if (this.folders.length === 0) {
              Text(localized($r('app.string.folders_empty').id, 'No folders yet'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                .width('100%')
                .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8 })
            } else {
              ForEach(this.folders, (folder: ChatFolderInfo) => {
                Row() {
                  Text(folder.title)
                    .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                    .fontColor(this.editingFolderId === folder.id
                      ? TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT : TgUiTokens.COLOR_TEXT_TITLE)
                    .layoutWeight(1)
                  if (this.editingFolderId === folder.id) {
                    Text(localized($r('app.string.folders_editing').id, 'Editing'))
                      .fontSize(TgUiTokens.FONT_META_SIZE)
                      .fontColor(TgUiTokens.COLOR_TEXT_META)
                  }
                }
                .width('100%')
                .height(44)
                .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
                .onClick(() => {
                  this.startEdit(folder);
                })
              }, (folder: ChatFolderInfo) => folder.id.toString())
            }

            Column() {
              Row() {
                Text(this.editingFolderId > 0
                  ? localized($r('app.string.folders_edit_title').id, 'Edit Folder')
                  : localized($r('app.string.folders_new').id, 'New Folder'))
                  .fontSize(TgUiTokens.FONT_META_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_META)
                  .layoutWeight(1)
                if (this.editingFolderId > 0) {
                  Text(localized($r('app.string.folders_cancel').id, 'Cancel'))
                    .fontSize(TgUiTokens.FONT_META_SIZE)
                    .fontColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
                    .onClick(() => {
                      this.startCreate();
                    })
                }
              }
              .width('100%')
              .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_12 })

              TextInput({
                text: this.draftTitle,
                placeholder: localized($r('app.string.folders_name_placeholder').id, 'Folder name')
              })
                .maxLength(CHAT_FOLDER_TITLE_MAX_LENGTH)
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .height(44)
                .margin({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8 })
                .onChange((value: string): void => {
                  this.draftTitle = value;
                })

              this.buildFlagRow(localized($r('app.string.folders_exclude_muted').id, 'Exclude muted'),
                this.excludeMuted, (): void => {
                  this.excludeMuted = !this.excludeMuted;
                })
              this.buildFlagRow(localized($r('app.string.folders_exclude_read').id, 'Exclude read'),
                this.excludeRead, (): void => {
                  this.excludeRead = !this.excludeRead;
                })
              this.buildFlagRow(localized($r('app.string.folders_exclude_archived').id, 'Exclude archived'),
                this.excludeArchived, (): void => {
                  this.excludeArchived = !this.excludeArchived;
                })
              this.buildFlagRow(localized($r('app.string.folders_include_contacts').id, 'Include contacts'),
                this.includeContacts, (): void => {
                  this.includeContacts = !this.includeContacts;
                })
              this.buildFlagRow(localized($r('app.string.folders_include_non_contacts').id, 'Include non-contacts'),
                this.includeNonContacts, (): void => {
                  this.includeNonContacts = !this.includeNonContacts;
                })
              this.buildFlagRow(localized($r('app.string.folders_include_bots').id, 'Include bots'),
                this.includeBots, (): void => {
                  this.includeBots = !this.includeBots;
                })
              this.buildFlagRow(localized($r('app.string.folders_include_groups').id, 'Include groups'),
                this.includeGroups, (): void => {
                  this.includeGroups = !this.includeGroups;
                })
              this.buildFlagRow(localized($r('app.string.folders_include_channels').id, 'Include channels'),
                this.includeChannels, (): void => {
                  this.includeChannels = !this.includeChannels;
                })

              Row() {
                Button(this.editingFolderId > 0
                  ? localized($r('app.string.folders_save').id, 'Save')
                  : localized($r('app.string.folders_create').id, 'Create'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .layoutWeight(1)
                  .enabled(!this.isBusy && !this.isLoadingFolder && this.draftTitle.trim().length > 0)
                  .onClick(() => {
                    this.save();
                  })
                if (this.editingFolderId > 0) {
                  Button(localized($r('app.string.folders_delete').id, 'Delete'))
                    .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                    .layoutWeight(1)
                    .backgroundColor(TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE)
                    .enabled(!this.isBusy)
                    .margin({ left: TgUiTokens.SPACE_8 })
                    .onClick(() => {
                      this.confirmDelete();
                    })
                }
              }
              .width('100%')
              .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_12 })
            }
            .width('100%')
            .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
            .borderRadius(12)
            .margin({ left: 16, right: 16, top: 16 })
            .clip(true)

            Column().height(40)
          }
          .width('100%')
        }
        .width('100%')
        .height('100%')
        .contentStartOffset(this.topBarTotalHeight)
        .scrollBar(BarState.Off)
        .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)

        TgChatTopBar({
          topInset: this.topBarInset,
          title: localized($r('app.string.settings_chat_folders').id, 'Chat Folders'),
          subtitle: this.folders.length > 0 ? `${this.folders.length}` : '',
          onBackPress: (): void => {
            this.pageStack.pop();
          }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }
    .hideTitleBar(true)
  }
}
