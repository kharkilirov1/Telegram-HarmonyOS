// loadProfileInfo — fetches getUserFullInfo / getSupergroupFullInfo from TDLib
// Direct responses are manually dispatched to store (Lesson #18)

import { getTdGatewayAdapter } from '../../infra/td/adapter/TdGatewayAdapter';
import { getAppCoreRuntime } from '../../app/bootstrap/AppCoreRuntime';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import {
  createGetUserFullInfoCommand,
  createGetSupergroupFullInfoCommand,
  createGetBasicGroupFullInfoCommand
} from '../../core/model/AppCommand';
import { UserFullInfoEvent, ChatFullInfoEvent, AnyAppEvent } from '../../core/model/AppEvent';
import { TdObject, tdGetString, tdGetNumber, tdGetObject, tdGetArray } from '../../core/utils/tdAccessors';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0030;
const TAG = 'loadProfileInfo';

export type ProfileLoadStatus = 'loaded' | 'unavailable' | 'stale' | 'invalid';

export class ProfileLoadResult {
  readonly status: ProfileLoadStatus;
  readonly cause?: Object;

  constructor(status: ProfileLoadStatus, cause?: Object) {
    this.status = status;
    this.cause = cause;
  }
}

// Capture at navigation push or operation start, never after a transport wait.
// createScope on a revoked view deliberately keeps its original account epoch.
export class ProfileLoadContext {
  readonly accountStore: AppStore;
  readonly store: AppStore;
  readonly gateway: TdGatewayPort;

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.accountStore = store;
    this.store = store.createScope();
    this.gateway = gateway;
  }

  isCurrent(): boolean {
    return this.store.isScopeCurrent();
  }
}

export function captureProfileLoadContext(): ProfileLoadContext {
  const store = getAppCoreRuntime().getStore();
  return new ProfileLoadContext(store, getTdGatewayAdapter());
}

async function dispatchProfileInfo(owner: ProfileLoadContext, event: AnyAppEvent): Promise<ProfileLoadResult> {
  if (!owner.isCurrent()) return new ProfileLoadResult('stale');
  await owner.store.dispatchBatch([event], (): boolean => owner.isCurrent());
  return new ProfileLoadResult(owner.isCurrent() ? 'loaded' : 'stale');
}

export async function loadUserFullInfo(userId: number, context?: ProfileLoadContext): Promise<ProfileLoadResult> {
  if (!Number.isSafeInteger(userId) || userId <= 0) return new ProfileLoadResult('invalid');
  let owner: ProfileLoadContext | undefined = context;
  try {
    owner = owner ?? captureProfileLoadContext();
    if (!owner.isCurrent()) return new ProfileLoadResult('stale');
    const response = await owner.gateway.send(createGetUserFullInfoCommand(userId));
    if (!owner.isCurrent()) return new ProfileLoadResult('stale');
    if (!(response instanceof TdObject)) return new ProfileLoadResult('unavailable', new Error('Invalid profile response'));
    const tdResponse = response;
    const responseType = tdGetString(tdResponse, '@type');
    if (responseType !== 'userFullInfo') {
      hilog.warn(DOMAIN, TAG, 'getUserFullInfo unexpected type: %{public}s', responseType);
      return new ProfileLoadResult('unavailable', new Error('Unexpected profile response type'));
    }

    const bio = tdGetString(tdGetObject(tdResponse, 'bio'), 'text');
    hilog.info(DOMAIN, TAG, 'getUserFullInfo loaded userId=%{public}d', userId);

    const event = new UserFullInfoEvent();
    event.userId = userId;
    event.bio = bio;
    event.timestamp = Date.now();

    return await dispatchProfileInfo(owner, event);
  } catch (e) {
    if (owner !== undefined && !owner.isCurrent()) return new ProfileLoadResult('stale');
    hilog.warn(DOMAIN, TAG, 'getUserFullInfo unavailable userId=%{public}d', userId);
    return new ProfileLoadResult('unavailable', e);
  }
}

