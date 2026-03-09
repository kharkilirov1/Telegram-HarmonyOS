// loadProfileInfo — fetches getUserFullInfo / getSupergroupFullInfo from TDLib
// Direct responses are manually dispatched to store (Lesson #18)

import { getTdGatewayAdapter } from '../../infra/td/adapter/TdGatewayAdapter';
import { getAppCoreRuntime } from '../../app/bootstrap/AppCoreRuntime';
import {
  createGetUserFullInfoCommand,
  createGetSupergroupFullInfoCommand
} from '../../core/model/AppCommand';
import { UserFullInfoEvent, ChatFullInfoEvent, AnyAppEvent } from '../../core/model/AppEvent';
import { TdObject, tdGetString, tdGetNumber } from '../../core/utils/tdAccessors';
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
    hilog.info(DOMAIN, TAG, 'getSupergroupFullInfo chatId=%{public}d members=%{public}d', chatId, memberCount);

    const event = new ChatFullInfoEvent();
    event.chatId = chatId;
    event.description = description;
    event.memberCount = memberCount;
    event.timestamp = Date.now();

    const events: AnyAppEvent[] = [event];
    const runtime = getAppCoreRuntime();
    runtime.getStore().dispatchBatch(events);
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'getSupergroupFullInfo failed: %{public}s', String(e));
  }
}
