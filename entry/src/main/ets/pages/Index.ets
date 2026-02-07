import { TDLibClient } from '../services/TDLibClient';
import { AuthController } from '../controllers/AuthController';
import { MessagesController } from '../controllers/MessagesController';
import { FileController } from '../controllers/FileController';
import { NotificationCenter, EventId } from '../controllers/NotificationCenter';
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
    // Initialize all layers in order
    TDLibClient.getInstance().initialize();
    AuthController.getInstance();
    MessagesController.getInstance();
    FileController.getInstance();

    NotificationCenter.getInstance()
      .addObserver(EventId.AUTH_STATE_CHANGED, this.authHandler);
  }

  aboutToDisappear(): void {
    NotificationCenter.getInstance()
      .removeObserver(EventId.AUTH_STATE_CHANGED, this.authHandler);
    TDLibClient.getInstance().destroy();
  }

  @Builder
  routeMap(name: string, param: Object) {
    if (name === 'LoginCode') {
      VerifyCodePage({ phoneNumber: (param as string) || '' })
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
}
