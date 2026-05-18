import { describe, it, expect } from '@ohos/hypium';
import { TdObject } from '../../../main/ets/core/utils/tdAccessors';
import { EventNormalizerImpl } from '../../../main/ets/core/events/EventNormalizer';
import { filesReducer } from '../../../main/ets/core/reducers/filesReducer';
import {
  AppState,
  Chat,
  Message,
  User,
  createInitialAppState
} from '../../../main/ets/core/model/AppState';
import {
  FileDownloadedEvent,
  FileTransferUpdatedEvent
} from '../../../main/ets/core/model/AppEvent';
import { createCancelDownloadFileCommand, createDownloadFileCommand } from '../../../main/ets/core/model/AppCommand';
import { ChatMediaDownloadController } from '../../../main/ets/ui/pages/chat/ChatMediaDownloadController';
import { ChatTimelineEntryVO } from '../../../main/ets/ui/pages/chat/ChatTimelineVO';

/**
 * Unit tests for the current file update/download pipeline.
 * Legacy FileController private LRU behavior remains a separate de-scope/follow-up.
 */
export default function filePipelineTest() {
  describe('FilePipeline', () => {

    describe('updateFile normalization', () => {
      it('should emit transfer progress for active downloads', 0, () => {
        const update = TdObject.fromJSON(
          '{"@type":"updateFile","file":{"@type":"file","id":42,"size":100,"expected_size":120,' +
            '"local":{"@type":"localFile","path":"","is_downloading_active":true,' +
            '"is_downloading_completed":false,"download_offset":10,' +
            '"downloaded_prefix_size":20,"downloaded_size":30}}}'
        );

        const events = new EventNormalizerImpl().normalize(update);
        expect(events.length).assertEqual(1);
        expect(events[0].type).assertEqual('fileTransferUpdated');

        const transfer = events[0] as FileTransferUpdatedEvent;
        expect(transfer.fileId).assertEqual(42);
        expect(transfer.localPath).assertEqual('');
        expect(transfer.isDownloadingActive).assertTrue();
        expect(transfer.isComplete).assertFalse();
        expect(transfer.size).assertEqual(100);
        expect(transfer.expectedSize).assertEqual(120);
        expect(transfer.downloadOffset).assertEqual(10);
        expect(transfer.downloadedPrefixSize).assertEqual(20);
        expect(transfer.downloadedSize).assertEqual(30);
      });

      it('should emit download completion when local path is available', 0, () => {
        const update = TdObject.fromJSON(
          '{"@type":"updateFile","file":{"@type":"file","id":77,"size":2048,' +
            '"local":{"@type":"localFile","path":"/data/files/video.mp4",' +
            '"is_downloading_active":false,"is_downloading_completed":true,' +
            '"download_offset":0,"downloaded_prefix_size":2048,"downloaded_size":2048}}}'
        );

        const events = new EventNormalizerImpl().normalize(update);
        expect(events.length).assertEqual(2);
        expect(events[0].type).assertEqual('fileTransferUpdated');
        expect(events[1].type).assertEqual('fileDownloaded');

        const downloaded = events[1] as FileDownloadedEvent;
        expect(downloaded.fileId).assertEqual(77);
        expect(downloaded.localPath).assertEqual('/data/files/video.mp4');
        expect(downloaded.isComplete).assertTrue();
      });
    });

    describe('filesReducer', () => {
      it('should store transfer progress and ignore identical updates', 0, () => {
        const state = createInitialAppState();
        const event = new FileTransferUpdatedEvent();
        event.fileId = 10;
        event.localPath = '';
        event.isDownloadingActive = true;
        event.isComplete = false;
        event.size = 500;
        event.expectedSize = 1000;
        event.downloadOffset = 100;
        event.downloadedPrefixSize = 200;
        event.downloadedSize = 300;

        const updated = filesReducer(state, event);
        expect(updated === state).assertFalse();
        expect(updated.version).assertEqual(state.version + 1);

        const transfer = updated.files.transfers.get(10);
        expect(transfer !== undefined).assertTrue();
        if (transfer !== undefined) {
          expect(transfer.fileId).assertEqual(10);
          expect(transfer.isDownloadingActive).assertTrue();
          expect(transfer.isDownloadingCompleted).assertFalse();
          expect(transfer.downloadedSize).assertEqual(300);
        }

        const unchanged = filesReducer(updated, event);
        expect(unchanged === updated).assertTrue();
      });

      it('should apply completed local paths to users, chats, messages, and transfer state', 0, () => {
        const state = createInitialAppState();

        const user = new User();
        user.id = 1;
        user.photoSmallFileId = 77;
        state.users.users.set(1, user);

        const chat = new Chat();
        chat.id = 100;
        chat.photoSmallFileId = 77;
        state.chats.chats.set(100, chat);

        const message = new Message();
        message.id = '900';
        message.chatId = 100;
        message.content.photoFileId = 77;
        const chatMessages = new Map<string, Message>();
        chatMessages.set(message.id, message);
        state.messages.messages.set(100, chatMessages);

        const event = new FileDownloadedEvent();
        event.fileId = 77;
        event.localPath = '/data/files/photo.jpg';
        event.isComplete = true;

        const updated = filesReducer(state, event);
        expect(updated === state).assertFalse();
        expect(updated.users.users.get(1)!.photoSmall).assertEqual('/data/files/photo.jpg');
        expect(updated.chats.chats.get(100)!.photoSmall).assertEqual('/data/files/photo.jpg');
        expect(updated.messages.messages.get(100)!.get('900')!.content.photoPath).assertEqual('/data/files/photo.jpg');
        expect(updated.files.transfers.get(77)!.isDownloadingCompleted).assertTrue();
        expect(updated.files.transfers.get(77)!.isDownloadingActive).assertFalse();
      });

      it('should not clone state when completed file has no matching owner', 0, () => {
        const state: AppState = createInitialAppState();
        const event = new FileDownloadedEvent();
        event.fileId = 404;
        event.localPath = '/data/files/missing.bin';
        event.isComplete = true;

        const updated = filesReducer(state, event);
        expect(updated === state).assertTrue();
      });
    });

    describe('downloadFile command', () => {
      it('should create command payload for current download requests', 0, () => {
        const command = createDownloadFileCommand(77, 32, true);
        expect(command.type).assertEqual('downloadFile');
        expect(command.payload.fileId).assertEqual(77);
        expect(command.payload.priority).assertEqual(32);
        expect(command.payload.synchronous).assertTrue();
      });

      it('should create command payload for current download cancellations', 0, () => {
        const command = createCancelDownloadFileCommand(77, false);
        expect(command.type).assertEqual('cancelDownloadFile');
        expect(command.payload.fileId).assertEqual(77);
        expect(command.payload.onlyIfPending).assertFalse();
      });
    });

    describe('ChatMediaDownloadController retry status', () => {
      it('should expose failed download status for retry-capable bubbles', 0, () => {
        const controller = new ChatMediaDownloadController();
        const initialVersion = controller.getVersion();

        controller.recordDownloadFailure(77, ' network failed ');

        expect(controller.getVersion()).assertEqual(initialVersion + 1);
        expect(controller.isDownloadPending(77)).assertFalse();
        expect(controller.isDownloadFailed(77)).assertTrue();
        expect(controller.getDownloadFailureMessage(77)).assertEqual('network failed');

        const status = controller.getDownloadStatus(77);
        expect(status.isPending).assertFalse();
        expect(status.isFailed).assertTrue();
        expect(status.errorMessage).assertEqual('network failed');
      });

      it('should clear failed status when the file is resolved in the timeline', 0, () => {
        const controller = new ChatMediaDownloadController();
        controller.recordDownloadFailure(88, 'failed');

        const entry = new ChatTimelineEntryVO();
        entry.kind = 'message';
        entry.message.audioFileId = 88;
        entry.message.audioPath = '/data/storage/song.mp3';

        controller.syncResolvedDownloads([entry]);

        expect(controller.isDownloadFailed(88)).assertFalse();
        expect(controller.getDownloadFailureMessage(88)).assertEqual('');
      });

      it('should clear failed photo and album download status when local media appears', 0, () => {
        const controller = new ChatMediaDownloadController();
        controller.recordDownloadFailure(101, 'photo failed');
        controller.recordDownloadFailure(202, 'album failed');

        const photoEntry = new ChatTimelineEntryVO();
        photoEntry.kind = 'message';
        photoEntry.message.photoFileId = 101;
        photoEntry.message.photoPath = 'file://photos/p1.jpg';
        photoEntry.message.hasLocalPhoto = true;

        const albumEntry = new ChatTimelineEntryVO();
        albumEntry.kind = 'message';
        albumEntry.message.albumPhotoFileIds = [202];
        albumEntry.message.albumPhotoPaths = ['file://photos/a1.jpg'];
        albumEntry.message.albumPhotoHasLocal = [true];

        controller.syncResolvedDownloads([photoEntry, albumEntry]);

        expect(controller.isDownloadFailed(101)).assertFalse();
        expect(controller.isDownloadFailed(202)).assertFalse();
      });

      it('should clear failed status on explicit pending reset', 0, () => {
        const controller = new ChatMediaDownloadController();
        controller.recordDownloadFailure(99, 'failed');

        controller.clearPendingDownloads();

        expect(controller.isDownloadFailed(99)).assertFalse();
        expect(controller.getDownloadStatus(99).isFailed).assertFalse();
      });
    });
  });
}
