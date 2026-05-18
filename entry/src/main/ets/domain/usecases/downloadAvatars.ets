// DownloadAvatars use case — triggers TDLib downloadFile for avatars
//
// Subscribes to store changes. When a user or chat appears with
// photoSmallFileId > 0 but empty photoSmall path, enqueues a download.
// TDLib responds with updateFile → FileNormalizer → FileDownloadedEvent → filesReducer.
// Also processes direct downloadFile response for immediate completions.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { AppState, Chat, User } from '../../core/model/AppState';
import { createDownloadFileCommand } from '../../core/model/AppCommand';
import { FileDownloadedEvent } from '../../core/model/AppEvent';
import { TdObject } from '../../models/td/common/index';

const TAG = 'DownloadAvatars';
const DOMAIN = 0x0008;
const AVATAR_DOWNLOAD_PRIORITY = 5;

export class DownloadAvatarsUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private pendingFileIds: Set<number> = new Set<number>();
  private unsubscribe: (() => void) | null = null;
  private scanScheduled: boolean = false;
  private scanTimerId: number = -1;
  private isRunning: boolean = false;
  private lifecycleToken: number = 0;
  private static readonly SCAN_THROTTLE_MS = 500;

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  start(): void {
    if (this.isRunning) return;
    this.isRunning = true;
    this.lifecycleToken++;

    hilog.info(DOMAIN, TAG, 'Starting avatar download watcher');

    // Scan current state
    this.scanAndDownload(this.store.getState());

    // Subscribe for future changes — throttled to avoid scan spam
    if (this.unsubscribe !== null) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
    const subscriptionToken = this.lifecycleToken;
    let activeUnsubscribe: (() => void) | null = null;
    activeUnsubscribe = this.store.subscribe((newState: AppState, prevState: AppState): void => {
      if (!this.isCurrentSubscription(subscriptionToken, activeUnsubscribe)) {
        return;
      }
      if (newState.users !== prevState.users || newState.chats !== prevState.chats) {
        this.scheduleScan();
      }
    });
    this.unsubscribe = activeUnsubscribe;
  }

  stop(): void {
    this.isRunning = false;
    this.lifecycleToken++;
    const activeUnsubscribe = this.unsubscribe;
    this.unsubscribe = null;
    if (activeUnsubscribe) {
      activeUnsubscribe();
    }
    if (this.scanTimerId !== -1) {
      clearTimeout(this.scanTimerId);
      this.scanTimerId = -1;
    }
    this.pendingFileIds.clear();
    this.scanScheduled = false;
  }

  private isCurrentRun(token: number): boolean {
    return this.isRunning && token === this.lifecycleToken;
  }

  private isCurrentSubscription(token: number, unsubscribe: (() => void) | null): boolean {
    return this.isCurrentRun(token) && this.unsubscribe === unsubscribe;
  }

  private scheduleScan(): void {
    if (this.scanScheduled) return;
    this.scanScheduled = true;
    const token = this.lifecycleToken;
    this.scanTimerId = setTimeout(() => {
      this.scanTimerId = -1;
      this.scanScheduled = false;
      if (!this.isCurrentRun(token)) {
        return;
      }
      // Use latest state, not the captured one
      this.scanAndDownload(this.store.getState());
    }, DownloadAvatarsUseCase.SCAN_THROTTLE_MS) as number;
  }

  private scanAndDownload(state: AppState): void {
    let usersNeedDownload = 0;
    let chatsNeedDownload = 0;
    let usersWithFileId = 0;
    let chatsWithFileId = 0;

    // Scan users
    state.users.users.forEach((user: User) => {
      if (user.photoSmallFileId > 0) {
        usersWithFileId++;
        if (user.photoSmall.length > 0) {
          this.pendingFileIds.delete(user.photoSmallFileId);
        } else {
          usersNeedDownload++;
          this.enqueueDownload(user.photoSmallFileId);
        }
      }
    });

    // Scan chats
    state.chats.chats.forEach((chat: Chat) => {
      if (chat.photoSmallFileId > 0) {
        chatsWithFileId++;
        if (chat.photoSmall.length > 0) {
          this.pendingFileIds.delete(chat.photoSmallFileId);
        } else {
          chatsNeedDownload++;
          this.enqueueDownload(chat.photoSmallFileId);
        }
      }
    });

    if (usersNeedDownload > 0 || chatsNeedDownload > 0) {
      hilog.info(DOMAIN, TAG,
        'Scan: users=%{public}d/%{public}d chats=%{public}d/%{public}d need download (withFileId/total)',
        usersNeedDownload, usersWithFileId, chatsNeedDownload, chatsWithFileId);
    }
  }

  private enqueueDownload(fileId: number): void {
    if (!this.isRunning) return;
    if (this.pendingFileIds.has(fileId)) return;
    this.pendingFileIds.add(fileId);

    hilog.info(DOMAIN, TAG, 'Downloading avatar fileId=%{public}d', fileId);

    const command = createDownloadFileCommand(fileId, AVATAR_DOWNLOAD_PRIORITY, false);
    const store = this.store;
    const token = this.lifecycleToken;

    this.gateway.send(command)
      .then((response: Object): void => {
        if (!this.isCurrentRun(token)) {
          return;
        }
        hilog.info(DOMAIN, TAG, 'downloadFile response received for fileId=%{public}d', fileId);

        // Response is a TdObject (TDLib "file" object) — use native accessors
        try {
          const tdResponse = response as TdObject;
          const local = tdResponse.getObject('local');
          const isComplete = local.getBool('is_downloading_completed');
          const path = local.getString('path');

          hilog.info(DOMAIN, TAG, 'downloadFile resp fileId=%{public}d complete=%{public}s path=%{public}s',
            fileId, isComplete ? 'true' : 'false', path.length > 0 ? path : '(empty)');

          if (isComplete && path.length > 0) {
            hilog.info(DOMAIN, TAG, 'File %{public}d already downloaded: %{public}s', fileId, path);
            this.pendingFileIds.delete(fileId);
            // Dispatch FileDownloadedEvent directly
            const event = new FileDownloadedEvent();
            event.fileId = fileId;
            event.localPath = path;
            event.isComplete = true;
            event.timestamp = Date.now();
            store.dispatch(event);
          }
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'Could not parse downloadFile response: %{public}s', String(e));
          this.pendingFileIds.delete(fileId);
        }
      })
      .catch((error: Error): void => {
        if (!this.isCurrentRun(token)) {
          return;
        }
        hilog.warn(DOMAIN, TAG, 'Failed to download fileId=%{public}d: %{public}s', fileId, error.message);
        this.pendingFileIds.delete(fileId);
      });
  }
}

// Singleton
let instance: DownloadAvatarsUseCase | null = null;

export function createDownloadAvatarsUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): DownloadAvatarsUseCase {
  if (!instance) {
    instance = new DownloadAvatarsUseCase(store, gateway);
  }
  return instance;
}

export function resetDownloadAvatarsUseCase(): void {
  if (instance) {
    instance.stop();
  }
  instance = null;
}
