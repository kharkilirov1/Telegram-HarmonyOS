// Shared ArkTS module loader for the host suites.
//
// The suites used to strip imports and evaluate a file in isolation, so a class moved into another module did
// not exist for them and god files could not be split. This loader resolves local imports, caches modules and
// auto-stubs the ambient ArkUI runtime: any Capitalised identifier the module uses as a member base (for
// example FontWeight.Bold or TextAlign.Center) becomes a proxy that answers with the member name, which is
// enough for token and presentation modules to evaluate without a UI context.
//
// API: createLoader(baseDirectory) -> load(relativePath, names?, deps?)

const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');

const IMPORT_PATTERN = /^import\s+([\s\S]*?)\s+from\s+['"]([^'"]+)['"];?\s*$/gm;
const SIDE_EFFECT_IMPORT = /^import\s+['"][^'"]+['"];?\s*$/gm;
const EXPORT_FROM_PATTERN = /^export\s*\{([\s\S]*?)\}\s*from\s*['"]([^'"]+)['"];?\s*$/gm;
const EXPORT_LIST_PATTERN = /^export\s*\{([^}]*)\};?\s*$/gm;
const DECLARATION_PATTERN = /^export\s+(?:async\s+)?(class|function|enum|const|let|type|interface)\s+(\w+)/gm;
const MEMBER_BASE_PATTERN = /\b([A-Z][A-Za-z0-9_]*)\./g;

const NATIVE_GLOBALS = new Set([
  'Array', 'ArrayBuffer', 'BigInt', 'Boolean', 'Buffer', 'Date', 'Error', 'EvalError', 'Float32Array',
  'Float64Array', 'Function', 'Infinity', 'Int16Array', 'Int32Array', 'Int8Array', 'Intl', 'JSON', 'Map',
  'Math', 'NaN', 'Number', 'Object', 'Promise', 'Proxy', 'RangeError', 'ReferenceError', 'Reflect',
  'RegExp', 'Set', 'String', 'Symbol', 'SyntaxError', 'TypeError', 'URIError', 'Uint16Array', 'Uint32Array',
  'Uint8Array', 'Uint8ClampedArray', 'WeakMap', 'WeakSet', 'undefined'
]);

function memberProxy() {
  const callable = function () { return memberProxy(); };
  return new Proxy(callable, {
    get: (target, property) => {
      if (property === 'toString' || property === 'valueOf') return () => '';
      if (property === Symbol.toPrimitive) return () => '';
      if (property === 'then') return undefined;
      return memberProxy();
    },
    apply: () => memberProxy()
  });
}

function bindingNames(binding) {
  const trimmed = binding.trim();
  const namespace = /^\*\s+as\s+(\w+)$/.exec(trimmed);
  if (namespace) return [{ imported: '*', local: namespace[1] }];
  const named = /^\{([\s\S]*)\}$/.exec(trimmed);
  if (named) {
    return named[1].split(',').map((part) => part.trim()).filter(Boolean).map((part) => {
      const [imported, local = imported] = part.split(/\s+as\s+/).map((value) => value.trim());
      return { imported, local };
    });
  }
  return [{ imported: 'default', local: trimmed }];
}

