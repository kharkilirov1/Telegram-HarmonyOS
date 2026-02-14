import { describe, it, expect } from '@ohos/hypium';
import { SessionService } from '../../../main/ets/services/SessionService';

/**
 * Unit tests for SessionService — session management use-case layer.
 * Tests singleton pattern. TDLib-dependent methods require integration setup.
 */

export default function sessionServiceTest() {
  describe('SessionService', () => {

    // -----------------------------------------------------------------------
    // Singleton pattern
    // -----------------------------------------------------------------------
    describe('getInstance', () => {

      it('should return same instance', 0, () => {
        const a = SessionService.getInstance();
        const b = SessionService.getInstance();
        expect(a === b).assertTrue();
      });

      it('should not be null', 0, () => {
        const instance = SessionService.getInstance();
        expect(instance !== null).assertTrue();
      });
    });
  });
}
