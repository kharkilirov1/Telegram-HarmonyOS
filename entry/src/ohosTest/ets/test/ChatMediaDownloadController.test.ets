import { describe, it, expect, ArgumentMatchers, MockKit, when } from '@ohos/hypium';
import { AnyAppCommand, DownloadFileCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent, FileDownloadedEvent } from '../../../main/ets/core/model/AppEvent';
import { getAppCoreRuntime } from '../../../main/ets/app/bootstrap/AppCoreRuntime';
import { getTdGatewayAdapter } from '../../../main/ets/infra/td/adapter/TdGatewayAdapter';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { ChatMediaDownloadController } from '../../../main/ets/ui/pages/chat/ChatMediaDownloadController';
import { ChatTimelineEntryVO } from '../../../main/ets/ui/pages/chat/ChatTimelineVO';

class DeferredDownloadResponse {
  promise: Promise<Object>;
  private resolveResponse?: (value: Object) => void;
  private rejectResponse?: (error: Error) => void;

  constructor() {
    this.promise = new Promise<Object>((resolve: (value: Object) => void, reject: (error: Error) => void): void => {
      this.resolveResponse = resolve;
      this.rejectResponse = reject;
    });
  }

  resolve(value: Object): void {
    if (this.resolveResponse) this.resolveResponse(value);
  }

  reject(message: string): void {
    if (this.rejectResponse) this.rejectResponse(new Error(message));
  }
}

// Only the external send/dispatch boundaries are mocked. Never initialize TDLib,
// and restore both singleton methods after every case (including assertions).
class DownloadFixture {
  controller: ChatMediaDownloadController = new ChatMediaDownloadController();
  commands: AnyAppCommand[] = [];
  responses: DeferredDownloadResponse[] = [];
  events: AnyAppEvent[] = [];
  changes: number[] = [];
  private mocker: MockKit = new MockKit();
  private gateway = getTdGatewayAdapter();
  private store = getAppCoreRuntime().getStore();

  constructor() {
    const send = this.mocker.mockFunc(this.gateway, this.gateway.send);
    when(send)(ArgumentMatchers.any).afterAction((command: AnyAppCommand): Promise<Object> => {
      const response = new DeferredDownloadResponse();
      this.commands.push(command);
      this.responses.push(response);
      return response.promise;
    });
    const dispatch = this.mocker.mockFunc(this.store, this.store.dispatch);
    when(dispatch)(ArgumentMatchers.any).afterAction((event: AnyAppEvent): Promise<void> => {
      this.events.push(event);
      return Promise.resolve();
    });
    this.controller.setChangeListener((version: number, _fileId: number): void => {
      this.changes.push(version);
    });
  }

  restore(): void {
    this.controller.setChangeListener();
    this.controller.clearPendingDownloads();
    this.mocker.ignoreMock(this.gateway, 'send');
    this.mocker.ignoreMock(this.store, 'dispatch');
  }
}

function fileResponse(path: string, complete: boolean = true): TdObject {
  return TdObject.fromJSON('{"@type":"file","id":77,"local":{"@type":"localFile",' +
    '"is_downloading_completed":' + complete + ',"path":"' + path + '"}}');
}

function resolvedEntry(fileId: number): ChatTimelineEntryVO {
  const entry = new ChatTimelineEntryVO();
  entry.kind = 'message';
  entry.message.audioFileId = fileId;
  entry.message.audioPath = '/data/test/resolved.mp3';
  return entry;
}

// Drain then/catch continuations, not wall-clock sleeps or a live receive loop.
async function settleResponses(): Promise<void> {
  await Promise.resolve();
  await Promise.resolve();
  await Promise.resolve();
}

function expectPending(controller: ChatMediaDownloadController, fileId: number): void {
  const status = controller.getDownloadStatus(fileId);
  expect(status.isPending).assertTrue();
  expect(status.isFailed).assertFalse();
  expect(status.errorMessage).assertEqual('');
}

// Hypium may skip afterEach when a test throws. Own cleanup in the test itself.
function downloadTest(name: string, run: (fixture: DownloadFixture) => Promise<void>): void {
  it(name, 0, async (): Promise<void> => {
    const fixture = new DownloadFixture();
    try {
      await run(fixture);
    } finally {
      fixture.restore();
    }
  });
}

