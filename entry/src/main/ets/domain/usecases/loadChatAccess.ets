// Hydrate membership from direct group responses; boosts from typed FullInfo.
// TDLib: getSupergroup(supergroup_id:int53) / getBasicGroup(basic_group_id:int53).

import { AppStore } from '../../core/store/AppStore';
import { createGetSupergroupCommand, createGetBasicGroupCommand, createGetChatCommand, createGetSupergroupFullInfoCommand } from '../../core/model/AppCommand';
import { createGroupAccessUpdatedEvent, createChatUpdatedEvent, createSupergroupBoostsUpdatedEvent, createSupergroupSlowmodeUpdatedEvent } from '../../core/model/AppEvent';
import { GroupAccessDto, GroupKind, GroupSendPermissionsDto, SupergroupBoostsDto, SupergroupSlowmodeDto, createGroupAccessDtoFromTd, createSupergroupBoostsDtoFromTd, createSupergroupSlowmodeDtoFromTd } from '../../core/model/dto/GroupAccessDto';
import { ChatUpdateDto } from '../../core/model/dto/ChatDto';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

class SupersededFullInfoError extends Error {}

export class LoadChatAccessUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private inFlight: Map<string, Promise<void>> = new Map<string, Promise<void>>();
  private fullInfoAccess: Map<number, GroupAccessDto | undefined> = new Map<number, GroupAccessDto | undefined>();

  constructor(store: AppStore, gateway: TdGatewayPort) {
    // Capture this account even if the caller supplies the root store. Never
    // reacquire a global store/gateway after an await or a session reset.
    this.store = store.createScope();
    this.gateway = gateway;
  }

  load(kind: GroupKind, groupId: number): Promise<void> {
    if ((kind !== 'supergroup' && kind !== 'basicGroup') ||
      !Number.isSafeInteger(groupId) || groupId <= 0) {
      return Promise.reject(new Error('Invalid group kind or groupId'));
    }
    const key = `${kind}:${groupId}`;
    const existing = this.inFlight.get(key);
    if (existing !== undefined) return existing;

    const captured = this.getAccess(kind, groupId);
    // Publish singleflight before gateway.send can synchronously reenter load.
    // Cleanup is part of the returned promise, including synchronous send errors.
    const request = Promise.resolve().then(() => this.hydrate(kind, groupId, captured)).finally(() => {
      this.inFlight.delete(key);
    });
    this.inFlight.set(key, request);
    return request;
  }

  private getAccess(kind: GroupKind, groupId: number): GroupAccessDto | undefined {
    const chats = this.store.getState().chats;
    return kind === 'supergroup' ? chats.supergroupAccess.get(groupId) : chats.basicGroupAccess.get(groupId);
  }

  loadPermissions(chatId: number): Promise<void> {
    if (!Number.isSafeInteger(chatId) || chatId === 0) return Promise.reject(new Error('Invalid chatId'));
    const key = `chat:${chatId}`;
    const existing = this.inFlight.get(key);
    if (existing !== undefined) return existing;
    const chat = this.store.getState().chats.chats.get(chatId);
    if (chat === undefined) return Promise.reject(new Error('Chat no longer available'));
    // Only hydrate an absent snapshot. A live snapshot, even all-false, wins.
    if (chat.sendPermissions !== undefined) return Promise.resolve();
    const request = Promise.resolve().then(() => this.hydratePermissions(chatId)).finally(() => {
      this.inFlight.delete(key);
    });
    this.inFlight.set(key, request);
    return request;
  }

  loadBoosts(groupId: number): Promise<void> {
    if (!Number.isSafeInteger(groupId) || groupId <= 0) return Promise.reject(new Error('Invalid supergroupId'));
    const key = `fullInfo:${groupId}`;
    const existing = this.inFlight.get(key);
    if (existing !== undefined) return existing;
    const captured = this.store.getState().chats.supergroupBoosts.get(groupId);
    if (captured !== undefined) return Promise.resolve();
    const access = this.getAccess('supergroup', groupId);
    const slowmode = this.store.getState().chats.supergroupSlowmode.get(groupId);
    const request = Promise.resolve().then(() => this.hydrateFullInfo(groupId, captured, access, slowmode, false)).finally(() => {
      this.inFlight.delete(key);
      this.fullInfoAccess.delete(groupId);
    });
    this.fullInfoAccess.set(groupId, access);
    this.inFlight.set(key, request);
    return request;
  }

  loadSlowmode(groupId: number): Promise<void> {
    if (!Number.isSafeInteger(groupId) || groupId <= 0) return Promise.reject(new Error('Invalid supergroupId'));
    return this.loadSlowmodeOnce(groupId, true);
  }

  private loadSlowmodeOnce(groupId: number, refreshSuperseded: boolean): Promise<void> {
    const key = `fullInfo:${groupId}`;
    const access = this.getAccess('supergroup', groupId);
    const existing = this.inFlight.get(key);
    if (existing !== undefined) {
      const previousAccess = this.fullInfoAccess.get(groupId);
      const canRefresh = (): boolean => refreshSuperseded && previousAccess !== access &&
        this.getAccess('supergroup', groupId) === access && access?.isSlowModeEnabled === true &&
        this.store.isScopeCurrent();
      // Join the old read for cleanup, then hydrate this newer owner once.
      // Rejections from the network remain explicit-retry failures.
      return existing.then((): Promise<void> => {
        if (this.store.getState().chats.supergroupSlowmode.get(groupId) !== undefined) return Promise.resolve();
        if (canRefresh()) return this.loadSlowmodeOnce(groupId, false);
        throw new SupersededFullInfoError('Slowmode FullInfo unavailable');
      }, (error: Error): Promise<void> => {
        if (error instanceof SupersededFullInfoError && canRefresh()) return this.loadSlowmodeOnce(groupId, false);
        throw error;
      });
    }
    const slowmode = this.store.getState().chats.supergroupSlowmode.get(groupId);
    if (slowmode !== undefined) return Promise.resolve();
    const boosts = this.store.getState().chats.supergroupBoosts.get(groupId);
    const request = Promise.resolve().then(() => this.hydrateFullInfo(groupId, boosts, access, slowmode, true)).finally(() => {
      this.inFlight.delete(key);
      this.fullInfoAccess.delete(groupId);
    });
    this.fullInfoAccess.set(groupId, access);
    this.inFlight.set(key, request);
    return request;
  }

  private async hydrateFullInfo(groupId: number, capturedBoosts: SupergroupBoostsDto | undefined,
    capturedAccess: GroupAccessDto | undefined, capturedSlowmode: SupergroupSlowmodeDto | undefined,
    requireSlowmode: boolean): Promise<void> {
    const response = await this.gateway.send(createGetSupergroupFullInfoCommand(groupId));
    if (!(response instanceof TdObject)) throw new Error('Invalid supergroup FullInfo response');
    // FullInfo has no ID: the request owns this groupId, never the active page.
    const boosts = createSupergroupBoostsDtoFromTd(response, groupId);
    const slowmode = createSupergroupSlowmodeDtoFromTd(response, groupId);
    if (requireSlowmode ? slowmode === undefined : boosts === undefined) {
      throw new Error('Missing or invalid supergroup FullInfo');
    }
    // Boosts and the slow-mode receipt have independent live-update owners.
    if (boosts !== undefined) await this.store.dispatch(createSupergroupBoostsUpdatedEvent(boosts), (): boolean => {
      return this.store.getState().chats.supergroupBoosts.get(groupId) === capturedBoosts;
    });
    if (slowmode !== undefined) await this.store.dispatch(createSupergroupSlowmodeUpdatedEvent(slowmode), (): boolean => {
      return this.getAccess('supergroup', groupId) === capturedAccess &&
        this.store.getState().chats.supergroupSlowmode.get(groupId) === capturedSlowmode;
    });
    if (requireSlowmode && this.store.getState().chats.supergroupSlowmode.get(groupId) === undefined) {
      throw new SupersededFullInfoError('Slowmode FullInfo superseded');
    }
  }

  private async hydratePermissions(chatId: number): Promise<void> {
    const response = await this.gateway.send(createGetChatCommand(chatId));
    if (!(response instanceof TdObject) || response.getType() !== 'chat' ||
      response.getTopLevelNumberStrict('id') !== chatId) throw new Error('Invalid chat permissions response');
    const permissions = response.getTopLevelObjectStrict('permissions');
    if (permissions === undefined || permissions.getTopLevelBooleanStrict('can_send_basic_messages') === undefined) {
      throw new Error('Missing chat permissions');
    }
    const updates = new ChatUpdateDto();
    updates.sendPermissions = GroupSendPermissionsDto.fromTd(permissions);
    updates.canSendBasicMessages = updates.sendPermissions.canSendBasicMessages;
    await this.store.dispatch(createChatUpdatedEvent(chatId, updates), (): boolean => {
      const current = this.store.getState().chats.chats.get(chatId);
      return current !== undefined && current.sendPermissions === undefined;
    });
  }

  private async hydrate(kind: GroupKind, groupId: number, captured: GroupAccessDto | undefined): Promise<void> {
    const command = kind === 'supergroup' ? createGetSupergroupCommand(groupId) : createGetBasicGroupCommand(groupId);
    const response = await this.gateway.send(command);
    if (!(response instanceof TdObject) || response.getType() !== kind) {
      throw new Error('Invalid group access response');
    }
    const access = createGroupAccessDtoFromTd(response, kind);
    if (access === undefined || access.kind !== kind || access.groupId !== groupId) {
      throw new Error('Invalid or mismatched group access response');
    }

    // Check the individual value, not the Map: unrelated group updates may clone
    // the Map. The check must run at dequeue, after any preceding live update.
    // AppStore's captured account scope also fences resets before/after enqueue.
    await this.store.dispatch(createGroupAccessUpdatedEvent(access), (): boolean => {
      return this.getAccess(kind, groupId) === captured;
    });
  }
}

export function createLoadChatAccessUseCase(store: AppStore, gateway: TdGatewayPort): LoadChatAccessUseCase {
  return new LoadChatAccessUseCase(store, gateway);
}
