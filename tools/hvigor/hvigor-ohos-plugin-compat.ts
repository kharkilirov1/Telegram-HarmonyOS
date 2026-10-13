const fs = require('fs');
const path = require('path');

const OH_META_FILE = 'oh-uni-package.json';
const HMS_META_FILE = 'uni-package.json';

function exists(targetPath: string | undefined): boolean {
  if (!targetPath) {
    return false;
  }
  try {
    return fs.existsSync(targetPath);
  } catch {
    return false;
  }
}

function readJson(jsonPath: string): any {
  return JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
}

function createApiVersion(raw: any) {
  const value = String(raw ?? '');
  const major = Number.parseInt(value.split('.')[0], 10);
  return {
    getMajor(): number {
      return Number.isFinite(major) ? major : 0;
    },
    getValue(): string {
      return value;
    }
  };
}

function createComponent(location: string, raw: any) {
  const data = raw?.data ?? raw ?? {};
  const componentPath = String(data.path ?? path.basename(location));
  const version = String(data.version ?? '');
  const releaseType = String(data.releaseType ?? 'Release');
  const apiVersion = data.fullApiVersion ?? data.apiVersion ?? '';

  return {
    getFullApiVersion() {
      return createApiVersion(apiVersion);
    },
    getLocation(): string {
      return location;
    },
    getPath(): string {
      return componentPath;
    },
    getReleaseType(): string {
      return releaseType;
    },
    getVersion(): string {
      return version;
    }
  };
}

function looksLikeLegacySplitRoot(rootPath: string | undefined): boolean {
  return exists(path.join(rootPath ?? '', 'openharmony', 'ets', OH_META_FILE))
    && exists(path.join(rootPath ?? '', 'openharmony', 'toolchains', OH_META_FILE))
    && exists(path.join(rootPath ?? '', 'hms', 'toolchains', HMS_META_FILE));
}

function getPluginRoot(): string | undefined {
  try {
    return path.dirname(require.resolve('@ohos/hvigor-ohos-plugin'));
  } catch {
    return undefined;
  }
}

function ensureJavaInPath(): void {
  const pluginRoot = getPluginRoot();
  const candidates = new Set<string>();

  if (process.env.JAVA_HOME) {
    candidates.add(path.join(process.env.JAVA_HOME, 'bin'));
  }
  if (pluginRoot) {
    candidates.add(path.resolve(pluginRoot, '..', '..', '..', 'jbr', 'bin'));
  }
  if (process.env.ProgramFiles) {
    candidates.add(path.join(process.env.ProgramFiles, 'Huawei', 'DevEco Studio', 'jbr', 'bin'));
  }

  for (const candidate of candidates) {
    const javaExe = path.join(candidate, 'java.exe');
    if (!exists(javaExe)) {
      continue;
    }

    process.env.JAVA_HOME = path.dirname(candidate);
    const currentPath = process.env.PATH ?? '';
    const normalizedEntries = currentPath.split(path.delimiter).filter(Boolean);
    if (!normalizedEntries.includes(candidate)) {
      process.env.PATH = [candidate, ...normalizedEntries].join(path.delimiter);
    }
    return;
  }
}

function resolveCompatSdkRoot(): string | undefined {
  const pluginRoot = getPluginRoot();
  const candidates = new Set<string>();

  if (process.env.DEVECO_SDK_HOME) {
    candidates.add(process.env.DEVECO_SDK_HOME);
  }
  if (pluginRoot) {
    candidates.add(path.resolve(pluginRoot, '..', '..', '..', 'sdk', 'default'));
  }
  if (process.env.ProgramFiles) {
    candidates.add(path.join(process.env.ProgramFiles, 'Huawei', 'DevEco Studio', 'sdk', 'default'));
  }

  for (const candidate of candidates) {
    if (looksLikeLegacySplitRoot(candidate)) {
      return candidate;
    }
  }
  return undefined;
}

function loadLegacyComponents(rootPath: string, family: 'openharmony' | 'hms', components: string[]) {
  const definitionFile = family === 'openharmony' ? OH_META_FILE : HMS_META_FILE;
  const resolved = new Map<string, any>();

  for (const component of components) {
    const location = path.join(rootPath, family, component);
    const metaPath = path.join(location, definitionFile);
    if (!exists(metaPath)) {
      return undefined;
    }
    resolved.set(component, createComponent(location, readJson(metaPath)));
  }

  return resolved;
}

const compatSdkRoot = resolveCompatSdkRoot();

ensureJavaInPath();

if (compatSdkRoot) {
  process.env.DEVECO_SDK_HOME = compatSdkRoot;
  process.env.OHOS_BASE_SDK_HOME = path.join(compatSdkRoot, 'openharmony');

  try {
    const pluginRoot = getPluginRoot();
    if (pluginRoot) {
      const loaderModule = require(path.join(pluginRoot, 'src', 'sdk', 'hmos-sdk-loader.js'));
      const HmosSdkLoader = loaderModule?.HmosSdkLoader;

      if (HmosSdkLoader && !HmosSdkLoader.__telegramHarmonyLegacySdkCompatPatched) {
        const prototype = HmosSdkLoader.prototype;
        const originalGetHmosSdkComponents = prototype.getHmosSdkComponents;
        const originalGetHmsSdkComponents = prototype.getHmsSdkComponents;

        prototype.getHmosSdkComponents = async function (sdkVersion: any, components: string[]) {
          const fallback = loadLegacyComponents(compatSdkRoot, 'openharmony', components);
          if (fallback && fallback.size === components.length) {
            const cache = this.sdkMap?.get?.(sdkVersion?.fullVersion) ?? new Map();
            fallback.forEach((value: any, key: string) => cache.set(key, value));
            this.sdkMap?.set?.(sdkVersion?.fullVersion, cache);
            return new Map(components.map((component: string) => [component, cache.get(component)]));
          }
          return originalGetHmosSdkComponents.call(this, sdkVersion, components);
        };

        prototype.getHmsSdkComponents = async function (sdkVersion: any, components: string[]) {
          const fallback = loadLegacyComponents(compatSdkRoot, 'hms', components);
          if (fallback && fallback.size === components.length) {
            const cache = this.hmsSdkMap?.get?.(sdkVersion?.api) ?? new Map();
            fallback.forEach((value: any, key: string) => cache.set(key, value));
            this.hmsSdkMap?.set?.(sdkVersion?.api, cache);
            return new Map(components.map((component: string) => [component, cache.get(component)]));
          }
          return originalGetHmsSdkComponents.call(this, sdkVersion, components);
        };

        HmosSdkLoader.__telegramHarmonyLegacySdkCompatPatched = true;
      }
    }
  } catch {
    // Fallback to the stock plugin behavior when the internal layout changes.
  }
}

const { appTasks } = require('@ohos/hvigor-ohos-plugin');

export { appTasks };
