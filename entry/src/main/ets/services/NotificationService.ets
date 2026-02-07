// HarmonyOS Notification Service
// Reference: Huawei @ohos.notificationManager API, Telegram Android NotificationsController

import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'NotificationService';
const DOMAIN = 0x0001;

export class NotificationService {
  private static instance: NotificationService | null = null;
  private notificationId: number = 0;
  private enabled: boolean = true;

  private constructor() {}

  static getInstance(): NotificationService {
    if (!NotificationService.instance) {
      NotificationService.instance = new NotificationService();
    }
    return NotificationService.instance;
  }

  async requestPermission(): Promise<boolean> {
    try {
      await notificationManager.requestEnableNotification();
      this.enabled = true;
      hilog.info(DOMAIN, TAG, 'Notification permission granted');
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Notification permission denied');
      this.enabled = false;
      return false;
    }
  }

  async showMessageNotification(
    chatTitle: string,
    senderName: string,
    messageText: string,
    chatId: number
  ): Promise<void> {
    if (!this.enabled) return;

    try {
      const request: notificationManager.NotificationRequest = {
        id: ++this.notificationId,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: chatTitle,
            text: `${senderName}: ${messageText}`,
            additionalText: ''
          }
        },
        groupName: `chat_${chatId}`
      };

      await notificationManager.publish(request);
      hilog.info(DOMAIN, TAG, 'Notification published for chat: %{public}d', chatId);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to publish notification');
    }
  }

  async cancelChatNotifications(chatId: number): Promise<void> {
    try {
      await notificationManager.cancelGroup(`chat_${chatId}`);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to cancel notifications for chat: %{public}d', chatId);
    }
  }

  async cancelAll(): Promise<void> {
    try {
      await notificationManager.cancelAll();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to cancel all notifications');
    }
  }

  async setBadgeNumber(count: number): Promise<void> {
    try {
      await notificationManager.setBadgeNumber(count);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to set badge number');
    }
  }

  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
  }
}
