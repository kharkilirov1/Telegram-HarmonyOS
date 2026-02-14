import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { TdFallbackRegistry } from '../../../main/ets/services/TdFallbackRegistry';

/**
 * Unit tests for TdFallbackRegistry — centralized tracking of
 * unknown/unhandled TDLib types.
 */

export default function tdFallbackRegistryTest() {
  describe('TdFallbackRegistry', () => {
    let registry: TdFallbackRegistry;

    beforeEach(() => {
      registry = TdFallbackRegistry.getInstance();
      registry.reset();
    });

    // -----------------------------------------------------------------------
    // Basic recording
    // -----------------------------------------------------------------------
    describe('recordUnhandled', () => {

      it('should record an unknown update type', 0, () => {
        registry.recordUnhandled('updateSomethingNew', 'update');
        expect(registry.getUnknownCount()).assertEqual(1);
      });

      it('should not double-count same type', 0, () => {
        registry.recordUnhandled('updateSomethingNew', 'update');
        registry.recordUnhandled('updateSomethingNew', 'update');
        registry.recordUnhandled('updateSomethingNew', 'update');
        expect(registry.getUnknownCount()).assertEqual(1);
      });

      it('should count distinct unknown types', 0, () => {
        registry.recordUnhandled('updateFoo', 'update');
        registry.recordUnhandled('updateBar', 'update');
        expect(registry.getUnknownCount()).assertEqual(2);
      });

      it('should not count known-unimplemented types as unknown', 0, () => {
        registry.recordUnhandled('updateOption', 'update');
        registry.recordUnhandled('updateFile', 'update');
        expect(registry.getUnknownCount()).assertEqual(0);
      });

      it('should track known-unimplemented content types without counting as unknown', 0, () => {
        registry.recordUnhandled('messageContact', 'content');
        registry.recordUnhandled('messageLocation', 'content');
        expect(registry.getUnknownCount()).assertEqual(0);
      });

      it('should count truly unknown content types', 0, () => {
        registry.recordUnhandled('messageSuperNew', 'content');
        expect(registry.getUnknownCount()).assertEqual(1);
      });
    });

    // -----------------------------------------------------------------------
    // getSummary
    // -----------------------------------------------------------------------
    describe('getSummary', () => {

      it('should return "No unhandled types" when empty', 0, () => {
        const summary = registry.getSummary();
        expect(summary).assertEqual('No unhandled types recorded');
      });

      it('should include type names in summary', 0, () => {
        registry.recordUnhandled('updateFoo', 'update');
        const summary = registry.getSummary();
        expect(summary.indexOf('updateFoo') >= 0).assertTrue();
      });

      it('should show count in summary', 0, () => {
        registry.recordUnhandled('updateFoo', 'update');
        registry.recordUnhandled('updateFoo', 'update');
        registry.recordUnhandled('updateFoo', 'update');
        const summary = registry.getSummary();
        expect(summary.indexOf('x3') >= 0).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // reset
    // -----------------------------------------------------------------------
    describe('reset', () => {

      it('should clear all entries', 0, () => {
        registry.recordUnhandled('updateFoo', 'update');
        registry.recordUnhandled('updateBar', 'update');
        registry.reset();
        expect(registry.getUnknownCount()).assertEqual(0);
        expect(registry.getSummary()).assertEqual('No unhandled types recorded');
      });
    });

    // -----------------------------------------------------------------------
    // Singleton
    // -----------------------------------------------------------------------
    describe('singleton', () => {

      it('should return same instance', 0, () => {
        const instance1 = TdFallbackRegistry.getInstance();
        const instance2 = TdFallbackRegistry.getInstance();
        expect(instance1 === instance2).assertTrue();
      });
    });
  });
}
