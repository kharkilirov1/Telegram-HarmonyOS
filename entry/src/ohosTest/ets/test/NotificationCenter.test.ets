import { describe, it, expect } from '@ohos/hypium';
import { NotificationCenter, EventId } from '../../../main/ets/controllers/NotificationCenter';

/**
 * Unit tests for NotificationCenter — event bus (Observer pattern).
 * Tests subscribe, unsubscribe, posting events, and edge cases.
 */

export default function notificationCenterTest() {
  describe('NotificationCenter', () => {

    // -----------------------------------------------------------------------
    // Singleton
    // -----------------------------------------------------------------------
    describe('singleton', () => {
      it('should return the same instance', 0, () => {
        const a = NotificationCenter.getInstance();
        const b = NotificationCenter.getInstance();
        expect(a === b).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // addObserver + post
    // -----------------------------------------------------------------------
    describe('addObserver and post', () => {

      it('should notify observer when event is posted', 0, () => {
        const nc = NotificationCenter.getInstance();
        let received = false;
        const handler = (): void => {
          received = true;
        };
        nc.addObserver(EventId.CONTACTS_UPDATED, handler);
        nc.post(EventId.CONTACTS_UPDATED);
        nc.removeObserver(EventId.CONTACTS_UPDATED, handler);
        expect(received).assertTrue();
      });

      it('should pass args to observer', 0, () => {
        const nc = NotificationCenter.getInstance();
        let receivedState = '';
        const handler = (args?: Record<string, unknown>): void => {
          if (args) {
            receivedState = args['state'] as string;
          }
        };
        nc.addObserver(EventId.CONNECTION_STATE_CHANGED, handler);
        const eventArgs: Record<string, unknown> = {};
        eventArgs['state'] = 'connectionStateReady';
        nc.post(EventId.CONNECTION_STATE_CHANGED, eventArgs);
        nc.removeObserver(EventId.CONNECTION_STATE_CHANGED, handler);
        expect(receivedState).assertEqual('connectionStateReady');
      });

      it('should notify multiple observers', 0, () => {
        const nc = NotificationCenter.getInstance();
        let count = 0;
        const handler1 = (): void => { count++; };
        const handler2 = (): void => { count++; };
        nc.addObserver(EventId.STORIES_UPDATED, handler1);
        nc.addObserver(EventId.STORIES_UPDATED, handler2);
        nc.post(EventId.STORIES_UPDATED);
        nc.removeObserver(EventId.STORIES_UPDATED, handler1);
        nc.removeObserver(EventId.STORIES_UPDATED, handler2);
        expect(count).assertEqual(2);
      });

      it('should not notify observers for different events', 0, () => {
        const nc = NotificationCenter.getInstance();
        let notified = false;
        const handler = (): void => { notified = true; };
        nc.addObserver(EventId.CALLS_UPDATED, handler);
        nc.post(EventId.CONTACTS_UPDATED);
        nc.removeObserver(EventId.CALLS_UPDATED, handler);
        expect(notified).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // removeObserver
    // -----------------------------------------------------------------------
    describe('removeObserver', () => {

      it('should stop notifications after removal', 0, () => {
        const nc = NotificationCenter.getInstance();
        let count = 0;
        const handler = (): void => { count++; };
        nc.addObserver(EventId.APP_ERROR, handler);
        nc.post(EventId.APP_ERROR);
        nc.removeObserver(EventId.APP_ERROR, handler);
        nc.post(EventId.APP_ERROR);
        expect(count).assertEqual(1);
      });

      it('should not throw when removing non-existent observer', 0, () => {
        const nc = NotificationCenter.getInstance();
        const handler = (): void => {};
        // Should not throw
        nc.removeObserver(EventId.DIALOG_DELETED, handler);
        expect(true).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------
    describe('edge cases', () => {

      it('should handle post with no observers', 0, () => {
        const nc = NotificationCenter.getInstance();
        // Should not throw
        nc.post(EventId.STORY_DELETED);
        expect(true).assertTrue();
      });

      it('should handle post with undefined args', 0, () => {
        const nc = NotificationCenter.getInstance();
        let called = false;
        const handler = (args?: Record<string, unknown>): void => {
          called = true;
          expect(args).assertUndefined();
        };
        nc.addObserver(EventId.MESSAGES_READ, handler);
        nc.post(EventId.MESSAGES_READ);
        nc.removeObserver(EventId.MESSAGES_READ, handler);
        expect(called).assertTrue();
      });
    });
  });
}
