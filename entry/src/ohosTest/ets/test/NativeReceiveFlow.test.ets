import { describe, it, expect } from '@ohos/hypium';
import tdlib, { ReceiveLoopStats } from 'libtdlib_napi.so';
import { systemDateTime } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

interface NativeWitnessBatch {
  json: string;
  epoch: number;
  id: number;
  bytes: number;
}

// Actual production N-API module, with a fresh pre-parameter TDLib client.
// No setTdlibParameters, credentials, database paths, login or network operation.
export default function nativeReceiveFlowTest() {
  describe('NativeReceiveFlow', () => {
    it('production receive credit and finalized stop with isolated pre-parameter client', 0, async () => {
      const pending: NativeWitnessBatch[] = [];
      let epoch = 0;
      let clientId = 0;
      let optionObserved = false;
      let closedObserved = false;
      let consumed = 0;
      let lastConsumedId = 0;
      let failure = '';
      let timer = -1;
      const utf8 = new util.TextEncoder('utf-8');
      const start = systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, false);
      const deadline = start + 15000;
      const drain = (): void => {
        timer = -1;
        while (pending.length > 0) {
          const batch = pending.shift();
          if (batch === undefined) return;
          try {
            const envelopes = JSON.parse(batch.json) as Record<string, Object>[];
            for (const envelope of envelopes) {
              if (envelope['@client_id'] !== clientId) continue;
              if (envelope['@extra'] === 'native_receive_probe_version') {
                if (envelope['@type'] === 'optionValueString') optionObserved = true;
                else failure = 'Unexpected synthetic option response';
              }
              if (envelope['@type'] === 'updateAuthorizationState') {
                const state = envelope['authorization_state'] as Record<string, Object>;
                if (state['@type'] === 'authorizationStateClosed') closedObserved = true;
              }
            }
          } catch {
            failure = 'Native batch parse failed';
          }
          batch.json = '';
          const stats: ReceiveLoopStats = tdlib.getReceiveLoopStats();
          if (stats.epoch !== epoch || stats.admittedBatches < 1 || stats.outstandingBatches > 4 ||
            stats.outstandingBytes > 16 * 1024 * 1024 || stats.pendingNotifications > 1) failure = 'Native credit bounds failed';
          if (tdlib.ackReceiveBatch(epoch + 1, batch.id)) failure = 'Stale epoch ACK accepted';
          if (!tdlib.ackReceiveBatch(epoch, batch.id)) failure = 'Consumption ACK rejected';
          if (tdlib.ackReceiveBatch(epoch, batch.id)) failure = 'Duplicate ACK accepted';
          consumed++;
          lastConsumedId = batch.id;
        }
      };
      const waitFor = async (condition: () => boolean): Promise<void> => {
        while (!condition() && systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, false) < deadline) {
          await new Promise<void>((resolve) => { setTimeout(resolve, 20); });
        }
        if (!condition()) throw new Error('Native receive witness deadline');
      };
      epoch = tdlib.startReceiveLoop((json: string, callbackEpoch: number, batchId: number, bytes: number): boolean => {
        if (callbackEpoch !== epoch || !Number.isSafeInteger(batchId) || batchId <= 0 ||
          bytes !== utf8.encodeInto(json).byteLength || bytes > 8 * 1024 * 1024 || pending.length >= 4) return false;
        pending.push({ json, epoch: callbackEpoch, id: batchId, bytes });
        if (timer === -1) timer = setTimeout(drain, 2) as number;
        return true;
      });
      expect(Number.isSafeInteger(epoch) && epoch > 0).assertTrue();
      try {
        expect(tdlib.getReceiveLoopStatus()).assertEqual(1);
        clientId = tdlib.createClient();
        expect(clientId > 0).assertTrue();
        tdlib.send(clientId, '{"@type":"getOption","name":"version","@extra":"native_receive_probe_version"}');
        await waitFor((): boolean => optionObserved || failure.length > 0);
      } finally {
        // A live client is retired only by its actual Closed update.
        if (clientId > 0 && !closedObserved) {
          tdlib.send(clientId, '{"@type":"close","@extra":"native_receive_probe_close"}');
          await waitFor((): boolean => closedObserved);
        }
        if (clientId === 0 || closedObserved) await tdlib.stopReceiveLoop();
        if (timer !== -1) clearTimeout(timer);
      }
      expect(failure).assertEqual('');
      expect(optionObserved && closedObserved && consumed > 0).assertTrue();
      const retired: ReceiveLoopStats = tdlib.getReceiveLoopStats();
      expect(retired.producerJoined && retired.tsfnFinalized).assertTrue();
      expect(retired.outstandingBatches).assertEqual(0);
      expect(retired.outstandingBytes).assertEqual(0);
      expect(retired.pendingNotifications).assertEqual(0);
      expect(tdlib.getReceiveLoopStatus()).assertEqual(0);
      expect(tdlib.ackReceiveBatch(epoch, lastConsumedId)).assertFalse();
      const nextEpoch: number = tdlib.startReceiveLoop((_json: string, _epoch: number, _id: number, _bytes: number): boolean => false);
      expect(nextEpoch > epoch).assertTrue();
      const stopA: Promise<void> = tdlib.stopReceiveLoop();
      const stopB: Promise<void> = tdlib.stopReceiveLoop();
      await Promise.all([stopA, stopB]);
      expect(tdlib.getReceiveLoopStats().producerJoined && tdlib.getReceiveLoopStats().tsfnFinalized).assertTrue();
    });
  });
}
