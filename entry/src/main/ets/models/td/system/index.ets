// TDLib system types
// Secret chats, auto-download settings, sessions, proxies, etc.

import { TdObject } from '../common';

export interface TdSecretChat {
  id?: number;
  state?: TdObject;
  key_hash?: string;
  user_id?: number;
}

export interface TdPassportAuthorizationForm {
  id?: number;
  required_elements?: Object[];
}

export interface TdSession {
  id?: number;
  is_current?: boolean;
  api_id?: number;
  application_name?: string;
  application_version?: string;
  device_model?: string;
  platform?: string;
  system_version?: string;
  log_in_date?: number;
  last_active_date?: number;
  ip_address?: string;
  location?: string;
}

export interface TdSessions {
  sessions?: TdSession[];
}

export interface TdProxyType {
  username?: string;
  password?: string;
  http_only?: boolean;
  secret?: string;
}

export interface TdProxy {
  id: number;
  server?: string;
  port?: number;
  last_used_date?: number;
  is_enabled?: boolean;
  type?: TdProxyType;
}

export interface TdProxies {
  proxies?: TdProxy[];
}

export interface TdOk {
  // empty — @type = 'ok'
}