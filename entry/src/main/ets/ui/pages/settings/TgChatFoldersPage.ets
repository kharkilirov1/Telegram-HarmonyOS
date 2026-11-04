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
import { ChatFolderInviteLinkDto } from '../../../core/model/dto/ChatFolderInviteLinkDto';
import { RecommendedChatFolderDto } from '../../../core/model/dto/RecommendedChatFolderDto';
import {
  createLoadRecommendedChatFoldersUseCase,
  LoadRecommendedChatFoldersUseCase
} from '../../../domain/usecases/loadRecommendedChatFolders';
import {
  createManageChatFolderInviteLinksUseCase,
  ManageChatFolderInviteLinksUseCase
} from '../../../domain/usecases/manageChatFolderInviteLinks';
import { pasteboard } from '@kit.BasicServicesKit';
import {
  FolderChatSelectionResult,
  FolderChatSelectionRouteParams
} from './folderChatSelectionRoute';
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
  // Explicitly included chats; empty means the folder is defined by flags only.
  @Local private includedChatIds: number[] = [];
  @Local private inviteLinks: ChatFolderInviteLinkDto[] = [];
  @Local private isLoadingLinks: boolean = false;
  @Local private editingLinkUri: string = '';
  @Local private linkNameDraft: string = '';
  // Chat ids the link under rename is restricted to; empty means all folder chats.
  @Local private editingLinkChatIds: number[] = [];
  @Local private isPickingLinkChats: boolean = false;
  @Local private recommendedFolders: RecommendedChatFolderDto[] = [];
  @Local private isLoadingRecommended: boolean = false;
  private recommendedUseCase?: LoadRecommendedChatFoldersUseCase;
  @Local private isBusy: boolean = false;
  @Local private isLoadingFolder: boolean = false;
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;

  private manageUseCase?: ManageChatFoldersUseCase;
  private inviteLinksUseCase?: ManageChatFolderInviteLinksUseCase;
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
      this.inviteLinksUseCase = createManageChatFolderInviteLinksUseCase(getTdGatewayAdapter());
      this.recommendedUseCase = createLoadRecommendedChatFoldersUseCase(getTdGatewayAdapter());
      this.loadRecommendedFolders();
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
    this.inviteLinksUseCase = undefined;
    this.recommendedUseCase = undefined;
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
    this.includedChatIds = [];
    this.inviteLinks = [];
    this.isLoadingLinks = false;
    this.editingLinkUri = '';
    this.linkNameDraft = '';
    this.editingLinkChatIds = [];
    this.isPickingLinkChats = false;
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
    this.loadInviteLinks(folder.id);
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
        this.includedChatIds = folder.includedChatIds.slice();
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isLoadingFolder = false;
        hilog.warn(DOMAIN, TAG, 'Load folder failed: %{public}s', error.message);
      });
  }

  private loadInviteLinks(folderId: number): void {
    const useCase = this.inviteLinksUseCase;
    if (useCase === undefined) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isLoadingLinks = true;
    useCase.listLinks(folderId)
      .then((links: ChatFolderInviteLinkDto[]) => {
        if (token !== this.pageLifecycleToken || this.editingFolderId !== folderId) {
          return;
        }
        this.isLoadingLinks = false;
        this.inviteLinks = links;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isLoadingLinks = false;
        hilog.warn(DOMAIN, TAG, 'Load invite links failed: %{public}s', error.message);
      });
  }

  private openLinkChatSelection(): void {
    const folderId = this.editingFolderId;
    if (folderId <= 0) {
      return;
    }
    this.isPickingLinkChats = true;
    const params = new FolderChatSelectionRouteParams();
    // Defaults to the chats explicitly included in the folder; empty means all folder chats.
    params.selectedChatIds = this.includedChatIds.slice();
    params.folderTitle = localized($r('app.string.folders_link_chats').id, 'Link Chats');
    this.pageStack.pushPathByName('TgFolderChatsPage', params,
      (popInfo: PopInfo): void => {
        this.isPickingLinkChats = false;
        const result = popInfo.result as FolderChatSelectionResult | undefined;
        if (result === undefined) {
          return;
        }
        this.createInviteLink(result.selectedChatIds.slice());
      });
  }

  private createInviteLink(chatIds: number[] = []): void {
    const useCase = this.inviteLinksUseCase;
    const folderId = this.editingFolderId;
    if (useCase === undefined || folderId <= 0) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    const name: string = localized($r('app.string.folders_link_default_name').id, 'Link') + ' ' +
      (this.inviteLinks.length + 1).toString();
    this.isLoadingLinks = true;
    useCase.createLink(folderId, name, chatIds).then(() => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.isLoadingLinks = false;
      this.toast(localized($r('app.string.folders_link_created_toast').id, 'Invite link created'));
      this.loadInviteLinks(folderId);
    }).catch((error: Error) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.isLoadingLinks = false;
      this.toast(error.message.length > 0
        ? error.message : localized($r('app.string.folders_link_failed_toast').id, 'Could not update invite links'));
    });
  }

  private startRenameLink(link: ChatFolderInviteLinkDto): void {
    this.editingLinkUri = link.inviteLink;
    this.linkNameDraft = link.name;
    this.editingLinkChatIds = link.chatIds.slice();
  }

  private saveLinkName(): void {
    const useCase = this.inviteLinksUseCase;
    const folderId = this.editingFolderId;
    const inviteLink = this.editingLinkUri;
    if (useCase === undefined || folderId <= 0 || inviteLink.length === 0) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    useCase.editLink(folderId, inviteLink, this.linkNameDraft, this.editingLinkChatIds).then(() => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.editingLinkUri = '';
      this.linkNameDraft = '';
      this.editingLinkChatIds = [];
      this.toast(localized($r('app.string.folders_link_renamed_toast').id, 'Link renamed'));
      this.loadInviteLinks(folderId);
    }).catch((error: Error) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.toast(error.message.length > 0
        ? error.message : localized($r('app.string.folders_link_failed_toast').id, 'Could not update invite links'));
    });
  }

  private copyInviteLink(link: string): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, link);
      pasteboard.getSystemPasteboard().setDataSync(data);
      this.toast(localized($r('app.string.folders_link_copied_toast').id, 'Link copied'));
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Copy invite link failed: %{public}s', String(error));
      this.toast(localized($r('app.string.folders_link_copy_failed').id, 'Could not copy the link'));
    }
  }

  private confirmDeleteInviteLink(inviteLink: string): void {
    const folderId = this.editingFolderId;
    if (folderId <= 0) {
      return;
    }
    this.getUIContext().getPromptAction().showDialog({
      title: localized($r('app.string.folders_delete_link').id, 'Delete Link'),
      message: localized($r('app.string.folders_delete_link_confirm').id,
        'Delete this invite link? People who already joined stay in the folder.'),
      buttons: [
        { text: localized($r('app.string.cancel').id, 'Cancel'), color: TgUiTokens.COLOR_TEXT_PREVIEW },
        { text: localized($r('app.string.folders_delete').id, 'Delete'),
          color: TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index !== 1) {
        return;
      }
      this.deleteInviteLink(folderId, inviteLink);
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'Delete link dialog failed: %{public}s', error.message);
    });
  }

  private deleteInviteLink(folderId: number, inviteLink: string): void {
    const useCase = this.inviteLinksUseCase;
    if (useCase === undefined) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    useCase.deleteLink(folderId, inviteLink).then(() => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.toast(localized($r('app.string.folders_link_deleted_toast').id, 'Invite link deleted'));
      this.loadInviteLinks(folderId);
    }).catch((error: Error) => {
      if (token !== this.pageLifecycleToken) {
        return;
      }
      this.toast(error.message.length > 0
        ? error.message : localized($r('app.string.folders_link_failed_toast').id, 'Could not update invite links'));
    });
  }

  private openChatSelection(): void {
    const params = new FolderChatSelectionRouteParams();
    params.selectedChatIds = this.includedChatIds.slice();
    params.folderTitle = this.draftTitle;
    this.pageStack.pushPathByName('TgFolderChatsPage', params,
      (popInfo: PopInfo): void => {
        if (this.isClosingPage()) {
          return;
        }
        const result = popInfo.result as FolderChatSelectionResult | undefined;
        if (result === undefined) {
          return;
        }
        this.includedChatIds = result.selectedChatIds.slice();
      });
  }

  private isClosingPage(): boolean {
    return this.isBusy || this.editingFolderId < 0;
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
    draft.includedChatIds = this.includedChatIds.slice();
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

  private loadRecommendedFolders(): void {
    const useCase = this.recommendedUseCase;
    if (useCase === undefined) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isLoadingRecommended = true;
    useCase.fetch()
      .then((folders: RecommendedChatFolderDto[]) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isLoadingRecommended = false;
        this.recommendedFolders = folders;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isLoadingRecommended = false;
        hilog.warn(DOMAIN, TAG, 'Load recommended folders failed: %{public}s', error.message);
      });
  }

  private addRecommendedFolder(recommended: RecommendedChatFolderDto): void {
    const useCase = this.manageUseCase;
    if (useCase === undefined || this.isBusy) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    // A recommended folder is a full chatFolder payload; reuse the normal create path with its flags.
    const draft = new ChatFolderDraftPayload();
    draft.title = recommended.folder.title;
    draft.excludeMuted = recommended.folder.excludeMuted;
    draft.excludeRead = recommended.folder.excludeRead;
    draft.excludeArchived = recommended.folder.excludeArchived;
    draft.includeContacts = recommended.folder.includeContacts;
    draft.includeNonContacts = recommended.folder.includeNonContacts;
    draft.includeBots = recommended.folder.includeBots;
    draft.includeGroups = recommended.folder.includeGroups;
    draft.includeChannels = recommended.folder.includeChannels;
    draft.includedChatIds = recommended.folder.includedChatIds.slice();
    this.isBusy = true;
    useCase.createFolder(draft)
      .then(() => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isBusy = false;
        this.toast(localized($r('app.string.folders_recommended_added').id, 'Folder added'));
        this.recommendedFolders = this.recommendedFolders.filter(
          (item: RecommendedChatFolderDto) => item !== recommended);
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isBusy = false;
        this.toast(error.message.length > 0
          ? error.message : localized($r('app.string.folders_recommended_failed').id,
            'Could not add the folder'));
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

            Row() {
              Text(localized($r('app.string.folders_link_open').id, 'Open Folder Link'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                .layoutWeight(1)
              Text('›')
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_META)
            }
            .width('100%')
            .height(44)
            .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8 })
            .onClick(() => {
              this.pageStack.pushPathByName('TgFolderLinkPage', undefined);
            })

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
                Text(localized($r('app.string.folders_included_chats').id, 'Included chats'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                  .layoutWeight(1)
                Text(`${this.includedChatIds.length}`)
                  .fontSize(TgUiTokens.FONT_META_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_META)
                  .margin({ right: TgUiTokens.SPACE_8 })
                Text(localized($r('app.string.folders_select_chats').id, 'Select chats'))
                  .fontSize(TgUiTokens.FONT_META_SIZE)
                  .fontColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
              }
              .width('100%')
              .height(44)
              .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
              .onClick(() => {
                this.openChatSelection();
              })

              if (this.editingFolderId > 0) {
                Row() {
                  Text(localized($r('app.string.folders_invite_links').id, 'Invite Links'))
                    .fontSize(TgUiTokens.FONT_META_SIZE)
                    .fontColor(TgUiTokens.COLOR_TEXT_META)
                    .layoutWeight(1)
                  Text(localized($r('app.string.folders_create_link').id, 'Create Link'))
                    .fontSize(TgUiTokens.FONT_META_SIZE)
                    .fontColor(this.isLoadingLinks ? TgUiTokens.COLOR_TEXT_META
                      : TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
                    .onClick(() => {
                      if (!this.isLoadingLinks && !this.isPickingLinkChats) {
                        this.openLinkChatSelection();
                      }
                    })
                }
                .width('100%')
                .height(40)
                .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8 })

                if (this.editingLinkUri.length > 0) {
                  Row() {
                    TextInput({ text: this.linkNameDraft, placeholder: localized(
                      $r('app.string.folders_rename_link').id, 'Link name') })
                      .maxLength(32)
                      .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                      .height(40)
                      .layoutWeight(1)
                      .onChange((value: string): void => {
                        this.linkNameDraft = value;
                      })
                    Text(localized($r('app.string.folders_save').id, 'Save'))
                      .fontSize(TgUiTokens.FONT_META_SIZE)
                      .fontColor(this.linkNameDraft.trim().length === 0 ? TgUiTokens.COLOR_TEXT_META
                        : TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
                      .margin({ left: TgUiTokens.SPACE_12 })
                      .onClick(() => {
                        if (this.linkNameDraft.trim().length > 0) {
                          this.saveLinkName();
                        }
                      })
                    Text(localized($r('app.string.folders_cancel').id, 'Cancel'))
                      .fontSize(TgUiTokens.FONT_META_SIZE)
                      .fontColor(TgUiTokens.COLOR_TEXT_META)
                      .margin({ left: TgUiTokens.SPACE_12 })
                      .onClick(() => {
                        this.editingLinkUri = '';
                        this.linkNameDraft = '';
                      })
                  }
                  .width('100%')
                  .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_4 })
                }

                if (this.inviteLinks.length === 0) {
                  Text(localized($r('app.string.folders_links_empty').id, 'No invite links yet'))
                    .fontSize(TgUiTokens.FONT_META_SIZE)
                    .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                    .width('100%')
                    .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_4 })
                } else {
                  ForEach(this.inviteLinks, (link: ChatFolderInviteLinkDto) => {
                    Row() {
                      Text(link.chatIds.length > 0
                        ? `${link.name.length > 0 ? link.name : link.inviteLink} · ${link.chatIds.length}`
                        : (link.name.length > 0 ? link.name : link.inviteLink))
                        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                      Text(localized($r('app.string.folders_copy_link').id, 'Copy'))
                        .fontSize(TgUiTokens.FONT_META_SIZE)
                        .fontColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
                        .margin({ right: TgUiTokens.SPACE_12 })
                        .onClick(() => {
                          this.copyInviteLink(link.inviteLink);
                        })
                      Text(localized($r('app.string.folders_delete').id, 'Delete'))
                        .fontSize(TgUiTokens.FONT_META_SIZE)
                        .fontColor(TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE)
                        .onClick(() => {
                          this.confirmDeleteInviteLink(link.inviteLink);
                        })
                    }
                    .width('100%')
                    .height(44)
                    .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
                    .onClick(() => {
                      this.startRenameLink(link);
                    })
                  }, (link: ChatFolderInviteLinkDto) => link.inviteLink)
                }
              }

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