export default function chatMediaDownloadControllerTest() {
  describe('ChatMediaDownloadController attempt isolation', () => {
    // A removed attempt must never regain ownership when B uses the same fileId,
    // even when the caller's primitive lifecycleToken did not change.
    for (const invalidation of ['cancel', 'clear', 'failure', 'resolved']) {
      for (const outcome of ['failure', 'success']) {
        downloadTest(invalidation + '_retry_ignores_late_' + outcome, async (fixture: DownloadFixture) => {
          const controller = fixture.controller;
          controller.requestMediaDownload(77, 1);
          const oldResponse = fixture.responses[0];
          if (invalidation === 'cancel') {
            controller.cancelMediaDownload(77);
            fixture.responses[1].resolve(TdObject.empty());
          } else if (invalidation === 'clear') {
            controller.clearPendingDownloads();
          } else if (invalidation === 'failure') {
            controller.recordDownloadFailure(77, 'interrupted');
          } else {
            controller.syncResolvedDownloads([resolvedEntry(77)]);
          }
          controller.requestMediaDownload(77, 1);
          const currentResponse = fixture.responses[fixture.responses.length - 1];
          const version = controller.getVersion();
          const changes = fixture.changes.length;
          const events = fixture.events.length;
          if (outcome === 'failure') oldResponse.reject('old-request-failed');
          else oldResponse.resolve(fileResponse('/data/test/old.mp3'));
          await settleResponses();

          expectPending(controller, 77);
          expect(controller.getVersion()).assertEqual(version);
          expect(fixture.changes.length).assertEqual(changes);
          expect(fixture.events.length).assertEqual(events);

          currentResponse.resolve(fileResponse('/data/test/current.mp3'));
          await settleResponses();
          expect(controller.isDownloadPending(77)).assertFalse();
          expect(controller.isDownloadFailed(77)).assertFalse();
          expect(fixture.events.length).assertEqual(events + 1);
          const completed = fixture.events[events] as FileDownloadedEvent;
          expect(completed.fileId).assertEqual(77);
          expect(completed.localPath).assertEqual('/data/test/current.mp3');
          expect(completed.isComplete).assertTrue();
        });
      }
    }

    downloadTest('clear_invalidates_all_files_across_a_new_lifecycle', async (fixture: DownloadFixture) => {
      const controller = fixture.controller;
      controller.requestMediaDownload(77, 1);
      controller.requestMediaDownload(88, 1);
      controller.clearPendingDownloads();
      controller.requestMediaDownload(77, 2);
      controller.requestMediaDownload(88, 2);
      const version = controller.getVersion();
      fixture.responses[0].reject('previous-page');
      fixture.responses[1].resolve(fileResponse('/data/test/old.mp3'));
      await settleResponses();
      expectPending(controller, 77);
      expectPending(controller, 88);
      expect(controller.getVersion()).assertEqual(version);
      expect(fixture.events.length).assertEqual(0);
    });

    downloadTest('cancel_without_retry_ignores_late_completion', async (fixture: DownloadFixture) => {
      const controller = fixture.controller;
      controller.requestMediaDownload(77, 1);
      controller.cancelMediaDownload(77);
      const version = controller.getVersion();
      fixture.responses[0].resolve(fileResponse('/data/test/old.mp3'));
      fixture.responses[1].reject('cancel-command-failed');
      await settleResponses();
      expect(controller.isDownloadPending(77)).assertFalse();
      expect(controller.isDownloadFailed(77)).assertFalse();
      expect(controller.getVersion()).assertEqual(version);
      expect(fixture.events.length).assertEqual(1);
      expect(fixture.events[0].type).assertEqual('fileTransferUpdated');
    });

    downloadTest('late_cancel_command_failure_does_not_poison_retry', async (fixture: DownloadFixture) => {
      const controller = fixture.controller;
      controller.requestMediaDownload(77, 1);
      controller.cancelMediaDownload(77);
      controller.requestMediaDownload(77, 1);
      const version = controller.getVersion();
      fixture.responses[1].reject('cancel-command-failed');
      await settleResponses();
      expectPending(controller, 77);
      expect(controller.getVersion()).assertEqual(version);
    });

    downloadTest('duplicate_request_keeps_the_original_attempt_and_command', async (fixture: DownloadFixture) => {
      const controller = fixture.controller;
      controller.requestMediaDownload(77, 1);
      const version = controller.getVersion();
      controller.requestMediaDownload(77, 1);
      expect(fixture.commands.length).assertEqual(1);
      const command = fixture.commands[0] as DownloadFileCommand;
      expect(command.type).assertEqual('downloadFile');
      expect(command.payload.fileId).assertEqual(77);
      expect(command.payload.priority).assertEqual(5);
      expect(command.payload.synchronous).assertFalse();
      expect(controller.getVersion()).assertEqual(version);
      fixture.responses[0].resolve(fileResponse('/data/test/current.mp3'));
      await settleResponses();
      expect(controller.isDownloadPending(77)).assertFalse();
      expect(fixture.events.length).assertEqual(1);
      expect(controller.getVersion()).assertEqual(version + 1);
    });

    for (const retry of [false, true]) {
      for (const hadFailure of [false, true]) {
        downloadTest('listener_cancel_before_send_retry_' + retry + '_failed_' + hadFailure, async (fixture: DownloadFixture) => {
          const controller = fixture.controller;
          if (hadFailure) controller.recordDownloadFailure(77, 'previous failure');
          let cancelled = false;
          controller.setChangeListener((_version: number, fileId: number): void => {
            if (fileId !== 77 || cancelled) return;
            cancelled = true;
            controller.cancelMediaDownload(77);
            if (retry) controller.requestMediaDownload(77, 1);
          });
          controller.requestMediaDownload(77, 1);

          expect(cancelled).assertTrue();
          expect(fixture.commands.length).assertEqual(retry ? 2 : 1);
          expect(fixture.commands[0].type).assertEqual('cancelDownloadFile');
          fixture.responses[0].resolve(TdObject.empty());
          if (retry) {
            expect(fixture.commands[1].type).assertEqual('downloadFile');
            expectPending(controller, 77);
            fixture.responses[1].resolve(fileResponse('/data/test/reentrant.mp3'));
          }
          await settleResponses();
          expect(controller.isDownloadPending(77)).assertFalse();
          expect(controller.isDownloadFailed(77)).assertFalse();
          expect(fixture.events.length).assertEqual(retry ? 2 : 1);
          expect(controller.getVersion()).assertEqual((retry ? 4 : 2) + (hadFailure ? 1 : 0));
        });
      }
    }

    downloadTest('another_file_request_does_not_invalidate_the_first_attempt', async (fixture: DownloadFixture) => {
      const controller = fixture.controller;
      controller.requestMediaDownload(77, 1);
      controller.requestMediaDownload(88, 1);
      fixture.responses[0].resolve(fileResponse('/data/test/current.mp3'));
      await settleResponses();
      expect(controller.isDownloadPending(77)).assertFalse();
      expectPending(controller, 88);
      expect(fixture.events.length).assertEqual(1);
      expect((fixture.events[0] as FileDownloadedEvent).fileId).assertEqual(77);
    });

    downloadTest('current_failure_is_visible_and_retry_clears_it', async (fixture: DownloadFixture) => {
      const controller = fixture.controller;
      controller.requestMediaDownload(77, 1);
      fixture.responses[0].reject(' network failed ');
      await settleResponses();
      expect(controller.isDownloadPending(77)).assertFalse();
      expect(controller.isDownloadFailed(77)).assertTrue();
      expect(controller.getDownloadFailureMessage(77)).assertEqual('network failed');
      controller.requestMediaDownload(77, 1);
      expectPending(controller, 77);
      fixture.responses[1].resolve(fileResponse('/data/test/retry.mp3'));
      await settleResponses();
      expect(controller.isDownloadPending(77)).assertFalse();
      expect(controller.isDownloadFailed(77)).assertFalse();
      expect(fixture.events.length).assertEqual(1);
    });

    downloadTest('malformed_current_response_fails_but_stale_response_is_ignored', async (fixture: DownloadFixture) => {
      const controller = fixture.controller;
      controller.requestMediaDownload(77, 1);
      controller.clearPendingDownloads();
      controller.requestMediaDownload(77, 1);
      fixture.responses[0].resolve(new Object());
      await settleResponses();
      expectPending(controller, 77);
      fixture.responses[1].resolve(new Object());
      await settleResponses();
      expect(controller.isDownloadPending(77)).assertFalse();
      expect(controller.isDownloadFailed(77)).assertTrue();
      expect(controller.getDownloadFailureMessage(77).startsWith('Invalid download response:')).assertTrue();
      expect(fixture.events.length).assertEqual(0);
    });

    downloadTest('incomplete_or_pathless_response_stays_pending_until_timeline_resolution', async (fixture: DownloadFixture) => {
      const controller = fixture.controller;
      controller.requestMediaDownload(77, 1);
      controller.requestMediaDownload(88, 1);
      fixture.responses[0].resolve(fileResponse('/data/test/partial.mp3', false));
      fixture.responses[1].resolve(fileResponse(''));
      await settleResponses();
      expectPending(controller, 77);
      expectPending(controller, 88);
      expect(fixture.events.length).assertEqual(0);
      controller.syncResolvedDownloads([resolvedEntry(77)]);
      expect(controller.isDownloadPending(77)).assertFalse();
      expectPending(controller, 88);
    });

    downloadTest('clear_removes_failure_and_empty_clear_does_not_notify', async (fixture: DownloadFixture) => {
      const controller = fixture.controller;
      controller.recordDownloadFailure(77, 'failed');
      controller.clearPendingDownloads();
      const version = controller.getVersion();
      controller.clearPendingDownloads();
      expect(controller.getVersion()).assertEqual(version);
      expect(controller.isDownloadFailed(77)).assertFalse();
      expect(controller.getDownloadFailureMessage(77)).assertEqual('');
      controller.requestMediaDownload(77, 1);
      expectPending(controller, 77);
    });

    downloadTest('cancel_listener_retry_is_sent_after_cancel_command', async (fixture: DownloadFixture) => {
      const controller = fixture.controller;
      controller.requestMediaDownload(77, 1);
      let once = false;
      controller.setChangeListener((): void => {
        if (once) return;
        once = true;
        controller.requestMediaDownload(77, 1);
      });
      controller.cancelMediaDownload(77);
      expect(fixture.commands.length).assertEqual(3);
      expect(fixture.commands[1].type).assertEqual('cancelDownloadFile');
      expect(fixture.commands[2].type).assertEqual('downloadFile');
      expectPending(controller, 77);
    });

    downloadTest('success_cleanup_preserves_a_new_failure_from_listener', async (fixture: DownloadFixture) => {
      const controller = fixture.controller;
      controller.requestMediaDownload(77, 1);
      let once = false;
      controller.setChangeListener((): void => {
        if (once) return;
        once = true;
        controller.requestMediaDownload(77, 1);
        controller.recordDownloadFailure(77, 'new-attempt-failed');
      });
      fixture.responses[0].resolve(fileResponse('/data/test/old.mp3'));
      await settleResponses();
      expect(controller.isDownloadFailed(77)).assertTrue();
      expect(controller.getDownloadFailureMessage(77)).assertEqual('new-attempt-failed');
    });

    downloadTest('invalid_file_ids_do_not_send_or_notify', async (fixture: DownloadFixture) => {
      const controller = fixture.controller;
      for (const fileId of [0, -1]) {
        controller.requestMediaDownload(fileId, 1);
        controller.cancelMediaDownload(fileId);
        controller.recordDownloadFailure(fileId, 'ignored');
        expect(controller.isDownloadPending(fileId)).assertFalse();
        expect(controller.isDownloadFailed(fileId)).assertFalse();
      }
      expect(fixture.commands.length).assertEqual(0);
      expect(fixture.events.length).assertEqual(0);
      expect(controller.getVersion()).assertEqual(0);
    });
  });
}
