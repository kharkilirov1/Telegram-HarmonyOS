// I1: thin notification adapter. The decision and the text live in notificationPolicy; this module only
// talks to NotificationKit and remembers whether publishing is allowed.
// iOS counterpart: Notifications/MessageNotifications.

import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppState } from '../../core/model/AppState';
import { navigationUIState } from '../../core/model/UIStateModels';
import { MessageNotificationSink } from '../bootstrap/AppCoreRuntime';
import { AnyAppEvent, NewMessageEvent } from '../../core/model/AppEvent';
import {
  MessageNotificationContent,
  buildMessageNotificationContent,
  shouldPublishMessageNotification
} from './notificationPolicy';

const DOMAIN = 0x00F1;
const TAG = 'MessageNotificationBridge';
const NOTIFICATION_ID_BASE = 4200;

// App visibility is tracked by navigationUIState.applicationForeground (EntryAbility owns it).

export class MessageNotificationBridge implements MessageNotificationSink {
  private enabled: boolean = false;
  private nextNotificationId: number = NOTIFICATION_ID_BASE;
  // The chat currently on screen, so its new messages never produce a notification.
  private activeChatIdProvider: () => number = (): number => 0;

  setActiveChatIdProvider(provider: () => number): void {
    this.activeChatIdProvider = provider;
  }

  // Permission is requested once per process; a denial leaves the bridge disabled rather than noisy.
  async start(context: common.UIAbilityContext): Promise<void> {
    try {
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
      this.publish(content);
    }
  }

  private publish(content: MessageNotificationContent): void {
    const request: notificationManager.NotificationRequest = {
      id: this.nextNotificationId,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: content.title,
          text: content.body,
          additionalText: ''
        }
      }
    };
    this.nextNotificationId += 1;
    notificationManager.publish(request)
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
