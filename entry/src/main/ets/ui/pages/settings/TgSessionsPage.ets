// TgSessionsPage — Settings → Devices: active TDLib sessions (H5).
// TDLib: getActiveSessions = Sessions (td_api.tl:13755), terminateSession (td_api.tl:13758).
// iOS counterpart: ActiveSessions/WebSessions screens under Settings → Devices.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction } from '@kit.ArkUI';
import { localized } from '../../../core/utils/AppResource';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { createLoadSessionsUseCase, LoadSessionsUseCase } from '../../../domain/usecases/loadSessions';
import { SessionInfoDto } from '../../../core/model/dto/SessionDto';
import { splitSessionsByKind, canTerminateOthers } from '../../../domain/selectors/sessionSelectors';
import { TgChatTopBar } from '../../tg_ui/atoms/TgChatTopBar';
import { TgIcon } from '../../tg_ui/atoms/TgIcon';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';
import { computeTopBarHeight } from '../../utils/SafeAreaUtils';
import { common } from '@kit.AbilityKit';

const DOMAIN = 0x0034;
const TAG = 'TgSessionsPage';

@Builder
export function TgSessionsPageBuilder() {
  TgSessionsPage();
}

@ComponentV2
export struct TgSessionsPage {
  @Local private pageStack: NavPathStack = new NavPathStack();
  @Local private sessions: SessionInfoDto[] = [];
  @Local private activeSessions: SessionInfoDto[] = [];
  @Local private webSessions: SessionInfoDto[] = [];
  @Local private isLoading: boolean = true;
  @Local private loadFailed: boolean = false;
  @Local private topBarTotalHeight: number = TgUiTokens.TOP_BAR_HEIGHT;
  @Local private topBarInset: number = TgUiTokens.STATUS_BAR_FALLBACK_INSET;
  @Local private terminatingId: string = '';

