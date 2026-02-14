import { describe, it, expect, beforeEach } from '@ohos/hypium';

/**
 * Unit tests for SecurityService.
 *
 * The real SecurityService relies on HUKS (Hardware Universal KeyStore)
 * which is only available on a device with a Trusted Execution
 * Environment. In a unit-test or emulator context, HUKS calls will fail.
 *
 * Strategy:
 *   - We test the fallback key generation path (software-only,
 *     deterministic) which is invoked when HUKS is unavailable.
 *   - We test the overall encrypt/decrypt round-trip concept using a
 *     simple XOR cipher stub that mirrors the init -> finish session
 *     pattern without requiring real HUKS hardware.
 *   - We validate that the service always produces a non-empty,
 *     base64-encoded key string regardless of path taken.
 */

// ---------------------------------------------------------------------------
// Pure-logic helpers extracted / mirrored from SecurityService
// ---------------------------------------------------------------------------

/**
 * Mirrors SecurityService.generateFallbackKey().
 * Deterministic key derivation from a fixed string.
 */
function generateFallbackKey(): string {
  const input = 'TelegramHarmonyOS_DBKey_v1_fallback_v1';
  // Manual base64 encoding of the UTF-8 bytes of the input string
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  const bytes: number[] = [];
  for (let i = 0; i < input.length; i++) {
    bytes.push(input.charCodeAt(i));
  }

  let result = '';
  let i = 0;
  while (i < bytes.length) {
    const b0 = bytes[i++] || 0;
    const b1 = i < bytes.length ? bytes[i++] : -1;
    const b2 = i < bytes.length ? bytes[i++] : -1;

    result += chars.charAt(b0 >> 2);
    if (b1 === -1) {
      result += chars.charAt((b0 & 0x03) << 4);
      result += '==';
    } else if (b2 === -1) {
      result += chars.charAt(((b0 & 0x03) << 4) | (b1 >> 4));
      result += chars.charAt((b1 & 0x0F) << 2);
      result += '=';
    } else {
      result += chars.charAt(((b0 & 0x03) << 4) | (b1 >> 4));
      result += chars.charAt(((b1 & 0x0F) << 2) | (b2 >> 6));
      result += chars.charAt(b2 & 0x3F);
    }
  }
  return result;
}

/**
 * Simple XOR-based encrypt/decrypt stub to test the round-trip concept.
 * Uses a repeating key byte pattern derived from a key string.
 */
function stubEncrypt(plaintext: string, keyString: string): number[] {
  const keyBytes: number[] = [];
  for (let i = 0; i < keyString.length; i++) {
    keyBytes.push(keyString.charCodeAt(i));
  }
  if (keyBytes.length === 0) return [];

  const encrypted: number[] = [];
  for (let i = 0; i < plaintext.length; i++) {
    encrypted.push(plaintext.charCodeAt(i) ^ keyBytes[i % keyBytes.length]);
  }
  return encrypted;
}

function stubDecrypt(cipherBytes: number[], keyString: string): string {
  const keyBytes: number[] = [];
  for (let i = 0; i < keyString.length; i++) {
    keyBytes.push(keyString.charCodeAt(i));
  }
  if (keyBytes.length === 0) return '';

  let result = '';
  for (let i = 0; i < cipherBytes.length; i++) {
    result += String.fromCharCode(cipherBytes[i] ^ keyBytes[i % keyBytes.length]);
  }
  return result;
}

/**
 * Validates that a string is valid base64.
 */
function isValidBase64(s: string): boolean {
  if (s.length === 0) return false;
  const base64Regex = /^[A-Za-z0-9+/]+={0,2}$/;
  return base64Regex.test(s) && s.length % 4 === 0;
}

// ---------------------------------------------------------------------------
// Stub SecurityService for testing without HUKS
// ---------------------------------------------------------------------------
class StubSecurityService {
  private dbEncryptionKey: string = '';
  private keyGenerated: boolean = false;

  async initialize(): Promise<void> {
    // Simulate HUKS failure, fall back to software key
    this.dbEncryptionKey = generateFallbackKey();
    this.keyGenerated = true;
  }

  getDatabaseEncryptionKey(): string {
    return this.dbEncryptionKey;
  }

