import { ChatTimelineEntryVO } from '../../../../main/ets/ui/pages/chat/ChatTimelineVO';
import { TimelineTransactionFixture } from '../TimelineTransactionFixture';

export const TIMELINE_UPDATE_ROUTE: string = 'SyntheticTimelineUpdateRoute';

export class TimelineUpdateFixture {
  static current: TimelineTransactionFixture = new TimelineTransactionFixture();
  static filesDir: string = '';
  static rows(): number[] {
    const ids: number[] = [];
    for (let index = 1; index <= 80; index++) ids.push(index * 10);
    return ids;
  }
  static prepare(): void {
    TimelineUpdateFixture.current.dispose();
    const fixture = new TimelineTransactionFixture();
    // Mount can emit index0 before the scenario positions the List. Protect
    // setup explicitly; the threshold case clears this before its real edit.
    fixture.blockAutoPaginationUntilUserScroll = true;
    fixture.guardProgrammaticScroll();
    // Populate before mounting. Actual transaction projection/DataSource run;
    // no history or transport capability is installed.
    fixture.apply(TimelineUpdateFixture.rows());
    TimelineUpdateFixture.current = fixture;
  }
}

@ComponentV2
struct SyntheticTimelineRow {
  @Require @Param entry: ChatTimelineEntryVO;
  build() {
    Text(this.entry.kind === 'message' ? this.entry.message.text : this.entry.dateText)
      .fontSize(16)
      .maxLines(2)
      .width('100%')
      .height(this.entry.kind === 'date' ? 32 : (this.entry.message.messageId === '150' ? 72 : 48))
      .padding({ left: 12, right: 12 })
      .backgroundColor(this.entry.kind === 'date' ? 0xFFDDDDDD : 0xFFFAFAFA)
      .fontColor(0xFF111111)
      .id('timeline-update-' + this.entry.stableKey)
  }
}

// Dedicated bounded native List. Uses production DataSource, projection, stamped
// LazyForEach key and scroll/transaction owners. Rows deliberately expose simple
// geometry/text instead of production bubbles, media or account capabilities.
@ComponentV2
export struct TimelineUpdateFixtureView {
  private fixture: TimelineTransactionFixture = TimelineUpdateFixture.current;
  aboutToAppear(): void { this.fixture.mounted = true; }
  aboutToDisappear(): void { this.fixture.dispose(); }
  build() {
    NavDestination() {
      Column({ space: 4 }) {
        Text('Synthetic timeline; no account or transport').fontSize(14).height(32)
        List({ scroller: this.fixture.listScroller }) {
          LazyForEach(this.fixture.dataSource, (entry: ChatTimelineEntryVO) => {
            ListItem() { SyntheticTimelineRow({ entry: entry }) }
          }, (entry: ChatTimelineEntryVO) => entry.key)
        }
        .id('timeline-update-list')
        .width('100%')
        .height(360)
        .cachedCount(30)
        .listDirection(Axis.Vertical)
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)
        .maintainVisibleContentPosition(true)
        .onDidScroll((offset: number, state: ScrollState) => this.fixture.onDidScroll(offset, state))
        .onScrollIndex((start: number, end: number) => this.fixture.onScrollIndex(start, end))
        .onTouch((event: TouchEvent) => this.fixture.touch(event))
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
  }
}
