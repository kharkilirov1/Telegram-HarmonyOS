// UIStateModels — @ObservedV2 синглтоны для UI state (Фаза 2 миграции)
//
// Замена @StorageLink / AppStorage-привязок в V2-компонентах.
// AppStoreBridge синхронизирует эти модели при каждом изменении AppStore.
//
// Паттерн использования в @ComponentV2:
//   private chatsState = chatsUIState;
//   build() { ... this.chatsState.connectionStatus ... }

@ObservedV2
export class ChatsUIState {
  @Trace connectionStatus: string = 'connecting';
  @Trace chatsCount: number = 0;
  @Trace chatsIsLoading: boolean = false;
  @Trace chatsHasMore: boolean = true;
  @Trace chatsLoadPhase: string = 'idle';
  @Trace totalUnreadCount: number = 0;
}

@ObservedV2
export class NavigationUIState {
  @Trace mainTabIndex: number = 2;
  @Trace chatScreenVisible: boolean = false;
  @Trace glassMode: string = 'auto';
}

@ObservedV2
export class ChatUIState {
  @Trace activeChatId: number = 0;
  @Trace activeChatTitle: string = '';
}

// ─── Singletons ───

export const chatsUIState: ChatsUIState = new ChatsUIState();
export const navigationUIState: NavigationUIState = new NavigationUIState();
export const chatUIState: ChatUIState = new ChatUIState();
