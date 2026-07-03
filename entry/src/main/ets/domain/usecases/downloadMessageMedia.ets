// DownloadMessageMedia use case — triggers TDLib downloadFile for message media
//
// Subscribes to store changes. When a message has a fileId > 0 but empty path,
// enqueues a bounded background download. Priority: thumbnails first (10),
// selective small-media second (5). Full-size photo/video/document/audio stay on-demand.
// TDLib responds with updateFile → FileNormalizer → FileDownloadedEvent → filesReducer.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { navigationUIState } from '../../core/model/UIStateModels';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { AppState, Message, MessageContent } from '../../core/model/AppState';
import { createDownloadFileCommand } from '../../core/model/AppCommand';
import { FileDownloadedEvent } from '../../core/model/AppEvent';
import { TdObject } from '../../models/td/common/index';

const TAG = 'DownloadMedia';
const DOMAIN = 0x0009;
const THUMB_PRIORITY = 10;  // Thumbnails load first
const MEDIA_PRIORITY = 5;   // Full media after thumbnails

export class DownloadMessageMediaUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private pendingFileIds: Set<number> = new Set<number>();
  private unsubscribe: (() => void) | null = null;
  private scanScheduled: boolean = false;
  private scanTimerId: number = -1;
  private isRunning: boolean = false;
  private lifecycleToken: number = 0;
  private static readonly SCAN_THROTTLE_MS = 600;
  private static readonly MAX_ENQUEUES_PER_SCAN = 4;

  private activeChatIdProvider: () => number;

  constructor(store: AppStore, gateway: TdGatewayPort, activeChatIdProvider: (() => number) | null = null) {
    this.store = store;
    this.gateway = gateway;
    this.activeChatIdProvider = activeChatIdProvider ?? ((): number => navigationUIState.activeChatId);
  }

  start(): void {
    if (this.isRunning) return;
    this.isRunning = true;
    this.lifecycleToken++;

    hilog.info(DOMAIN, TAG, 'Starting message media download watcher');

    // Defer the initial scan so cold-start routing/first-frame work wins the main thread.
    this.scheduleScan(DownloadMessageMediaUseCase.SCAN_THROTTLE_MS);

    // Subscribe for future changes
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
      if (newState.messages !== prevState.messages) {
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

  private scheduleScan(delayMs: number = DownloadMessageMediaUseCase.SCAN_THROTTLE_MS): void {
    if (!this.isRunning || this.scanScheduled) {
      return;
    }
    this.scanScheduled = true;
    const token = this.lifecycleToken;
    this.scanTimerId = setTimeout(() => {
      this.scanTimerId = -1;
      this.scanScheduled = false;
      if (!this.isCurrentRun(token)) {
        return;
      }
      this.scanAndDownload(this.store.getState());
    }, delayMs) as number;
  }

  private scanAndDownload(state: AppState): void {
    if (!this.isRunning) {
      return;
    }
    let enqueued = 0;
    let remainingBudget = DownloadMessageMediaUseCase.MAX_ENQUEUES_PER_SCAN;

    // Активный чат сканируется первым: иначе видимые тумбы голодают позади
    // сотен сообщений других чатов при бюджете MAX_ENQUEUES_PER_SCAN за проход.
    const activeChatId = this.activeChatIdProvider();
    const activeMessages = activeChatId !== 0 ? state.messages.messages.get(activeChatId) : undefined;
    if (activeMessages) {
      activeMessages.forEach((message: Message) => {
        if (remainingBudget <= 0) {
          return;
        }
        const added = this.scanContent(message.content, remainingBudget);
        enqueued += added;
        remainingBudget -= added;
      });
    }

    state.messages.messages.forEach((chatMessages: Map<string, Message>, chatId: number) => {
      if (chatId === activeChatId) {
        return;
      }
      chatMessages.forEach((message: Message) => {
        if (remainingBudget <= 0) {
          return;
        }
        const added = this.scanContent(message.content, remainingBudget);
        enqueued += added;
        remainingBudget -= added;
      });
    });

    if (enqueued > 0) {
      hilog.info(DOMAIN, TAG, 'Enqueued %{public}d media downloads', enqueued);
    }
    if (remainingBudget <= 0) {
      this.scheduleScan(DownloadMessageMediaUseCase.SCAN_THROTTLE_MS);
    }
  }

  private scanContent(content: MessageContent, budget: number): number {
    let count = 0;

    // Photo — thumbnail only. Full photo is resolved by explicit tap/gallery download state.
    count += this.scanFileSlot(content.photoThumbFileId, content.photoThumbPath, THUMB_PRIORITY, budget - count);

    // Video — download thumbnail only (full video on demand)
    count += this.scanFileSlot(content.videoThumbFileId, content.videoThumbPath, THUMB_PRIORITY, budget - count);

    // Sticker — auto-download (small files)
    count += this.scanFileSlot(content.stickerFileId, content.stickerPath, MEDIA_PRIORITY, budget - count);

    // Voice — auto-download (small files, Telegram iOS/Android always auto-download voice)
    count += this.scanFileSlot(content.voiceFileId, content.voicePath, MEDIA_PRIORITY, budget - count);

    // Animation (GIF) — auto-download (Telegram auto-downloads GIFs)
    count += this.scanFileSlot(content.animationFileId, content.animationPath, MEDIA_PRIORITY, budget - count);

    // Video note (circles) — auto-download (small, Telegram always auto-downloads)
    count += this.scanFileSlot(content.videoNoteFileId, content.videoNotePath, MEDIA_PRIORITY, budget - count);

    // Document / Audio / full Photo / full Video stay on-demand — user taps to download.

    return count;
  }

  /**
   * Check a single fileId/path slot. If path resolved — clean up pendingFileIds.
   * If path still empty — enqueue download. Returns 1 if enqueued, 0 otherwise.
   */
  private scanFileSlot(fileId: number, path: string, priority: number, budget: number): number {
    if (fileId <= 0) return 0;
    if (path.length > 0) {
      // File already downloaded — remove from pending if it was tracked
      this.pendingFileIds.delete(fileId);
      return 0;
    }
    if (budget <= 0) return 0;
    return this.enqueueDownload(fileId, priority) ? 1 : 0;
  }

  private enqueueDownload(fileId: number, priority: number): boolean {
    if (!this.isRunning) return false;
    if (this.pendingFileIds.has(fileId)) return false;
    this.pendingFileIds.add(fileId);

    const command = createDownloadFileCommand(fileId, priority, false);
    const store = this.store;
    const token = this.lifecycleToken;

    this.gateway.send(command)
      .then((response: Object): void => {
        if (!this.isCurrentRun(token)) {
          return;
        }
        try {
          const tdResponse = response as TdObject;
          const local = tdResponse.getObject('local');
          const isComplete = local.getBool('is_downloading_completed');
          const path = local.getString('path');

          if (isComplete && path.length > 0) {
            hilog.info(DOMAIN, TAG, 'File %{public}d ready: %{public}s', fileId, path);
            this.pendingFileIds.delete(fileId);
            const event = new FileDownloadedEvent();
            event.fileId = fileId;
            event.localPath = path;
            event.isComplete = true;
            event.timestamp = Date.now();
            store.dispatch(event);
          }
          // If not complete yet, TDLib will send updateFile callbacks → FileNormalizer handles progress.
          // pendingFileIds stays set to prevent duplicate enqueue; syncResolvedPendingDownloads cleans up.
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'Parse error fileId=%{public}d: %{public}s', fileId, String(e));
          this.pendingFileIds.delete(fileId);
        }
      })
      .catch((error: Error): void => {
        if (!this.isCurrentRun(token)) {
          return;
        }
        hilog.warn(DOMAIN, TAG, 'Download failed fileId=%{public}d: %{public}s', fileId, error.message);
        this.pendingFileIds.delete(fileId);
      });
    return true;
  }
}

// Singleton
let instance: DownloadMessageMediaUseCase | null = null;

export function createDownloadMessageMediaUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): DownloadMessageMediaUseCase {
  if (!instance) {
    instance = new DownloadMessageMediaUseCase(store, gateway);
  }
  return instance;
}

export function resetDownloadMessageMediaUseCase(): void {
  if (instance) {
    instance.stop();
  }
  instance = null;
}
