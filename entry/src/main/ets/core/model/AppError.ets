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
  // Set only by an explicit TDLib Error response or a known pre-dispatch gate.
  // A retryable network failure does not prove that a write was rejected.
  requestRejected: boolean;

  constructor(
    kind: AppErrorKind,
    userMessage: string,
    technicalMessage: string = '',
    tdlibCode: number = 0,
    retryable: boolean = false,
    requestRejected: boolean = false
  ) {
    super(userMessage);
    this.name = 'AppError';
    this.kind = kind;
    this.userMessage = userMessage;
    this.technicalMessage = technicalMessage;
    this.tdlibCode = tdlibCode;
    this.retryable = retryable;
    this.requestRejected = requestRejected;
  }
}

// Preserve typed causes; untyped catches must not assume TDLib fields exist.
// Callers check silent 406 before inspecting any message or detail.
export function normalizeAppError(error: Object): AppError {
  if (error instanceof AppError) return error;
  return new AppError(AppErrorKind.UNKNOWN, error instanceof Error ? error.message : 'Unexpected failure');
}

export function isSilentTdlibError(error: Object): boolean {
  return error instanceof AppError && error.tdlibCode === 406;
}

// A contextual copy keeps the caller's typed cause intact. Only mutating
// gateway catches create this wrapper; eligibility/read errors are not writes.
export class WriteRequestError extends AppError {
  writeOutcomeUnknown: boolean;

  constructor(error: Object, fallbackMessage: string) {
    const typed = error instanceof AppError ? error : undefined;
    const silent = typed !== undefined && typed.tdlibCode === 406;
    super(silent ? AppErrorKind.TDLIB_ERROR : typed?.kind ?? AppErrorKind.UNKNOWN,
      silent ? '' : typed?.userMessage ?? fallbackMessage,
      silent ? '' : typed?.technicalMessage ?? (error instanceof Error ? error.message : 'Write request failed'),
      typed?.tdlibCode ?? 0, silent ? false : typed?.retryable ?? false,
      typed?.requestRejected ?? false);
    this.name = 'WriteRequestError';
    this.writeOutcomeUnknown = !this.requestRejected;
  }
}

export function asWriteRequestError(error: Object, fallbackMessage: string): WriteRequestError {
  return new WriteRequestError(error, fallbackMessage);
}

export function isWriteOutcomeUnknown(error: Object): boolean {
  return error instanceof WriteRequestError && error.writeOutcomeUnknown;
}

function tdlibRejectedError(kind: AppErrorKind, userMessage: string, technicalMessage: string,
  code: number, retryable: boolean): AppError {
  return new AppError(kind, userMessage, technicalMessage, code, retryable, true);
}

/**
 * Classify a TDLib error code + message into an AppError.
 * Reference: TDLib error codes documentation and Telegram client implementations.
 */
export function classifyTdlibError(code: number, message: string): AppError {
  // TDLib forbids processing the 406 message, including string classification.
  if (code === 406) return tdlibRejectedError(AppErrorKind.TDLIB_ERROR, '', '', code, false);
  // Initialization timeout — client didn't reach Ready state in time
  if (code === 0 && message.startsWith(ERR_TDLIB_INIT_TIMEOUT)) {
    return tdlibRejectedError(
      AppErrorKind.NETWORK,
      'Initialization timed out. Please restart the app.',
      message, code, true
    );
  }

  // Client destroyed while caller was waiting
  if (code === 0 && message.startsWith(ERR_TDLIB_CLIENT_DESTROYED)) {
    return tdlibRejectedError(
      AppErrorKind.NETWORK,
      'Connection interrupted.',
      message, code, false
    );
  }

  // Network errors
  if (code === 0 && (message.includes('timed out') || message.includes('Client destroyed'))) {
    return tdlibRejectedError(
      AppErrorKind.NETWORK,
      'Connection issue. Please check your network.',
      message, code, true
    );
  }

  // Auth errors (401, 403)
  if (code === 401) {
    return tdlibRejectedError(
      AppErrorKind.AUTH,
      'Session expired. Please log in again.',
      message, code, false
    );
  }

  if (code === 403) {
    return tdlibRejectedError(
      AppErrorKind.AUTH,
      'Access denied.',
      message, code, false
    );
  }

  // Rate limiting (420, 429, FLOOD_WAIT_*)
  if (code === 420 || code === 429 || message.startsWith('FLOOD_WAIT')) {
    const waitMatch = message.match(/FLOOD_WAIT_(\d+)/);
    const waitSeconds = waitMatch ? parseInt(waitMatch[1]) : 30;
    return tdlibRejectedError(
      AppErrorKind.RATE_LIMIT,
      `Please wait ${waitSeconds} seconds before trying again.`,
      message, code, true
    );
  }

  // Common TDLib errors
  if (code === 400) {
    // Map known 400 messages to user-friendly text
    if (message === 'CHAT_NOT_FOUND') {
      return tdlibRejectedError(AppErrorKind.TDLIB_ERROR, 'Chat not found.', message, code, false);
    }
    if (message === 'MESSAGE_NOT_FOUND') {
      return tdlibRejectedError(AppErrorKind.TDLIB_ERROR, 'Message not found.', message, code, false);
    }
    if (message === 'USER_NOT_FOUND') {
      return tdlibRejectedError(AppErrorKind.TDLIB_ERROR, 'User not found.', message, code, false);
    }
    if (message === 'PEER_ID_INVALID') {
      return tdlibRejectedError(AppErrorKind.TDLIB_ERROR, 'Invalid chat.', message, code, false);
    }
    if (message === 'MESSAGE_TOO_LONG') {
      return tdlibRejectedError(AppErrorKind.TDLIB_ERROR, 'Message is too long.', message, code, false);
    }
    if (message === 'CHAT_WRITE_FORBIDDEN') {
      return tdlibRejectedError(AppErrorKind.TDLIB_ERROR, 'You cannot write in this chat.', message, code, false);
    }
    return tdlibRejectedError(AppErrorKind.TDLIB_ERROR, 'Request failed.', message, code, false);
  }

  // File errors (5xx in file context) — bounded so unknown codes (e.g. 999)
  // fall through to the UNKNOWN non-retryable fallback
  if (code >= 500 && code < 600) {
    return tdlibRejectedError(
      AppErrorKind.NETWORK,
      'Server error. Please try again later.',
      message, code, true
    );
  }

  // Fallback
  return tdlibRejectedError(
    AppErrorKind.UNKNOWN,
    'An unexpected error occurred.',
    message, code, false
  );
}