  private loadSessionsUseCase?: LoadSessionsUseCase;
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
      this.loadSessionsUseCase = createLoadSessionsUseCase(getTdGatewayAdapter());
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Session use case init failed: %{public}s', String(error));
      this.isLoading = false;
      this.loadFailed = true;
      return;
    }
    this.reloadSessions();
  }

  aboutToDisappear(): void {
    this.pageLifecycleToken += 1;
    this.loadSessionsUseCase = undefined;
  }

  private reloadSessions(): void {
    const useCase = this.loadSessionsUseCase;
    if (useCase === undefined) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.isLoading = true;
    this.loadFailed = false;
    useCase.fetchSessions()
      .then((sessions: SessionInfoDto[]) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.sessions = sessions;
        const sections = splitSessionsByKind(sessions);
        this.activeSessions = sections.active;
        this.webSessions = sections.web;
        this.isLoading = false;
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Load sessions failed: %{public}s', error.message);
        this.isLoading = false;
        this.loadFailed = true;
      });
  }

  private confirmTerminate(session: SessionInfoDto): void {
    if (session.isCurrent) {
      // TDLib terminates the current session only after the client confirms logout; the page must
      // not offer it (iOS uses a separate Log Out flow).
      return;
    }
    const title: string = localized($r('app.string.sessions_terminate_title').id, 'Terminate Session');
    const message: string = session.deviceModel.length > 0
      ? session.deviceModel : localized($r('app.string.sessions_unknown_device').id, 'Unknown device');
    promptAction.showDialog({
      title: title,
      message: message,
      buttons: [
        { text: localized($r('app.string.cancel').id, 'Cancel'), color: TgUiTokens.COLOR_TEXT_PREVIEW },
        { text: localized($r('app.string.sessions_terminate').id, 'Terminate'), color: TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index !== 1) {
        return;
      }
      this.terminate(session);
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'Terminate dialog failed: %{public}s', error.message);
    });
  }

  private terminate(session: SessionInfoDto): void {
    const useCase = this.loadSessionsUseCase;
    if (useCase === undefined) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    this.terminatingId = session.id;
    useCase.terminate(session.id)
      .then(() => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.terminatingId = '';
        this.reloadSessions();
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.terminatingId = '';
        hilog.error(DOMAIN, TAG, 'Terminate failed: %{public}s', error.message);
      });
  }

  private deviceTitle(session: SessionInfoDto): string {
    const model: string = session.deviceModel.trim();
    const platform: string = session.platform.trim();
    if (model.length > 0 && platform.length > 0) {
      return `${model} · ${platform}`;
    }
    if (model.length > 0) {
      return model;
    }
    return localized($r('app.string.sessions_unknown_device').id, 'Unknown device');
  }

  private deviceSubtitle(session: SessionInfoDto): string {
    const parts: string[] = [];
    if (session.applicationName.length > 0) {
      parts.push(session.applicationVersion.length > 0
        ? `${session.applicationName} ${session.applicationVersion}` : session.applicationName);
    }
    if (session.ipAddress.length > 0) {
      parts.push(session.country.length > 0 ? `${session.ipAddress} · ${session.country}` : session.ipAddress);
    }
    return parts.join('  ');
  }

  private lastActiveText(session: SessionInfoDto): string {
    if (session.isCurrent) {
      return localized($r('app.string.sessions_this_device').id, 'This device');
    }
    if (session.lastActiveDate <= 0) {
      return '';
    }
    const date = new Date(session.lastActiveDate * 1000);
    return date.toLocaleString();
  }

  @Builder
  buildSessionSection(title: string, list: SessionInfoDto[], showTerminateAll: boolean) {
    ListItem() {
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
    ForEach(list, (session: SessionInfoDto) => {
      ListItem() {
        this.buildSessionRow(session)
      }
    }, (session: SessionInfoDto) => session.id)
    if (showTerminateAll) {
      ListItem() {
        Text(localized($r('app.string.sessions_terminate_all').id, 'Terminate All Other Sessions'))
          .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
          .fontColor(TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE)
          .width('100%')
          .padding({
            left: TgUiTokens.SPACE_16,
            right: TgUiTokens.SPACE_16,
            top: TgUiTokens.SPACE_12,
            bottom: TgUiTokens.SPACE_12
          })
          .onClick(() => {
            this.confirmTerminateAll();
          })
      }
    }
  }

  @Builder
  buildSessionRow(session: SessionInfoDto) {
    Row() {
      TgIcon({
        src: TgUiTokens.ICON_RES_DEVICE,
        iconSize: TgUiTokens.ICON_SIZE_MD,
        tintColor: TgUiTokens.COLOR_TEXT_PREVIEW
      })
        .margin({ right: TgUiTokens.SPACE_12 })
      Column() {
        Row() {
          Text(this.deviceTitle(session))
            .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (session.isCurrent) {
            Text(localized($r('app.string.sessions_current').id, 'Current'))
              .fontSize(TgUiTokens.FONT_META_SIZE)
              .fontColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
              .margin({ left: TgUiTokens.SPACE_8 })
          }
        }
        .width('100%')

        Text(this.deviceSubtitle(session))
          .fontSize(TgUiTokens.FONT_META_SIZE)
          .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: TgUiTokens.SPACE_4 })

        if (this.lastActiveText(session).length > 0) {
          Text(this.lastActiveText(session))
            .fontSize(TgUiTokens.FONT_META_SIZE)
            .fontColor(TgUiTokens.COLOR_TEXT_META)
            .maxLines(1)
            .width('100%')
            .margin({ top: TgUiTokens.SPACE_4 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: TgUiTokens.SPACE_16,
      right: TgUiTokens.SPACE_16,
      top: TgUiTokens.SPACE_12,
      bottom: TgUiTokens.SPACE_12
    })
    .opacity(this.terminatingId === session.id ? 0.5 : 1)
    .onClick(() => {
      this.confirmTerminate(session);
    })
  }

  private confirmTerminateAll(): void {
    const title: string = localized($r('app.string.sessions_terminate_all_title').id,
      'Terminate All Other Sessions');
    promptAction.showDialog({
      title: title,
      buttons: [
        { text: localized($r('app.string.cancel').id, 'Cancel'), color: TgUiTokens.COLOR_TEXT_PREVIEW },
        { text: localized($r('app.string.sessions_terminate').id, 'Terminate'),
          color: TgUiTokens.CHAT_CONTEXT_MENU_DESTRUCTIVE }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index !== 1) {
        return;
      }
      this.terminateAllOthers();
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'Terminate-all dialog failed: %{public}s', error.message);
    });
  }

  private terminateAllOthers(): void {
    const useCase = this.loadSessionsUseCase;
    if (useCase === undefined) {
      return;
    }
    const token: number = this.pageLifecycleToken;
    useCase.terminateAllOthers()
      .then(() => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        this.reloadSessions();
      })
      .catch((error: Error) => {
        if (token !== this.pageLifecycleToken) {
          return;
        }
        hilog.error(DOMAIN, TAG, 'Terminate all failed: %{public}s', error.message);
      });
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        List() {
          if (this.isLoading) {
            ListItem() {
              Text(localized($r('app.string.sessions_loading').id, 'Loading…'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: TgUiTokens.SPACE_24 })
            }
          } else if (this.loadFailed) {
            ListItem() {
              Column() {
                Text(localized($r('app.string.sessions_load_failed').id, 'Could not load sessions'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                Text(localized($r('app.string.sessions_retry').id, 'Retry'))
                  .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                  .fontColor(TgUiTokens.CHAT_TOP_BAR_SUBTITLE_ACCENT)
                  .margin({ top: TgUiTokens.SPACE_8 })
                  .onClick(() => {
                    this.reloadSessions();
                  })
              }
              .width('100%')
              .padding({ top: TgUiTokens.SPACE_24 })
            }
          } else if (this.sessions.length === 0) {
            ListItem() {
              Text(localized($r('app.string.sessions_empty').id, 'No active sessions'))
                .fontSize(TgUiTokens.FONT_PREVIEW_SIZE)
                .fontColor(TgUiTokens.COLOR_TEXT_PREVIEW)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: TgUiTokens.SPACE_24 })
            }
          } else {
            this.buildSessionSection(
              localized($r('app.string.sessions_active_title').id, 'Active Sessions'),
              this.activeSessions,
              canTerminateOthers(this.sessions)
            )
            if (this.webSessions.length > 0) {
              this.buildSessionSection(
                localized($r('app.string.sessions_web_title').id, 'Web Sessions'),
                this.webSessions,
                false
              )
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
          title: localized($r('app.string.settings_devices').id, 'Devices'),
          subtitle: this.isLoading ? '' : `${this.sessions.length}`,
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
