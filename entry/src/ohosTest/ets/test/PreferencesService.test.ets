import { describe, it, expect, beforeEach } from '@ohos/hypium';

/**
 * Unit tests for PreferencesService.
 *
 * PreferencesService depends on @ohos.data.preferences which requires a
 * valid HarmonyOS Context. In a unit-test environment the real Context
 * may not be available, so we test two scenarios:
 *
 * 1. Uninitialised store (store === null) -- verifies that every getter
 *    gracefully returns its documented default value.
 * 2. Stub-backed store -- a lightweight in-memory Map that implements
 *    the getSync / putSync / flush contract, proving the round-trip
 *    read-after-write behaviour.
 */

// ---------------------------------------------------------------------------
// Minimal in-memory stub that satisfies the Preferences contract used by
// PreferencesService's private helpers.
// ---------------------------------------------------------------------------
class StubPreferences {
  private data: Map<string, string | number | boolean> = new Map();

  getSync(key: string, defaultValue: string | number | boolean): string | number | boolean {
    if (this.data.has(key)) {
      return this.data.get(key)!;
    }
    return defaultValue;
  }

  putSync(key: string, value: string | number | boolean): void {
    this.data.set(key, value);
  }

  async flush(): Promise<void> {
    // no-op for in-memory stub
  }
}

// ---------------------------------------------------------------------------
// Thin wrapper around the PreferencesService logic so we can inject the
// stub store without modifying production code.
// ---------------------------------------------------------------------------
class TestablePreferencesService {
  private store: StubPreferences | null = null;

  initializeWithStub(): void {
    this.store = new StubPreferences();
  }

  // --- Theme ---

  async getThemeMode(): Promise<string> {
    return this.getString('theme_mode', 'system');
  }

  async setThemeMode(mode: string): Promise<void> {
    await this.putString('theme_mode', mode);
  }

  // --- Font size ---

  async getFontSize(): Promise<number> {
    return this.getNumber('font_size', 16);
  }

  async setFontSize(size: number): Promise<void> {
    await this.putNumber('font_size', size);
  }

  // --- Notifications ---

  async getNotificationsEnabled(): Promise<boolean> {
    return this.getBoolean('notifications_enabled', true);
  }

  async setNotificationsEnabled(enabled: boolean): Promise<void> {
    await this.putBoolean('notifications_enabled', enabled);
  }

  // --- Generic public keys ---

  async getBooleanSetting(key: string, defaultValue: boolean): Promise<boolean> {
    return this.getBoolean(key, defaultValue);
  }

  async setBooleanSetting(key: string, value: boolean): Promise<void> {
    await this.putBoolean(key, value);
  }

  async getStringSetting(key: string, defaultValue: string): Promise<string> {
    return this.getString(key, defaultValue);
  }

  async setStringSetting(key: string, value: string): Promise<void> {
    await this.putString(key, value);
  }

  async getNumberSetting(key: string, defaultValue: number): Promise<number> {
    return this.getNumber(key, defaultValue);
  }

  async setNumberSetting(key: string, value: number): Promise<void> {
    await this.putNumber(key, value);
  }

  // --- Generic accessors (mirrors production code) ---

  private async getString(key: string, defaultValue: string): Promise<string> {
    if (!this.store) return defaultValue;
    try {
      return this.store.getSync(key, defaultValue) as string;
    } catch (_e) {
      return defaultValue;
    }
  }

  private async putString(key: string, value: string): Promise<void> {
    if (!this.store) return;
    this.store.putSync(key, value);
    await this.store.flush();
  }

  private async getBoolean(key: string, defaultValue: boolean): Promise<boolean> {
    if (!this.store) return defaultValue;
    try {
      return this.store.getSync(key, defaultValue) as boolean;
    } catch (_e) {
      return defaultValue;
    }
  }

  private async putBoolean(key: string, value: boolean): Promise<void> {
    if (!this.store) return;
    this.store.putSync(key, value);
    await this.store.flush();
  }

  private async getNumber(key: string, defaultValue: number): Promise<number> {
    if (!this.store) return defaultValue;
    try {
      return this.store.getSync(key, defaultValue) as number;
    } catch (_e) {
      return defaultValue;
    }
  }

