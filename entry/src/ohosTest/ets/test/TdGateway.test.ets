import { describe, it, expect } from '@ohos/hypium';
import { getMethodTimeout, getTdGateway, TdGatewayImpl } from '../../../main/ets/infra/td/gateway/TdGateway';

/**
 * Tests for TdGateway — method timeout mapping, state machine, and singleton lifecycle.
 * Does NOT require native TDLib: tests pure TypeScript logic only.
 */
export default function tdGatewayTest() {
  describe('TdGateway', () => {

    describe('getMethodTimeout', () => {
      it('should return 15s for chat list / history / search methods', 0, () => {
        expect(getMethodTimeout('getChats')).assertEqual(15000);
        expect(getMethodTimeout('loadChats')).assertEqual(15000);
        expect(getMethodTimeout('getChatHistory')).assertEqual(15000);
        expect(getMethodTimeout('searchCallMessages')).assertEqual(15000);
        expect(getMethodTimeout('getChat')).assertEqual(15000);
      });

      it('should return 30s for sendMessage', 0, () => {
        expect(getMethodTimeout('sendMessage')).assertEqual(30000);
      });

      it('should return 120s for downloadFile', 0, () => {
        expect(getMethodTimeout('downloadFile')).assertEqual(120000);
      });

      it('should return 10s for close', 0, () => {
        expect(getMethodTimeout('close')).assertEqual(10000);
      });

      it('should return 30s default for unknown methods', 0, () => {
        expect(getMethodTimeout('unknownMethod')).assertEqual(30000);
        expect(getMethodTimeout('')).assertEqual(30000);
        expect(getMethodTimeout('getMe')).assertEqual(30000);
      });
    });

    describe('singleton', () => {
      it('should return same instance for repeated calls', 0, () => {
        const gw1 = getTdGateway();
        const gw2 = getTdGateway();
        expect(gw1 === gw2).assertTrue();
      });

      it('should start in idle state', 0, () => {
        const gw = getTdGateway();
        expect(gw.getState()).assertEqual('idle');
      });

      it('should report isReady=false when idle', 0, () => {
        const gw = getTdGateway();
        expect(gw.isReady()).assertFalse();
      });
    });

    describe('getGatewayStats', () => {
      it('should return stats object with expected shape', 0, () => {
        const gw = getTdGateway();
        const stats = gw.getGatewayStats();
        expect(stats.state).assertEqual('idle');
        expect(stats.pendingRequests).assertEqual(0);
        expect(typeof stats.timeouts === 'number').assertTrue();
      });
    });

    describe('send validation', () => {
      it('should reject empty method name', 0, async () => {
        const gw = getTdGateway();
        let gotError = false;
        try {
          await gw.send('');
        } catch (error) {
          gotError = true;
        }
        expect(gotError).assertTrue();
      });

      it('should reject send when not ready', 0, async () => {
        const gw = getTdGateway();
        let gotError = false;
        try {
          await gw.send('getChats');
        } catch (error) {
          gotError = true;
        }
        expect(gotError).assertTrue();
      });
    });

    describe('subscribeUpdates', () => {
      it('should return an unsubscribe function', 0, () => {
        const gw = getTdGateway();
        let called = false;
        const unsub = gw.subscribeUpdates((_update: Object) => { called = true; });
        expect(typeof unsub === 'function').assertTrue();
        unsub();
      });

      it('should unsubscribe without error when called twice', 0, () => {
        const gw = getTdGateway();
        const unsub = gw.subscribeUpdates((_update: Object) => {});
        unsub();
        unsub();
        expect(true).assertTrue();
      });
    });

    describe('isDrainCongested', () => {
      it('should return false for fresh idle gateway', 0, () => {
        const gw = getTdGateway() as TdGatewayImpl;
        expect(gw.isDrainCongested()).assertFalse();
      });
    });
  });
}
