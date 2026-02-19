// Application error model - unified error classification
// Core module without UI dependencies

export const ERR_TDLIB_INIT_TIMEOUT = 'TDLIB_INIT_TIMEOUT';
export const ERR_TDLIB_CLIENT_DESTROYED = 'TDLIB_CLIENT_DESTROYED';

/**
 * Error classification for the entire app.
 * Each kind maps to a specific UX treatment.
 */
export enum AppErrorKind {
  /** Transient network issue — show retry prompt */
  NETWORK = 'NETWORK',
  /** TDLib returned a typed error — show user-facing message */
  TDLIB_ERROR = 'TDLIB_ERROR',
  /** Auth-related (session expired, 2FA required, etc.) */
  AUTH = 'AUTH',
  /** Rate limiting — show "slow down" toast */
  RATE_LIMIT = 'RATE_LIMIT',
  /** File operation failed (download, upload) */
  FILE = 'FILE',
  /** Unknown/unexpected error — log and show generic message */
  UNKNOWN = 'UNKNOWN'
}

/**
 * Structured app error with classification, user message, and optional retry.
 */
export class AppError extends Error {
  kind: AppErrorKind;
  userMessage: string;
  technicalMessage: string;
  tdlibCode: number;
  retryable: boolean;

  constructor(
    kind: AppErrorKind,
    userMessage: string,
    technicalMessage: string = '',
    tdlibCode: number = 0,
    retryable: boolean = false
  ) {
    super(userMessage);
    this.name = 'AppError';
    this.kind = kind;
    this.userMessage = userMessage;
    this.technicalMessage = technicalMessage;
    this.tdlibCode = tdlibCode;
    this.retryable = retryable;
  }
}

/**
 * Classify a TDLib error code + message into an AppError.
 * Reference: TDLib error codes documentation and Telegram client implementations.
 */
export function classifyTdlibError(code: number, message: string): AppError {
  // Initialization timeout — client didn't reach Ready state in time
  if (code === 0 && message.startsWith(ERR_TDLIB_INIT_TIMEOUT)) {
    return new AppError(
      AppErrorKind.NETWORK,
      'Initialization timed out. Please restart the app.',
      message, code, true
    );
  }

  // Client destroyed while caller was waiting
  if (code === 0 && message.startsWith(ERR_TDLIB_CLIENT_DESTROYED)) {
    return new AppError(
      AppErrorKind.NETWORK,
      'Connection interrupted.',
      message, code, false
    );
  }

  // Network errors
  if (code === 0 && (message.includes('timed out') || message.includes('Client destroyed'))) {
    return new AppError(
      AppErrorKind.NETWORK,
      'Connection issue. Please check your network.',
      message, code, true
    );
  }

  // Auth errors (401, 403)
  if (code === 401) {
    return new AppError(
      AppErrorKind.AUTH,
      'Session expired. Please log in again.',
      message, code, false
    );
  }

  if (code === 403) {
    return new AppError(
      AppErrorKind.AUTH,
      'Access denied.',
      message, code, false
    );
  }

  // Rate limiting (420, 429, FLOOD_WAIT_*)
  if (code === 420 || code === 429 || message.startsWith('FLOOD_WAIT')) {
    const waitMatch = message.match(/FLOOD_WAIT_(\d+)/);
    const waitSeconds = waitMatch ? parseInt(waitMatch[1]) : 30;
    return new AppError(
      AppErrorKind.RATE_LIMIT,
      `Please wait ${waitSeconds} seconds before trying again.`,
      message, code, true
    );
  }

  // Common TDLib errors
  if (code === 400) {
    // Map known 400 messages to user-friendly text
    if (message === 'CHAT_NOT_FOUND') {
      return new AppError(AppErrorKind.TDLIB_ERROR, 'Chat not found.', message, code, false);
    }
    if (message === 'MESSAGE_NOT_FOUND') {
      return new AppError(AppErrorKind.TDLIB_ERROR, 'Message not found.', message, code, false);
    }
    if (message === 'USER_NOT_FOUND') {
      return new AppError(AppErrorKind.TDLIB_ERROR, 'User not found.', message, code, false);
    }
    if (message === 'PEER_ID_INVALID') {
      return new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chat.', message, code, false);
    }
    if (message === 'MESSAGE_TOO_LONG') {
      return new AppError(AppErrorKind.TDLIB_ERROR, 'Message is too long.', message, code, false);
    }
    if (message === 'CHAT_WRITE_FORBIDDEN') {
      return new AppError(AppErrorKind.TDLIB_ERROR, 'You cannot write in this chat.', message, code, false);
    }
    return new AppError(AppErrorKind.TDLIB_ERROR, 'Request failed.', message, code, false);
  }

  // File errors (5xx in file context)
  if (code >= 500) {
    return new AppError(
      AppErrorKind.NETWORK,
      'Server error. Please try again later.',
      message, code, true
    );
  }

  // Fallback
  return new AppError(
    AppErrorKind.UNKNOWN,
    'An unexpected error occurred.',
    message, code, false
  );
}