// TgFolderLinkPage — preview and join a chat folder by invite link (B7 / S13j).
// iOS counterpart: ChatFolderLinkPreviewScreen. The link is pasted or typed here because the app has no
// external t.me/addlist routing yet; the preview itself uses TDLib's checkChatFolderInviteLink.

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { ChatFolderInviteLinkInfoDto } from '../../../core/model/dto/ChatFolderInviteLinkInfoDto';
import {
  createFolderInviteLinkUseCase,
  FolderInviteLinkUseCase,
  isFolderInviteLink
} from '../../../domain/usecases/folderInviteLink';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x003f;
const TAG = 'TgFolderLinkPage';

@Builder
export function TgFolderLinkPageBuilder() {
  TgFolderLinkPage();
}

@ComponentV2
export struct TgFolderLinkPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private linkDraft: string = '';
  @Local private preview: ChatFolderInviteLinkInfoDto | undefined = undefined;
  @Local private isChecking: boolean = false;
  @Local private isAdding: boolean = false;
  @Local private errorText: string = '';
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  private useCase?: FolderInviteLinkUseCase;
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
      this.useCase = createFolderInviteLinkUseCase(getTdGatewayAdapter());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Use case init failed: %{public}s', String(error));
      this.useCase = undefined;
    }
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.useCase = undefined;
  }

  private checkLink(): void {
    const useCase = this.useCase;
    if (useCase === undefined || this.isChecking) {
      return;
    }
    if (!isFolderInviteLink(this.linkDraft)) {
      this.preview = undefined;
      this.errorText = localized($r('app.string.folders_link_invalid').id,
        'Paste a folder link like https://t.me/addlist/...');
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isChecking = true;
    this.errorText = '';
    this.preview = undefined;
    useCase.check(this.linkDraft)
      .then((info: ChatFolderInviteLinkInfoDto) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isChecking = false;
        this.preview = info;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isChecking = false;
        this.errorText = error.message.length > 0
          ? error.message : localized($r('app.string.folders_link_check_failed').id,
            'Could not check the folder link');
      });
  }

  private addFolder(): void {
    const useCase = this.useCase;
    const preview = this.preview;
    if (useCase === undefined || preview === undefined || this.isAdding) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isAdding = true;
    this.errorText = '';
    useCase.add(this.linkDraft, preview.missingChatIds)
      .then(() => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isAdding = false;
        this.getUIContext().getPromptAction().showToast({
          message: localized($r('app.string.folders_link_added').id, 'Folder added'),
          duration: 2000
        });
        this.pageStack.pop();
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isAdding = false;
        this.errorText = error.message.length > 0
          ? error.message : localized($r('app.string.folders_link_add_failed').id,
            'Could not add the folder');
      });
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Scroll() {
          Column() {
            Text(localized($r('app.string.folders_link_hint').id,
              'Paste a folder invite link to preview the folder before adding it.'))
              .fontSize(TgUiTokens.FONT_META_SIZE)
              .fontColor(TgUiTokens.COLOR_TEXT_META)
              .width('100%')
              .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_12 })

            TextInput({ text: this.linkDraft, placeholder: 'https://t.me/addlist/...' })
              .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
              .height(44)
              .margin({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8 })
              .onChange((value: string): void => {
                this.linkDraft = value;
              })

            Row() {
              Button(localized($r('app.string.folders_link_check').id, 'Check Link'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .height(40)
                .enabled(!this.isChecking)
                .onClick(() => {
                  this.checkLink();
                })
            }
            .width('100%')
            .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8 })

            if (this.errorText.length > 0) {
              Text(this.errorText)
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE)
                .width('100%')
                .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8 })
            }

            if (this.isChecking) {
              Text(localized($r('app.string.folders_link_checking').id, 'Checking…'))
                .fontSize(TgUiTokens.FONT_META_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_META)
                .width('100%')
                .padding({ left: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_8 })
            }

            if (this.preview !== undefined) {
              Column() {
                Text(this.preview.title)
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text((this.preview.addedChatIds.length + this.preview.missingChatIds.length)
                  .toString() + ' ' + localized($r('app.string.folders_link_chats').id, 'chats'))
                  .fontSize(TgUiTokens.FONT_META_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_META)
                  .margin({ top: TgUiTokens.SPACE_4 })
                if (this.preview.missingChatIds.length > 0) {
                  Text(this.preview.missingChatIds.length.toString() + ' ' +
                    localized($r('app.string.folders_link_missing').id, 'missing'))
                    .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                    .fontColor(TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE)
                }
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_16 })

              Row() {
                Button(localized($r('app.string.folders_link_join').id, 'Add Folder'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .height(40)
                  .enabled(!this.isAdding)
                  .onClick(() => {
                    this.addFolder();
                  })
              }
              .width('100%')
              .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16, top: TgUiTokens.SPACE_12 })
            }
          }
          .width('100%')
          .padding({ bottom: TgUiTokens.SPACE_24 })
        }
        .width('100%')
        .height('100%')
        .contentStartOffset(this.topBarTotalHeight)
        .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)

        TgChatTopBar({
          topInset: this.topBarInset,
          title: localized($r('app.string.folders_link_title').id, 'Folder Link'),
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
