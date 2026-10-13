// Test-only source boundary. Never imported by application code.
// Runtime behavior comes from current production exports and is accepted only
// when the current Session actually delegates to the matching export.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { stripTypeScriptTypes } = require('node:module');
const manifest = require('./chat-screen-probe-signatures.cjs');
// UI events introduced by the decomposition have the same ordered forwarding
// contract as the original method manifest. Do not infer it from the call body.
const eventArguments = {
  getComposerInputRevision: [],
  removePendingPhoto: ['uri'],
  movePendingPhoto: ['uri', 'direction'],
  handleTimelineScrollIndex: ['start', 'end'],
  handleComposerTextChange: ['value'],
  handleComposerAreaChange: ['height'],
  handleGalleryIndexChange: ['index'],
  handleNavReady: ['context'],
  handleNavShown: [],
  handleNavBackPressed: []
};
const PAGE = 'TgChatScreenPage.ets';
const normalize = text => text.replaceAll('\r\n', '\n');
const raw = file => fs.readFileSync(file, 'utf8');
function receiverBridge(text, from = 'host', to = 'this') {
  function segment(start, expression = false) {
    let out = '', index = start, depth = 0;
    while (index < text.length) {
      const ch = text[index];
      if (expression && ch === '}' && depth === 0) return [out, index];
      if (ch === "'" || ch === '"') {
        let end = index + 1;
        while (end < text.length) {
          if (text[end] === '\\') end += 2;
          else if (text[end++] === ch) break;
        }
        out += text.slice(index, end); index = end; continue;
      }
      if (text.startsWith('//', index) || text.startsWith('/*', index)) {
        const line = text.startsWith('//', index);
        let end = line ? text.indexOf('\n', index) : text.indexOf('*/', index + 2);
        if (end < 0) end = text.length; else if (!line) end += 2;
        out += text.slice(index, end); index = end; continue;
      }
      if (ch === '`') {
        out += ch; index++;
        while (index < text.length) {
          if (text[index] === '\\') { out += text.slice(index, index + 2); index += 2; }
          else if (text[index] === '`') { out += '`'; index++; break; }
          else if (text.startsWith('${', index)) {
            const [nested, end] = segment(index + 2, true);
            out += '${' + nested + '}'; index = end + 1;
          } else out += text[index++];
        }
        continue;
      }
      if (/[A-Za-z_$]/.test(ch)) {
        let end = index + 1;
        while (end < text.length && /[A-Za-z0-9_$]/.test(text[end])) end++;
        const token = text.slice(index, end);
        out += token === from ? to : token; index = end; continue;
      }
      if (ch === '{') depth++; else if (ch === '}') depth--;
      out += ch; index++;
    }
    assert.ok(!expression, 'complete template expression required');
    return [out, index];
  }
  return segment(0)[0];
}
const imports = source => [...source.matchAll(/^import\s+([\s\S]*?)\s+from\s+['"]([^'"]+)['"];?/gm)]
  .map(m => ({ binding: m[1], specifier: m[2] }));
