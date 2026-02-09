import { huks } from '@kit.UniversalKeystoreKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';

const TAG = 'SecurityService';
const DOMAIN = 0x0001;

// HUKS key alias for database encryption key derivation
const DB_KEY_ALIAS = 'telegram_db_enc_key';

// Fixed derivation input — encrypted with the HUKS hardware key to produce the DB key
const DERIVATION_INPUT = 'TelegramHarmonyOS_DBKey_v1';

export class SecurityService {
  private static instance: SecurityService | null = null;
  private dbEncryptionKey: string = '';

  private constructor() {}

  static getInstance(): SecurityService {
    if (!SecurityService.instance) {
      SecurityService.instance = new SecurityService();
    }
    return SecurityService.instance;
  }

  /**
   * Initialize HUKS key and derive the database encryption key.
   * Must be called before getDatabaseEncryptionKey().
   */
  async initialize(): Promise<void> {
    try {
      await this.ensureHuksKeyExists();
      this.dbEncryptionKey = await this.deriveDbKey();
      hilog.info(DOMAIN, TAG, 'Security service initialized successfully');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize security: %{public}s', String(e));
      // Fallback: generate a deterministic key from device info
      // This is less secure but prevents app from crashing
      this.dbEncryptionKey = this.generateFallbackKey();
    }
  }

  /**
   * Returns the database encryption key (base64-encoded).
   */
  getDatabaseEncryptionKey(): string {
    return this.dbEncryptionKey;
  }

  /**
   * Ensure the HUKS AES key exists, create if not.
   */
  private async ensureHuksKeyExists(): Promise<void> {
    const checkOptions: huks.HuksOptions = {
      properties: []
    };

    try {
      const exists = await huks.isKeyItemExist(DB_KEY_ALIAS, checkOptions);
      if (exists) {
        hilog.info(DOMAIN, TAG, 'HUKS key already exists');
        return;
      }
    } catch (e) {
      hilog.debug(DOMAIN, TAG, 'HUKS key not found, will create: %{public}s', String(e));
    }

    hilog.info(DOMAIN, TAG, 'Generating HUKS AES-256 key');
    const generateOptions: huks.HuksOptions = {
      properties: [
        {
          tag: huks.HuksTag.HUKS_TAG_ALGORITHM,
          value: huks.HuksKeyAlg.HUKS_ALG_AES
        },
        {
          tag: huks.HuksTag.HUKS_TAG_PURPOSE,
          value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT |
            huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT
        },
        {
          tag: huks.HuksTag.HUKS_TAG_KEY_SIZE,
          value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256
        },
        {
          tag: huks.HuksTag.HUKS_TAG_PADDING,
          value: huks.HuksKeyPadding.HUKS_PADDING_PKCS7
        },
        {
          tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE,
          value: huks.HuksCipherMode.HUKS_MODE_CBC
        }
      ]
    };
    await huks.generateKeyItem(DB_KEY_ALIAS, generateOptions);
    hilog.info(DOMAIN, TAG, 'HUKS key generated successfully');
  }

  /**
   * Derive the database key by encrypting a known constant with the HUKS key.
   * The encrypted output serves as a deterministic, hardware-bound key.
   */
  private async deriveDbKey(): Promise<string> {
    const textEncoder = new util.TextEncoder();
    const plainData = textEncoder.encodeInto(DERIVATION_INPUT);

    // Fixed IV for deterministic derivation
    const iv = new Uint8Array([
      0x54, 0x47, 0x48, 0x4F, 0x53, 0x5F, 0x44, 0x42,
      0x5F, 0x4B, 0x45, 0x59, 0x5F, 0x49, 0x56, 0x31
    ]);

    const encryptOptions: huks.HuksOptions = {
      properties: [
        {
          tag: huks.HuksTag.HUKS_TAG_ALGORITHM,
          value: huks.HuksKeyAlg.HUKS_ALG_AES
        },
        {
          tag: huks.HuksTag.HUKS_TAG_PURPOSE,
          value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT
        },
        {
          tag: huks.HuksTag.HUKS_TAG_PADDING,
          value: huks.HuksKeyPadding.HUKS_PADDING_PKCS7
        },
        {
          tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE,
          value: huks.HuksCipherMode.HUKS_MODE_CBC
        },
        {
          tag: huks.HuksTag.HUKS_TAG_IV,
          value: iv
        }
      ],
      inData: plainData
    };

    // Init → Finish (single-block operation)
    const sessionHandle = await huks.initSession(DB_KEY_ALIAS, encryptOptions);
    const finishOptions: huks.HuksOptions = {
      properties: [],
      inData: plainData
    };
    const result = await huks.finishSession(sessionHandle.handle, finishOptions);

    if (result.outData) {
      const base64Helper = new util.Base64Helper();
      return base64Helper.encodeToStringSync(new Uint8Array(result.outData));
    }

    throw new Error('HUKS encryption returned no data');
  }

  /**
   * Fallback key derivation without HUKS (e.g., emulator without TEE).
   */
  private generateFallbackKey(): string {
    hilog.warn(DOMAIN, TAG, 'Using fallback key derivation — HUKS unavailable');
    const base64Helper = new util.Base64Helper();
    const textEncoder = new util.TextEncoder();
    const data = textEncoder.encodeInto(DERIVATION_INPUT + '_fallback_v1');
    return base64Helper.encodeToStringSync(data);
  }
}
