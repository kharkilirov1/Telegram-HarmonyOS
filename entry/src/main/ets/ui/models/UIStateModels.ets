// UIStateModels — @ObservedV2 singletons for V2 component reactivity
//
// Replaces @StorageLink/@StorageProp for shell pages migrated to @ComponentV2.
// AppStoreBridge pushes to both AppStorage (for legacy V1 pages) and these
// singletons (for V2 pages) during the transition period.

// ─── Navigation / Tab / Active Chat ───

@ObservedV2
class NavigationUIState {
  @Trace mainTabIndex: number = 2;
  @Trace chatScreenVisible: boolean = false;
  @Trace chatNavLockUntil: number = 0;
  @Trace activeChatId: number = 0;
  @Trace activeChatTitle: string = '';
  @Trace glassMode: string = 'auto';
}

export const navigationUIState: NavigationUIState = new NavigationUIState();

// ─── Chats / Connection ───

@ObservedV2
class ChatsUIState {
  @Trace connectionStatus: string = 'connecting';
  @Trace chatsCount: number = 0;
  @Trace chatsIsLoading: boolean = false;
  @Trace chatsHasMore: boolean = true;
  @Trace chatsLoadPhase: string = 'idle';
  @Trace totalUnread: number = 0;
}

export const chatsUIState: ChatsUIState = new ChatsUIState();
