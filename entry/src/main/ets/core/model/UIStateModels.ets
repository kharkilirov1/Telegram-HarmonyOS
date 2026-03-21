// UIStateModels — @ObservedV2 reactive state models for V2 components
//
// Используются вместо @StorageLink в @ComponentV2 компонентах.
// AppStoreBridge синхронизирует AppStore → authUIState (и другие синглтоны).
// V2 компоненты читают поля напрямую — @Trace обеспечивает реактивность.

import { AuthStatus } from './AppState';

// ─── Auth UI State ───

@ObservedV2
export class AuthUIState {
  @Trace status: string = 'notInitialized';
  @Trace phoneNumber: string = '';
  @Trace codeType: string = 'sms';
  @Trace codeLength: number = 5;
  @Trace codeTimeout: number = 60;
  @Trace nextCodeType: string = 'call';
  @Trace passwordHint: string = '';
  @Trace qrCodeLink: string = '';
  @Trace error: string = '';
}

// ─── Singletons ───
// Импортируй и читай в build() @ComponentV2 — реактивность через @Trace

export const authUIState: AuthUIState = new AuthUIState();
