// LoginController — сервис авторизации
// Референс: Telegram iOS AuthorizationSequenceController
//
// Интегрирован с TdGatewayAdapter для отправки команд в TDLib

import { getTdGatewayAdapter } from '../../infra/td/adapter/TdGatewayAdapter';
import { TdGatewayPort } from '../../domain/ports/TdGatewayPort';
import {
  createSetPhoneNumberCommand,
  createCheckAuthCodeCommand,
  createCheckAuthPasswordCommand,
  createRequestPasswordRecoveryCommand,
  createResendAuthCodeCommand
} from '../../core/model/AppCommand';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'LoginController';
const DOMAIN = 0x0010;

// ─── Error Types (iOS mapped) ───

export class LoginError {
  code: LoginErrorCode = 'UNKNOWN';
  message: string = '';
  retryAfter: number = 0;

  constructor(code: LoginErrorCode, message: string, retryAfter: number = 0) {
    this.code = code;
    this.message = message;
    this.retryAfter = retryAfter;
  }
}

export type LoginErrorCode =
  // SendCode errors
  | 'PHONE_NUMBER_INVALID'
  | 'PHONE_NUMBER_FLOOD'
  | 'PHONE_NUMBER_BANNED'
  | 'PHONE_CODE_EXPIRED'
  | 'APP_OUTDATED'
  // AuthCode errors
  | 'CODE_INVALID'
  | 'CODE_EXPIRED'
  | 'EMAIL_TOKEN_INVALID'
  | 'EMAIL_ADDRESS_INVALID'
  | 'EMAIL_NOT_ALLOWED'
  // Password errors
  | 'PASSWORD_INVALID'
  // Common
  | 'FLOOD_WAIT'
  | 'NETWORK_ERROR'
  | 'UNKNOWN';

// ─── Code Type (iOS: SentAuthorizationCodeType) ───

export type CodeType =
  | 'sms'
  | 'call'
  | 'otherSession'
  | 'missedCall'
  | 'fragment'
  | 'email'
  | 'emailSetupRequired'
  | 'word'
  | 'phrase';

export class CodeInfo {
  type: CodeType = 'sms';
  length: number = 5;
  nextType: CodeType | null = null;
  timeout: number = 60;
  phoneCodeHash: string = '';
  emailPattern: string = '';
}

// ─── Result Types ───

export class SendCodeSuccess {
  success: boolean = true;
  codeInfo: CodeInfo = new CodeInfo();
}

export class SendCodeFailure {
  success: boolean = false;
  error: LoginError = new LoginError('UNKNOWN', '');
}

export type SendCodeResult = SendCodeSuccess | SendCodeFailure;

export class CheckCodeSuccess {
  success: boolean = true;
  nextStep: 'ready' | 'signUp' | 'password' = 'ready';
}

export class CheckCodeFailure {
  success: boolean = false;
  error: LoginError = new LoginError('UNKNOWN', '');
}

export type CheckCodeResult = CheckCodeSuccess | CheckCodeFailure;

export class CheckPasswordSuccess {
  success: boolean = true;
}

export class CheckPasswordFailure {
  success: boolean = false;
  error: LoginError = new LoginError('UNKNOWN', '');
}

export type CheckPasswordResult = CheckPasswordSuccess | CheckPasswordFailure;

export class RecoverySuccess {
  success: boolean = true;
  emailPattern: string = '';
}

export class RecoveryFailure {
  success: boolean = false;
  error: LoginError = new LoginError('UNKNOWN', '');
}

export type RecoveryResult = RecoverySuccess | RecoveryFailure;

// ─── Error Parser ───

