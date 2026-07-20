import { describe, expect, it } from '@ohos/hypium';
import { shouldShowAvatarOnline } from '../../../main/ets/ui/pages/chatlist/ChatItemVO';

export default function chatItemVOTest() {
  describe('ChatItemVO', () => {
    it('shows presence only for online non-bot users', 0, () => {
      expect(shouldShowAvatarOnline('online', false)).assertTrue();
      expect(shouldShowAvatarOnline('online', true)).assertFalse();
      expect(shouldShowAvatarOnline('offline', false)).assertFalse();
    });
  });
}
