import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { createInitialAppState } from '../../../main/ets/core/model/AppState';
import { appReducer } from '../../../main/ets/core/reducers/index';
import { AppStore } from '../../../main/ets/core/store/AppStore';
import { LoadActiveStoriesUseCase } from '../../../main/ets/domain/usecases/loadActiveStories';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { TdObject } from '../../../main/ets/models/TdTypes';

class FakeActiveStoriesGateway implements TdGatewayPort {
  sentCommands: AnyAppCommand[] = [];
  private responses: Object[] = [];
  private responseIndex: number = 0;

  constructor(responses: Object[]) {
    this.responses = responses;
  }

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  send(command: AnyAppCommand): Promise<Object> {
    this.sentCommands.push(command);
    if (this.responseIndex >= this.responses.length) {
      return Promise.resolve(TdObject.empty());
    }
    const response = this.responses[this.responseIndex];
    this.responseIndex += 1;
    return Promise.resolve(response);
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

export default function loadActiveStoriesTest() {
  describe('LoadActiveStories', () => {
    it('loads storyListMain and hydrates each missing poster chat once', 0, async () => {
      const store = new AppStore(appReducer, createInitialAppState(), false);
      const gateway = new FakeActiveStoriesGateway([
        TdObject.fromJSON('{"@type":"ok"}'),
        TdObject.fromJSON(
          '{"@type":"chat","id":42,"title":"Story peer",' +
          '"type":{"@type":"chatTypePrivate","user_id":7},"unread_count":0,' +
          '"last_read_outbox_message_id":"0","last_read_inbox_message_id":"0"}'
        )
      ]);
      const useCase = new LoadActiveStoriesUseCase(store, gateway);

      await useCase.execute();
      await useCase.hydrateChatsIfMissing([42, 42]);

      expect(gateway.sentCommands.length).assertEqual(2);
      expect(gateway.sentCommands[0].type).assertEqual('loadActiveStories');
      expect(gateway.sentCommands[1].type).assertEqual('getChat');
      expect(store.getState().chats.chats.has(42)).assertTrue();
    });
  });
}
