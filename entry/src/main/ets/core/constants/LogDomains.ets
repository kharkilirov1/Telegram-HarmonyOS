// LogDomains - централизованные коды доменов для hilog
// Huawei Best Practice: все domain коды в одном месте для consistency
// ArkTS compliant - без Object.entries и keyof

/**
 * Коды доменов для hilog.
 * Каждый модуль имеет уникальный код для фильтрации логов.
 *
 * Использование:
 * ```typescript
 * import { LogDomain } from '../constants/LogDomains';
 * hilog.info(LogDomain.GATEWAY, 'TdGateway', 'message');
 * ```
 */
export class LogDomain {
  // Native layer
  static readonly NAPI: number = 0x0001;

  // Infrastructure
  static readonly GATEWAY: number = 0x0002;
  static readonly RUNTIME: number = 0x0003;

  // Core
  static readonly STORE: number = 0x0004;
  static readonly NORMALIZER: number = 0x0005;
  static readonly REDUCERS: number = 0x0006;

  // Domain
  static readonly USE_CASES: number = 0x0007;
  static readonly SELECTORS: number = 0x0008;

  // UI
  static readonly PAGES: number = 0x0009;
  static readonly COMPONENTS: number = 0x000A;

  // Utils
  static readonly INVARIANTS: number = 0x000B;
  static readonly DISPATCHER: number = 0x000C;
  static readonly CACHE: number = 0x000D;

  // Services
  static readonly NOTIFICATION: number = 0x000E;
  static readonly FILE: number = 0x000F;
}

/**
 * Получить имя домена для логирования.
 * ArkTS compliant - явное сопоставление вместо Object.entries.
 */
export function getLogDomainName(domain: number): string {
  if (domain === LogDomain.NAPI) return 'NAPI';
  if (domain === LogDomain.GATEWAY) return 'GATEWAY';
  if (domain === LogDomain.RUNTIME) return 'RUNTIME';
  if (domain === LogDomain.STORE) return 'STORE';
  if (domain === LogDomain.NORMALIZER) return 'NORMALIZER';
  if (domain === LogDomain.REDUCERS) return 'REDUCERS';
  if (domain === LogDomain.USE_CASES) return 'USE_CASES';
  if (domain === LogDomain.SELECTORS) return 'SELECTORS';
  if (domain === LogDomain.PAGES) return 'PAGES';
  if (domain === LogDomain.COMPONENTS) return 'COMPONENTS';
  if (domain === LogDomain.INVARIANTS) return 'INVARIANTS';
  if (domain === LogDomain.DISPATCHER) return 'DISPATCHER';
  if (domain === LogDomain.CACHE) return 'CACHE';
  if (domain === LogDomain.NOTIFICATION) return 'NOTIFICATION';
  if (domain === LogDomain.FILE) return 'FILE';
  return `UNKNOWN_0x${domain.toString(16)}`;
}
