// Port interface for TDLib gateway (Dependency Inversion Principle)
// UseCases depend on this interface, not on concrete infra implementation

import { AnyAppCommand } from '../../core/model/AppCommand';
import { AnyAppEvent } from '../../core/model/AppEvent';
import { AppError, AppErrorKind } from '../../core/model/AppError';

export interface TdGatewayPort {
  // Initialize connection to TDLib
  initialize(): Promise<void>;

  // Send a command to TDLib - returns Object since TDLib responses vary
  send(command: AnyAppCommand): Promise<Object>;

  // Subscribe to TDLib updates (converted to AppEvents)
  subscribeUpdates(handler: (event: AnyAppEvent) => void): () => void;

  // Get current connection state
  getConnectionState(): 'connecting' | 'ready' | 'updating' | 'waitingForNetwork';

  // Optional backpressure signal: update-batch drain is congested (storm).
  // Background main-thread consumers (media watcher) should defer timer work.
  // Optional so test fakes stay minimal; absence means "not congested".
  isDrainCongested?: () => boolean;

  // Cleanup resources
  destroy(): Promise<void>;
}

// Error types specific to gateway operations
export enum GatewayErrorCode {
  NOT_INITIALIZED = 'GATEWAY_NOT_INITIALIZED',
  CONNECTION_FAILED = 'GATEWAY_CONNECTION_FAILED',
  SEND_TIMEOUT = 'GATEWAY_SEND_TIMEOUT',
  INVALID_COMMAND = 'GATEWAY_INVALID_COMMAND'
}

// Gateway error class
export class GatewayError extends AppError {
  code: GatewayErrorCode;

  constructor(
    code: GatewayErrorCode,
    message: string,
    technicalMessage: string = ''
  ) {
    super(AppErrorKind.NETWORK, message, technicalMessage, 0, true);
    this.code = code;
  }
}

// Helper functions to create gateway errors
export function createGatewayNotInitializedError(): GatewayError {
  return new GatewayError(
    GatewayErrorCode.NOT_INITIALIZED,
    'TDLib gateway is not initialized'
  );
}

export function createGatewayConnectionFailedError(details: string = ''): GatewayError {
  return new GatewayError(
    GatewayErrorCode.CONNECTION_FAILED,
    'Failed to connect to TDLib',
    details
  );
}

export function createGatewaySendTimeoutError(commandType: string): GatewayError {
  return new GatewayError(
    GatewayErrorCode.SEND_TIMEOUT,
    `Command ${commandType} timed out`
  );
}

export function createGatewayInvalidCommandError(commandType: string): GatewayError {
  return new GatewayError(
    GatewayErrorCode.INVALID_COMMAND,
    `Invalid command format: ${commandType}`
  );
}