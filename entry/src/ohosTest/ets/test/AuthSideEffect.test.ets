import { describe, it, expect } from '@ohos/hypium';
import {
  getAuthSideEffect,
  setAuthSideEffectStore,
  stopAuthSideEffect
} from '../../../main/ets/core/sideeffects/AuthSideEffect';
import { AppState } from '../../../main/ets/core/model/AppState';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { AppStore } from '../../../main/ets/core/store/AppStore';

function identityReducer(state: AppState, _event: AnyAppEvent): AppState {
  return state;
}

export default function authSideEffectTest() {
  describe('AuthSideEffect', () => {
    it('should expose stable singleton instance', 0, () => {
      const first = getAuthSideEffect();
      const second = getAuthSideEffect();
      expect(first === second).assertTrue();
    });

    it('should accept store injection and idempotent stop without native startup', 0, () => {
      const store = new AppStore(identityReducer, new AppState(), false);
      setAuthSideEffectStore(store);
      stopAuthSideEffect();
      stopAuthSideEffect();
      expect(true).assertTrue();
    });
  });
}
