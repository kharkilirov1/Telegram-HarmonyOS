// G4: "Delete and Exit" for a member removed from a group. Leaving may already have happened, so the
// leave failure is tolerated and the chat deletion is the goal; afterwards the screen closes.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createLeaveChatUseCase } from '../../../domain/usecases/chatMembership';
import { createDeleteChatHistoryUseCase } from '../../../domain/usecases/deleteChatHistory';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';

const DOMAIN = 0x0044;
const TAG = 'ChatExit';

export function deleteAndExitChat(chatId: number, onExited: () => void): void {
  if (!Number.isSafeInteger(chatId) || chatId === 0) {
    return;
  }
  try {
    const leave = createLeaveChatUseCase(getTdGatewayAdapter());
    const remove = createDeleteChatHistoryUseCase(getTdGatewayAdapter());
    leave.leave(chatId)
      .catch((): void => {})
      .then((): Promise<void> => remove.execute(chatId, true, true))
      .then((): void => {
        onExited();
      })
      .catch((error: Error): void => {
        hilog.warn(DOMAIN, TAG, 'Delete and Exit failed: %{public}s', error.message);
      });
  } catch (error) {
    hilog.error(DOMAIN, TAG, 'Delete and Exit init failed: %{public}s', String(error));
  }
}
