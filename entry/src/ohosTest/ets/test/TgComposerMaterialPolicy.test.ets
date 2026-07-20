import { describe, expect, it } from '@ohos/hypium';
import { resolveComposerMaterialMode } from '../../../main/ets/ui/tg_ui/utils/TgComposerMaterialPolicy';

export default function tgComposerMaterialPolicyTest() {
  describe('TgComposerMaterialPolicy', () => {
    it('uses immersive material only on API 26 when enabled', 0, () => {
      expect(resolveComposerMaterialMode(true, true, true)).assertEqual('nativeImmersive');
    });

    it('keeps the realtime blur path on the API 23 runtime floor', 0, () => {
      expect(resolveComposerMaterialMode(false, true, true)).assertEqual('realtimeBlur');
    });

    it('keeps realtime blur when the native material flag is disabled', 0, () => {
      expect(resolveComposerMaterialMode(true, false, true)).assertEqual('realtimeBlur');
    });

    it('uses the opaque fallback when realtime glass is disabled', 0, () => {
      expect(resolveComposerMaterialMode(true, true, false)).assertEqual('fallback');
      expect(resolveComposerMaterialMode(false, false, false)).assertEqual('fallback');
    });
  });
}
