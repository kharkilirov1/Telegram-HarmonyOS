import { describe, it, expect } from '@ohos/hypium';
import { Call, CallDiscardReason } from '../../../main/ets/models/Call';

/**
 * Unit tests for CallsController — call history parsing and Call model.
 * Tests parseCallFromMessage logic, missed call filtering, sorting by date.
 */

// Standalone copy of parseCallFromMessage — the private method on CallsController
function parseCallFromMessage(raw: Record<string, unknown>): Call | null {
  const content = raw['content'] as Record<string, unknown>;
  if (!content) return null;

  const contentType = (content['@type'] as string) || '';
  if (contentType !== 'messageCall') return null;

  const senderId = raw['sender_id'] as Record<string, unknown>;
  const userId = senderId ? ((senderId['user_id'] as number) || 0) : 0;
  const isOutgoing = (raw['is_outgoing'] as boolean) || false;
  const isVideo = (content['is_video'] as boolean) || false;
  const duration = (content['duration'] as number) || 0;

  const discardReasonObj = content['discard_reason'] as Record<string, unknown>;
  let discardReason = CallDiscardReason.EMPTY;
  if (discardReasonObj) {
    const reasonType = (discardReasonObj['@type'] as string) || '';
    switch (reasonType) {
      case 'callDiscardReasonMissed':
        discardReason = CallDiscardReason.MISSED;
        break;
      case 'callDiscardReasonDeclined':
        discardReason = CallDiscardReason.DECLINED;
        break;
      case 'callDiscardReasonDisconnected':
        discardReason = CallDiscardReason.DISCONNECTED;
        break;
      case 'callDiscardReasonHungUp':
        discardReason = CallDiscardReason.HUNG_UP;
        break;
    }
  }

  return new Call(
    (raw['id'] as number) || 0,
    (raw['chat_id'] as number) || 0,
    userId,
    '',
    null,
    isOutgoing,
    isVideo,
    duration,
    (raw['date'] as number) || 0,
    discardReason
  );
}

// Helper to build a raw TDLib call message
function makeRawCallMessage(overrides: Record<string, unknown>): Record<string, unknown> {
  const discardReason: Record<string, unknown> = {};
  discardReason['@type'] = (overrides['reasonType'] as string) || 'callDiscardReasonHungUp';
  const content: Record<string, unknown> = {};
  content['@type'] = 'messageCall';
  content['is_video'] = (overrides['is_video'] as boolean) || false;
  content['duration'] = (overrides['duration'] as number) || 60;
  content['discard_reason'] = discardReason;
  const senderId: Record<string, unknown> = {};
  senderId['user_id'] = (overrides['user_id'] as number) || 100;
  const raw: Record<string, unknown> = {};
  raw['id'] = (overrides['id'] as number) || 1;
  raw['chat_id'] = (overrides['chat_id'] as number) || 200;
  raw['sender_id'] = senderId;
  raw['is_outgoing'] = (overrides['is_outgoing'] as boolean) || false;
  raw['date'] = (overrides['date'] as number) || 1700000000;
  raw['content'] = content;
  return raw;
}

