// Storage statistics — Settings → Data and Storage (H4).
// TDLib: getStorageStatistics (td_api.tl:14426), getStorageStatisticsFast (:14429),
// optimizeStorage (:14444, used for "Clear cache").

import { hilog } from '@kit.PerformanceAnalysisKit';
import { TdObject } from '../../models/TdTypes';
import {
  OptimizeStoragePayload,
  createGetStorageStatisticsCommand,
  createGetStorageStatisticsFastCommand,
  createOptimizeStorageCommand
} from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import {
  FastStorageStatisticsDto,
  StorageStatisticsDto,
  createFastStorageStatisticsFromTd,
  createStorageStatisticsFromTd
} from '../../core/model/dto/StorageStatisticsDto';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0036;
const TAG = 'LoadStorageStatistics';
export const STORAGE_CHAT_LIMIT: number = 20;

export class StorageSnapshot {
  fast: FastStorageStatisticsDto = new FastStorageStatisticsDto();
  full: StorageStatisticsDto = new StorageStatisticsDto();
}

// The limit is only enforced when it is set (0 / -1 mean "no limit") and the usage genuinely exceeds it.
export function shouldAutoEnforce(limitBytes: number, usageBytes: number): boolean {
  if (!Number.isSafeInteger(limitBytes) || limitBytes <= 0) {
    return false;
  }
  if (!Number.isSafeInteger(usageBytes) || usageBytes < 0) {
    return false;
  }
  return usageBytes > limitBytes;
}

export class LoadStorageStatisticsUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async fetchSnapshot(chatLimit: number = STORAGE_CHAT_LIMIT): Promise<StorageSnapshot> {
    if (!Number.isSafeInteger(chatLimit) || chatLimit < 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatLimit', 'Input validation failed', 400, false);
    }
    const snapshot = new StorageSnapshot();
    try {
      const fastResponse = await this.gateway.send(createGetStorageStatisticsFastCommand()) as TdObject;
      snapshot.fast = createFastStorageStatisticsFromTd(fastResponse);
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'getStorageStatisticsFast failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load storage statistics', err.message, 0, true);
    }
    try {
      const fullResponse = await this.gateway.send(createGetStorageStatisticsCommand(chatLimit)) as TdObject;
      snapshot.full = createStorageStatisticsFromTd(fullResponse);
    } catch (error) {
      // Per-chat breakdown is optional: the totals above are still honest, so keep them.
      const err = error as Error;
      hilog.warn(DOMAIN, TAG, 'getStorageStatistics failed: %{public}s', err.message);
    }
    return snapshot;
  }

  // Enforces the user's "Maximum cache size" now: files above the limit are dropped, ttl/count keep
  // their TDLib defaults (-1). A non-positive limit means unlimited and sends nothing.
  // Called after a statistics load: enforces the persisted limit only when the cache really grew past it.
  async autoEnforce(limitBytes: number, usageBytes: number): Promise<boolean> {
    if (!shouldAutoEnforce(limitBytes, usageBytes)) {
      return false;
    }
    return this.enforceCacheLimit(limitBytes);
  }

  async enforceCacheLimit(limitBytes: number): Promise<boolean> {
    if (!Number.isSafeInteger(limitBytes) || limitBytes < 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid cache limit', 'Input validation failed', 400,
        false);
    }
    if (limitBytes === 0) {
      return false;
    }
    const payload = new OptimizeStoragePayload();
    payload.size = limitBytes;
    payload.ttl = -1;
    payload.count = -1;
    payload.immunityDelay = -1;
    try {
      hilog.info(DOMAIN, TAG, 'Enforcing cache limit %{public}d bytes', limitBytes);
      await this.gateway.send(createOptimizeStorageCommand(payload));
      return true;
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'optimizeStorage(limit) failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to apply the cache limit', err.message, 0, true);
    }
  }

  // "Clear cache": TDLib drops every cache file it may free; database and logs stay.
  async clearCache(): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Clearing storage cache');
      await this.gateway.send(createOptimizeStorageCommand());
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'optimizeStorage failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to clear the cache', err.message, 0, true);
    }
  }
}

export function createLoadStorageStatisticsUseCase(gateway: TdGatewayPort): LoadStorageStatisticsUseCase {
  return new LoadStorageStatisticsUseCase(gateway);
}
