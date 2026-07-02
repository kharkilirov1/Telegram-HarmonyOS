import { describe, it, expect } from '@ohos/hypium';
import {
  EventNormalizer,
  EventNormalizerImpl,
  NormalizerStats,
  getEventNormalizer
} from '../../../main/ets/core/events/EventNormalizer';
import { TdObject } from '../../../main/ets/models/TdTypes';

/**
 * Tests for EventNormalizer — handler registration, normalization dispatch, and stats.
 * Does NOT require native TDLib: uses in-memory TdObject fixtures.
 */
export default function eventNormalizerTest() {
  describe('EventNormalizer', () => {

    describe('singleton', () => {
      it('should return same instance', 0, () => {
        const n1 = getEventNormalizer();
        const n2 = getEventNormalizer();
        expect(n1 === n2).assertTrue();
      });

      it('should return instance with normalize method', 0, () => {
        const normalizer = getEventNormalizer();
        expect(typeof normalizer.normalize === 'function').assertTrue();
      });

      it('should return instance with getStats method', 0, () => {
        const normalizer = getEventNormalizer();
        expect(typeof normalizer.getStats === 'function').assertTrue();
      });
    });

    describe('normalize with empty/null input', () => {
      it('should return empty array for null-like input', 0, () => {
        const normalizer = getEventNormalizer();
        const nullObj = null as ESObject as TdObject;
        const result = normalizer.normalize(nullObj);
        expect(result.length).assertEqual(0);
      });

      it('should return empty array for update without @type', 0, () => {
        const normalizer = getEventNormalizer();
        const update = TdObject.fromJSON('{"no_type": 123}');
        const result = normalizer.normalize(update);
        expect(result.length).assertEqual(0);
      });
    });

    describe('normalize with known update type', () => {
      it('should dispatch updateNewMessage to handler', 0, () => {
        const normalizer = getEventNormalizer();
        const update = TdObject.fromJSON(
          '{"@type":"updateNewMessage","message":{"@type":"message","id":1,"chat_id":100}}'
        );
        const result = normalizer.normalize(update);
        // updateNewMessage handler should produce at least one event
        expect(result.length > 0).assertTrue();
      });

      it('should dispatch updateUser to handler', 0, () => {
        const normalizer = getEventNormalizer();
        const update = TdObject.fromJSON(
          '{"@type":"updateUser","user":{"@type":"user","id":200,"first_name":"Test"}}'
        );
        const result = normalizer.normalize(update);
        expect(result.length > 0).assertTrue();
      });

      it('should dispatch updateFile to handler', 0, () => {
        const normalizer = getEventNormalizer();
        const update = TdObject.fromJSON(
          '{"@type":"updateFile","file":{"@type":"file","id":10,"size":1024,"local":{"@type":"localFile","path":"/tmp/test"}}}'
        );
        const result = normalizer.normalize(update);
        expect(result.length > 0).assertTrue();
      });

      it('should dispatch updateChatTitle to handler', 0, () => {
        const normalizer = getEventNormalizer();
        const update = TdObject.fromJSON(
          '{"@type":"updateChatTitle","chat_id":100,"title":"New Title"}'
        );
        const result = normalizer.normalize(update);
        expect(result.length > 0).assertTrue();
      });

      it('should dispatch updateAuthorizationState', 0, () => {
        const normalizer = getEventNormalizer();
        const update = TdObject.fromJSON(
          '{"@type":"updateAuthorizationState","authorization_state":{"@type":"authorizationStateWaitTdlibParameters"}}'
        );
        const result = normalizer.normalize(update);
        expect(result.length > 0).assertTrue();
      });
    });

    describe('normalize with unknown type', () => {
      it('should return empty array for unknown update type', 0, () => {
        const normalizer = getEventNormalizer();
        const update = TdObject.fromJSON('{"@type":"updateNonExistentType","data":{}}');
        const result = normalizer.normalize(update);
        expect(result.length).assertEqual(0);
      });
    });

    describe('stats', () => {
      it('should initialize with zero stats', 0, () => {
        const normalizer = new EventNormalizerImpl();
        const stats = normalizer.getStats();
        expect(stats.totalUpdates).assertEqual(0);
        expect(stats.normalizedEvents).assertEqual(0);
        expect(stats.droppedUpdates).assertEqual(0);
      });

      it('should increment totalUpdates after normalize', 0, () => {
        const normalizer = new EventNormalizerImpl();
        const update = TdObject.fromJSON('{"@type":"updateUser","user":{"@type":"user","id":1}}');
        normalizer.normalize(update);
        const stats = normalizer.getStats();
        expect(stats.totalUpdates).assertEqual(1);
      });

      it('should track unknown types as dropped', 0, () => {
        const normalizer = new EventNormalizerImpl();
        const update = TdObject.fromJSON('{"@type":"updateUnknownXYZ","data":{}}');
        normalizer.normalize(update);
        const stats = normalizer.getStats();
        expect(stats.totalUpdates).assertEqual(1);
        expect(stats.droppedUpdates).assertEqual(1);
      });

      it('should return stats copy, not reference', 0, () => {
        const normalizer = new EventNormalizerImpl();
        const stats1 = normalizer.getStats();
        const stats2 = normalizer.getStats();
        expect(stats1 !== stats2).assertTrue();
      });
    });
  });
}