export default function callsControllerTest() {
  describe('CallsController', () => {

    // -----------------------------------------------------------------------
    // Call model
    // -----------------------------------------------------------------------
    describe('Call model', () => {

      it('should construct with default values', 0, () => {
        const call = new Call();
        expect(call.id).assertEqual(0);
        expect(call.chatId).assertEqual(0);
        expect(call.userId).assertEqual(0);
        expect(call.isOutgoing).assertFalse();
        expect(call.isVideo).assertFalse();
        expect(call.duration).assertEqual(0);
      });

      it('should construct with all parameters', 0, () => {
        const call = new Call(10, 20, 30, 'Alice', '/photo.jpg', true, true, 120, 1700000000,
          CallDiscardReason.HUNG_UP);
        expect(call.id).assertEqual(10);
        expect(call.chatId).assertEqual(20);
        expect(call.userId).assertEqual(30);
        expect(call.userName).assertEqual('Alice');
        expect(call.userPhotoUrl).assertEqual('/photo.jpg');
        expect(call.isOutgoing).assertTrue();
        expect(call.isVideo).assertTrue();
        expect(call.duration).assertEqual(120);
        expect(call.date).assertEqual(1700000000);
        expect(call.discardReason).assertEqual(CallDiscardReason.HUNG_UP);
      });

      it('should report isMissed for MISSED reason', 0, () => {
        const call = new Call(1, 0, 0, '', null, false, false, 0, 0, CallDiscardReason.MISSED);
        expect(call.isMissed).assertTrue();
      });

      it('should report isMissed for DECLINED reason', 0, () => {
        const call = new Call(1, 0, 0, '', null, false, false, 0, 0, CallDiscardReason.DECLINED);
        expect(call.isMissed).assertTrue();
      });

      it('should not report isMissed for HUNG_UP reason', 0, () => {
        const call = new Call(1, 0, 0, '', null, false, false, 0, 0, CallDiscardReason.HUNG_UP);
        expect(call.isMissed).assertFalse();
      });

      it('should not report isMissed for DISCONNECTED reason', 0, () => {
        const call = new Call(1, 0, 0, '', null, false, false, 0, 0,
          CallDiscardReason.DISCONNECTED);
        expect(call.isMissed).assertFalse();
      });

      it('should not report isMissed for EMPTY reason', 0, () => {
        const call = new Call(1, 0, 0, '', null, false, false, 0, 0, CallDiscardReason.EMPTY);
        expect(call.isMissed).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // parseCallFromMessage
    // -----------------------------------------------------------------------
    describe('parseCallFromMessage', () => {

      it('should parse basic call message', 0, () => {
        const overrides: Record<string, unknown> = {};
        overrides['id'] = 42;
        overrides['chat_id'] = 100;
        overrides['user_id'] = 200;
        overrides['date'] = 1700001234;
        overrides['duration'] = 300;
        overrides['reasonType'] = 'callDiscardReasonHungUp';
        const raw = makeRawCallMessage(overrides);

        const call = parseCallFromMessage(raw);
        expect(call !== null).assertTrue();
        if (call) {
          expect(call.id).assertEqual(42);
          expect(call.chatId).assertEqual(100);
          expect(call.userId).assertEqual(200);
          expect(call.date).assertEqual(1700001234);
          expect(call.duration).assertEqual(300);
          expect(call.discardReason).assertEqual(CallDiscardReason.HUNG_UP);
        }
      });

      it('should parse missed call', 0, () => {
        const overrides: Record<string, unknown> = {};
        overrides['reasonType'] = 'callDiscardReasonMissed';
        overrides['duration'] = 0;
        const raw = makeRawCallMessage(overrides);

        const call = parseCallFromMessage(raw);
        expect(call !== null).assertTrue();
        if (call) {
          expect(call.discardReason).assertEqual(CallDiscardReason.MISSED);
          expect(call.isMissed).assertTrue();
        }
      });

      it('should parse declined call', 0, () => {
        const overrides: Record<string, unknown> = {};
        overrides['reasonType'] = 'callDiscardReasonDeclined';
        const raw = makeRawCallMessage(overrides);

        const call = parseCallFromMessage(raw);
        expect(call !== null).assertTrue();
        if (call) {
          expect(call.discardReason).assertEqual(CallDiscardReason.DECLINED);
          expect(call.isMissed).assertTrue();
        }
      });

      it('should parse video call', 0, () => {
        const overrides: Record<string, unknown> = {};
        overrides['is_video'] = true;
        const raw = makeRawCallMessage(overrides);

        const call = parseCallFromMessage(raw);
        expect(call !== null).assertTrue();
        if (call) {
          expect(call.isVideo).assertTrue();
        }
      });

      it('should parse outgoing call', 0, () => {
        const overrides: Record<string, unknown> = {};
        overrides['is_outgoing'] = true;
        const raw = makeRawCallMessage(overrides);

        const call = parseCallFromMessage(raw);
        expect(call !== null).assertTrue();
        if (call) {
          expect(call.isOutgoing).assertTrue();
        }
      });

      it('should return null for missing content', 0, () => {
        const raw: Record<string, unknown> = {};
        raw['id'] = 1;
        const call = parseCallFromMessage(raw);
        expect(call === null).assertTrue();
      });

      it('should return null for non-messageCall content', 0, () => {
        const content: Record<string, unknown> = {};
        content['@type'] = 'messageText';
        const raw: Record<string, unknown> = {};
        raw['id'] = 1;
        raw['content'] = content;
        const call = parseCallFromMessage(raw);
        expect(call === null).assertTrue();
      });

      it('should default discardReason to EMPTY when no reason', 0, () => {
        const content: Record<string, unknown> = {};
        content['@type'] = 'messageCall';
        content['duration'] = 10;
        const raw: Record<string, unknown> = {};
        raw['id'] = 1;
        raw['content'] = content;
        const call = parseCallFromMessage(raw);
        expect(call !== null).assertTrue();
        if (call) {
          expect(call.discardReason).assertEqual(CallDiscardReason.EMPTY);
        }
      });
    });

    // -----------------------------------------------------------------------
    // getMissedCalls filter
    // -----------------------------------------------------------------------
    describe('getMissedCalls filter', () => {

      it('should filter only missed and declined calls', 0, () => {
        const calls: Call[] = [
          new Call(1, 0, 0, '', null, false, false, 0, 0, CallDiscardReason.MISSED),
          new Call(2, 0, 0, '', null, false, false, 60, 0, CallDiscardReason.HUNG_UP),
          new Call(3, 0, 0, '', null, false, false, 0, 0, CallDiscardReason.DECLINED),
          new Call(4, 0, 0, '', null, false, false, 30, 0, CallDiscardReason.DISCONNECTED),
        ];

        const missed = calls.filter(c => c.isMissed);
        expect(missed.length).assertEqual(2);
        expect(missed[0].id).assertEqual(1);
        expect(missed[1].id).assertEqual(3);
      });

      it('should return empty array when no missed calls', 0, () => {
        const calls: Call[] = [
          new Call(1, 0, 0, '', null, false, false, 60, 0, CallDiscardReason.HUNG_UP),
          new Call(2, 0, 0, '', null, false, false, 120, 0, CallDiscardReason.DISCONNECTED),
        ];

        const missed = calls.filter(c => c.isMissed);
        expect(missed.length).assertEqual(0);
      });
    });

    // -----------------------------------------------------------------------
    // Call history sorting
    // -----------------------------------------------------------------------
    describe('call history sorting', () => {

      it('should sort calls by date descending (newest first)', 0, () => {
        const calls: Call[] = [
          new Call(1, 0, 0, '', null, false, false, 0, 1000),
          new Call(2, 0, 0, '', null, false, false, 0, 3000),
          new Call(3, 0, 0, '', null, false, false, 0, 2000),
        ];

        calls.sort((a, b) => b.date - a.date);
        expect(calls[0].id).assertEqual(2);
        expect(calls[1].id).assertEqual(3);
        expect(calls[2].id).assertEqual(1);
      });
    });
  });
}
