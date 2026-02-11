// ProxyService — use-case layer for proxy management
// Encapsulates all TDLib proxy operations so pages don't call TDLibClient directly
// Reference: Telegram iOS ProxyListController, Android ProxyListActivity

import { TDLibClient, TDLibError } from './TDLibClient';
import { handleTdlibError, AppError } from './AppError';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'ProxyService';
const DOMAIN = 0x0001;

export interface ProxyInfo {
  id: number;
  server: string;
  port: number;
  type: string;
  isEnabled: boolean;
  lastPingMs: number;
  username: string;
}

export class ProxyService {
  private static instance: ProxyService | null = null;
  private tdlib: TDLibClient = TDLibClient.getInstance();

  private constructor() {}

  static getInstance(): ProxyService {
    if (!ProxyService.instance) {
      ProxyService.instance = new ProxyService();
    }
    return ProxyService.instance;
  }

  /**
   * Fetch all configured proxy servers from TDLib.
   */
  async getProxies(): Promise<ProxyInfo[]> {
    const result = await this.tdlib.send('getProxies') as Record<string, unknown>;
    const rawProxies = result['proxies'] as Record<string, unknown>[];
    if (!rawProxies) return [];

    const parsed: ProxyInfo[] = [];
    for (const raw of rawProxies) {
      const proxyType = raw['type'] as Record<string, unknown>;
      parsed.push({
        id: raw['id'] as number,
        server: raw['server'] as string,
        port: raw['port'] as number,
        type: ProxyService.parseProxyType(proxyType),
        isEnabled: raw['is_enabled'] as boolean,
        lastPingMs: -1,
        username: ProxyService.parseUsername(proxyType)
      });
    }
    return parsed;
  }

  /**
   * Ping a proxy and return latency in milliseconds.
   * Returns -2 on failure (proxy unavailable).
   */
  async pingProxy(proxyId: number): Promise<number> {
    try {
      const params: Record<string, unknown> = {};
      params['proxy_id'] = proxyId;
      const result = await this.tdlib.send('pingProxy', params);
      return Math.round((result['seconds'] as number) * 1000);
    } catch (e) {
      hilog.debug(DOMAIN, TAG, 'Proxy ping failed for id=%{public}d: %{public}s',
        proxyId, e instanceof TDLibError ? e.tdMessage : String(e));
      return -2;
    }
  }

  /**
   * Enable a specific proxy by ID.
   */
  async enableProxy(proxyId: number): Promise<AppError | null> {
    try {
      const params: Record<string, unknown> = {};
      params['proxy_id'] = proxyId;
      await this.tdlib.send('enableProxy', params);
      return null;
    } catch (e) {
      if (e instanceof TDLibError) {
        return handleTdlibError(e.code, e.tdMessage);
      }
      hilog.error(DOMAIN, TAG, 'enableProxy failed: %{public}s', String(e));
      return null;
    }
  }

  /**
   * Disable proxy usage.
   */
  async disableProxy(): Promise<AppError | null> {
    try {
      await this.tdlib.send('disableProxy');
      return null;
    } catch (e) {
      if (e instanceof TDLibError) {
        return handleTdlibError(e.code, e.tdMessage);
      }
      hilog.error(DOMAIN, TAG, 'disableProxy failed: %{public}s', String(e));
      return null;
    }
  }

  /**
   * Add a new proxy configuration.
   */
  async addProxy(server: string, port: number, enable: boolean,
    type: Record<string, unknown>): Promise<AppError | null> {
    try {
      const params: Record<string, unknown> = {};
      params['server'] = server;
      params['port'] = port;
      params['enable'] = enable;
      params['type'] = type;
      await this.tdlib.send('addProxy', params);
      return null;
    } catch (e) {
      if (e instanceof TDLibError) {
        return handleTdlibError(e.code, e.tdMessage);
      }
      hilog.error(DOMAIN, TAG, 'addProxy failed: %{public}s', String(e));
      return null;
    }
  }

  /**
   * Remove a proxy configuration by ID.
   */
  async removeProxy(proxyId: number): Promise<AppError | null> {
    try {
      const params: Record<string, unknown> = {};
      params['proxy_id'] = proxyId;
      await this.tdlib.send('removeProxy', params);
      return null;
    } catch (e) {
      if (e instanceof TDLibError) {
        return handleTdlibError(e.code, e.tdMessage);
      }
      hilog.error(DOMAIN, TAG, 'removeProxy failed: %{public}s', String(e));
      return null;
    }
  }

  /**
   * Build a TDLib proxy type parameter object.
   */
  static buildProxyTypeParam(formType: string, username: string,
    password: string, secret: string): Record<string, unknown> {
    if (formType === 'socks5') {
      const t: Record<string, unknown> = {};
      t['@type'] = 'proxyTypeSocks5';
      t['username'] = username;
      t['password'] = password;
      return t;
    } else if (formType === 'http') {
      const t: Record<string, unknown> = {};
      t['@type'] = 'proxyTypeHttp';
      t['username'] = username;
      t['password'] = password;
      t['http_only'] = false;
      return t;
    } else {
      const t: Record<string, unknown> = {};
      t['@type'] = 'proxyTypeMtproto';
      t['secret'] = secret;
      return t;
    }
  }

  private static parseProxyType(proxyType: Record<string, unknown>): string {
    const typeName = proxyType['@type'] as string;
    if (typeName === 'proxyTypeSocks5') return 'socks5';
    if (typeName === 'proxyTypeHttp') return 'http';
    if (typeName === 'proxyTypeMtproto') return 'mtproto';
    return 'socks5';
  }

  private static parseUsername(proxyType: Record<string, unknown>): string {
    return (proxyType['username'] as string) || '';
  }
}
