import { TDLibClient } from '../services/TDLibClient';
import { AuthorizationState } from '../models/User';
import { PhoneNumberPage } from './Login/PhoneNumberPage';
import { VerifyCodePage } from './Login/VerifyCodePage';
import { PasswordPage } from './Login/PasswordPage';
import { ChatListPage } from './Chat/ChatListPage';
import { ChatDetailPage } from './Chat/ChatDetailPage';

@Entry
@Component
struct Index {
  @State isAuthorized: boolean = false;
  @Provide('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.setupAuthHandler();
    TDLibClient.getInstance().initialize();
  }

  aboutToDisappear(): void {
    TDLibClient.getInstance().destroy();
  }

  @Builder
  routeMap(name: string, param: Object) {
    if (name === 'LoginCode') {
      VerifyCodePage({ phoneNumber: param as string })
    } else if (name === 'LoginPassword') {
      PasswordPage()
    } else if (name === 'ChatDetail') {
      ChatDetailPage({ chatId: param as number })
    }
  }

  build() {
    Navigation(this.navPathStack) {
      if (this.isAuthorized) {
        ChatListPage()
      } else {
        PhoneNumberPage()
      }
    }
    .navDestination(this.routeMap)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
  }

  private setupAuthHandler(): void {
    const client = TDLibClient.getInstance();

    client.on('updateAuthorizationState', (update: object) => {
      const data = update as Record<string, object>;
      const authState = data['authorization_state'] as Record<string, string>;
      const stateType = authState?.['@type'] || '';

      if (stateType === 'authorizationStateWaitPhoneNumber') {
        this.isAuthorized = false;
      } else if (stateType === 'authorizationStateWaitCode') {
        // Navigation handled by PhoneNumberPage
      } else if (stateType === 'authorizationStateWaitPassword') {
        this.navPathStack.pushPath({ name: 'LoginPassword' });
      } else if (stateType === 'authorizationStateReady') {
        this.isAuthorized = true;
        this.navPathStack.clear();
      } else if (stateType === 'authorizationStateClosed') {
        this.isAuthorized = false;
        this.navPathStack.clear();
      }
    });
  }
}
