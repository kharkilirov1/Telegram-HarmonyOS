// Folder chat pagination — asks TDLib to load one chatListFolder page.
//
// TDLib answers a loadChats(chatListFolder) by pushing the usual updateNewChat /
// updateChatAddedToList(chatListFolder) events, so this use case only owns the request: it never
// mutates the store. The chat folder reducer mirrors the membership those updates describe.
//
// Dedupe rules: one request per folder in flight, and a short cooldown after a request because
// TDLib may answer with no new chats (the folder is exhausted) and the list keeps scrolling.

import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { createLoadChatsCommand } from '../../core/model/AppCommand';

export const FOLDER_LOAD_PAGE_SIZE: number = 20;
export const FOLDER_LOAD_COOLDOWN_MS: number = 1500;

export class LoadFolderChatsUseCase {
  private readonly store: AppStore;
  private readonly gateway: TdGatewayPort;
  private inFlight: Set<number> = new Set<number>();
  private lastRequestAt: Map<number, number> = new Map<number, number>();
  private isActive: boolean = true;
  private now: () => number;

  constructor(store: AppStore, gateway: TdGatewayPort, now: () => number = (): number => Date.now()) {
    this.store = store;
    this.gateway = gateway;
    this.now = now;
  }

  cancel(): void {
    this.isActive = false;
    this.inFlight.clear();
    this.lastRequestAt.clear();
  }

  isRequesting(folderId: number): boolean {
    return this.inFlight.has(folderId);
  }

  // Returns true when a request was issued; false when it was skipped by a guard.
  request(folderId: number, limit: number = FOLDER_LOAD_PAGE_SIZE): boolean {
    if (!this.isActive || folderId <= 0) {
      return false;
    }
    if (this.inFlight.has(folderId)) {
      return false;
    }
    const requestedAt = this.lastRequestAt.get(folderId);
    if (requestedAt !== undefined && this.now() - requestedAt < FOLDER_LOAD_COOLDOWN_MS) {
      return false;
    }
    this.inFlight.add(folderId);
    this.lastRequestAt.set(folderId, this.now());
    this.gateway.send(createLoadChatsCommand(limit, 'folder', folderId))
      .then((): void => {
        this.inFlight.delete(folderId);
      })
      .catch((_error: Object): void => {
        this.inFlight.delete(folderId);
      });
    return true;
  }
}

export function createLoadFolderChatsUseCase(store: AppStore, gateway: TdGatewayPort): LoadFolderChatsUseCase {
  return new LoadFolderChatsUseCase(store, gateway);
}