function importedFile(file, specifier) {
  assert.ok(specifier.startsWith('.'), 'source owner import must be relative');
  return path.resolve(path.dirname(file), specifier + '.ets');
}
function fullExport(source, name) {
  const matches = [...source.matchAll(new RegExp(`^export (?:async )?function ${name}\\(`, 'gm'))];
  assert.equal(matches.length, 1, `one actual production export: ${name}`);
  const start = matches[0].index;
  const next = /^export\s/m.exec(source.slice(start + matches[0][0].length));
  const end = next ? start + matches[0][0].length + next.index : source.length;
  const full = source.slice(start, end).trimEnd();
  assert.ok(full.endsWith('}'), `complete production export: ${name}`);
  return full;
}
function sourceGraph(pageFile, { requireSplit = true, transform = source => source } = {}) {
  const read = file => transform(raw(file), file);
  const page = read(pageFile);
  const sessionImport = imports(page).find(item => /\bChatScreenSession\b/.test(item.binding));
  if (!sessionImport) {
    assert.ok(!requireSplit, 'page must import the production ChatScreenSession');
    return undefined;
  }
  const sessionFile = importedFile(pageFile, sessionImport.specifier);
  const session = read(sessionFile);
  const files = new Map([[path.resolve(pageFile), page], [sessionFile, session]]);
  const aliases = new Map();
  for (const item of imports(session)) {
    if (!item.specifier.startsWith('.')) continue;
    if (!/delegate|\bChatScreenContext\b|\bChatScreenViewState\b/.test(item.binding)) continue;
    const file = importedFile(sessionFile, item.specifier);
    const source = read(file);
    files.set(file, source);
    const namespace = /^\* as (\w+)$/.exec(item.binding.trim());
    if (namespace) aliases.set(namespace[1], file);
    const named = /^\{([\s\S]*)\}$/.exec(item.binding.trim());
    if (named) for (const part of named[1].split(',')) {
      const [exportName, localName = exportName] = part.trim().split(/\s+as\s+/);
      aliases.set(localName, { file, exportName });
    }
  }
  const delegates = new Map();
  const originalNames = new Set(manifest.map(item => item.name));
  const extra = [...session.matchAll(/^  (?:async )?(\w+)\([^\n]+$/gm)]
    .map(match => match[1])
    .filter(name => name !== 'constructor' && !originalNames.has(name));
  assert.deepEqual([...extra].sort(), Object.keys(eventArguments).sort(),
    'every additional Session event must have an explicit argument contract');
  const eventManifest = extra.map(name => ({ name, extra: true, arguments: eventArguments[name] }));
  for (const item of [...manifest, ...eventManifest]) {
    const method = session.match(new RegExp(`^  (?:(?:public|private|async)\\s+)*${item.name}\\([^\\n]+$`, 'm'));
    assert.ok(method, `Session must expose ${item.name}`);
    const call = method[0].match(/(?:return\s+)?(?:await\s+)?(\w+)(?:\.(\w+))?\(this(?:,|\))/);
    assert.ok(call, `Session must delegate ${item.name} to a production export with its own receiver`);
    assert.match(method[0].slice(method[0].indexOf('{') + 1, method[0].lastIndexOf('}')),
      /^\s*(?:return\s+)?(?:await\s+)?\w+(?:\.\w+)?\(this(?:,[\s\S]*)?\);\s*$/,
      `Session must contain only the actual delegate call: ${item.name}`);
    const imported = aliases.get(call[1]);
    assert.ok(imported, `Session delegate must resolve an import: ${item.name}`);
    const file = typeof imported === 'string' ? imported : imported.file;
    const exportName = call[2] || imported.exportName;
    assert.equal(exportName, item.name, `Session delegate preserves method identity: ${item.name}`);
    assert.ok(method[0].replace(/\s/g, '').includes(
      `${call[1]}${call[2] ? '.' + call[2] : ''}(this${item.arguments.length ? ',' + item.arguments.join(',') : ''})`),
      `Session must forward every argument in order: ${item.name}`);
    const source = files.get(file);
    const exported = fullExport(source, exportName);
    delegates.set(item.name, { file, source, exported, delegate: method[0], binding: call[1], exportName,
      arguments: item.arguments });
  }
  // Only transitively referenced new owners are included. An unused file cannot
  // make an old static behavior/render contract pass.
  const directory = path.dirname(pageFile);
  const pending = [...files.keys()];
  while (pending.length) {
    const owner = pending.pop();
    for (const item of imports(files.get(owner))) {
      if (!item.specifier.startsWith('.')) continue;
      const file = importedFile(owner, item.specifier);
      if (path.dirname(file) !== directory || files.has(file)) continue;
      if (!/^ChatScreen|^Chat(?:Chrome|ComposerState|PanelsState|TimelineViewState|MediaViewState|PinnedSearchState|ScrollPositionCache)|^TgChat(?:Timeline|ComposerDock|KeyboardPanels|MessageActionsPopup|PinnedOverlay|MediaOverlay)/.test(path.basename(file))) continue;
      files.set(file, read(file)); pending.push(file);
    }
  }
  return { pageFile, page, sessionFile, session, files, aliases, delegates };
}
function probeSource(graph) {
  const constants = new Map();
  for (const source of graph.files.values()) for (const match of source.matchAll(/^const (\w+) = ([^\n]+);$/gm)) {
    if (!constants.has(match[1])) constants.set(match[1], match[0]);
  }
  const probes = [...manifest];
  // New Session getters are real exported bodies too. The source graph
  // already validates their receiver, identity and ordered argument forwarding.
  for (const [name, delegate] of graph.delegates) {
    if (probes.some(item => item.name === name) || !/^get[A-Z]/.test(name)) continue;
    const header = delegate.exported.slice(0, delegate.exported.indexOf('{')).trim();
    const signature = receiverBridge(header.replace(/^export (async )?function /, '$1')
      .replace(/\(host: \w+(?:,\s*)?/, '(')).trim();
    probes.push({ name, signature, extra: true });
  }
  const methods = probes.map(item => {
    const { exported } = graph.delegates.get(item.name);
    const bodyAt = exported.indexOf('{');
    const header = exported.slice(0, bodyAt).trim();
    const actualSignature = receiverBridge(header.replace(/^export (async )?function /, '$1')
      .replace(/\(host: \w+(?:,\s*)?/, '(')).trim();
    assert.equal(actualSignature.replace(/\s+/g, ''), item.signature.replace(/^private /, '').trim().replace(/\s+/g, ''),
      `probe signature must match the actual export: ${item.name}`);
    // A class-method probe has an implicit receiver; this is the only behavior
    // syntax bridge. No baseline implementation or baseline fields are read.
    const body = receiverBridge(exported.slice(bodyAt));
    // Standalone new exports have function-level indentation. Bridge indentation
    // for legacy class-method extraction without substituting any behavior.
    return '  ' + item.signature + ' ' + (item.extra ? body.replace(/\n/g, '\n  ') : body);
  });
  return [...constants.values()].join('\n') + '\n' + methods.join('\n\n');
}
function contractSource(graph, { bindings = true } = {}) {
  const behaviorFiles = new Set([...graph.delegates.values()].map(item => item.file));
  const moduleImports = [...behaviorFiles].map(file => imports(graph.files.get(file))
    .map(item => `import ${item.binding} from '${item.specifier}';`).join('\n')).join('\n');
  const source = moduleImports + '\n' + [...graph.files.entries()].filter(([file]) => file !== graph.sessionFile && !behaviorFiles.has(file) &&
    !/ChatScreenViewPorts/.test(path.basename(file)) && (bindings || !/ChatScreenViewBindings/.test(path.basename(file))))
    .map(([file, text]) => {
      if (path.resolve(file) === path.resolve(graph.pageFile)) for (const { name } of manifest) {
        text = text.replace(new RegExp(`^  (?:(?:private|public|async)\\s+)*${name}\\([\\s\\S]*?^  \\}\\n?`, 'm'), '');
      }
      return `// Actual owner: ${path.basename(file)}\n${text}`;
    }).join('\n');
  // Flatten only receiver paths for historical static contracts. Decorators,
  // field declarations, callbacks and all bodies remain current source text.
  const normalized = receiverBridge(source)
    .replace(/\bthis\.(?:view|state)\.(?:chrome|composer|panels|timeline|media|pinnedSearch)\./g, 'this.')
    .replace(/\bthis\.(?:chrome|composer|panels|timeline|media|pinnedSearch|bindings)\./g, 'this.')
    .replace(/\bthis\.session\b/g, 'this')
    .replace(/\bthis\.entry\b/g, 'entry');
  return probeSource(graph) + '\n' + normalized;
}
function readChatSource(file, encoding = 'utf8') {
  if (path.basename(String(file)) !== PAGE) return fs.readFileSync(file, encoding);
  const graph = sourceGraph(String(file), { requireSplit: false });
  return graph ? contractSource(graph, { bindings: false }) : fs.readFileSync(file, encoding);
}
function fieldInitializers(pageFile, names) {
  const graph = sourceGraph(pageFile);
  const declarations = [];
  for (const name of names) {
    const hits = [];
    for (const [file, source] of graph.files) {
      if (!/ChatScreenContext|Chat(?:Chrome|Composer|Panels|TimelineView|MediaView|PinnedSearch)State/.test(path.basename(file))) continue;
      const match = source.match(new RegExp(`^  (?:@Trace )?(?:private )?${name}[^\\n]*;`, 'm'));
      if (match) hits.push(match[0].replace('@Trace ', ''));
    }
    assert.equal(hits.length, 1, `one actual state initializer: ${name}`);
    declarations.push(hits[0]);
  }
  return declarations.join('\n');
}
function compileExports(graph, deps, mutate = source => source, probeOverrides = {}) {
  const modules = new Map();
  for (const { file, source } of graph.delegates.values()) {
    if (modules.has(file)) continue;
    let changed = mutate(source, file);
    for (const [name, probe] of Object.entries(probeOverrides)) {
      const owner = graph.delegates.get(name);
      if (!owner || owner.file !== file) continue;
      const bodyAt = probe.indexOf('{');
      const original = fullExport(changed, name);
      changed = changed.replace(original, original.slice(0, original.indexOf('{')) +
        receiverBridge(probe.slice(bodyAt), 'this', 'host'));
    }
    const names = [...changed.matchAll(/^export (?:async )?function (\w+)\(/gm)].map(m => m[1]);
    const code = changed.replace(/^import[\s\S]*?;\s*/gm, '').replace(/^export /gm, '');
    const locals = new Set([...code.matchAll(/^const (\w+)\b/gm)].map(m => m[1]));
    const injected = Object.fromEntries(Object.entries(deps).filter(([key]) => !locals.has(key)));
    modules.set(file, new Function(...Object.keys(injected), stripTypeScriptTypes(code, { mode: 'transform' }) +
      `\nreturn {${names.join(',')}};`)(...Object.values(injected)));
  }
  const bindings = {};
  for (const [alias, imported] of graph.aliases) {
    const file = typeof imported === 'string' ? imported : imported.file;
    if (!modules.has(file)) continue;
    bindings[alias] = typeof imported === 'string' ? modules.get(file) : modules.get(file)[imported.exportName];
  }
  const methods = [...graph.delegates.values()].map(item => item.delegate).join('\n');
  const Session = new Function(...Object.keys(bindings), stripTypeScriptTypes(`class ActualSessionDelegates {\n${methods}\n}`,
    { mode: 'transform' }) + '\nreturn ActualSessionDelegates;')(...Object.values(bindings));
  return { modules, Session };
}
module.exports = { sourceGraph, probeSource, contractSource, readChatSource, fieldInitializers, compileExports, fullExport, imports, importedFile, raw, receiverBridge };
if (require.main === module) {
  assert.equal(process.argv[2], '--contract');
  const graph = sourceGraph(path.resolve(process.argv[3]), { requireSplit: false });
  process.stdout.write(graph ? contractSource(graph) : fs.readFileSync(process.argv[3], 'utf8'));
}
