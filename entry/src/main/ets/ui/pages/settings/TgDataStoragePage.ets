// TgDataStoragePage — Settings → Data and Storage (H4).
// TDLib: getStorageStatisticsFast / getStorageStatistics / optimizeStorage (td_api.tl:14426-14444).

import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { localized } from '../../../core/utils/AppResource';
import { AppState } from '../../../core/model/AppState';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import {
  createLoadStorageStatisticsUseCase,
  LoadStorageStatisticsUseCase,
  StorageSnapshot
} from '../../../domain/usecases/loadStorageStatistics';
import {
  FastStorageStatisticsDto,
  StorageChatUsageDto,
  formatStorageBytes
} from '../../../core/model/dto/StorageStatisticsDto';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';

const DOMAIN = 0x0036;
const TAG = 'TgDataStoragePage';

@Builder
export function TgDataStoragePageBuilder() {
  TgDataStoragePage();
}

@ComponentV2
export struct TgDataStoragePage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private filesSize: number = 0;
  @Local private fileCount: number = 0;
  @Local private databaseSize: number = 0;
  @Local private languagePackSize: number = 0;
  @Local private logSize: number = 0;
  @Local private byChat: StorageChatUsageDto[] = [];
  @Local private totalSize: number = 0;
  @Local private isLoading: boolean = true;
  @Local private loadFailed: boolean = false;
  @Local private isClearing: boolean = false;
  // Maximum cache size in bytes; 0 means unlimited. Persisted locally, applied on demand.
  @Local private cacheLimitBytes: number = 0;
  private cacheLimitStore?: preferences.Preferences;
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;

  private loadStorageUseCase?: LoadStorageStatisticsUseCase;
  private pageLifecycleToken: number = 0;

  aboutToAppear(): void {
    this.restoreCacheLimit();
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
      this.loadStorageUseCase = createLoadStorageStatisticsUseCase(getTdGatewayAdapter());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Storage use case init failed: %{public}s', String(error));
      this.isLoading = false;
      this.loadFailed = true;
      return;
    }
    this.reloadStatistics();
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.loadStorageUseCase = undefined;
  }

  private reloadStatistics(): void {
    const useCase = this.loadStorageUseCase;
    if (useCase === undefined) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isLoading = true;
    this.loadFailed = false;
    useCase.fetchSnapshot()
      .then((snapshot: StorageSnapshot) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        const fast: FastStorageStatisticsDto = snapshot.fast;
        this.filesSize = fast.filesSize;
        this.fileCount = fast.fileCount;
        this.databaseSize = fast.databaseSize;
        this.languagePackSize = fast.languagePackDatabaseSize;
        this.logSize = fast.logSize;
        this.byChat = snapshot.full.byChat;
        this.totalSize = fast.filesSize + fast.databaseSize + fast.languagePackDatabaseSize + fast.logSize;
        this.isLoading = false;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Load storage statistics failed: %{public}s', error.message);
        this.isLoading = false;
        this.loadFailed = true;
      });
  }

  private chatTitle(chatId: number): string {
    let state: AppState | undefined = undefined;
    try {
      state = getAppCoreRuntime().getStore().getState();
    } catch (_error) {
      state = undefined;
    }
    const chat = state === undefined ? undefined : state.chats.chats.get(chatId);
    if (chat !== undefined && chat.title.length > 0) {
      return chat.title;
    }
    return localized($r('app.string.data_storage_unknown_chat').id, 'Chat') + ' ' + chatId.toString();
  }

  private restoreCacheLimit(): void {
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      this.cacheLimitStore = preferences.getPreferencesSync(context, { name: 'storage_settings' });
      const stored = this.cacheLimitStore.getSync('max_cache_bytes', 0) as number;
      this.cacheLimitBytes = Number.isSafeInteger(stored) && stored >= 0 ? stored : 0;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Cache limit preference unavailable: %{public}s', String(error));
      this.cacheLimitBytes = 0;
    }
  }

  private cacheLimitLabel(bytes: number): string {
    return bytes > 0
      ? formatStorageBytes(bytes)
      : localized($r('app.string.data_storage_unlimited').id, 'Unlimited');
  }

  private selectCacheLimit(): void {
    const options: number[] = [256 * 1024 * 1024, 512 * 1024 * 1024, 1024 * 1024 * 1024,
      2 * 1024 * 1024 * 1024, 0];
    this.getUIContext().getPromptAction().showActionMenu({
      title: localized($r('app.string.data_storage_max_cache').id, 'Maximum Cache Size'),
      buttons: [
        { text: formatStorageBytes(options[0]), color: TgUiTokens.COLOR_TEXT_TITLE },
        { text: formatStorageBytes(options[1]), color: TgUiTokens.COLOR_TEXT_TITLE },
        { text: formatStorageBytes(options[2]), color: TgUiTokens.COLOR_TEXT_TITLE },
        { text: formatStorageBytes(options[3]), color: TgUiTokens.COLOR_TEXT_TITLE },
        { text: this.cacheLimitLabel(0), color: TgUiTokens.COLOR_TEXT_TITLE }
      ]
    }).then((result: promptAction.ActionMenuSuccessResponse) => {
      const chosen = options[result.index];
      if (chosen === undefined) {
        return;
      }
      this.applyCacheLimit(chosen);
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'Cache limit menu failed: %{public}s', error.message);
    });
  }

  private applyCacheLimit(limitBytes: number): void {
    const useCase = this.loadStorageUseCase;
    if (useCase === undefined) {
      return;
    }
    this.cacheLimitBytes = limitBytes;
    this.persistCacheLimit(limitBytes);
    const token: number = this.pageLifecycleToken;
    useCase.enforceCacheLimit(limitBytes)
      .then((applied: boolean) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        if (applied) {
          this.getUIContext().getPromptAction().showToast({
            message: localized($r('app.string.data_storage_cache_limit_applied').id,
              'Cache trimmed to the new limit'),
            duration: 2000
          });
          this.reloadStatistics();
        }
      })
      .catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Cache limit failed: %{public}s', error.message);
      });
  }

  private persistCacheLimit(limitBytes: number): void {
    try {
      if (this.cacheLimitStore === undefined) {
        return;
      }
      this.cacheLimitStore.putSync('max_cache_bytes', limitBytes);
      this.cacheLimitStore.flush();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Cache limit persist failed: %{public}s', String(error));
    }
  }

  private confirmClearCache(): void {
    promptAction.showDialog({
      title: localized($r('app.string.data_storage_clear_cache').id, 'Clear Cache'),
      message: localized($r('app.string.data_storage_clear_cache_message').id,
        'Cached media will be downloaded again when needed.'),
      buttons: [
        { text: localized($r('app.string.cancel').id, 'Cancel'), color: TgUiTokens.COLOR_TEXT_PREVIEW },
        { text: localized($r('app.string.data_storage_clear_cache').id, 'Clear Cache'),
          color: TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index !== 1) {
        return;
      }
      this.clearCache();
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'Clear-cache dialog failed: %{public}s', error.message);
    });
  }

  private clearCache(): void {
    const useCase = this.loadStorageUseCase;
    if (useCase === undefined || this.isClearing) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isClearing = true;
    useCase.clearCache()
      .then(() => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isClearing = false;
        this.reloadStatistics();
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.isClearing = false;
        hilog.error(DOMAIN, TAG, 'Clear cache failed: %{public}s', error.message);
      });
  }

  @Builder
  buildValueRow(label: string, value: string, separator: boolean) {
    Row() {
      Text(label)
        .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
        .layoutWeight(1)
      Text(value)
        .fontSize(TgUiTokens.FONT_META_SIZE)
        .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
    }
    .width('100%')
    .height(44)
    .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
    .border(separator ? {
      width: { bottom: 0.5 },
      color: $r('app.color.separator')
    } : { width: 0 })
  }

  @Builder
  buildSectionTitle(title: string) {
    Text(title)
      .fontSize(TgUiTokens.FONT_META_SIZE)
      .fontColor(TgUiTokens.COLOR_TEXT_META)
      .width('100%')
      .padding({
        left: TgUiTokens.SPACE_16,
        right: TgUiTokens.SPACE_16,
        top: TgUiTokens.SPACE_12,
        bottom: TgUiTokens.SPACE_4
      })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        List() {
          if (this.isLoading) {
            ListItem() {
              Text(localized($r('app.string.data_storage_loading').id, 'Loading…'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: TgUiTokens.SPACE_24 })
            }
          } else if (this.loadFailed) {
            ListItem() {
              Column() {
                Text(localized($r('app.string.data_storage_load_failed').id, 'Could not load storage usage'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                Text(localized($r('app.string.data_storage_retry').id, 'Retry'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
                  .margin({ top: TgUiTokens.SPACE_8 })
                  .onClick(() => {
                    this.reloadStatistics();
                  })
              }
              .width('100%')
              .padding({ top: TgUiTokens.SPACE_24 })
            }
          } else {
            ListItem() {
              this.buildSectionTitle(localized($r('app.string.data_storage_usage_section').id, 'STORAGE USAGE'))
            }
            ListItem() {
              this.buildValueRow(localized($r('app.string.data_storage_total').id, 'Total'),
                formatStorageBytes(this.totalSize), true)
            }
            ListItem() {
              this.buildValueRow(localized($r('app.string.data_storage_files').id, 'Media files'),
                formatStorageBytes(this.filesSize), true)
            }
            ListItem() {
              this.buildValueRow(localized($r('app.string.data_storage_file_count').id, 'Files'),
                this.fileCount.toString(), true)
            }
            ListItem() {
              this.buildValueRow(localized($r('app.string.data_storage_database').id, 'Database'),
                formatStorageBytes(this.databaseSize), true)
            }
            ListItem() {
              this.buildValueRow(localized($r('app.string.data_storage_language_packs').id, 'Language packs'),
                formatStorageBytes(this.languagePackSize), true)
            }
            ListItem() {
              this.buildValueRow(localized($r('app.string.data_storage_logs').id, 'Logs'),
                formatStorageBytes(this.logSize), true)
            }
            ListItem() {
              Row() {
                Text(localized($r('app.string.data_storage_auto_download').id, 'Auto-Download'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                  .layoutWeight(1)
                Text('›')
                  .fontSize(TgUiTokens.FONT_META_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_META)
              }
              .width('100%')
              .height(44)
              .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
              .onClick(() => {
                this.pageStack.pushPathByName('TgAutoDownloadPage', undefined);
              })
            }
            ListItem() {
              Row() {
                Text(localized($r('app.string.data_storage_max_cache').id, 'Maximum Cache Size'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
                  .layoutWeight(1)
                Text(this.cacheLimitLabel(this.cacheLimitBytes))
                  .fontSize(TgUiTokens.FONT_META_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_META)
              }
              .width('100%')
              .height(44)
              .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
              .onClick(() => {
                this.selectCacheLimit();
              })
            }
            ListItem() {
              Text(this.isClearing
                ? localized($r('app.string.data_storage_clearing').id, 'Clearing…')
                : localized($r('app.string.data_storage_clear_cache').id, 'Clear Cache'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE)
                .width('100%')
                .height(44)
                .padding({ left: TgUiTokens.SPACE_16, right: TgUiTokens.SPACE_16 })
                .opacity(this.isClearing ? 0.5 : 1)
                .onClick(() => {
                  this.confirmClearCache();
                })
            }

            if (this.byChat.length > 0) {
              ListItem() {
                this.buildSectionTitle(localized($r('app.string.data_storage_by_chat').id, 'BY CHAT'))
              }
              ForEach(this.byChat, (usage: StorageChatUsageDto) => {
                ListItem() {
                  this.buildValueRow(this.chatTitle(usage.chatId),
                    formatStorageBytes(usage.size), true)
                }
              }, (usage: StorageChatUsageDto) => usage.chatId.toString() + ':' + usage.size.toString())
            }
          }
        }
        .width('100%')
        .height('100%')
        .contentStartOffset(this.topBarTotalHeight)
        .edgeEffect(EdgeEffect.Spring)
        .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)

        TgChatTopBar({
          topInset: this.topBarInset,
          title: localized($r('app.string.settings_data_storage').id, 'Data and Storage'),
          subtitle: this.isLoading ? '' : formatStorageBytes(this.totalSize),
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
