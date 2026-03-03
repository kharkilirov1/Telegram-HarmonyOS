// UserNormalizer — handles user-related TDLib updates
// Extracted from EventNormalizer to prevent god-file growth

import {
  AnyAppEvent,
  UserUpdatedEvent,
  UserStatusChangedEvent
} from '../../model/AppEvent';
import { createUserDtoFromTd, parseUserStatus } from '../../model/dto/UserDto';
import { TdObject } from '../../../models/TdTypes';
import { tdGetNumber, tdGetObject } from '../../utils/tdAccessors';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0003;
const TAG = 'UserNormalizer';

function pushUserUpdatedEvent(events: AnyAppEvent[], user: TdObject): void {
  const userId = tdGetNumber(user, 'id');
  if (!userId) return;

  try {
    const userDto = createUserDtoFromTd(user);

    const event = new UserUpdatedEvent();
    event.userId = userId;
    event.userData = userDto;
    event.timestamp = Date.now();
    events.push(event);
  } catch (error) {
    hilog.error(DOMAIN, TAG, 'Failed to parse user: %{public}s', String(error));
  }
}

function handleUser(events: AnyAppEvent[], update: TdObject): void {
  const user = tdGetObject(update, 'user');
  pushUserUpdatedEvent(events, user);
}

function handleDirectUser(events: AnyAppEvent[], update: TdObject): void {
  // Direct response to getUser has shape {"@type":"user", ...fields}
  pushUserUpdatedEvent(events, update);
}

function handleUserStatus(events: AnyAppEvent[], update: TdObject): void {
  const userId = tdGetNumber(update, 'user_id');
  if (!userId) return;

  const statusObj = tdGetObject(update, 'status');
  const status = parseUserStatus(statusObj);

  const event = new UserStatusChangedEvent();
  event.userId = userId;
  event.status = status;
  event.timestamp = Date.now();
  events.push(event);
}

export function registerUserHandlers(
  handlers: Map<string, (events: AnyAppEvent[], update: TdObject) => void>
): void {
  handlers.set('updateUser', handleUser);
  handlers.set('user', handleDirectUser);
  handlers.set('updateUserStatus', handleUserStatus);
}
