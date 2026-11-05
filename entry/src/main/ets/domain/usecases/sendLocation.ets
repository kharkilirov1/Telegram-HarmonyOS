// D25: sending the current location. The use case validates the point, the gateway sends it; the device
// reading and the permission prompt belong to the UI layer.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { createSendLocationCommand } from '../../core/model/AppCommand';
import { TdObject } from '../../core/utils/tdAccessors';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x00D25;
const TAG = 'SendLocation';

// WGS-84 bounds; anything outside is a broken reading, not a location.
export function isValidLocationPoint(latitude: number, longitude: number): boolean {
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return false;
  }
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return false;
  }
  return !(latitude === 0 && longitude === 0);
}

export class SendLocationUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(chatId: number, latitude: number, longitude: number,
    horizontalAccuracy: number = 0): Promise<boolean> {
    if (chatId === 0 || !isValidLocationPoint(latitude, longitude)) {
      return false;
    }
    try {
      const accuracy = horizontalAccuracy > 0 && Number.isFinite(horizontalAccuracy) ? horizontalAccuracy : 0;
      const response = await this.gateway.send(
        createSendLocationCommand(chatId, latitude, longitude, accuracy)) as TdObject;
      return response instanceof TdObject;
    } catch (error) {
      hilog.info(DOMAIN, TAG, 'Sending a location failed: %{public}s', String(error));
      return false;
    }
  }
}

export function createSendLocationUseCase(gateway: TdGatewayPort): SendLocationUseCase {
  return new SendLocationUseCase(gateway);
}