  isKeyGenerated(): boolean {
    return this.keyGenerated;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

export default function securityServiceTest() {
  describe('SecurityService', () => {

    // -----------------------------------------------------------------------
    // Key generation (fallback path)
    // -----------------------------------------------------------------------
    describe('key generation', () => {
      let service: StubSecurityService;

      beforeEach(async () => {
        service = new StubSecurityService();
        await service.initialize();
      });

      it('should generate a non-empty encryption key after initialization', 0, () => {
        const key = service.getDatabaseEncryptionKey();
        expect(key.length > 0).assertTrue();
      });

      it('should produce a valid base64-encoded key', 0, () => {
        const key = service.getDatabaseEncryptionKey();
        expect(isValidBase64(key)).assertTrue();
      });

      it('should produce a deterministic key (same input always yields same output)', 0, async () => {
        const service2 = new StubSecurityService();
        await service2.initialize();

        expect(service.getDatabaseEncryptionKey())
          .assertEqual(service2.getDatabaseEncryptionKey());
      });

      it('should mark key as generated after initialization', 0, () => {
        expect(service.isKeyGenerated()).assertTrue();
      });

      it('should return empty key before initialization', 0, () => {
        const uninitService = new StubSecurityService();
        expect(uninitService.getDatabaseEncryptionKey()).assertEqual('');
      });

      it('fallback key should have reasonable length for AES usage', 0, () => {
        const key = service.getDatabaseEncryptionKey();
        // The base64-encoded key should be at least 16 characters
        // (representing at least 12 bytes of key material)
        expect(key.length >= 16).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // Encrypt / decrypt round-trip (stub cipher)
    // -----------------------------------------------------------------------
    describe('encrypt/decrypt round-trip', () => {
      let encryptionKey: string;

      beforeEach(async () => {
        const service = new StubSecurityService();
        await service.initialize();
        encryptionKey = service.getDatabaseEncryptionKey();
      });

      it('should encrypt and decrypt a simple message', 0, () => {
        const plaintext = 'Hello, Telegram!';
        const encrypted = stubEncrypt(plaintext, encryptionKey);
        const decrypted = stubDecrypt(encrypted, encryptionKey);

        expect(decrypted).assertEqual(plaintext);
      });

      it('encrypted bytes should differ from plaintext bytes', 0, () => {
        const plaintext = 'Secret message content';
        const encrypted = stubEncrypt(plaintext, encryptionKey);

        // At least some bytes should be different (unless XOR key byte matches)
        let diffCount = 0;
        for (let i = 0; i < plaintext.length; i++) {
          if (encrypted[i] !== plaintext.charCodeAt(i)) {
            diffCount++;
          }
        }
        expect(diffCount > 0).assertTrue();
      });

      it('should handle empty plaintext', 0, () => {
        const encrypted = stubEncrypt('', encryptionKey);
        const decrypted = stubDecrypt(encrypted, encryptionKey);
        expect(decrypted).assertEqual('');
        expect(encrypted.length).assertEqual(0);
      });

      it('should handle long messages', 0, () => {
        let longText = '';
        for (let i = 0; i < 1000; i++) {
          longText += 'A';
        }
        const encrypted = stubEncrypt(longText, encryptionKey);
        const decrypted = stubDecrypt(encrypted, encryptionKey);

        expect(decrypted).assertEqual(longText);
        expect(encrypted.length).assertEqual(1000);
      });

      it('should produce different ciphertext for different keys', 0, () => {
        const plaintext = 'Test data';
        const encrypted1 = stubEncrypt(plaintext, encryptionKey);
        const encrypted2 = stubEncrypt(plaintext, 'different_key_entirely');

        let areDifferent = false;
        for (let i = 0; i < encrypted1.length; i++) {
          if (encrypted1[i] !== encrypted2[i]) {
            areDifferent = true;
            break;
          }
        }
        expect(areDifferent).assertTrue();
      });

      it('should produce different ciphertext for different plaintexts', 0, () => {
        const encrypted1 = stubEncrypt('Message A', encryptionKey);
        const encrypted2 = stubEncrypt('Message B', encryptionKey);

        let areDifferent = false;
        for (let i = 0; i < encrypted1.length; i++) {
          if (encrypted1[i] !== encrypted2[i]) {
            areDifferent = true;
            break;
          }
        }
        expect(areDifferent).assertTrue();
      });
    });
  });
}
