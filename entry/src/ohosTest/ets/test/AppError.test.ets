import { describe, it, expect } from '@ohos/hypium';
import {
  AppError,
  AppErrorKind,
  classifyTdlibError
} from '../../../main/ets/services/AppError';

/**
 * Unit tests for AppError — error classification and user-facing message mapping.
 * Validates that TDLib error codes/messages map to the correct AppErrorKind
 * and user-facing messages.
 */

export default function appErrorTest() {
  describe('AppError', () => {

    // -----------------------------------------------------------------------
    // classifyTdlibError — network errors
    // -----------------------------------------------------------------------
    describe('classifyTdlibError — network', () => {

      it('should classify timeout as NETWORK', 0, () => {
        const error = classifyTdlibError(0, 'Request timed out after 30000ms');
        expect(error.kind).assertEqual(AppErrorKind.NETWORK);
        expect(error.retryable).assertTrue();
      });

      it('should classify client destroyed as NETWORK', 0, () => {
        const error = classifyTdlibError(0, 'Client destroyed');
        expect(error.kind).assertEqual(AppErrorKind.NETWORK);
        expect(error.retryable).assertTrue();
      });

      it('should classify 5xx as NETWORK', 0, () => {
        const error = classifyTdlibError(500, 'Internal Server Error');
        expect(error.kind).assertEqual(AppErrorKind.NETWORK);
        expect(error.retryable).assertTrue();
      });

      it('should classify 502 as NETWORK', 0, () => {
        const error = classifyTdlibError(502, 'Bad Gateway');
        expect(error.kind).assertEqual(AppErrorKind.NETWORK);
        expect(error.retryable).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // classifyTdlibError — auth errors
    // -----------------------------------------------------------------------
    describe('classifyTdlibError — auth', () => {

      it('should classify 401 as AUTH', 0, () => {
        const error = classifyTdlibError(401, 'Unauthorized');
        expect(error.kind).assertEqual(AppErrorKind.AUTH);
        expect(error.retryable).assertFalse();
        expect(error.userMessage).assertContain('Session expired');
      });

      it('should classify 403 as AUTH', 0, () => {
        const error = classifyTdlibError(403, 'Forbidden');
        expect(error.kind).assertEqual(AppErrorKind.AUTH);
        expect(error.retryable).assertFalse();
        expect(error.userMessage).assertContain('Access denied');
      });
    });

    // -----------------------------------------------------------------------
    // classifyTdlibError — rate limiting
    // -----------------------------------------------------------------------
    describe('classifyTdlibError — rate limit', () => {

      it('should classify 420 as RATE_LIMIT', 0, () => {
        const error = classifyTdlibError(420, 'FLOOD_WAIT_30');
        expect(error.kind).assertEqual(AppErrorKind.RATE_LIMIT);
        expect(error.retryable).assertTrue();
        expect(error.userMessage).assertContain('30');
      });

      it('should classify 429 as RATE_LIMIT', 0, () => {
        const error = classifyTdlibError(429, 'Too Many Requests');
        expect(error.kind).assertEqual(AppErrorKind.RATE_LIMIT);
        expect(error.retryable).assertTrue();
      });

      it('should extract FLOOD_WAIT seconds', 0, () => {
        const error = classifyTdlibError(420, 'FLOOD_WAIT_60');
        expect(error.userMessage).assertContain('60');
      });

      it('should default FLOOD_WAIT to 30s when no match', 0, () => {
        const error = classifyTdlibError(420, 'FLOOD_WAIT');
        expect(error.userMessage).assertContain('30');
      });
    });

    // -----------------------------------------------------------------------
    // classifyTdlibError — 400 errors
    // -----------------------------------------------------------------------
    describe('classifyTdlibError — 400', () => {

      it('should classify CHAT_NOT_FOUND', 0, () => {
        const error = classifyTdlibError(400, 'CHAT_NOT_FOUND');
        expect(error.kind).assertEqual(AppErrorKind.TDLIB_ERROR);
        expect(error.userMessage).assertContain('Chat not found');
      });

      it('should classify MESSAGE_NOT_FOUND', 0, () => {
        const error = classifyTdlibError(400, 'MESSAGE_NOT_FOUND');
        expect(error.kind).assertEqual(AppErrorKind.TDLIB_ERROR);
        expect(error.userMessage).assertContain('Message not found');
      });

      it('should classify USER_NOT_FOUND', 0, () => {
        const error = classifyTdlibError(400, 'USER_NOT_FOUND');
        expect(error.kind).assertEqual(AppErrorKind.TDLIB_ERROR);
        expect(error.userMessage).assertContain('User not found');
      });

      it('should classify PEER_ID_INVALID', 0, () => {
        const error = classifyTdlibError(400, 'PEER_ID_INVALID');
        expect(error.kind).assertEqual(AppErrorKind.TDLIB_ERROR);
        expect(error.userMessage).assertContain('Invalid chat');
      });

      it('should classify MESSAGE_TOO_LONG', 0, () => {
        const error = classifyTdlibError(400, 'MESSAGE_TOO_LONG');
        expect(error.kind).assertEqual(AppErrorKind.TDLIB_ERROR);
        expect(error.userMessage).assertContain('too long');
      });

      it('should classify CHAT_WRITE_FORBIDDEN', 0, () => {
        const error = classifyTdlibError(400, 'CHAT_WRITE_FORBIDDEN');
        expect(error.kind).assertEqual(AppErrorKind.TDLIB_ERROR);
        expect(error.userMessage).assertContain('cannot write');
      });

      it('should fallback unknown 400 to TDLIB_ERROR', 0, () => {
        const error = classifyTdlibError(400, 'UNKNOWN_THING');
        expect(error.kind).assertEqual(AppErrorKind.TDLIB_ERROR);
        expect(error.userMessage).assertEqual('Request failed.');
      });
    });

    // -----------------------------------------------------------------------
    // classifyTdlibError — unknown errors
    // -----------------------------------------------------------------------
    describe('classifyTdlibError — unknown', () => {

      it('should classify unrecognized code as UNKNOWN', 0, () => {
        const error = classifyTdlibError(999, 'Something odd');
        expect(error.kind).assertEqual(AppErrorKind.UNKNOWN);
        expect(error.retryable).assertFalse();
      });
    });

    // -----------------------------------------------------------------------
    // AppError constructor
    // -----------------------------------------------------------------------
    describe('AppError constructor', () => {

      it('should store all fields', 0, () => {
        const error = new AppError(
          AppErrorKind.FILE, 'Upload failed', 'Disk full', 507, true);
        expect(error.kind).assertEqual(AppErrorKind.FILE);
        expect(error.userMessage).assertEqual('Upload failed');
        expect(error.technicalMessage).assertEqual('Disk full');
        expect(error.tdlibCode).assertEqual(507);
        expect(error.retryable).assertTrue();
      });

      it('should default optional fields', 0, () => {
        const error = new AppError(AppErrorKind.UNKNOWN, 'Error');
        expect(error.technicalMessage).assertEqual('');
        expect(error.tdlibCode).assertEqual(0);
        expect(error.retryable).assertFalse();
      });
    });
  });
}
