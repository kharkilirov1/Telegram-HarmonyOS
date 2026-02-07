import { TDLibClient } from '../services/TDLibClient';
import { NotificationCenter, EventId } from '../controllers/NotificationCenter';
import { PhoneNumberPage } from './Login/PhoneNumberPage';
import { ChatListPage } from './Chat/ChatListPage';

@Entry
@ComponentV2
struct Index {
  @Local isAuthorized: boolean = false;
  @Provider('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  // Auth state handler — driven by NotificationCenter, not raw TDLib
  private authHandler = (args?: Record<string, Object>): void => {
    if (!args) return;
    const state = args['state'] as string;

    switch (state) {
      case 'authorizationStateWaitPhoneNumber':
        this.isAuthorized = false;
        this.navPathStack.clear();
        break;
      case 'authorizationStateWaitCode':
        this.navPathStack.pushPath({ name: 'LoginCode' });
        break;
      case 'authorizationStateWaitPassword':
        this.navPathStack.pushPath({ name: 'LoginPassword' });
        break;
      case 'authorizationStateReady':
        this.isAuthorized = true;
        this.navPathStack.clear();
        break;
      case 'authorizationStateClosed':
        this.isAuthorized = false;
        this.navPathStack.clear();
        break;
    }
  };

  aboutToAppear(): void {
    // Singletons already initialized in TelegramAbilityStage.onCreate()
    NotificationCenter.getInstance()
      .addObserver(EventId.AUTH_STATE_CHANGED, this.authHandler);
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance()
      .removeObserver(EventId.AUTH_STATE_CHANGED, this.authHandler);
    TDLibClient.getInstance().destroy();
  }

  build() {
    Navigation(this.navPathStack) {
      if (this.isAuthorized) {
        ChatListPage()
      } else {
        PhoneNumberPage()
      }
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
  }
}
