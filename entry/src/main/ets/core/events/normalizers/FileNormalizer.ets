// FileNormalizer — handles file-related TDLib updates (updateFile)
// Converts updateFile into FileDownloadedEvent when download completes

import { AnyAppEvent, FileDownloadedEvent } from '../../model/AppEvent';
import { TdObject } from '../../../models/TdTypes';
import { tdGetString, tdGetBoolean, tdGetObject } from '../../utils/tdAccessors';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'FileNormalizer';

function handleUpdateFile(events: AnyAppEvent[], update: TdObject): void {
  const file = tdGetObject(update, 'file');
  // Use getTopLevelNumber to avoid nested remote.id (string) shadowing numeric file id
  const fileId = file.getTopLevelNumber('id');
  if (!fileId) return;

  const local = tdGetObject(file, 'local');
  const isComplete = tdGetBoolean(local, 'is_downloading_completed');
  const localPath = tdGetString(local, 'path');

  hilog.info(DOMAIN, TAG, 'updateFile fileId=%{public}d complete=%{public}s path=%{public}s',
    fileId, isComplete ? 'true' : 'false', localPath.length > 0 ? localPath : '(empty)');

  if (isComplete && localPath.length > 0) {
    const event = new FileDownloadedEvent();
    event.fileId = fileId;
    event.localPath = localPath;
    event.isComplete = true;
    event.timestamp = Date.now();
    events.push(event);
    hilog.info(DOMAIN, TAG, 'FileDownloadedEvent emitted for fileId=%{public}d', fileId);
  }
}

export function registerFileHandlers(
  handlers: Map<string, (events: AnyAppEvent[], update: TdObject) => void>
): void {
  handlers.set('updateFile', handleUpdateFile);
}
