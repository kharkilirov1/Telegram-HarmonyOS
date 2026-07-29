// loadProfileInfo — fetches getUserFullInfo / getSupergroupFullInfo from TDLib
// Direct responses are manually dispatched to store (Lesson #18)

import { getTdGatewayAdapter } from '../../infra/td/adapter/TdGatewayAdapter';
import { getAppCoreRuntime } from '../../app/bootstrap/AppCoreRuntime';
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

export async function loadUserFullInfo(userId: number): Promise<void> {
  if (userId <= 0) return;
  try {
    const adapter = getTdGatewayAdapter();
    const response = await adapter.send(createGetUserFullInfoCommand(userId));
    const tdResponse = response as TdObject;
    const responseType = tdGetString(tdResponse, '@type');
    if (responseType !== 'userFullInfo') {
      hilog.warn(DOMAIN, TAG, 'getUserFullInfo unexpected type: %{public}s', responseType);
      return;
    }

    const bio = tdGetString(tdResponse, 'bio');
    hilog.info(DOMAIN, TAG, 'getUserFullInfo userId=%{public}d bio="%{public}s"', userId, bio.substring(0, 50));

    const event = new UserFullInfoEvent();
    event.userId = userId;
    event.bio = bio;
    event.timestamp = Date.now();

    const events: AnyAppEvent[] = [event];
    const runtime = getAppCoreRuntime();
    runtime.getStore().dispatchBatch(events);
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'getUserFullInfo failed for userId=%{public}d: %{public}s', userId, String(e));
  }
}

export async function loadSupergroupFullInfo(chatId: number, supergroupId: number): Promise<void> {
  if (supergroupId <= 0) return;
  try {
    const adapter = getTdGatewayAdapter();
    const response = await adapter.send(createGetSupergroupFullInfoCommand(supergroupId));
    const tdResponse = response as TdObject;
    const responseType = tdGetString(tdResponse, '@type');
    if (responseType !== 'supergroupFullInfo') {
      hilog.warn(DOMAIN, TAG, 'getSupergroupFullInfo unexpected type: %{public}s', responseType);
      return;
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

    const events: AnyAppEvent[] = [event];
    const runtime = getAppCoreRuntime();
    runtime.getStore().dispatchBatch(events);
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'getSupergroupFullInfo failed: %{public}s', String(e));
  }
}

// Basic groups keep no member_count in full info — the count is the length of
// the returned members list (TDLib basicGroupFullInfo contract).
export async function loadBasicGroupFullInfo(chatId: number, basicGroupId: number): Promise<void> {
  if (basicGroupId <= 0) return;
  try {
    const adapter = getTdGatewayAdapter();
    const response = await adapter.send(createGetBasicGroupFullInfoCommand(basicGroupId));
    const tdResponse = response as TdObject;
    const responseType = tdGetString(tdResponse, '@type');
    if (responseType !== 'basicGroupFullInfo') {
      hilog.warn(DOMAIN, TAG, 'getBasicGroupFullInfo unexpected type: %{public}s', responseType);
      return;
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

    const events: AnyAppEvent[] = [event];
    const runtime = getAppCoreRuntime();
    runtime.getStore().dispatchBatch(events);
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'getBasicGroupFullInfo failed: %{public}s', String(e));
  }
}
