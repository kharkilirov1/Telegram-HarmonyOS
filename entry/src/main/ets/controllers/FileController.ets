import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { hilog } from '@kit.PerformanceAnalysisKit';

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

    // Queue callback
    const existing = this.downloadCallbacks.get(fileId) || [];
    existing.push(callback);
    this.downloadCallbacks.set(fileId, existing);

    // Request download from TDLib
    const downloadParams: Record<string, Object> = {
      file_id: fileId,
      priority: priority,
      offset: 0,
      limit: 0,
      synchronous: false
    };
    TDLibClient.getInstance().send('downloadFile', downloadParams);
  }

  /**
   * Cancel a pending download
   */
  cancelDownload(fileId: number): void {
    this.downloadCallbacks.delete(fileId);
    const cancelParams: Record<string, Object> = {
      file_id: fileId,
      only_if_pending: true
    };
    TDLibClient.getInstance().send('cancelDownloadFile', cancelParams);
  }

  private subscribeToUpdates(): void {
    TDLibClient.getInstance().on('updateFile', (update: Record<string, Object>) => {
      const file = update['file'] as Record<string, Object>;
      if (!file) return;

      const fileId = file['id'] as number;
      const local = file['local'] as Record<string, Object>;
      if (!local) return;

      const isComplete = local['is_downloading_completed'] as boolean;
      const path = local['path'] as string;

      if (isComplete && path && path.length > 0) {
        // Download finished — cache and notify
        this.addToCache(fileId, path);

        const callbacks = this.downloadCallbacks.get(fileId) || [];
        for (const cb of callbacks) {
          cb(path);
        }
        this.downloadCallbacks.delete(fileId);

        NotificationCenter.getInstance().post(
          EventId.FILE_DOWNLOAD_COMPLETED,
          { fileId: fileId, path: path } as Record<string, Object>
        );
      } else if (!isComplete) {
        // Progress update
        const downloaded = local['downloaded_size'] as number || 0;
        const totalSize = (file['expected_size'] as number) || (file['size'] as number) || 0;

        NotificationCenter.getInstance().post(
          EventId.FILE_DOWNLOAD_PROGRESS,
          {
            fileId: fileId,
            downloaded: downloaded,
            total: totalSize
          } as Record<string, Object>
        );
      }
    });
  }

  private addToCache(fileId: number, path: string): void {
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