function parseTdError(errorCode: number, errorMessage: string): LoginError {
  const msg = errorMessage.toUpperCase();

  // Обработка по кодам ошибок TDLib
  switch (errorCode) {
    case 400: // Bad Request
      if (msg.includes('PHONE_NUMBER_INVALID')) {
        return new LoginError('PHONE_NUMBER_INVALID', 'Invalid phone number. Please check and try again.');
      }
      if (msg.includes('PHONE_NUMBER_FLOOD')) {
        return new LoginError('PHONE_NUMBER_FLOOD', 'Too many attempts. Please try again later.');
      }
      if (msg.includes('PHONE_NUMBER_BANNED')) {
        return new LoginError('PHONE_NUMBER_BANNED', 'This phone number is banned.');
      }
      if (msg.includes('PHONE_CODE_INVALID') || msg.includes('CODE_INVALID')) {
        return new LoginError('CODE_INVALID', 'Invalid code. Please try again.');
      }
      if (msg.includes('PHONE_CODE_EXPIRED') || msg.includes('CODE_EXPIRED')) {
        return new LoginError('CODE_EXPIRED', 'Code has expired. Please request a new one.');
      }
      if (msg.includes('PASSWORD_HASH_INVALID') || msg.includes('SRP_PASSWORD_CHANGED')) {
        return new LoginError('PASSWORD_INVALID', 'Wrong password. Please try again.');
      }
      if (msg.includes('EMAIL_UNCONFIRMED') || msg.includes('EMAIL_INVALID')) {
        return new LoginError('EMAIL_ADDRESS_INVALID', 'Invalid email address.');
      }
      if (msg.includes('EMAIL_NOT_ALLOWED')) {
        return new LoginError('EMAIL_NOT_ALLOWED', 'This email is not allowed.');
      }
      break;
    
    case 401: // Unauthorized
      return new LoginError('CODE_INVALID', 'Session expired. Please login again.');
    
    case 403: // Forbidden
      if (msg.includes('FLOOD_WAIT')) {
        const floodMatch = msg.match(/FLOOD_WAIT_(\d+)/);
        if (floodMatch && floodMatch.length > 1) {
          const seconds = parseInt(floodMatch[1]);
          return new LoginError('FLOOD_WAIT', `Too many attempts. Please wait ${seconds} seconds.`, seconds);
        }
      }
      break;
    
    case 429: // Too Many Requests
      return new LoginError('FLOOD_WAIT', 'Too many requests. Please try again later.', 60);
  }

  // Timeout / network
  if (errorCode === -1 || msg.includes('TIMEOUT') || msg.includes('NETWORK')) {
    return new LoginError('NETWORK_ERROR', 'Connection error. Please check your network.');
  }

  // Обработка по сообщению как fallback
  if (msg.includes('PHONE_NUMBER_INVALID')) {
    return new LoginError('PHONE_NUMBER_INVALID', 'Invalid phone number. Please check and try again.');
  }
  if (msg.includes('PHONE_NUMBER_FLOOD')) {
    return new LoginError('PHONE_NUMBER_FLOOD', 'Too many attempts. Please try again later.');
  }
  if (msg.includes('PHONE_NUMBER_BANNED')) {
    return new LoginError('PHONE_NUMBER_BANNED', 'This phone number is banned.');
  }
  if (msg.includes('PHONE_CODE_INVALID') || msg.includes('CODE_INVALID')) {
    return new LoginError('CODE_INVALID', 'Invalid code. Please try again.');
  }
  if (msg.includes('PHONE_CODE_EXPIRED') || msg.includes('CODE_EXPIRED')) {
    return new LoginError('CODE_EXPIRED', 'Code has expired. Please request a new one.');
  }
  if (msg.includes('PASSWORD_HASH_INVALID') || msg.includes('SRP_PASSWORD_CHANGED')) {
    return new LoginError('PASSWORD_INVALID', 'Wrong password. Please try again.');
  }

  return new LoginError('UNKNOWN', `An error occurred (${errorCode}: ${errorMessage}). Please try again.`);
}

// ─── LoginController ───

export class LoginController {
  private static instance: LoginController | null = null;
  private gateway: TdGatewayPort;

  private constructor() {
    this.gateway = getTdGatewayAdapter();
  }

  static getInstance(): LoginController {
    if (LoginController.instance === null) {
      LoginController.instance = new LoginController();
    }
    return LoginController.instance;
  }

  // ─── Send Phone Number ───
  async sendPhoneNumber(phone: string): Promise<SendCodeResult> {
    try {
      hilog.info(DOMAIN, TAG, 'Sending phone number: %{public}s***', phone.substring(0, 4));

      const command = createSetPhoneNumberCommand(phone);
      await this.gateway.send(command);

      // Успех — состояние обновится через AppStore
      const result = new SendCodeSuccess();
      result.codeInfo = this.createDefaultCodeInfo();
      return result;
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'sendPhoneNumber failed: %{public}s', err.message);
      const failure = new SendCodeFailure();
      failure.error = parseTdError(0, err.message);
      return failure;
    }
  }

  // ─── Check Auth Code ───
  async checkCode(code: string): Promise<CheckCodeResult> {
    try {
      hilog.info(DOMAIN, TAG, 'Checking auth code');

      const command = createCheckAuthCodeCommand(code);
      await this.gateway.send(command);

      const result = new CheckCodeSuccess();
      result.nextStep = 'ready';
      return result;
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'checkCode failed: %{public}s', err.message);
      const failure = new CheckCodeFailure();
      failure.error = parseTdError(0, err.message);
      return failure;
    }
  }

  // ─── Check Password (2FA) ───
  async checkPassword(password: string): Promise<CheckPasswordResult> {
    try {
      hilog.info(DOMAIN, TAG, 'Checking password');

      const command = createCheckAuthPasswordCommand(password);
      await this.gateway.send(command);

      return new CheckPasswordSuccess();
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'checkPassword failed: %{public}s', err.message);
      const failure = new CheckPasswordFailure();
      failure.error = parseTdError(0, err.message);
      return failure;
    }
  }

  // ─── Request Password Recovery ───
  async requestPasswordRecovery(): Promise<RecoveryResult> {
    try {
      hilog.info(DOMAIN, TAG, 'Requesting password recovery');
      const command = createRequestPasswordRecoveryCommand();
      await this.gateway.send(command);
      return new RecoverySuccess();
    } catch (e) {
      const err = e as Error;
      const failure = new RecoveryFailure();
      failure.error = parseTdError(0, err.message);
      return failure;
    }
  }

  // ─── Resend Code ───
  async resendCode(): Promise<SendCodeResult> {
    try {
      hilog.info(DOMAIN, TAG, 'Resending code');
      const command = createResendAuthCodeCommand();
      await this.gateway.send(command);
      const result = new SendCodeSuccess();
      result.codeInfo = this.createDefaultCodeInfo();
      return result;
    } catch (e) {
      const err = e as Error;
      const failure = new SendCodeFailure();
      failure.error = parseTdError(0, err.message);
      return failure;
    }
  }

  private createDefaultCodeInfo(): CodeInfo {
    const info = new CodeInfo();
    info.type = 'sms';
    info.length = 5;
    info.nextType = 'call';
    info.timeout = 60;
    return info;
  }
}
