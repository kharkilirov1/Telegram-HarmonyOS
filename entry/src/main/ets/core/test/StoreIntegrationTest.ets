// Store integration test - demonstrates store + reducers working together
// This is not a unit test, but a manual verification of the architecture

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../store/AppStore';
import { appReducer } from '../reducers/index';
import { createAuthStateChangedEvent, createNewMessageEvent } from '../model/AppEvent';
import { MessageDto, MessageContentDto, MessageContentType } from '../model/dto/MessageDto';

const TAG = 'StoreIntegrationTest';
const DOMAIN = 0x0005;

export class StoreIntegrationTest {
  private store: AppStore;

  constructor() {
    // Create store with app reducer
    this.store = new AppStore(appReducer);
  }

  async run(): Promise<boolean> {
    hilog.info(DOMAIN, TAG, 'Starting test...');

    try {
      // Test 1: Initial state
      const initialState = this.store.getState();
      hilog.info(DOMAIN, TAG, 'Initial auth state: %{public}s', initialState.auth.status);

      // Test 2: Subscribe to state changes
      let stateChangeCount = 0;
      const unsubscribe = this.store.subscribe((newState, prevState) => {
        stateChangeCount++;
        hilog.info(DOMAIN, TAG, 'State changed #%{public}d: prevAuth=%{public}s, newAuth=%{public}s, version=%{public}d',
          stateChangeCount, prevState.auth.status, newState.auth.status, newState.version);
      });

      // Test 3: Dispatch auth event
      hilog.info(DOMAIN, TAG, 'Dispatching authStateChanged event...');
      await this.store.dispatch(createAuthStateChangedEvent('waitPhoneNumber'));

      // Test 4: Verify state changed
      const afterAuthState = this.store.getState();
      if (afterAuthState.auth.status !== 'waitPhoneNumber') {
        throw new Error(`Expected auth status 'waitPhoneNumber', got '${afterAuthState.auth.status}'`);
      }

      // Test 5: Dispatch another event (serial queue test)
      hilog.info(DOMAIN, TAG, 'Dispatching newMessage event...');
      const messageDto = new MessageDto();
      messageDto.id = '67890';
      messageDto.chatId = 12345;
      const contentDto = new MessageContentDto();
      contentDto.type = MessageContentType.TEXT;
      contentDto.text = 'Hello';
      messageDto.content = contentDto;
      await this.store.dispatch(createNewMessageEvent(12345, '67890', messageDto));

      // Test 6: Verify messages state
      const afterMessageState = this.store.getState();
      const chatMessages = afterMessageState.messages.messages.get(12345);
      if (!chatMessages) {
        throw new Error('Expected messages for chat 12345');
      }

      // Test 7: Unsubscribe
      unsubscribe();

      // Test 8: Dispatch after unsubscribe (should not trigger listener)
      const listenerCallsBefore = stateChangeCount;
      await this.store.dispatch(createAuthStateChangedEvent('waitCode'));
      if (stateChangeCount !== listenerCallsBefore) {
        throw new Error('Listener called after unsubscribe');
      }

      hilog.info(DOMAIN, TAG, 'All tests passed!');
      return true;

    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Test failed: %{public}s', err.message);
      return false;
    }
  }

  // Static method to run test
  static async runTest(): Promise<void> {
    const test = new StoreIntegrationTest();
    const passed = await test.run();

    if (passed) {
      hilog.info(DOMAIN, TAG, '✅ Integration test passed');
    } else {
      hilog.error(DOMAIN, TAG, '❌ Integration test failed');
    }
  }
}

// Export test runner
export default StoreIntegrationTest;
