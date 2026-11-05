// A5: check a username before saving, the way iOS does while typing. TDLib answers with a typed
// checkChatUsernameResult; local validation short-circuits so obviously invalid input never round-trips.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createCheckChatUsernameCommand } from '../../core/model/AppCommand';
import { TdObject } from '../../core/utils/tdAccessors';
import { isValidProfileUsername } from './editProfile';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x00A5;
const TAG = 'CheckUsername';

export type UsernameAvailability =
  'idle' | 'checking' | 'available' | 'invalid' | 'occupied' | 'purchasable' | 'tooMany' | 'groupsUnavailable' | 'unknown';

// The TDLib result object carries only its type; the suffix is the stable part.
export function usernameAvailabilityFromTd(tdResult: TdObject | undefined): UsernameAvailability {
  if (tdResult === undefined) {
    return 'unknown';
  }
  const type = tdResult.getTopLevelStringStrict('@type');
  switch (type) {
    case 'checkChatUsernameResultOk':
      return 'available';
    case 'checkChatUsernameResultUsernameInvalid':
      return 'invalid';
    case 'checkChatUsernameResultUsernameOccupied':
      return 'occupied';
    case 'checkChatUsernameResultUsernamePurchasable':
      return 'purchasable';
    case 'checkChatUsernameResultPublicChatsTooMany':
      return 'tooMany';
    case 'checkChatUsernameResultPublicGroupsUnavailable':
      return 'groupsUnavailable';
    default:
      return 'unknown';
  }
}

export function usernameAvailabilityMessage(availability: UsernameAvailability): string {
  switch (availability) {
    case 'available':
      return 'Username is available';
    case 'invalid':
      return 'This username is invalid';
    case 'occupied':
      return 'This username is already taken';
    case 'purchasable':
      return 'This username can be bought on fragment.com';
    case 'tooMany':
      return 'Too many public chats use this name; make one private first';
    case 'groupsUnavailable':
      return 'Public groups are unavailable for this account';
    default:
      return '';
  }
}

export class CheckUsernameUseCase {
  private gateway: TdGatewayPort;
  // Every request carries a sequence number so a stale answer cannot overwrite a newer one.
  private sequence: number = 0;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  isCurrent(sequence: number): boolean {
    return sequence === this.sequence;
  }

  nextSequence(): number {
    this.sequence += 1;
    return this.sequence;
  }

  async check(chatId: number, username: string): Promise<UsernameAvailability> {
    const candidate = username.trim().replace(/^@/, '');
    if (chatId === 0 || candidate.length === 0) {
      return 'idle';
    }
    if (!isValidProfileUsername(candidate)) {
      return 'invalid';
    }
    try {
      const response = await this.gateway.send(createCheckChatUsernameCommand(chatId, candidate));
      if (!(response instanceof TdObject)) {
        return 'unknown';
      }
      return usernameAvailabilityFromTd(response);
    } catch (error) {
      hilog.info(DOMAIN, TAG, 'Username check settled with an error: %{public}s', String(error));
      return 'unknown';
    }
  }
}

export function createCheckUsernameUseCase(gateway: TdGatewayPort): CheckUsernameUseCase {
  return new CheckUsernameUseCase(gateway);
}