export async function loadSupergroupFullInfo(chatId: number, supergroupId: number, context?: ProfileLoadContext): Promise<ProfileLoadResult> {
  if (!Number.isSafeInteger(chatId) || chatId === 0 || !Number.isSafeInteger(supergroupId) || supergroupId <= 0) return new ProfileLoadResult('invalid');
  let owner: ProfileLoadContext | undefined = context;
  try {
    owner = owner ?? captureProfileLoadContext();
    if (!owner.isCurrent()) return new ProfileLoadResult('stale');
    const response = await owner.gateway.send(createGetSupergroupFullInfoCommand(supergroupId));
    if (!owner.isCurrent()) return new ProfileLoadResult('stale');
    if (!(response instanceof TdObject)) return new ProfileLoadResult('unavailable', new Error('Invalid profile response'));
    const tdResponse = response;
    const responseType = tdGetString(tdResponse, '@type');
    if (responseType !== 'supergroupFullInfo') {
      hilog.warn(DOMAIN, TAG, 'getSupergroupFullInfo unexpected type: %{public}s', responseType);
      return new ProfileLoadResult('unavailable', new Error('Unexpected profile response type'));
    }

    const description = tdGetString(tdResponse, 'description');
    const memberCount = tdGetNumber(tdResponse, 'member_count');
    const administratorCount = tdGetNumber(tdResponse, 'administrator_count');

    // invite_link is a chatInviteLink object with an 'invite_link' string field
    let inviteLink = '';
    const inviteLinkObj = tdGetObject(tdResponse, 'invite_link');
    if (inviteLinkObj && inviteLinkObj.hasType()) {
      inviteLink = tdGetString(inviteLinkObj, 'invite_link');
    }

    hilog.info(DOMAIN, TAG, 'getSupergroupFullInfo chatId=%{public}d members=%{public}d admins=%{public}d link=%{public}s',
      chatId, memberCount, administratorCount, inviteLink.length > 0 ? 'yes' : 'no');

    const event = new ChatFullInfoEvent();
    event.chatId = chatId;
    event.description = description;
    event.memberCount = memberCount;
    event.administratorCount = administratorCount;
    event.inviteLink = inviteLink;
    event.timestamp = Date.now();

    return await dispatchProfileInfo(owner, event);
  } catch (e) {
    if (owner !== undefined && !owner.isCurrent()) return new ProfileLoadResult('stale');
    hilog.warn(DOMAIN, TAG, 'getSupergroupFullInfo unavailable');
    return new ProfileLoadResult('unavailable', e);
  }
}

// Basic groups keep no member_count in full info — the count is the length of
// the returned members list (TDLib basicGroupFullInfo contract).
export async function loadBasicGroupFullInfo(chatId: number, basicGroupId: number, context?: ProfileLoadContext): Promise<ProfileLoadResult> {
  if (!Number.isSafeInteger(chatId) || chatId === 0 || !Number.isSafeInteger(basicGroupId) || basicGroupId <= 0) return new ProfileLoadResult('invalid');
  let owner: ProfileLoadContext | undefined = context;
  try {
    owner = owner ?? captureProfileLoadContext();
    if (!owner.isCurrent()) return new ProfileLoadResult('stale');
    const response = await owner.gateway.send(createGetBasicGroupFullInfoCommand(basicGroupId));
    if (!owner.isCurrent()) return new ProfileLoadResult('stale');
    if (!(response instanceof TdObject)) return new ProfileLoadResult('unavailable', new Error('Invalid profile response'));
    const tdResponse = response;
    const responseType = tdGetString(tdResponse, '@type');
    if (responseType !== 'basicGroupFullInfo') {
      hilog.warn(DOMAIN, TAG, 'getBasicGroupFullInfo unexpected type: %{public}s', responseType);
      return new ProfileLoadResult('unavailable', new Error('Unexpected profile response type'));
    }

    const description = tdGetString(tdResponse, 'description');
    const members = tdGetArray(tdResponse, 'members');
    let administratorCount = 0;
    for (const member of members) {
      const statusType = tdGetString(tdGetObject(member, 'status'), '@type');
      if (statusType === 'chatMemberStatusCreator' || statusType === 'chatMemberStatusAdministrator') {
        administratorCount++;
      }
    }

    let inviteLink = '';
    const inviteLinkObj = tdGetObject(tdResponse, 'invite_link');
    if (inviteLinkObj && inviteLinkObj.hasType()) {
      inviteLink = tdGetString(inviteLinkObj, 'invite_link');
    }

    hilog.info(DOMAIN, TAG, 'getBasicGroupFullInfo chatId=%{public}d members=%{public}d admins=%{public}d',
      chatId, members.length, administratorCount);

    const event = new ChatFullInfoEvent();
    event.chatId = chatId;
    event.description = description;
    event.memberCount = members.length;
    event.administratorCount = administratorCount;
    event.inviteLink = inviteLink;
    event.timestamp = Date.now();

    return await dispatchProfileInfo(owner, event);
  } catch (e) {
    if (owner !== undefined && !owner.isCurrent()) return new ProfileLoadResult('stale');
    hilog.warn(DOMAIN, TAG, 'getBasicGroupFullInfo unavailable');
    return new ProfileLoadResult('unavailable', e);
  }
}
