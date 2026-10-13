// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { AppState } from '../../../core/model/AppState';
import { BotMenuCommandEntry, BotMenuInfo, loadBotMenuInfo } from '../../../domain/usecases/loadBotMenu';
import { localized } from '../../../core/utils/AppResource';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common, Want } from '@kit.AbilityKit';

const DOMAIN = 0x0021;
const TAG = 'TgChatScreenPage';

export interface ChatBotMenuCoordinatorPort {
  activeChatId: number;
  botMenuCommands: BotMenuCommandEntry[];
  botMenuLoadingUserId: number;
  botMenuOpen: boolean;
  botMenuPeerUserId: number;
  botMenuTitle: string;
  botMenuUrl: string;
  pageLifecycleToken: number;
  showBotMenu: boolean;
  handleSendMessage(text: string): void;
  resetBotMenuState(): void;
  getUIContext(): UIContext;
}

export function resetBotMenuState(host: ChatBotMenuCoordinatorPort): void {
    host.showBotMenu = false;
    host.botMenuOpen = false;
    host.botMenuTitle = '';
    host.botMenuUrl = '';
    host.botMenuCommands = [];
    host.botMenuPeerUserId = 0;
    host.botMenuLoadingUserId = 0;
  }

export function refreshBotMenuState(host: ChatBotMenuCoordinatorPort, state: AppState): void {
    const chat = state.chats.chats.get(host.activeChatId);
    if (chat === undefined || chat.type !== 'private' || chat.peerUserId <= 0) {
      host.resetBotMenuState();
      return;
    }
    const user = state.users.users.get(chat.peerUserId);
    if (user === undefined || !user.isBot) {
      host.resetBotMenuState();
      return;
    }
    if (host.botMenuPeerUserId === chat.peerUserId || host.botMenuLoadingUserId === chat.peerUserId) {
      return;
    }

    const peerUserId = chat.peerUserId;
    const chatId = host.activeChatId;
    const lifecycleToken = host.pageLifecycleToken;
    host.botMenuLoadingUserId = peerUserId;
    loadBotMenuInfo(peerUserId)
      .then((info: BotMenuInfo) => {
        if (host.pageLifecycleToken !== lifecycleToken || host.activeChatId !== chatId) {
          return;
        }
        host.botMenuLoadingUserId = 0;
        host.botMenuPeerUserId = peerUserId;
        host.botMenuOpen = false;
        host.botMenuUrl = info.url;
        host.botMenuCommands = info.commands;
        host.botMenuTitle = info.title.length > 0
          ? info.title
          : localized($r('app.string.composer_bot_menu').id, 'Menu');
        host.showBotMenu = info.isAvailable;
      })
      .catch((error: Error) => {
        if (host.pageLifecycleToken !== lifecycleToken || host.activeChatId !== chatId) {
          return;
        }
        host.botMenuLoadingUserId = 0;
        host.botMenuPeerUserId = 0;
        hilog.warn(DOMAIN, TAG, 'Bot menu load failed: %{public}s', error.message);
      });
  }

export function handleBotMenuPress(host: ChatBotMenuCoordinatorPort): void {
    if (!host.showBotMenu) {
      return;
    }
    if (host.botMenuUrl.length > 0) {
      host.botMenuOpen = false;
      try {
        const context = host.getUIContext().getHostContext() as common.UIAbilityContext;
        const want: Want = {
          action: 'ohos.want.action.viewData',
          uri: host.botMenuUrl
        };
        context.startAbility(want).catch((_error: Object) => {});
      } catch (_error) {}
      return;
    }
    if (host.botMenuCommands.length === 0) {
      return;
    }

    host.botMenuOpen = !host.botMenuOpen;
  }

export function botMenuCommandNames(host: ChatBotMenuCoordinatorPort): string[] {
    const result: string[] = [];
    for (const entry of host.botMenuCommands) {
      result.push(entry.command);
    }
    return result;
  }

export function botMenuCommandDescriptions(host: ChatBotMenuCoordinatorPort): string[] {
    const result: string[] = [];
    for (const entry of host.botMenuCommands) {
      result.push(entry.description);
    }
    return result;
  }

export function handleBotMenuOpenChange(host: ChatBotMenuCoordinatorPort, isOpen: boolean): void {
    host.botMenuOpen = isOpen && host.showBotMenu && host.botMenuUrl.length === 0 &&
      host.botMenuCommands.length > 0;
  }

export function handleBotMenuCommandPress(host: ChatBotMenuCoordinatorPort, index: number): void {
    host.botMenuOpen = false;
    if (index < 0 || index >= host.botMenuCommands.length) {
      return;
    }
    host.handleSendMessage(`/${host.botMenuCommands[index].command}`);
  }
