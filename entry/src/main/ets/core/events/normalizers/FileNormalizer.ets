// FileNormalizer — handles file-related TDLib updates (updateFile)
// Converts updateFile into FileDownloadedEvent when download completes

import { AnyAppEvent, FileDownloadedEvent, FileTransferUpdatedEvent } from '../../model/AppEvent';
import { TdObject } from '../../../models/TdTypes';
import { tdGetString, tdGetBoolean, tdGetObject } from '../../utils/tdAccessors';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'FileNormalizer';

function handleUpdateFile(events: AnyAppEvent[], update: TdObject): void {
  const file = tdGetObject(update, 'file');
  // Use getTopLevelNumber to avoid nested remote.id (string) shadowing numeric file id
  const fileId = file.getTopLevelNumber('id');
  if (fileId <= 0) return;

  const local = tdGetObject(file, 'local');
  const uniqueId = tdGetString(tdGetObject(file, 'remote'), 'unique_id');
  const size = file.getTopLevelNumber('size');
  const expectedSize = file.getTopLevelNumber('expected_size');
  const isComplete = tdGetBoolean(local, 'is_downloading_completed');
  const isDownloadingActive = tdGetBoolean(local, 'is_downloading_active');
  const localPath = tdGetString(local, 'path');
  const downloadOffset = local.getTopLevelNumber('download_offset');
  const downloadedPrefixSize = local.getTopLevelNumber('downloaded_prefix_size');
  const downloadedSize = local.getTopLevelNumber('downloaded_size');

  const transferEvent = new FileTransferUpdatedEvent();
  transferEvent.fileId = fileId;
  transferEvent.uniqueId = uniqueId;
  transferEvent.localPath = localPath;
  transferEvent.isComplete = isComplete;
  transferEvent.isDownloadingActive = isDownloadingActive;
  transferEvent.size = size;
  transferEvent.expectedSize = expectedSize;
  transferEvent.downloadOffset = downloadOffset;
  transferEvent.downloadedPrefixSize = downloadedPrefixSize;
  transferEvent.downloadedSize = downloadedSize;
  transferEvent.timestamp = Date.now();
  events.push(transferEvent);

  // debug, не info: updateFile прилетает сотнями при штормах — info-запись в hilog
  // блокирует main thread внутри HiLogPrint (см. freeze 2026-07-03 13:29)
  hilog.debug(DOMAIN, TAG,
    'updateFile fileId=%{public}d active=%{public}s complete=%{public}s progress=%{public}d/%{public}d path=%{public}s',
    fileId,
    isDownloadingActive ? 'true' : 'false',
    isComplete ? 'true' : 'false',
    downloadOffset + downloadedPrefixSize,
    Math.max(size, expectedSize),
    localPath.length > 0 ? localPath : '(empty)');

  if (isComplete && localPath.length > 0) {
    const event = new FileDownloadedEvent();
    event.fileId = fileId;
    event.uniqueId = uniqueId;
    event.localPath = localPath;
    event.isComplete = true;
    event.timestamp = Date.now();
    events.push(event);
    hilog.debug(DOMAIN, TAG, 'FileDownloadedEvent emitted for fileId=%{public}d', fileId);
  }
}

export function registerFileHandlers(
  handlers: Map<string, (events: AnyAppEvent[], update: TdObject) => void>
): void {
  handlers.set('updateFile', handleUpdateFile);
}
