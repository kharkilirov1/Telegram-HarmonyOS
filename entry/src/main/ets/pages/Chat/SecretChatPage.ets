// Secret Chat page — initiate and manage secret (end-to-end encrypted) chats
// Reference: Telegram iOS SecretChatKeyController, Android SecretChatInfoActivity
// HarmonyOS: NavDestination, @ComponentV2, V2 state decorators

import { TDLibClient } from '../../services/TDLibClient';
import { UserService } from '../../services/UserService';
import { ChatService } from '../../services/ChatService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdSecretChat } from '../../models/TdTypes';
import { SecretChatInfoSection } from './components/SecretChatInfoSection';
import { SecretChatKeySection } from './components/SecretChatKeySection';
import { SecretChatStatusSection } from './components/SecretChatStatusSection';
import { SecretChatTimerOption, SecretChatTimerSection } from './components/SecretChatTimerSection';
import { SecretChatTopBar } from './components/SecretChatTopBar';

@Builder
export function SecretChatBuilder(name: string, param: Object) {
  SecretChatPage({ userId: (param as Record<string, number>)['userId'] ?? 0 })
}

@ComponentV2
export struct SecretChatPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param userId: number = 0;

  @Local chatState: string = 'creating';
  @Local secretChatId: number = 0;
  @Local chatId: number = 0;
  @Local userName: string = '';

  @Local keyHash: number[] = [];

  @Local selectedTimerIndex: number = 0;
  @Local isSettingTimer: boolean = false;
  @Local showTimerPicker: boolean = false;

  @Local errorMessage: string = '';

  private timerOptions: SecretChatTimerOption[] = [
    { label: '', seconds: 0 },
    { label: '1s', seconds: 1 },
    { label: '5s', seconds: 5 },
    { label: '15s', seconds: 15 },
    { label: '30s', seconds: 30 },
    { label: '1m', seconds: 60 },
    { label: '5m', seconds: 300 },
    { label: '1h', seconds: 3600 },
    { label: '1d', seconds: 86400 },
    { label: '1w', seconds: 604800 }
  ];

  private secretChatUpdateHandler = (update: Record<string, Object>): void => {
    this.handleSecretChatUpdate(update);
  };

  aboutToAppear(): void {
    try {
      this.timerOptions[0].label = getContext(this).resourceManager.getStringByNameSync('timer_off');
    } catch (e) {
      this.timerOptions[0].label = 'Off';
    }

    TDLibClient.getInstance().on('updateSecretChat', this.secretChatUpdateHandler);
    this.loadUserName();
    this.createSecretChat();
  }

  aboutToDisappear(): void {
    TDLibClient.getInstance().off('updateSecretChat', this.secretChatUpdateHandler);
  }

  private getUserFallback(): string {
    try {
      return getContext(this).resourceManager.getStringByNameSync('user_fallback');
    } catch (e) {
      return 'User';
    }
  }

  private formatWaitingMessage(): string {
    try {
      const template = getContext(this).resourceManager.getStringByNameSync('waiting_for_user');
      return template.replace('%s', this.userName);
    } catch (e) {
      return `Waiting for ${this.userName} to come online`;
    }
  }

  private formatCompareKeyHint(): string {
    try {
      const template = getContext(this).resourceManager.getStringByNameSync('compare_key_hint');
      return template.replace('%s', this.userName);
    } catch (e) {
      return `Compare this image with the one shown on ${this.userName}'s device. If they are the same, your chat is 100% secure.`;
    }
  }

  private async loadUserName(): Promise<void> {
    try {
      const result = await UserService.getInstance().getUser(this.userId);
      const first = result.first_name || '';
      const last = result.last_name || '';
      this.userName = `${first} ${last}`.trim() || this.getUserFallback();
    } catch (e) {
      hilog.warn(0x0001, 'SecretChatPage', 'Failed to load user name');
      this.userName = this.getUserFallback();
    }
  }

  private async createSecretChat(): Promise<void> {
    this.chatState = 'creating';
    this.errorMessage = '';

    try {
      const result = await ChatService.getInstance().createNewSecretChat(this.userId);

      const chatType = result['type'] as Record<string, Object> | undefined;
      if (chatType) {
        this.secretChatId = (chatType['secret_chat_id'] as number) || 0;
      }
      this.chatId = (result['id'] as number) || 0;

      if (this.secretChatId > 0) {
        await this.fetchSecretChatInfo();
      }
    } catch (e) {
      hilog.warn(0x0001, 'SecretChatPage', 'Failed to create secret chat');
      this.errorMessage = getContext(this).resourceManager.getStringSync($r('app.string.failed_secret_chat'));
      this.chatState = 'closed';
    }
  }

  private async fetchSecretChatInfo(): Promise<void> {
    try {
      const secretChat = await ChatService.getInstance().getSecretChat(this.secretChatId);

      const state = secretChat.state as Record<string, string> | undefined;
      const stateType = state ? state['@type'] : '';

      if (stateType === 'secretChatStateReady') {
        this.chatState = 'active';
      } else if (stateType === 'secretChatStateClosed') {
        this.chatState = 'closed';
      } else {
        this.chatState = 'creating';
      }

      const rawHash = secretChat.key_hash || '';
      if (rawHash.length > 0) {
        const decoded = this.decodeBase64ToBytes(rawHash);
        if (decoded.length > 0) {
          this.keyHash = decoded;
          return;
        }
      }
      // No key hash available yet — show empty (UI should indicate key not yet exchanged)
      this.keyHash = [];
    } catch (e) {
      hilog.warn(0x0001, 'SecretChatPage', 'Failed to fetch secret chat info');
      this.keyHash = [];
    }
  }

  private handleSecretChatUpdate(update: Record<string, Object>): void {
    const record = update as Record<string, Object>;
    const secretChat = record['secret_chat'] as TdSecretChat | undefined;
    if (!secretChat) {
      return;
    }

    const id = secretChat.id;
    if (id !== this.secretChatId) {
      return;
    }

    const state = secretChat.state as Record<string, string> | undefined;
    const stateType = state ? state['@type'] : '';

    if (stateType === 'secretChatStateReady') {
      this.chatState = 'active';
      this.fetchSecretChatInfo();
    } else if (stateType === 'secretChatStateClosed') {
      this.chatState = 'closed';
    }
  }

  private decodeBase64ToBytes(base64: string): number[] {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const bytes: number[] = [];
    let buffer = 0;
    let bitsCollected = 0;

    for (let i = 0; i < base64.length; i++) {
      const c = base64.charAt(i);
      if (c === '=') {
        break;
      }
      const idx = chars.indexOf(c);
      if (idx < 0) {
        continue;
      }
      buffer = (buffer << 6) | idx;
      bitsCollected += 6;
      while (bitsCollected >= 8) {
        bitsCollected -= 8;
        bytes.push((buffer >> bitsCollected) & 0xFF);
      }
    }

    return bytes;
  }

  private async setAutoDeleteTimer(seconds: number): Promise<void> {
    if (this.chatId === 0) {
      return;
    }

    this.isSettingTimer = true;
    try {
      await ChatService.getInstance().setChatMessageAutoDeleteTime(this.chatId, seconds);
    } catch (e) {
      hilog.warn(0x0001, 'SecretChatPage', 'Failed to set auto-delete timer');
    }
    this.isSettingTimer = false;
  }

  build() {
    NavDestination() {
      Column() {
        SecretChatTopBar({
          userName: this.userName,
          onBack: () => {
            this.navPathStack.pop();
          }
        })

        Scroll() {
          Column() {
            SecretChatStatusSection({
              chatState: this.chatState,
              waitingMessage: this.formatWaitingMessage(),
              errorMessage: this.errorMessage
            })

            Blank().height(16)

            SecretChatKeySection({
              keyHash: this.keyHash,
              compareKeyHint: this.formatCompareKeyHint()
            })

            Blank().height(16)

            SecretChatTimerSection({
              selectedTimerLabel: this.timerOptions[this.selectedTimerIndex].label,
              isSettingTimer: this.isSettingTimer,
              showTimerPicker: this.showTimerPicker,
              canOpenPicker: this.chatState === 'active',
              selectedTimerIndex: this.selectedTimerIndex,
              timerOptions: this.timerOptions,
              onTogglePicker: () => {
                this.showTimerPicker = !this.showTimerPicker;
              },
              onSelectTimer: (index: number, seconds: number) => {
                this.selectedTimerIndex = index;
                this.showTimerPicker = false;
                this.setAutoDeleteTimer(seconds);
              }
            })

            Blank().height(16)

            SecretChatInfoSection()

            Blank().height(40)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
    }
    .hideTitleBar(true)
  }
}