function createLoader(baseDirectory) {
  const cache = new Map();
  const inFlight = new Set();

  function resolvePath(relative) {
    const candidates = [
      path.resolve(baseDirectory, relative.replace(/^[./\\]+/, '')),
      path.resolve(baseDirectory, relative)
    ];
    for (const candidate of candidates) {
      if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) return candidate;
      if (fs.existsSync(candidate + '.ets')) return candidate + '.ets';
    }
    throw new Error('ets-load: cannot resolve ' + relative);
  }

  function evaluate(relative, overrides) {
    const absolute = resolvePath(relative);
    if (cache.has(absolute)) return cache.get(absolute);
    if (inFlight.has(absolute)) return {};
    inFlight.add(absolute);
    try {
      const source = fs.readFileSync(absolute, 'utf8').replaceAll('\r\n', '\n');
      const directory = path.dirname(absolute);
      const resolved = {};
      const external = new Set();
      const unresolved = [];

      for (const match of [...source.matchAll(IMPORT_PATTERN)]) {
        const specifier = match[2];
        const names = bindingNames(match[1]);
        if (!specifier.startsWith('.')) {
          for (const binding of names) {
            external.add(binding.local);
            if (!(binding.local in overrides)) resolved[binding.local] = memberProxy();
          }
          continue;
        }
        let child;
        try {
          child = evaluate(path.resolve(directory, specifier), {});
        } catch (error) {
          // A module that cannot be resolved (a type-only shim, an absent barrel) degrades to undefined
          // bindings: the caller's explicit deps still win and unused imports stay harmless.
          child = {};
          unresolved.push(path.basename(absolute) + ' -> ' + specifier + ': ' + error.message);
        }
        for (const binding of names) {
          const value = binding.imported === '*' ? child
            : binding.imported === 'default' ? child : child[binding.imported];
          // An unresolved enum or class still has to answer member lookups; a missing value would crash at
          // the first TdObjectType.Search and look like a logic bug.
          resolved[binding.local] = value === undefined && /^[A-Z]/.test(binding.local) ? memberProxy() : value;
        }
      }

      const reExported = [];
      for (const match of [...source.matchAll(EXPORT_FROM_PATTERN)]) {
        const specifier = match[2];
        if (!specifier.startsWith('.')) continue;
        const child = evaluate(path.resolve(directory, specifier), {});
        for (const part of match[1].split(',').map((value) => value.trim()).filter(Boolean)) {
          const [imported, exported = imported] = part.split(/\s+as\s+/).map((value) => value.trim());
          resolved[exported] = child[imported];
          reExported.push(exported);
        }
      }
      for (const match of [...source.matchAll(EXPORT_LIST_PATTERN)]) {
        for (const part of match[1].split(',').map((value) => value.trim()).filter(Boolean)) {
          const [local, exported = local] = part.split(/\s+as\s+/).map((value) => value.trim());
          if (resolved[exported] === undefined && resolved[local] !== undefined) {
            resolved[exported] = resolved[local];
          }
          reExported.push(exported);
        }
      }

      const body = source
        .replace(IMPORT_PATTERN, '')
        .replace(SIDE_EFFECT_IMPORT, '')
        .replace(EXPORT_FROM_PATTERN, '')
        .replace(EXPORT_LIST_PATTERN, '')
        .replace(/^export\s+default\s+/gm, '')
        .replace(/^export\s+/gm, '')
        .replace(/^@ObservedV2\s*\n/gm, '')
        .replace(/^(\s*)@Trace\s+/gm, '$1');

      const declared = [...source.matchAll(DECLARATION_PATTERN)]
        .filter((match) => match[1] !== 'type' && match[1] !== 'interface')
        .map((match) => match[2]);

      // Locals matter as much as exports: COMMAND_SERIALIZATION_HANDLERS.set(...) is a declaration, not an
      // ambient global, and injecting a stub for it would collide with the module's own const.
      const locals = [...body.matchAll(/^\s*(?:export\s+)?(?:const|let|var|class|function|enum)\s+(\w+)/gm)]
        .map((match) => match[1]);
      const known = new Set([...Object.keys(resolved), ...declared, ...locals, ...external, ...NATIVE_GLOBALS]);
      const stubs = {};
      for (const match of body.matchAll(MEMBER_BASE_PATTERN)) {
        const name = match[1];
        if (known.has(name) || stubs[name] !== undefined) continue;
        stubs[name] = memberProxy();
      }

      const dependencies = {
        $r: (id) => ({ id: String(id) }),
        $rawfile: (id) => ({ id: String(id) }),
        hilog: { info() {}, debug() {}, warn() {}, error() {} },
        ...stubs,
        ...resolved,
        ...overrides
      };
      const exportList = declared.concat(reExported.filter((name) => !declared.includes(name)));
      const code = stripTypeScriptTypes(body, { mode: 'transform' }) +
        '\nreturn {' + exportList.join(',') + '};';
      const parameterNames = Object.keys(dependencies);
      const duplicated = parameterNames.filter((name) => new RegExp('(?:^|\\n)\\s*(?:const|let|var|class|function)\\s+' + name + '\\b').test(code));
      if (duplicated.length > 0) {
        throw new Error('ets-load: ' + path.basename(absolute) + ' declares injected names: ' + duplicated.join(', '));
      }
      const result = new Function(...parameterNames, code)(...Object.values(dependencies));
      for (const name of Object.keys(resolved)) {
        if (result[name] === undefined) result[name] = resolved[name];
      }
      if (unresolved.length > 0) result.__unresolved = unresolved;
      cache.set(absolute, result);
      return result;
    } finally {
      inFlight.delete(absolute);
    }
  }

  return function load(relative, names, deps) {
    let requested = names;
    let dependencies = deps;
    if (Array.isArray(names)) {
      requested = names;
      dependencies = deps === undefined ? {} : deps;
    } else if (names !== undefined && typeof names === 'object') {
      dependencies = names;
      requested = undefined;
    }
    const exports = evaluate(relative, dependencies === undefined ? {} : dependencies);
    if (!Array.isArray(requested)) return exports;
    const picked = {};
    for (const name of requested) picked[name] = exports[name];
    return picked;
  };
}

module.exports = { createLoader };