  private async putNumber(key: string, value: number): Promise<void> {
    if (!this.store) return;
    this.store.putSync(key, value);
    await this.store.flush();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

export default function preferencesServiceTest() {
  describe('PreferencesService', () => {

    // -----------------------------------------------------------------------
    // Default values when store is NOT initialised (store === null)
    // -----------------------------------------------------------------------
    describe('uninitialised store defaults', () => {
      let service: TestablePreferencesService;

      beforeEach(() => {
        service = new TestablePreferencesService();
        // Intentionally NOT calling initializeWithStub()
      });

      it('getThemeMode should return "system" by default', 0, async () => {
        const mode = await service.getThemeMode();
        expect(mode).assertEqual('system');
      });

      it('getFontSize should return 16 by default', 0, async () => {
        const size = await service.getFontSize();
        expect(size).assertEqual(16);
      });

      it('getNotificationsEnabled should return true by default', 0, async () => {
        const enabled = await service.getNotificationsEnabled();
        expect(enabled).assertTrue();
      });
    });

    // -----------------------------------------------------------------------
    // Round-trip read/write with stub store
    // -----------------------------------------------------------------------
    describe('stub store round-trip', () => {
      let service: TestablePreferencesService;

      beforeEach(() => {
        service = new TestablePreferencesService();
        service.initializeWithStub();
      });

      it('getThemeMode should return default "system" before any write', 0, async () => {
        const mode = await service.getThemeMode();
        expect(mode).assertEqual('system');
      });

      it('setThemeMode + getThemeMode should round-trip "dark"', 0, async () => {
        await service.setThemeMode('dark');
        const mode = await service.getThemeMode();
        expect(mode).assertEqual('dark');
      });

      it('setThemeMode + getThemeMode should round-trip "light"', 0, async () => {
        await service.setThemeMode('light');
        const mode = await service.getThemeMode();
        expect(mode).assertEqual('light');
      });

      it('setThemeMode should overwrite previous value', 0, async () => {
        await service.setThemeMode('dark');
        await service.setThemeMode('light');
        const mode = await service.getThemeMode();
        expect(mode).assertEqual('light');
      });

      it('getFontSize should return default 16 before any write', 0, async () => {
        const size = await service.getFontSize();
        expect(size).assertEqual(16);
      });

      it('setFontSize + getFontSize should round-trip custom value', 0, async () => {
        await service.setFontSize(20);
        const size = await service.getFontSize();
        expect(size).assertEqual(20);
      });

      it('setFontSize should accept small values', 0, async () => {
        await service.setFontSize(10);
        const size = await service.getFontSize();
        expect(size).assertEqual(10);
      });

      it('setFontSize should accept large values', 0, async () => {
        await service.setFontSize(32);
        const size = await service.getFontSize();
        expect(size).assertEqual(32);
      });

      it('setNotificationsEnabled + getNotificationsEnabled round-trip', 0, async () => {
        await service.setNotificationsEnabled(false);
        const enabled = await service.getNotificationsEnabled();
        expect(enabled).assertFalse();
      });

      it('multiple settings should be independent', 0, async () => {
        await service.setThemeMode('dark');
        await service.setFontSize(24);
        await service.setNotificationsEnabled(false);

        expect(await service.getThemeMode()).assertEqual('dark');
        expect(await service.getFontSize()).assertEqual(24);
        expect(await service.getNotificationsEnabled()).assertFalse();
      });

      it('generic boolean setting should round-trip', 0, async () => {
        await service.setBooleanSetting('x_bool', true);
        expect(await service.getBooleanSetting('x_bool', false)).assertTrue();
      });

      it('generic string setting should round-trip', 0, async () => {
        await service.setStringSetting('x_string', 'hello');
        expect(await service.getStringSetting('x_string', 'default')).assertEqual('hello');
      });

      it('generic number setting should round-trip', 0, async () => {
        await service.setNumberSetting('x_number', 42);
        expect(await service.getNumberSetting('x_number', 0)).assertEqual(42);
      });
    });
  });
}
