// DownloadMessageMediaUseCase — throttle/budget/priority coverage.
// Runtime baseline: hilog on emulator showed Enqueued 4→4→2 with ~600ms steps.

import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand, DownloadFileCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { AppState, Message, MessageContent, createInitialAppState } from '../../../main/ets/core/model/AppState';
import { AppStore } from '../../../main/ets/core/store/AppStore';
import appReducer from '../../../main/ets/core/reducers/index';
import { DownloadMessageMediaUseCase } from '../../../main/ets/domain/usecases/downloadMessageMedia';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { TdObject } from '../../../main/ets/models/TdTypes';

class FakeGateway implements TdGatewayPort {
  sentCommands: AnyAppCommand[] = [];
  // Optional port member: undefined by default (backward-compat case relies on it)
  isDrainCongested?: () => boolean = undefined;

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  send(command: AnyAppCommand): Promise<Object> {
    this.sentCommands.push(command);
    return Promise.resolve(new TdObject());
  }

  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void {
    return (): void => {};
  }

  getConnectionState(): 'connecting' | 'ready' | 'updating' | 'waitingForNetwork' {
    return 'ready';
  }

  destroy(): Promise<void> {
    return Promise.resolve();
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(resolve, ms);
  });
}

function photoMessage(thumbFileId: number): Message {
  const message = new Message();
  message.content = new MessageContent();
  message.content.photoThumbFileId = thumbFileId;
  return message;
}

function stateWithChats(chats: Map<number, number[]>): AppState {
  const state = createInitialAppState();
  chats.forEach((thumbIds: number[], chatId: number) => {
    const chatMessages = new Map<string, Message>();
    for (let i = 0; i < thumbIds.length; i++) {
      chatMessages.set(`${chatId}_${i}`, photoMessage(thumbIds[i]));
    }
    state.messages.messages.set(chatId, chatMessages);
  });
  return state;
}

function sentFileIds(gateway: FakeGateway): number[] {
  const ids: number[] = [];
  for (let i = 0; i < gateway.sentCommands.length; i++) {
    const cmd = gateway.sentCommands[i];
    if (cmd.type === 'downloadFile') {
      ids.push((cmd as DownloadFileCommand).payload.fileId);
    }
  }
  return ids;
}

export default function downloadMessageMediaTest() {
  describe('DownloadMessageMediaUseCase', () => {

    it('caps_enqueues_per_scan_and_continues_via_rescan_chain', 0, async () => {
      const chats = new Map<number, number[]>();
      chats.set(101, [1, 2, 3, 4, 5, 6]);
      const store = new AppStore(appReducer, stateWithChats(chats), false);
      const gateway = new FakeGateway();
      const useCase = new DownloadMessageMediaUseCase(store, gateway, (): number => 0);

      useCase.start();
      await sleep(750);
      expect(sentFileIds(gateway).length).assertEqual(4);

      await sleep(700);
      expect(sentFileIds(gateway).length).assertEqual(6);
      useCase.stop();
    });

    it('scans_active_chat_before_other_chats', 0, async () => {
      const chats = new Map<number, number[]>();
      chats.set(101, [1, 2, 3]);
      chats.set(202, [11, 12, 13]);
      const store = new AppStore(appReducer, stateWithChats(chats), false);
      const gateway = new FakeGateway();
      const useCase = new DownloadMessageMediaUseCase(store, gateway, (): number => 202);

      useCase.start();
      await sleep(750);

      const ids = sentFileIds(gateway);
      expect(ids.length).assertEqual(4);
      expect(ids[0]).assertEqual(11);
      expect(ids[1]).assertEqual(12);
      expect(ids[2]).assertEqual(13);
      useCase.stop();
    });

    it('stop_cancels_the_scheduled_scan', 0, async () => {
      const chats = new Map<number, number[]>();
      chats.set(101, [1]);
      const store = new AppStore(appReducer, stateWithChats(chats), false);
      const gateway = new FakeGateway();
      const useCase = new DownloadMessageMediaUseCase(store, gateway, (): number => 0);

      useCase.start();
      useCase.stop();
      await sleep(750);
      expect(sentFileIds(gateway).length).assertEqual(0);
    });

    it('dedupes_pending_file_ids_across_messages', 0, async () => {
      const chats = new Map<number, number[]>();
      chats.set(101, [7, 7, 7]);
      const store = new AppStore(appReducer, stateWithChats(chats), false);
      const gateway = new FakeGateway();
      const useCase = new DownloadMessageMediaUseCase(store, gateway, (): number => 0);

      useCase.start();
      await sleep(750);
      expect(sentFileIds(gateway).length).assertEqual(1);
      useCase.stop();
    });

    // P4-d anti-freeze: congested drain → scan deferred, no downloads sent
    it('defers_scan_when_drain_is_congested', 0, async () => {
      const chats = new Map<number, number[]>();
      chats.set(101, [1, 2, 3, 4, 5, 6]);
      const store = new AppStore(appReducer, stateWithChats(chats), false);
      const gateway = new FakeGateway();
      gateway.isDrainCongested = (): boolean => true;
      const useCase = new DownloadMessageMediaUseCase(store, gateway, (): number => 0);

      useCase.start();
      // SCAN_THROTTLE_MS=600 fires → congested → reschedule CONGESTED_RETRY_MS=1500
      await sleep(750);
      expect(sentFileIds(gateway).length).assertEqual(0);

      // After another ~800ms (total ~1550ms) the 1500ms retry hasn't fired yet
      await sleep(800);
      expect(sentFileIds(gateway).length).assertEqual(0);
      useCase.stop();
    });

    // Explicit isDrainCongested=false — scan proceeds normally
    it('scans_when_drain_is_explicitly_not_congested', 0, async () => {
      const chats = new Map<number, number[]>();
      chats.set(101, [1, 2, 3, 4, 5, 6]);
      const store = new AppStore(appReducer, stateWithChats(chats), false);
      const gateway = new FakeGateway();
      gateway.isDrainCongested = (): boolean => false;
      const useCase = new DownloadMessageMediaUseCase(store, gateway, (): number => 0);

      useCase.start();
      await sleep(750);
      expect(sentFileIds(gateway).length).assertEqual(4);

      await sleep(700);
      expect(sentFileIds(gateway).length).assertEqual(6);
      useCase.stop();
    });

    // Backward compat: undefined isDrainCongested → not congested → scan proceeds
    it('scans_when_isDrainCongested_is_undefined', 0, async () => {
      const chats = new Map<number, number[]>();
      chats.set(101, [1, 2, 3, 4, 5, 6]);
      const store = new AppStore(appReducer, stateWithChats(chats), false);
      const gateway = new FakeGateway();
      // isDrainCongested stays undefined (default FakeGateway)
      const useCase = new DownloadMessageMediaUseCase(store, gateway, (): number => 0);

      useCase.start();
      await sleep(750);
      expect(sentFileIds(gateway).length).assertEqual(4);

      await sleep(700);
      expect(sentFileIds(gateway).length).assertEqual(6);
      useCase.stop();
    });
  });
}
