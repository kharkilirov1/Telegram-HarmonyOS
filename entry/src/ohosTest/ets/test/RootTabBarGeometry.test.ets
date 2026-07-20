import { describe, expect, it } from '@ohos/hypium';
import {
  computeRootTabContentBottomInset,
  resolveRootSearchDockGeometry,
  resolveRootTabBarRenderState,
  ROOT_TAB_BAR_FALLBACK_CONTENT_INSET
} from '../../../main/ets/ui/utils/RootTabBarGeometry';

export default function rootTabBarGeometryTest() {
  describe('RootTabBarGeometry', () => {
    it('resolves the accepted visible native tuple', 0, () => {
      const state = resolveRootTabBarRenderState(2, false);
      expect(state.overlap).assertTrue();
      expect(state.height).assertEqual(48);
      expect(state.bottomMargin).assertEqual(30);
      expect(state.opacity).assertEqual(1);
      expect(state.maskHeight).assertEqual(110);
    });

    it('resolves the coordinated chat-detail hidden tuple', 0, () => {
      const state = resolveRootTabBarRenderState(2, true);
      expect(state.overlap).assertFalse();
      expect(state.height).assertEqual(0);
      expect(state.bottomMargin).assertEqual(0);
      expect(state.opacity).assertEqual(0);
      expect(state.maskHeight).assertEqual(0);
    });

    it('hides the native bar while the keyboard owns the bottom avoid area', 0, () => {
      const state = resolveRootTabBarRenderState(2, false, true);
      expect(state.overlap).assertFalse();
      expect(state.height).assertEqual(0);
      expect(state.bottomMargin).assertEqual(0);
      expect(state.opacity).assertEqual(0);
      expect(state.maskHeight).assertEqual(0);
    });

    it('keeps the native container for an expanded bottom Search mini bar', 0, () => {
      const state = resolveRootTabBarRenderState(2, false, true, true);
      expect(state.overlap).assertTrue();
      expect(state.height).assertEqual(48);
      expect(state.bottomMargin).assertEqual(30);
      expect(state.opacity).assertEqual(1);
      expect(state.maskHeight).assertEqual(110);
    });

    it('does not hide on a non-Chats tab with a stale detail flag', 0, () => {
      const state = resolveRootTabBarRenderState(1, true);
      expect(state.overlap).assertTrue();
      expect(state.height).assertEqual(48);
      expect(resolveRootTabBarRenderState(1, false, true).height).assertEqual(0);
    });

    it('preserves the existing content-clearance formula', 0, () => {
      expect(computeRootTabContentBottomInset(0, 0)).assertEqual(64);
      expect(computeRootTabContentBottomInset(20, 24)).assertEqual(78);
      expect(computeRootTabContentBottomInset(40, 20)).assertEqual(94);
      expect(computeRootTabContentBottomInset(-10, -20)).assertEqual(64);
      expect(ROOT_TAB_BAR_FALLBACK_CONTENT_INSET).assertEqual(82);
    });

    it('reserves the native idle Search surface and iOS-equivalent side delta', 0, () => {
      const phone = resolveRootSearchDockGeometry(436);
      expect(phone.groupWidth).assertEqual(436);
      expect(phone.tabBarWidth).assertEqual(332);
      expect(phone.activeTabBarWidth).assertEqual(48);
      expect(phone.miniBarExpandedWidth).assertEqual(396);
      expect(phone.miniBarIdleWidth).assertEqual(48);
      expect(phone.gap).assertEqual(16);
      expect(phone.sideMargin).assertEqual(20);

      const capped = resolveRootSearchDockGeometry(600);
      expect(capped.groupWidth).assertEqual(500);
      expect(capped.tabBarWidth).assertEqual(396);
      expect(capped.activeTabBarWidth).assertEqual(48);
      expect(capped.miniBarExpandedWidth).assertEqual(460);
    });
  });
}
