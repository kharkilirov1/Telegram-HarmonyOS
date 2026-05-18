// Smoke test для проверки работоспособности TDLib bridge
// Использует TdGateway напрямую
// Цель P0: убедиться, что native bridge и core pipeline работают

import { hilog } from '@kit.PerformanceAnalysisKit';
import { getTdGateway, TdGateway } from '../../infra/td/gateway/TdGateway';
import { TdObject, tdGetProperty, safeString, asRecord } from '../../models/TdTypes';

const TAG = 'SmokeTest';
const DOMAIN = 0x0001;

export class SmokeTest {
  private gateway: TdGateway;
  private isRunning: boolean = false;
  private logs: string[] = [];
  private unsubscribe?: () => void;

  constructor() {
    this.gateway = getTdGateway();
  }

  static getInstance(): SmokeTest {
    return new SmokeTest();
  }

  async run(): Promise<boolean> {
    if (this.isRunning) {
      this.log('Smoke test already running');
      return false;
    }

    this.isRunning = true;
    this.log('=== Начало smoke test ===');
    this.log('Цель: проверить базовую работоспособность TDLib bridge');

    try {
      // 1. Инициализировать gateway
      await this.gateway.initialize();
      this.log('✓ TdGateway инициализирован');

      // 2. Подписаться на обновления
      this.setupSubscriptions();
      this.log('✓ Подписки установлены');

      // 3. Ждать обновлений состояния (таймаут 30 секунд)
      await this.waitForAuthState(30000);

      this.log('=== Smoke test завершен успешно ===');
      return true;
    } catch (error) {
      const err = error as Error;
      this.log(`✗ Ошибка smoke test: ${err.message}`);
      hilog.error(DOMAIN, TAG, 'Smoke test failed: %{public}s', err.message);
      return false;
    } finally {
      this.cleanupSubscription();
      this.isRunning = false;
    }
  }

  private setupSubscriptions(): void {
    this.cleanupSubscription();
    this.unsubscribe = this.gateway.subscribeUpdates((update: TdObject) => {
      const type = safeString(tdGetProperty(update, '@type'));

      switch (type) {
        case 'updateAuthorizationState': {
          const authStateObj = asRecord(tdGetProperty(update, 'authorization_state'));
          const authState = safeString(tdGetProperty(authStateObj, '@type'));
          this.log(`Auth state: ${authState}`);
          break;
        }

        case 'updateConnectionState': {
          const connStateObj = asRecord(tdGetProperty(update, 'state'));
          const connState = safeString(tdGetProperty(connStateObj, '@type'));
          this.log(`Connection state: ${connState}`);
          break;
        }

        case 'updateOption': {
          const name = safeString(tdGetProperty(update, 'name'));
          this.log(`Option: ${name}`);
          break;
        }
      }
    });
  }

  private cleanupSubscription(): void {
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
  }

  private async waitForAuthState(timeoutMs: number): Promise<void> {
    return new Promise((resolve, reject) => {
      let resolved = false;
      let timeoutId: number = -1;
      let unsubscribe: (() => void) | undefined = undefined;

      const cleanup = (): void => {
        if (timeoutId !== -1) {
          clearTimeout(timeoutId);
          timeoutId = -1;
        }
        if (unsubscribe !== undefined) {
          unsubscribe();
          unsubscribe = undefined;
        }
      };

      const finishResolve = (): void => {
        if (resolved) {
          return;
        }
        resolved = true;
        cleanup();
        this.log('✓ Состояние авторизации: ready');
        resolve();
      };

      const finishReject = (error: Error): void => {
        if (resolved) {
          return;
        }
        resolved = true;
        cleanup();
        reject(error);
      };

      timeoutId = setTimeout(() => {
        finishReject(new Error(`Таймаут ожидания состояния авторизации (${timeoutMs}ms)`));
      }, timeoutMs) as number;

      unsubscribe = this.gateway.subscribeUpdates((update: TdObject) => {
        const updateType = safeString(tdGetProperty(update, '@type'));
        if (updateType !== 'updateAuthorizationState') return;

        const authStateObj = asRecord(tdGetProperty(update, 'authorization_state'));
        const authState = safeString(tdGetProperty(authStateObj, '@type'));
        if (authState === 'authorizationStateReady') {
          finishResolve();
        }
      });
    });
  }

  private log(message: string): void {
    const timestamp = new Date().toISOString().split('T')[1].split('.')[0];
    const logMessage = `[${timestamp}] ${message}`;
    this.logs.push(logMessage);

    if (this.logs.length > 100) {
      this.logs.shift();
    }

    hilog.info(DOMAIN, TAG, '%{public}s', message);
  }

  getLogs(): string[] {
    return [...this.logs];
  }

  stop(): void {
    this.cleanupSubscription();
    this.gateway.destroy()
      .catch((error: Error): void => {
        hilog.warn(DOMAIN, TAG, 'TdGateway stop failed: %{public}s', String(error));
      });
    this.log('TdGateway stop requested');
    this.isRunning = false;
  }
}
