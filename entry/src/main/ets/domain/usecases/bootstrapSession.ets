// BootstrapSession use case - initializes TDLib session and sets up event flow
// Core business logic for application startup

import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStore } from '../../core/store/AppStore';
import { TdGatewayPort } from '../ports/TdGatewayPort';
import { AnyAppEvent, createAuthStateChangedEvent } from '../../core/model/AppEvent';
import { AppError, AppErrorKind } from '../../core/model/AppError';

const TAG = 'BootstrapSession';
const DOMAIN = 0x0004;

export class BootstrapSessionUseCase {
  private store: AppStore;
  private gateway: TdGatewayPort;
  private unsubscribeGateway?: () => void;

  constructor(store: AppStore, gateway: TdGatewayPort) {
    this.store = store;
    this.gateway = gateway;
  }

  // Main entry point
  async execute(): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Starting session bootstrap...');

      // 1. Initialize gateway
      await this.gateway.initialize();
      hilog.info(DOMAIN, TAG, 'Gateway initialized');

      // 2. Subscribe to gateway updates and dispatch to store
      this.setupGatewaySubscription();

      // 3. Dispatch initial connection state
      await this.store.dispatch(createAuthStateChangedEvent('notInitialized'));

      // 4. Send initial TDLib command to get auth state
      // In TDLib, we need to send 'getOption' or similar to trigger updates
      // For now, we'll just mark as waiting for phone number
      await this.store.dispatch(createAuthStateChangedEvent('waitPhoneNumber'));

      hilog.info(DOMAIN, TAG, 'Session bootstrap completed');
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Bootstrap failed: %{public}s', err.message);

      // Dispatch error state
      await this.store.dispatch(createAuthStateChangedEvent('closed'));

      throw new AppError(
        AppErrorKind.UNKNOWN,
        'Failed to bootstrap TDLib session',
        err.message,
        0,
        false
      );
    }
  }

  // Setup gateway subscription to forward events to store
  private setupGatewaySubscription(): void {
    this.unsubscribeGateway = this.gateway.subscribeUpdates(async (event: AnyAppEvent) => {
      try {
        // Dispatch event to store
        await this.store.dispatch(event);

        // Additional business logic based on event type
        this.handleGatewayEvent(event);
      } catch (error) {
        const err = error as Error;
        hilog.error(DOMAIN, TAG, 'Error processing gateway event: %{public}s', err.message);
      }
    });

    hilog.info(DOMAIN, TAG, 'Gateway subscription established');
  }

  // Handle specific gateway events with business logic
  private handleGatewayEvent(event: AnyAppEvent): void {
    switch (event.type) {
      case 'connectionStateChanged':
        hilog.info(DOMAIN, TAG, 'Connection state: %{public}s', event.state);
        break;

      case 'authStateChanged':
        hilog.info(DOMAIN, TAG, 'Auth state changed: %{public}s', event.state);
        break;
    }
  }

  // Cleanup resources
  async cleanup(): Promise<void> {
    if (this.unsubscribeGateway) {
      this.unsubscribeGateway();
      this.unsubscribeGateway = undefined;
      hilog.info(DOMAIN, TAG, 'Gateway subscription removed');
    }

    await this.gateway.destroy();
    hilog.info(DOMAIN, TAG, 'Gateway destroyed');
  }

  // Check if session is ready (auth state is 'ready')
  isSessionReady(): boolean {
    // This would need access to store state
    // For now, return false - selectors will handle this
    return false;
  }
}

// Factory function for convenience
export function createBootstrapSessionUseCase(
  store: AppStore,
  gateway: TdGatewayPort
): BootstrapSessionUseCase {
  return new BootstrapSessionUseCase(store, gateway);
}
