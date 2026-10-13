// Both actual playback classes; only SDK/files/network are controlled boundaries.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const { fixture, deferred, flush } = require('./test-media-playback-ownership.cjs');
const file = path.join(__dirname, '../entry/src/main/ets/ui/pages/chat/GlobalMediaPlayback.ets');
const code = fs.readFileSync(file, 'utf8').replace(/^import[\s\S]*?;\s*/gm, '')
  .replace(/@ObservedV2\s*/g, '').replace(/@Trace\s*/g, '').replace(/^export\s+/gm, '')
  .replace(/^const globalMediaPlayback: GlobalMediaPlayback = new GlobalMediaPlayback\(\);?\s*$/m, '');
function setup() {
  const f = fixture(); const find = deferred();
  const deps = {
    MediaPlaybackController: class { constructor() { return f.controller; } },
    createSearchChatMessagesUseCase: () => ({ findAdjacentAudio: () => find.promise, downloadAudioSync: async () => '/downloaded', requestThumbDownload: async () => '' }),
    getTdGatewayAdapter: () => ({}), hilog: { debug() {}, warn() {} },
    AVSessionManager: {}, backgroundTaskManager: {}, wantAgent: {}
  };
  const loaded = new Function(...Object.keys(deps), stripTypeScriptTypes(code, { mode: 'strip' }) + '\nreturn { GlobalMediaPlayback, mediaPlaybackUIState };')(...Object.values(deps));
  const global = new loaded.GlobalMediaPlayback();
  const account = { createScope() { return this; }, isScopeCurrent: () => true,
    subscribeScopeInvalidation: () => () => {} };
  global.createPageHandle(account, -10, () => true).setNowPlaying('', '');
  return { f, global, ui: loaded.mediaPlaybackUIState, find };
}
const track = { messageId: 'T', localPath: '/T', fileId: 1, title: 'Track T', performer: 'Artist T', coverPath: '', coverFileId: 0 };
const tests = [
  ['real controller zero/start snapshots preserve metadata and adjacent success', async () => {
    const { f, global, ui, find } = setup(); global.setNowPlaying('Track A', 'Artist A', -10);
    const { work } = await f.start('A'); await work; assert.equal(ui.title, 'Track A'); assert.equal(ui.isPlaying, true);
    const next = global.playNextAudio(); find.resolve(track); await flush();
    assert.equal(f.creates.length, 2, 'next actually requests a player'); f.creates[1].resolve(f.player('T'));
    assert.equal(await next, true); assert.equal(ui.messageId, 'T'); assert.equal(ui.title, 'Track T'); assert.equal(ui.chatId, -10);
    await global.stop(); assert.equal(ui.hasActive, false); assert.deepEqual(f.closed, [1, 2]); assert.deepEqual(f.violations, []);
  }],
  ['global stop cancels network-delayed next without reviving actual controller', async () => {
    const { f, global, ui, find } = setup(); global.setNowPlaying('Track A', '', -10); const { work } = await f.start('A'); await work;
    const next = global.playNextAudio(); await global.stop(); find.resolve(track); assert.equal(await next, false);
    assert.equal(f.creates.length, 1); assert.equal(ui.messageId, '0'); assert.equal(f.players[0].releases, 1); assert.deepEqual(f.violations, []);
  }],
  ['new track defeats old adjacent lookup through actual snapshots', async () => {
    const { f, global, ui, find } = setup(); global.setNowPlaying('Track A', '', -10); const { work: a } = await f.start('A'); await a;
    const next = global.playNextAudio(); global.setNowPlaying('Track B', '', -20); const { work: b } = await f.start('B'); await b;
    find.resolve(track); assert.equal(await next, false); assert.equal(ui.messageId, 'B'); assert.equal(ui.title, 'Track B'); assert.equal(ui.chatId, -20);
    assert.equal(f.creates.length, 2); assert.equal(f.players[1].releases, 0); assert.deepEqual(f.violations, []);
  }],
  ['global stop cancels native create already requested by adjacent playback', async () => {
    const { f, global, ui, find } = setup(); global.setNowPlaying('Track A', '', -10); const { work } = await f.start('A'); await work;
    const next = global.playNextAudio(); find.resolve(track); await flush(); assert.equal(f.creates.length, 2);
    await global.stop(); const p = f.player('T'); f.creates[1].resolve(p); assert.equal(await next, false);
    assert.equal(p.prepares, 0); assert.equal(p.releases, 1); assert.equal(ui.messageId, '0'); assert.deepEqual(f.violations, []);
  }]
];
async function main() {
  let passed = 0, failed = 0;
  for (const [name, run] of tests) {
    let timeout;
    try { await Promise.race([run(), new Promise((_, reject) => { timeout = setTimeout(() => reject(new Error('test did not settle')), 1500); })]); passed++; console.log('PASS ' + name); }
    catch (e) { failed++; console.error('FAIL ' + name + '\n' + e.stack); }
    finally { clearTimeout(timeout); }
  }
  console.log(JSON.stringify({ passed, failed })); process.exitCode = failed ? 1 : 0;
}
main().catch(e => { console.error(e); process.exitCode = 1; });
