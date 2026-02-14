import { describe, it, expect } from '@ohos/hypium';
import { UserService } from '../../../main/ets/services/UserService';

/**
 * Unit tests for UserService — singleton pattern and service structure.
 * UserService methods are async TDLib wrappers; we test the singleton
 * contract and method existence.
 */

export default function userServiceTest() {
  describe('UserService', () => {

    // -----------------------------------------------------------------------
    // Singleton
    // -----------------------------------------------------------------------
    describe('singleton', () => {

      it('should return the same instance', 0, () => {
        const a = UserService.getInstance();
        const b = UserService.getInstance();
        expect(a === b).assertTrue();
      });

      it('should not be null', 0, () => {
        const instance = UserService.getInstance();
        expect(instance !== null).assertTrue();
        expect(instance !== undefined).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // API surface — ensure methods exist (type-safety)
    // -----------------------------------------------------------------------
    describe('API surface', () => {

      it('should have getMe method', 0, () => {
        const service = UserService.getInstance();
        expect(typeof service.getMe).assertEqual('function');
      });

      it('should have getUser method', 0, () => {
        const service = UserService.getInstance();
        expect(typeof service.getUser).assertEqual('function');
      });

      it('should have getUserFullInfo method', 0, () => {
        const service = UserService.getInstance();
        expect(typeof service.getUserFullInfo).assertEqual('function');
      });

      it('should have setName method', 0, () => {
        const service = UserService.getInstance();
        expect(typeof service.setName).assertEqual('function');
      });

      it('should have setBio method', 0, () => {
        const service = UserService.getInstance();
        expect(typeof service.setBio).assertEqual('function');
      });

      it('should have setUsername method', 0, () => {
        const service = UserService.getInstance();
        expect(typeof service.setUsername).assertEqual('function');
      });

      it('should have isPremium method', 0, () => {
        const service = UserService.getInstance();
        expect(typeof service.isPremium).assertEqual('function');
      });
    });
  });
}
