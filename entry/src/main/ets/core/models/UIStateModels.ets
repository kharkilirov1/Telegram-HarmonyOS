// UIStateModels — @ObservedV2 синглтоны для V2-компонентов
//
// Фаза 0 миграции на V2: создаём типизированные реактивные модели
// как замену AppStorage/@StorageProp в V2-компонентах.
//
// Синглтоны обновляются из AppStoreBridge параллельно с AppStorage
// (AppStorage остаётся как fallback для V1-компонентов).
//
// Использование в V2-компоненте:
//   import { authUIState } from '../../core/models/UIStateModels';
//   @ComponentV2 struct MyComp {
//     build() { Text(authUIState.authStatus) }
//   }

@ObservedV2
export class AuthUIState {
  @Trace authStatus: string = 'notInitialized';
  @Trace phone: string = '';
  @Trace codeType: string = 'sms';
  @Trace codeLength: number = 5;
  @Trace codeTimeout: number = 60;
  @Trace codeNextType: string = 'call';
  @Trace passwordHint: string = '';
}

@ObservedV2
export class ChatsUIState {
  @Trace connectionStatus: string = 'connecting';
  @Trace chatsCount: number = 0;
  @Trace chatsIsLoading: boolean = false;
  @Trace chatsHasMore: boolean = true;
  @Trace chatsLoadPhase: string = 'idle';
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

// ─── Синглтоны ───
// Импортируй нужный синглтон в компоненте — изменения будут реактивными.

export const authUIState = new AuthUIState();
export const chatsUIState = new ChatsUIState();
export const navigationUIState = new NavigationUIState();
export const chatUIState = new ChatUIState();
