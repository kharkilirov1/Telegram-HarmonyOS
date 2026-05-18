import { describe, it, expect } from '@ohos/hypium';
import {
  AppError,
  AppErrorKind,
  classifyTdlibError,
  ERR_TDLIB_CLIENT_DESTROYED,
  ERR_TDLIB_INIT_TIMEOUT
} from '../../../main/ets/core/model/AppError';

/**
 * Unit tests for the current core AppError model and TDLib error classifier.
 */
export default function appErrorTest() {
  describe('AppError', () => {

    describe('classifyTdlibError — network', () => {
      it('classifies initialization timeout as retryable network error', 0, () => {
        const error = classifyTdlibError(0, `${ERR_TDLIB_INIT_TIMEOUT}: ready timeout`);
        expect(error.kind).assertEqual(AppErrorKind.NETWORK);
        expect(error.retryable).assertTrue();
        expect(error.userMessage.indexOf('Initialization timed out') >= 0).assertTrue();
      });

      it('classifies destroyed-client constant as non-retryable network interruption', 0, () => {
        const error = classifyTdlibError(0, ERR_TDLIB_CLIENT_DESTROYED);
        expect(error.kind).assertEqual(AppErrorKind.NETWORK);
        expect(error.retryable).assertFalse();
        expect(error.userMessage).assertEqual('Connection interrupted.');
      });

      it('classifies generic timeouts as retryable network errors', 0, () => {
        const error = classifyTdlibError(0, 'Request timed out after 30000ms');
        expect(error.kind).assertEqual(AppErrorKind.NETWORK);
        expect(error.retryable).assertTrue();
      });

      it('classifies server 5xx as retryable network errors', 0, () => {
        const error = classifyTdlibError(502, 'Bad Gateway');
        expect(error.kind).assertEqual(AppErrorKind.NETWORK);
        expect(error.retryable).assertTrue();
        expect(error.userMessage.indexOf('Server error') >= 0).assertTrue();
      });
    });

    describe('classifyTdlibError — auth', () => {
      it('classifies 401 as non-retryable auth error', 0, () => {
        const error = classifyTdlibError(401, 'Unauthorized');
        expect(error.kind).assertEqual(AppErrorKind.AUTH);
        expect(error.retryable).assertFalse();
        expect(error.userMessage.indexOf('Session expired') >= 0).assertTrue();
      });

      it('classifies 403 as non-retryable auth error', 0, () => {
        const error = classifyTdlibError(403, 'Forbidden');
        expect(error.kind).assertEqual(AppErrorKind.AUTH);
        expect(error.retryable).assertFalse();
        expect(error.userMessage).assertEqual('Access denied.');
      });
    });

    describe('classifyTdlibError — rate limit', () => {
      it('classifies 420 FLOOD_WAIT as retryable rate limit and preserves seconds', 0, () => {
        const error = classifyTdlibError(420, 'FLOOD_WAIT_60');
        expect(error.kind).assertEqual(AppErrorKind.RATE_LIMIT);
        expect(error.retryable).assertTrue();
        expect(error.userMessage.indexOf('60 seconds') >= 0).assertTrue();
      });

      it('defaults bare FLOOD_WAIT to 30 seconds', 0, () => {
        const error = classifyTdlibError(420, 'FLOOD_WAIT');
        expect(error.kind).assertEqual(AppErrorKind.RATE_LIMIT);
        expect(error.userMessage.indexOf('30 seconds') >= 0).assertTrue();
      });

      it('classifies 429 as retryable rate limit', 0, () => {
        const error = classifyTdlibError(429, 'Too Many Requests');
        expect(error.kind).assertEqual(AppErrorKind.RATE_LIMIT);
        expect(error.retryable).assertTrue();
      });
    });

    describe('classifyTdlibError — common TDLib 400 errors', () => {
      it('maps CHAT_NOT_FOUND to user-facing TDLib error', 0, () => {
        const error = classifyTdlibError(400, 'CHAT_NOT_FOUND');
        expect(error.kind).assertEqual(AppErrorKind.TDLIB_ERROR);
        expect(error.userMessage).assertEqual('Chat not found.');
        expect(error.retryable).assertFalse();
      });

      it('maps MESSAGE_NOT_FOUND to user-facing TDLib error', 0, () => {
        const error = classifyTdlibError(400, 'MESSAGE_NOT_FOUND');
        expect(error.kind).assertEqual(AppErrorKind.TDLIB_ERROR);
        expect(error.userMessage).assertEqual('Message not found.');
      });

      it('maps USER_NOT_FOUND to user-facing TDLib error', 0, () => {
        const error = classifyTdlibError(400, 'USER_NOT_FOUND');
        expect(error.kind).assertEqual(AppErrorKind.TDLIB_ERROR);
        expect(error.userMessage).assertEqual('User not found.');
      });

      it('maps write-forbidden and unknown 400 variants', 0, () => {
        const forbidden = classifyTdlibError(400, 'CHAT_WRITE_FORBIDDEN');
        const unknown = classifyTdlibError(400, 'UNKNOWN_THING');
        expect(forbidden.userMessage.indexOf('cannot write') >= 0).assertTrue();
        expect(unknown.kind).assertEqual(AppErrorKind.TDLIB_ERROR);
        expect(unknown.userMessage).assertEqual('Request failed.');
      });
    });

    describe('classifyTdlibError — fallback', () => {
      it('classifies unrecognized codes as unknown non-retryable errors', 0, () => {
        const error = classifyTdlibError(999, 'Something odd');
        expect(error.kind).assertEqual(AppErrorKind.UNKNOWN);
        expect(error.retryable).assertFalse();
        expect(error.userMessage.indexOf('unexpected') >= 0).assertTrue();
      });
    });

    describe('AppError constructor', () => {
      it('stores explicit fields', 0, () => {
        const error = new AppError(
          AppErrorKind.FILE,
          'Upload failed',
          'Disk full',
          507,
          true
        );
        expect(error.kind).assertEqual(AppErrorKind.FILE);
        expect(error.userMessage).assertEqual('Upload failed');
        expect(error.technicalMessage).assertEqual('Disk full');
        expect(error.tdlibCode).assertEqual(507);
        expect(error.retryable).assertTrue();
      });

      it('defaults optional fields', 0, () => {
        const error = new AppError(AppErrorKind.UNKNOWN, 'Error');
        expect(error.technicalMessage).assertEqual('');
        expect(error.tdlibCode).assertEqual(0);
        expect(error.retryable).assertFalse();
      });
    });
  });
}
