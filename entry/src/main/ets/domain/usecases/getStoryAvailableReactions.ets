// I6: the reaction row the story viewer shows. The TDLib answer shares the message reactions shape,
// so the parser is reused; a failure degrades to an empty row instead of breaking the viewer.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createGetStoryAvailableReactionsCommand } from '../../core/model/AppCommand';
import { MessageAvailableReactionsSnapshot, parseAvailableReactions } from '../../core/model/dto/MessageDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x00B6;
const TAG = 'GetStoryAvailableReactions';
const DEFAULT_ROW_SIZE = 6;

export class GetStoryAvailableReactionsUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async load(rowSize: number = DEFAULT_ROW_SIZE): Promise<MessageAvailableReactionsSnapshot> {
    const empty = new MessageAvailableReactionsSnapshot();
    try {
      const response = await this.gateway.send(
        createGetStoryAvailableReactionsCommand(rowSize)) as TdObject;
      return parseAvailableReactions(response);
    } catch (error) {
      hilog.info(DOMAIN, TAG, 'Available story reactions settled with an error: %{public}s', String(error));
      return empty;
    }
  }
}

export function createGetStoryAvailableReactionsUseCase(
  gateway: TdGatewayPort): GetStoryAvailableReactionsUseCase {
  return new GetStoryAvailableReactionsUseCase(gateway);
}
