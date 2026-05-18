import { describe, it, expect } from '@ohos/hypium';
import {
  LoadCallsParams,
  LoadCallsResult,
  CallHistoryRecord
} from '../../../main/ets/domain/usecases/loadCalls';
import { createSearchCallMessagesCommand } from '../../../main/ets/core/model/AppCommand';

/**
 * Unit tests for the current LoadCalls model/command surface.
 * Parser and TDLib hydration behavior remain integration/use-case follow-ups.
 */
export default function loadCallsTest() {
  describe('LoadCalls', () => {

    describe('LoadCallsParams', () => {
      it('should default to first page of all calls', 0, () => {
        const params = new LoadCallsParams();
        expect(params.fromMessageId).assertEqual('0');
        expect(params.limit).assertEqual(50);
        expect(params.onlyMissed).assertFalse();
      });

      it('should allow pagination and missed-only overrides', 0, () => {
        const params = new LoadCallsParams();
        params.fromMessageId = '9876543210';
        params.limit = 25;
        params.onlyMissed = true;

        expect(params.fromMessageId).assertEqual('9876543210');
        expect(params.limit).assertEqual(25);
        expect(params.onlyMissed).assertTrue();
      });
    });

    describe('CallHistoryRecord', () => {
      it('should default to an outgoing voice call record shell', 0, () => {
        const record = new CallHistoryRecord();
        expect(record.messageId).assertEqual('0');
        expect(record.chatId).assertEqual(0);
        expect(record.peerUserId).assertEqual(0);
        expect(record.senderUserId).assertEqual(0);
        expect(record.fallbackTitle).assertEqual('');
        expect(record.fallbackAvatarPath).assertEqual('');
        expect(record.timestamp).assertEqual(0);
        expect(record.direction).assertEqual('outgoing');
        expect(record.isVideo).assertFalse();
        expect(record.discardReasonType).assertEqual('');
        expect(record.contentType).assertEqual('messageCall');
      });

      it('should represent missed video and group-call variants', 0, () => {
        const record = new CallHistoryRecord();
        record.messageId = '42';
        record.chatId = 100;
        record.peerUserId = 200;
        record.senderUserId = 300;
        record.fallbackTitle = 'Alice';
        record.fallbackAvatarPath = '/avatar.jpg';
        record.timestamp = 1700000000;
        record.direction = 'missed';
        record.isVideo = true;
        record.discardReasonType = 'callDiscardReasonMissed';
        record.contentType = 'messageGroupCall';

        expect(record.messageId).assertEqual('42');
        expect(record.chatId).assertEqual(100);
        expect(record.peerUserId).assertEqual(200);
        expect(record.senderUserId).assertEqual(300);
        expect(record.fallbackTitle).assertEqual('Alice');
        expect(record.fallbackAvatarPath).assertEqual('/avatar.jpg');
        expect(record.timestamp).assertEqual(1700000000);
        expect(record.direction).assertEqual('missed');
        expect(record.isVideo).assertTrue();
        expect(record.discardReasonType).assertEqual('callDiscardReasonMissed');
        expect(record.contentType).assertEqual('messageGroupCall');
      });
    });

    describe('LoadCallsResult', () => {
      it('should default to empty terminal page', 0, () => {
        const result = new LoadCallsResult();
        expect(result.records.length).assertEqual(0);
        expect(result.nextFromMessageId).assertEqual('0');
        expect(result.hasMore).assertFalse();
      });
    });

    describe('search call messages command', () => {
      it('should create command payload from current LoadCalls params', 0, () => {
        const command = createSearchCallMessagesCommand('123', 20, true);
        expect(command.type).assertEqual('searchCallMessages');
        expect(command.payload.fromMessageId).assertEqual('123');
        expect(command.payload.limit).assertEqual(20);
        expect(command.payload.onlyMissed).assertTrue();
      });
    });
  });
}
