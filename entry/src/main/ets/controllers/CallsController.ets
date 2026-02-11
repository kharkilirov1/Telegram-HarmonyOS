import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { Call, CallDiscardReason } from '../models/Call';
import { TdObject, safeNumber, safeString, safeBool, asRecord, asArray } from '../models/TdTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'CallsController';
const DOMAIN = 0x0001;

export class CallsController {
  private static instance: CallsController | null = null;

  private calls: Call[] = [];
  private callsLoaded: boolean = false;
  private activeCallId: number = 0;

  private constructor() {
    this.subscribeToUpdates();
  }

  static getInstance(): CallsController {
    if (!CallsController.instance) {
      CallsController.instance = new CallsController();
    }
    return CallsController.instance;
  }

  // --- Public read API ---

  getCalls(): Call[] {
    return this.calls;
  }

  getMissedCalls(): Call[] {
    return this.calls.filter(c => c.isMissed);
  }

  getActiveCallId(): number {
    return this.activeCallId;
  }

  isCallsLoaded(): boolean {
    return this.callsLoaded;
  }

  // --- Public action API ---

  async loadCallHistory(limit: number = 50): Promise<void> {
    try {
      // TDLib: searchCallMessages to get call history
      const searchParams: TdObject = {};
      searchParams['offset'] = '';
      searchParams['limit'] = limit;
      searchParams['only_missed'] = false;
      const result = await TDLibClient.getInstance()
        .send('searchCallMessages', searchParams);

      const rawMessages = asArray(result['messages']);
      if (rawMessages) {
        this.calls = [];
        for (const raw of rawMessages) {
          const call = this.parseCallFromMessage(raw);
          if (call) {
            this.calls.push(call);
          }
        }
        this.calls.sort((a, b) => b.date - a.date);
        this.callsLoaded = true;
        NotificationCenter.getInstance().post(EventId.CALLS_UPDATED);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to load call history');
    }
  }

  async startCall(userId: number, isVideo: boolean = false): Promise<void> {
    const libraryVersions: string[] = ['5.0.0'];
    const protocol: TdObject = {};
    protocol['@type'] = 'callProtocol';
    protocol['udp_p2p'] = true;
    protocol['udp_reflector'] = true;
    protocol['min_layer'] = 65;
    protocol['max_layer'] = 92;
    protocol['library_versions'] = libraryVersions;
    const callParams: TdObject = {};
    callParams['user_id'] = userId;
    callParams['protocol'] = protocol;
    callParams['is_video'] = isVideo;
    await TDLibClient.getInstance().send('createCall', callParams);
  }

  async discardCall(callId: number): Promise<void> {
    const discardParams: TdObject = {};
    discardParams['call_id'] = callId;
    discardParams['is_disconnected'] = false;
    discardParams['duration'] = 0;
    discardParams['is_video'] = false;
    discardParams['connection_id'] = 0;
    await TDLibClient.getInstance().send('discardCall', discardParams);
  }

  // --- Private ---

  private parseCallFromMessage(raw: TdObject): Call | null {
    const contentObj = raw['content'];
    if (!contentObj) return null;
    const content = asRecord(contentObj);

    const contentType = safeString(content['@type']);
    if (contentType !== 'messageCall') return null;

    const senderId = asRecord(raw['sender_id']);
    const userId = safeNumber(senderId['user_id']);
    const isOutgoing = safeBool(raw['is_outgoing']);
    const isVideo = safeBool(content['is_video']);
    const duration = safeNumber(content['duration']);

    const discardReasonVal = content['discard_reason'];
    let discardReason = CallDiscardReason.EMPTY;
    if (discardReasonVal) {
      const discardReasonObj = asRecord(discardReasonVal);
      const reasonType = safeString(discardReasonObj['@type']);
      switch (reasonType) {
        case 'callDiscardReasonMissed':
          discardReason = CallDiscardReason.MISSED;
          break;
        case 'callDiscardReasonDeclined':
          discardReason = CallDiscardReason.DECLINED;
          break;
        case 'callDiscardReasonDisconnected':
          discardReason = CallDiscardReason.DISCONNECTED;
          break;
        case 'callDiscardReasonHungUp':
          discardReason = CallDiscardReason.HUNG_UP;
          break;
      }
    }

    return new Call(
      safeNumber(raw['id']),
      safeNumber(raw['chat_id']),
      userId,
      '',
      null,
      isOutgoing,
      isVideo,
      duration,
      safeNumber(raw['date']),
      discardReason
    );
  }

  private subscribeToUpdates(): void {
    const client = TDLibClient.getInstance();

    client.on('updateCall', (update: TdObject) => {
      const rawCallVal = update['call'];
      if (!rawCallVal) return;
      const rawCall = asRecord(rawCallVal);

      const callId = safeNumber(rawCall['id']);
      const state = asRecord(rawCall['state']);
      const stateType = safeString(state['@type']);

      hilog.info(DOMAIN, TAG, 'Call %{public}d state: %{public}s', callId, stateType);

      if (stateType === 'callStatePending' || stateType === 'callStateExchangingKeys' ||
        stateType === 'callStateReady') {
        this.activeCallId = callId;
      } else if (stateType === 'callStateDiscarded' || stateType === 'callStateError') {
        if (this.activeCallId === callId) {
          this.activeCallId = 0;
        }
        // Reload call history to include the ended call
        this.loadCallHistory();
      }

      const callStateArgs: TdObject = {};
      callStateArgs['callId'] = callId;
      callStateArgs['state'] = stateType;
      NotificationCenter.getInstance().post(
        EventId.CALL_STATE_UPDATED,
        callStateArgs
      );
    });
  }
}
