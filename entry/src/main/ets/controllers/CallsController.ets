import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from './NotificationCenter';
import { Call, CallDiscardReason } from '../models/Call';
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
      const searchParams: Record<string, Object> = {
        offset: '',
        limit: limit,
        only_missed: false
      };
      const result = await TDLibClient.getInstance()
        .send('searchCallMessages', searchParams) as Record<string, Object>;

      const rawMessages = result['messages'] as Record<string, Object>[];
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
    const protocol: Record<string, Object> = {
      '@type': 'callProtocol',
      udp_p2p: true,
      udp_reflector: true,
      min_layer: 65,
      max_layer: 92,
      library_versions: libraryVersions
    };
    const callParams: Record<string, Object> = {
      user_id: userId,
      protocol: protocol,
      is_video: isVideo
    };
    await TDLibClient.getInstance().send('createCall', callParams);
  }

  async discardCall(callId: number): Promise<void> {
    const discardParams: Record<string, Object> = {
      call_id: callId,
      is_disconnected: false,
      duration: 0,
      is_video: false,
      connection_id: 0
    };
    await TDLibClient.getInstance().send('discardCall', discardParams);
  }

  // --- Private ---

  private parseCallFromMessage(raw: Record<string, Object>): Call | null {
    const content = raw['content'] as Record<string, Object>;
    if (!content) return null;

    const contentType = (content['@type'] as string) || '';
    if (contentType !== 'messageCall') return null;

    const senderId = raw['sender_id'] as Record<string, Object>;
    const userId = senderId ? ((senderId['user_id'] as number) || 0) : 0;
    const isOutgoing = (raw['is_outgoing'] as boolean) || false;
    const isVideo = (content['is_video'] as boolean) || false;
    const duration = (content['duration'] as number) || 0;

    const discardReasonObj = content['discard_reason'] as Record<string, Object>;
    let discardReason = CallDiscardReason.EMPTY;
    if (discardReasonObj) {
      const reasonType = (discardReasonObj['@type'] as string) || '';
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
      (raw['id'] as number) || 0,
      (raw['chat_id'] as number) || 0,
      userId,
      '',
      null,
      isOutgoing,
      isVideo,
      duration,
      (raw['date'] as number) || 0,
      discardReason
    );
  }

  private subscribeToUpdates(): void {
    const client = TDLibClient.getInstance();

    client.on('updateCall', (update: Record<string, Object>) => {
      const rawCall = update['call'] as Record<string, Object>;
      if (!rawCall) return;

      const callId = (rawCall['id'] as number) || 0;
      const state = rawCall['state'] as Record<string, Object>;
      const stateType = state ? ((state['@type'] as string) || '') : '';

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

      NotificationCenter.getInstance().post(
        EventId.CALL_STATE_UPDATED,
        { callId: callId, state: stateType } as Record<string, Object>
      );
    });
  }
}
