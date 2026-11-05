// A5: current-user profile editing. TDLib: setName(first_name, last_name), setBio(bio),
// setUsername(username) — every method answers Ok. iOS counterpart: ProfileEditingController.
// Validation mirrors the TDLib/server contract so a rejected edit never costs a round trip.

import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AnyAppCommand,
  createSetProfileBioCommand,
  createSetProfileNameCommand,
  createSetProfileUsernameCommand
} from '../../core/model/AppCommand';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdObject } from '../../core/utils/tdAccessors';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x00A5;
const TAG = 'EditProfile';
export const PROFILE_NAME_PART_MAX_LENGTH = 64;
export const PROFILE_BIO_MAX_LENGTH = 70;
export const PROFILE_USERNAME_MIN_LENGTH = 5;
export const PROFILE_USERNAME_MAX_LENGTH = 32;

// TDLib usernames: 5..32 characters, latin letters, digits and underscores, must start with a letter.
export function isValidProfileUsername(username: string): boolean {
  return /^[A-Za-z][A-Za-z0-9_]{4,31}$/.test(username);
}

export function isValidProfileNamePart(value: string): boolean {
  return value.length <= PROFILE_NAME_PART_MAX_LENGTH;
}

export function isValidProfileBio(bio: string): boolean {
  return bio.length <= PROFILE_BIO_MAX_LENGTH;
}

function assertOkResponse(response: TdObject, what: string): void {
  if (!(response instanceof TdObject) || response.getTopLevelStringStrict('@type') !== 'ok') {
    throw new AppError(AppErrorKind.UNKNOWN, 'Profile update rejected', 'Unsupported ' + what + ' response',
      0, false);
  }
}

export class EditProfileUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async updateName(firstName: string, lastName: string = ''): Promise<void> {
    const first = firstName.trim();
    const last = lastName.trim();
    if (first.length === 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'First name is required', 'Input validation failed',
        400, false);
    }
    if (!isValidProfileNamePart(first) || !isValidProfileNamePart(last)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Name is too long', 'Input validation failed', 400, false);
    }
    await this.send(createSetProfileNameCommand(first, last), 'setName');
  }

  async updateBio(bio: string): Promise<void> {
    const value = bio.trim();
    if (!isValidProfileBio(value)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Bio is too long', 'Input validation failed', 400, false);
    }
    await this.send(createSetProfileBioCommand(value), 'setBio');
  }

  // An empty username removes it, exactly like the iOS "Delete username" action.
  async updateUsername(username: string): Promise<void> {
    const value = username.trim().replace(/^@/, '');
    if (value.length > 0 && !isValidProfileUsername(value)) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid username', 'Input validation failed', 400, false);
    }
    await this.send(createSetProfileUsernameCommand(value), 'setUsername');
  }

  private async send(command: AnyAppCommand, what: string): Promise<void> {
    try {
      const response = await this.gateway.send(command) as TdObject;
      assertOkResponse(response, what);
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, '%{public}s failed: %{public}s', what, err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to update the profile', err.message, 0, true);
    }
  }
}

export function createEditProfileUseCase(gateway: TdGatewayPort): EditProfileUseCase {
  return new EditProfileUseCase(gateway);
}
