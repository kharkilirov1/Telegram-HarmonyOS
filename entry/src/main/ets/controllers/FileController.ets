import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdObject, safeNumber, safeString, safeBool, asRecord } from '../models/TdTypes';

const TAG = 'FileController';
const DOMAIN = 0x0001;

export class FileController {
  private static instance: FileController | null = null;

  // LRU path cache: fileId -> local file path
  private pathCache: Map<number, string> = new Map();
  private cacheOrder: number[] = [];
  private maxCacheSize: number = 500;

  // Pending download callbacks
  private downloadCallbacks: Map<number, ((path: string) => void)[]> = new Map();

  private constructor() {
    this.subscribeToUpdates();
  }

  static getInstance(): FileController {
    if (!FileController.instance) {
      FileController.instance = new FileController();
    }
    return FileController.instance;
  }

  /**
   * Get cached file path. Returns null if not yet downloaded.
   */
  getFilePath(fileId: number): string | null {
    const path = this.pathCache.get(fileId);
    if (path) {
      this.touchLRU(fileId);
      return path;
    }
    return null;
  }

  /**
   * Request a file. Calls callback immediately if cached,
   * otherwise triggers download and calls callback when complete.
   * Priority: 1 (low) to 32 (high)
   */
  requestFile(fileId: number, priority: number, callback: (path: string) => void): void {
    // Check cache first
    const cached = this.pathCache.get(fileId);
    if (cached) {
      callback(cached);
      return;
    }

    // Queue callback; only send download request if this is the first request for this fileId
    const existing = this.downloadCallbacks.get(fileId);
    if (existing) {
      existing.push(callback);
      return;
    }
    this.downloadCallbacks.set(fileId, [callback]);

    // Request download from TDLib
    const downloadParams: TdObject = {};
    downloadParams['file_id'] = fileId;
    downloadParams['priority'] = priority;
    downloadParams['offset'] = 0;
    downloadParams['limit'] = 0;
    downloadParams['synchronous'] = false;
    TDLibClient.getInstance().send('downloadFile', downloadParams);
  }

  /**
   * Cancel a pending download
   */
  cancelDownload(fileId: number): void {
    this.downloadCallbacks.delete(fileId);
    const cancelParams: TdObject = {};
    cancelParams['file_id'] = fileId;
    cancelParams['only_if_pending'] = true;
    TDLibClient.getInstance().send('cancelDownloadFile', cancelParams);
  }

  private subscribeToUpdates(): void {
    TDLibClient.getInstance().on('updateFile', (update: TdObject) => {
      const file = asRecord(update['file']);
      if (!file) return;

      const fileId = safeNumber(file['id']);
      const local = asRecord(file['local']);
      if (!local) return;

      const isComplete = safeBool(local['is_downloading_completed']);
      const path = safeString(local['path']);

      if (isComplete && path && path.length > 0) {
        // Download finished — cache and notify
        this.addToCache(fileId, path);

        const callbacks = this.downloadCallbacks.get(fileId) || [];
        for (const cb of callbacks) {
          cb(path);
        }
        this.downloadCallbacks.delete(fileId);

        const completedArgs: TdObject = {};
        completedArgs['fileId'] = fileId;
        completedArgs['path'] = path;
        NotificationCenter.getInstance().post(
          EventId.FILE_DOWNLOAD_COMPLETED,
          completedArgs
        );
      } else if (!isComplete) {
        // Progress update
        const downloaded = safeNumber(local['downloaded_size']);
        const totalSize = safeNumber(file['expected_size']) || safeNumber(file['size']);

        const progressArgs: TdObject = {};
        progressArgs['fileId'] = fileId;
        progressArgs['downloaded'] = downloaded;
        progressArgs['total'] = totalSize;
        NotificationCenter.getInstance().post(
          EventId.FILE_DOWNLOAD_PROGRESS,
          progressArgs
        );
      }
    });
  }

  private addToCache(fileId: number, path: string): void {
    // Remove existing entry to avoid duplicates in cacheOrder
    const existingIdx = this.cacheOrder.indexOf(fileId);
    if (existingIdx >= 0) {
      this.cacheOrder.splice(existingIdx, 1);
    }
    // LRU eviction
    if (this.cacheOrder.length >= this.maxCacheSize) {
      const evictId = this.cacheOrder.shift()!;
      this.pathCache.delete(evictId);
    }
    this.pathCache.set(fileId, path);
    this.cacheOrder.push(fileId);
  }

  private touchLRU(fileId: number): void {
    const idx = this.cacheOrder.indexOf(fileId);
    if (idx >= 0) {
      this.cacheOrder.splice(idx, 1);
      this.cacheOrder.push(fileId);
    }
  }
}
