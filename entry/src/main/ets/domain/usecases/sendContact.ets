// D26: sending a contact card. Validation mirrors TDLib: a number and at least one name part.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ShareContactPayload, createShareContactCommand } from '../../core/model/AppCommand';
import { TdObject } from '../../core/utils/tdAccessors';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x00D26;
const TAG = 'SendContact';

// Digits with an optional leading plus: enough to reject obvious junk without rejecting valid formats.
export function isValidContactPhone(phoneNumber: string): boolean {
  const value = phoneNumber.trim();
  if (value.length < 5 || value.length > 32) {
    return false;
  }
  return /^\+?[0-9 ()-]+$/.test(value) && (value.match(/[0-9]/g) ?? []).length >= 5;
}

export function isValidContactName(firstName: string, lastName: string): boolean {
  return (firstName.trim() + lastName.trim()).length > 0;
}

export class SendContactUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(chatId: number, phoneNumber: string, firstName: string, lastName: string = '',
    userId: number = 0): Promise<boolean> {
    if (chatId === 0 || !isValidContactPhone(phoneNumber) || !isValidContactName(firstName, lastName)) {
      return false;
    }
    try {
      const payload = new ShareContactPayload();
      payload.chatId = chatId;
      payload.phoneNumber = phoneNumber.trim();
      payload.firstName = firstName.trim();
      payload.lastName = lastName.trim();
      payload.userId = userId > 0 ? userId : 0;
      const response = await this.gateway.send(createShareContactCommand(payload)) as TdObject;
      return response instanceof TdObject;
    } catch (error) {
      hilog.info(DOMAIN, TAG, 'Sending a contact failed: %{public}s', String(error));
      return false;
    }
  }
}

export function createSendContactUseCase(gateway: TdGatewayPort): SendContactUseCase {
  return new SendContactUseCase(gateway);
}
