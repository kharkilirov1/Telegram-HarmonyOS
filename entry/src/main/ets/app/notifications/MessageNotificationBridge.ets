// I1: thin notification adapter. The decision and the text live in notificationPolicy; this module only
// talks to NotificationKit and remembers whether publishing is allowed.
// iOS counterpart: Notifications/MessageNotifications.

import { notificationManager } from '@kit.NotificationKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppState } from '../../core/model/AppState';
import { navigationUIState } from '../../core/model/UIStateModels';
import { MessageNotificationSink } from '../bootstrap/AppCoreRuntime';
import { AnyAppEvent, NewMessageEvent } from '../../core/model/AppEvent';
import {
  MessageNotificationContent,
  buildMessageNotificationContent,
  notificationAppMessageId,
  notificationBadgeNumber,
  notificationGroupName,
  shouldPublishMessageNotification
} from './notificationPolicy';

const DOMAIN = 0x00F1;
const TAG = 'MessageNotificationBridge';
const NOTIFICATION_ID_BASE = 4200;

// App visibility is tracked by navigationUIState.applicationForeground (EntryAbility owns it).

export class MessageNotificationBridge implements MessageNotificationSink {
  private enabled: boolean = false;
  private nextNotificationId: number = NOTIFICATION_ID_BASE;
  private chatNotificationIds: Map<number, number> = new Map<number, number>();
  // The chat currently on screen, so its new messages never produce a notification.
  private activeChatIdProvider: () => number = (): number => 0;
  private bundleName: string = '';
  private abilityName: string = 'EntryAbility';

  setActiveChatIdProvider(provider: () => number): void {
    this.activeChatIdProvider = provider;
  }

  // Permission is requested once per process; a denial leaves the bridge disabled rather than noisy.
  async start(context: common.UIAbilityContext): Promise<void> {
    try {
      this.bundleName = context.abilityInfo.bundleName;
      this.abilityName = context.abilityInfo.name;
      await notificationManager.requestEnableNotification(context);
      this.enabled = true;
      hilog.info(DOMAIN, TAG, 'Message notifications enabled');
    } catch (error) {
      this.enabled = false;
      hilog.warn(DOMAIN, TAG, 'Notification permission unavailable: %{public}s', String(error));
    }
  }

  stop(): void {
    this.enabled = false;
  }

  isEnabled(): boolean {
    return this.enabled;
  }

  // Called after the batch reached the store, so the state already holds the message.
  handleEvents(state: AppState, events: AnyAppEvent[]): void {
    if (!this.enabled) {
      return;
    }
    const activeChatId = this.activeChatIdProvider();
    for (const event of events) {
      if (event.type !== 'newMessage') {
        continue;
      }
      const messageEvent = event as NewMessageEvent;
      if (!shouldPublishMessageNotification(state, messageEvent, navigationUIState.applicationForeground,
        activeChatId)) {
        continue;
      }
      const content = buildMessageNotificationContent(state, messageEvent);
      this.publish(state, content);
    }
  }

  // Tapping the notification opens the chat: the want carries the chat id for MainTabsPage.
  private async buildChatWantAgent(chatId: number): Promise<WantAgent | undefined> {
    if (this.bundleName.length === 0) {
      return undefined;
    }
    try {
      const parameters: Record<string, Object> = {};
      parameters['chatId'] = chatId;
      const info: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: this.bundleName,
          abilityName: this.abilityName,
          parameters: parameters
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: this.nextNotificationId,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      return await wantAgent.getWantAgent(info);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'WantAgent for a notification failed: %{public}s', String(error));
      return undefined;
    }
  }

  // I1: the same chat reuses its notification id, so a burst of messages updates one entry.
  private notificationIdFor(chatId: number): number {
    const existing = this.chatNotificationIds.get(chatId);
    if (existing !== undefined) {
      return existing;
    }
    const id = this.nextNotificationId;
    this.nextNotificationId += 1;
    this.chatNotificationIds.set(chatId, id);
    return id;
  }

  // iOS clears a chat's notifications once the chat is open.
  async cancelForChat(chatId: number): Promise<void> {
    const id = this.chatNotificationIds.get(chatId);
    if (id === undefined || !this.enabled) {
      return;
    }
    this.chatNotificationIds.delete(chatId);
    try {
      await notificationManager.cancel(id);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Cancelling a notification failed: %{public}s', String(error));
    }
  }

  async cancelAll(): Promise<void> {
    if (!this.enabled) {
      return;
    }
    this.chatNotificationIds.clear();
    try {
      await notificationManager.cancelAll();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Cancelling all notifications failed: %{public}s', String(error));
    }
  }

  private publish(state: AppState, content: MessageNotificationContent): void {
    const notificationId = this.notificationIdFor(content.chatId);
    this.buildChatWantAgent(content.chatId).then((agent: WantAgent | undefined): Promise<void> => {
      const request: notificationManager.NotificationRequest = {
        id: notificationId,
        groupName: notificationGroupName(content.chatId),
        appMessageId: notificationAppMessageId(content.chatId),
        badgeNumber: notificationBadgeNumber(state, content.chatId),
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: content.title,
            text: content.body,
            additionalText: ''
          }
        }
      };
      if (agent !== undefined) {
        request.wantAgent = agent;
      }
      return notificationManager.publish(request);
    })
      .then((): void => {
        hilog.info(DOMAIN, TAG, 'Notification published for chat %{public}d', content.chatId);
      })
      .catch((error: Error): void => {
        hilog.warn(DOMAIN, TAG, 'Publishing a notification failed: %{public}s', error.message);
      });
  }
}

// One bridge per process; EntryAbility asks for it lazily so the ability class keeps no state.
const messageNotificationBridge: MessageNotificationBridge = new MessageNotificationBridge();

export function getMessageNotificationBridge(): MessageNotificationBridge {
  return messageNotificationBridge;
}
