import { expect } from '@ohos/hypium';
import { ChatTimelineDataSource } from '../../../main/ets/ui/pages/chat/ChatTimelineDataSource';
import { ChatTimelineEntryVO, ChatTimelineEntryKind } from '../../../main/ets/ui/pages/chat/ChatTimelineVO';

// Synthetic complete production VOs. Stable identity and stamped render identity
// deliberately differ, as they do in buildChatTimeline.
export function timelineMessage(id: string, stamp: number = 0, text: string = ''): ChatTimelineEntryVO {
  const entry = new ChatTimelineEntryVO();
  entry.kind = 'message';
  entry.stableKey = 'msg_' + id;
  entry.key = entry.stableKey + '_s' + stamp.toString() + '_r0_e0';
  entry.message.messageId = id;
  entry.message.sourceMessageIds = [id];
  entry.message.text = text.length > 0 ? text : 'synthetic ' + id;
  return entry;
}

export function timelineMarker(kind: ChatTimelineEntryKind, id: string): ChatTimelineEntryVO {
  const entry = new ChatTimelineEntryVO();
  entry.kind = kind;
  entry.stableKey = kind + '_' + id;
  entry.key = entry.stableKey;
  entry.dateText = kind === 'date' ? id : '';
  entry.unreadText = kind === 'unread' ? id : '';
  return entry;
}

export function timelineEntries(ids: string[]): ChatTimelineEntryVO[] {
  return ids.map((id: string) => timelineMessage(id));
}

export function timelineSnapshot(entries: ChatTimelineEntryVO[]): string {
  return JSON.stringify(entries.map((entry: ChatTimelineEntryVO) =>
    [entry.stableKey, entry.key, entry.kind, entry.message.text, entry.dateText, entry.unreadText]));
}

export class TimelineNotification {
  kind: string = '';
  index: number = -1;
  count: number = 0;
  snapshot: string = '';
  identity: string = '';
}

// For the new reconciliation path, replay every signal against an independent
// listener model. Existing bulk-assignment fast paths have their own controls.
export class TimelineUpdateRecorder implements DataChangeListener {
  readonly events: TimelineNotification[] = [];
  readonly removed: string[] = [];
  readonly added: string[] = [];
  private model: ChatTimelineEntryVO[];
  private source: ChatTimelineDataSource;
  private coherent: boolean;
  constructor(source: ChatTimelineDataSource, coherent: boolean = true) {
    this.source = source;
    this.coherent = coherent;
    this.model = source.getAllEntries().slice();
  }
  private record(kind: string, index: number): void {
    const current = this.source.getAllEntries();
    const event = new TimelineNotification();
    event.kind = kind;
    event.index = index;
    event.count = current.length;
    event.snapshot = timelineSnapshot(current);
    if (kind === 'reload') {
      this.model = current.slice();
    } else if (kind === 'add') {
      expect(index >= 0 && index < current.length).assertTrue();
      event.identity = current[index].stableKey;
      this.added.push(event.identity);
      if (this.coherent) {
        expect(current.length).assertEqual(this.model.length + 1);
        this.model.splice(index, 0, current[index]);
      }
    } else if (kind === 'delete') {
      if (this.coherent) {
        expect(index >= 0 && index < this.model.length).assertTrue();
        event.identity = this.model[index].stableKey;
        this.removed.push(event.identity);
        expect(current.length).assertEqual(this.model.length - 1);
        this.model.splice(index, 1);
      }
    } else if (kind === 'change') {
      expect(index >= 0 && index < current.length).assertTrue();
      event.identity = current[index].stableKey;
      if (this.coherent) {
        expect(current.length).assertEqual(this.model.length);
        expect(this.model[index].stableKey).assertEqual(current[index].stableKey);
        this.model[index] = current[index];
      }
    } else {
      // No move signal is needed for order-preserving reconciliation. The SDK
      // onDataMove contract is an exchange, not an arbitrary shift operation.
      expect(kind).assertEqual('supported add/delete/change/reload');
    }
    if (this.coherent) expect(timelineSnapshot(current)).assertEqual(timelineSnapshot(this.model));
    this.events.push(event);
  }
  onDataReloaded(): void { this.record('reload', -1); }
  onDataAdd(index: number): void { this.record('add', index); }
  onDataDelete(index: number): void { this.record('delete', index); }
  onDataChange(index: number): void { this.record('change', index); }
  onDataMove(from: number, _to: number): void { this.record('move', from); }
  onDatasetChange(_operations: DataOperation[]): void { this.record('batch', -1); }
  onDataAdded(index: number): void { this.onDataAdd(index); }
  onDataDeleted(index: number): void { this.onDataDelete(index); }
  onDataChanged(index: number): void { this.onDataChange(index); }
  onDataMoved(from: number, to: number): void { this.onDataMove(from, to); }
}

export class TimelineUpdateHarness {
  readonly source: ChatTimelineDataSource = new ChatTimelineDataSource();
  readonly recorder: TimelineUpdateRecorder;
  constructor(before: ChatTimelineEntryVO[], coherent: boolean = true) {
    this.source.applyDiff(before.slice());
    this.recorder = new TimelineUpdateRecorder(this.source, coherent);
    this.source.registerDataChangeListener(this.recorder);
  }
  apply(next: ChatTimelineEntryVO[], reload: boolean = false): void {
    const start = this.recorder.events.length;
    this.source.applyDiff(next.slice());
    expect(this.source.totalCount()).assertEqual(next.length);
    expect(timelineSnapshot(this.source.getAllEntries())).assertEqual(timelineSnapshot(next));
    const events = this.recorder.events.slice(start);
    expect(events.filter((event: TimelineNotification) => event.kind === 'reload').length).assertEqual(reload ? 1 : 0);
    if (reload) expect(events.length).assertEqual(1);
  }
}
