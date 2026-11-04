// Recommended chat folders (B7 / S13i).
// TDLib: getRecommendedChatFolders (td_api.tl:12075); the result is a list of suggested folders that
// the user may add as normal folders (createChatFolder keeps the flags and included chats).

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createGetRecommendedChatFoldersCommand } from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import {
  RecommendedChatFolderDto,
  createRecommendedChatFoldersFromTd
} from '../../core/model/dto/RecommendedChatFolderDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x003e;
const TAG = 'RecommendedChatFolders';

export class LoadRecommendedChatFoldersUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async fetch(): Promise<RecommendedChatFolderDto[]> {
    try {
      const response = await this.gateway.send(createGetRecommendedChatFoldersCommand()) as TdObject;
      return createRecommendedChatFoldersFromTd(response).folders;
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'getRecommendedChatFolders failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load recommended folders', err.message, 0, true);
    }
  }
}

export function createLoadRecommendedChatFoldersUseCase(
  gateway: TdGatewayPort
): LoadRecommendedChatFoldersUseCase {
  return new LoadRecommendedChatFoldersUseCase(gateway);
}
