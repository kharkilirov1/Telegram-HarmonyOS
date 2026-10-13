import { AppStore } from '../../../core/store/AppStore';
import { TdGatewayPort } from '../../../domain/ports/TdGatewayPort';
import { ChatOpenLease } from '../../../domain/usecases/ChatOpenLease';

let nextChatNavigationToken: number = 0;

export class ChatScreenRouteParams {
  readonly chatId: number;
  readonly chatTitle: string;
  readonly accountStore: AppStore;
  readonly gateway: TdGatewayPort;
  readonly navigationToken: number;
  readonly openLease: ChatOpenLease;
  readonly entryUnreadCount?: number;
  readonly entryLastReadInboxMessageId?: string;
  private readonly accountScope: AppStore;

  constructor(chatId: number, chatTitle: string, store: AppStore, gateway: TdGatewayPort) {
    this.chatId = chatId;
    this.chatTitle = chatTitle;
    this.accountStore = store;
    this.gateway = gateway;
    this.accountScope = store.createScope();
    this.navigationToken = ++nextChatNavigationToken;
    this.openLease = new ChatOpenLease(chatId, gateway);
    const chat = this.accountScope.getState().chats.chats.get(chatId);
    this.entryUnreadCount = chat?.unreadCount;
    this.entryLastReadInboxMessageId = chat?.lastReadInboxMessageId;
  }

  isCurrentAccount(store: AppStore): boolean {
    return Number.isSafeInteger(this.chatId) && this.chatId !== 0 &&
      this.accountStore === store && this.accountScope.isScopeCurrent();
  }
}
