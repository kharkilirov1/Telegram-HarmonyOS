// Node >=24 + C++17 compiler. Diagnostic audit, not a device/whole-TDLib test.
// Intentionally excluded from test-*.cjs discovery; use --strict for the open lifetime gate.
// Runs actual Gateway/Dispatcher/Runtime through existing read-only host fixtures.
// Replays their native-boundary traces through the verbatim threaded ClientManager::Impl
// from the local TDLib source. Scheduler/TD actor/queue/locks are explicit fixtures.
// Default is an audit: exit 0 means reproductions/controls executed, NOT lifetime
// acceptance. --strict exits 1 on remaining findings. This keeps independent
// client-ownership findings visible without pretending the stop-barrier fixes them.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { createHash } = require('node:crypto');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const sourceFiles = [
  'entry/src/main/ets/infra/td/gateway/TdGateway.ets',
  'entry/src/main/ets/app/bootstrap/AppCoreRuntime.ets',
  'entry/src/main/ets/infra/threading/MainThreadDispatcher.ets',
  'entry/src/main/ets/types/libtdlib_napi.d.ts',
  'tdlib/td/telegram/Client.cpp', 'tdlib/td/telegram/ClientJson.cpp',
  'tdlib/td/telegram/td_json_client.cpp', 'tdlib/td/telegram/td_json_client.h',
  'scripts/test-td-gateway-recovery.cjs', 'scripts/test-runtime-account-recovery.cjs'
];
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const hash = file => createHash('sha256').update(fs.readFileSync(path.join(root, file))).digest('hex');
const hashes = Object.fromEntries(sourceFiles.map(file => [file, hash(file)]));
const { fixture, auth, observed } = require('./test-td-gateway-recovery.cjs');
const { fixture: runtimeFixture } = require('./test-runtime-account-recovery.cjs');
const tick = () => new Promise(resolve => setImmediate(resolve));
const findings = [];
let controls = 0;

// Do not reimplement ClientManager's lifetime logic. Extract the entire second
// (threaded) class; fail closed if the source layout no longer matches.
const clientSource = read('tdlib/td/telegram/Client.cpp');
const marker = 'class ClientManager::Impl final {';
const first = clientSource.indexOf(marker);
const begin = clientSource.indexOf(marker, first + marker.length);
const end = clientSource.indexOf('\nclass Client::Impl final {', begin);
assert.ok(first >= 0 && begin > first && end > begin);
assert.equal(clientSource.indexOf(marker, begin + marker.length), -1);
const managerSource = clientSource.slice(begin, end);
const managerLine = clientSource.slice(0, begin).split('\n').length;

const cppPrefix = String.raw`
#include <iostream>
#include <memory>
#include <map>
#include <deque>
#include <string>
#include <stdexcept>
#include <cstdint>
#define CHECK(x) do { if (!(x)) throw std::runtime_error(#x); } while (false)
struct QuietLog { template<class T> QuietLog &operator<<(const T &) { return *this; } };
#define LOG(x) QuietLog()
namespace td_api {
struct Object { virtual int get_id() const = 0; virtual ~Object() = default; };
template<class T> using object_ptr = std::unique_ptr<T>;
template<class T, class... Args> auto make_object(Args&&... args) {
  return std::make_unique<T>(std::forward<Args>(args)...);
}
struct Function : Object { int get_id() const override { return 1; } };
struct error : Object {
  int code; error(int c, const char *) : code(c) {}
  int get_id() const override { return 2; }
};
struct authorizationStateClosed : Object {
  static constexpr int ID = 3; int get_id() const override { return ID; }
};
struct updateAuthorizationState : Object {
  static constexpr int ID = 4; object_ptr<Object> authorization_state_;
  explicit updateAuthorizationState(object_ptr<Object> state) : authorization_state_(std::move(state)) {}
  int get_id() const override { return ID; }
};
}
struct ClientManager {
  using ClientId = int; using RequestId = uint64_t;
  struct Response { ClientId client_id; RequestId request_id; td_api::object_ptr<td_api::Object> object; };
  class Impl;
};
template<class K, class V> using FlatHashMap = std::map<K, V>;
template<class T> void reset_to_empty(T &value) { value.clear(); }
struct RwMutex {
  struct Lock { void reset() {} };
  Lock lock_read() { return {}; } Lock lock_write() { return {}; }
};
struct ExitGuard { static bool is_exited() { return false; } };
struct TdReceiver {
  std::deque<ClientManager::Response> queue;
  struct Callback { int id; TdReceiver *receiver; };
  Callback create_callback(int id) { return {id, this}; }
  void add_response(int id, uint64_t request, td_api::object_ptr<td_api::Object> object) {
    queue.push_back({id, request, std::move(object)});
  }
  ClientManager::Response receive(double, bool) {
    if (queue.empty()) return {0, 0, nullptr};
    auto response = std::move(queue.front()); queue.pop_front(); return response;
  }
};
struct MultiImpl {
  static inline int last_id = 0;
  std::map<int, TdReceiver::Callback> callbacks;
  static int create_id() { return ++last_id; }
  static bool is_valid_client_id(int id) { return id > 0 && id <= last_id; }
  void create(int id, TdReceiver::Callback callback) { callbacks.emplace(id, callback); }
  // No simulated close-on-send: receipt of Closed is independently driven.
  void send(int, uint64_t, td_api::object_ptr<td_api::Function>) {}
  void close(int id) {
    auto cb = callbacks.at(id); callbacks.erase(id);
    // Match actual TdReceiver::Callback destructor sentinel (Client.cpp).
    cb.receiver->add_response(id, 0, nullptr);
  }
};
struct MultiImplPool {
  std::shared_ptr<MultiImpl> get() { return std::make_shared<MultiImpl>(); }
  void try_clear() {}
};
// White-box observation only: statements in the actual class are unchanged.
#define private public
`;
const cppSuffix = String.raw`
#undef private
int main() {
  try {
    ClientManager::Impl manager;
    std::string op, method; int id; uint64_t request = 1;
    size_t public_closed = 0;
    while (std::cin >> op) {
      if (op == "C") { CHECK(manager.create_client_id() > 0); }
      else if (op == "S") {
        std::cin >> id >> method;
        manager.send(id, request++, td_api::make_object<td_api::Function>());
      } else if (op == "E") {
        std::cin >> id;
        manager.receiver_.add_response(id, 0, td_api::make_object<td_api::updateAuthorizationState>(
          td_api::make_object<td_api::authorizationStateClosed>()));
      } else if (op == "R") {
        auto response = manager.receive(0);
        if (response.object && response.object->get_id() == td_api::updateAuthorizationState::ID) public_closed++;
      } else if (op == "T") {
        // NAPI receive-worker stop has no ClientManager API/side effect.
      } else { throw std::runtime_error("Unexpected trace command"); }
    }
    size_t initialized = 0;
    for (const auto &entry : manager.impls_) if (entry.second.impl) initialized++;
    std::cout << "{\"slots\":" << manager.impls_.size()
      << ",\"initialized\":" << initialized << ",\"publicClosed\":" << public_closed << "}\n";
    // Normal manager destructor drains fixtures; measurement above is pre-dtor.
  } catch (const std::exception &e) { std::cerr << e.what() << '\n'; return 2; }
}
`;

function run(command, args, input) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', input, timeout: 30000 });
  assert.equal(result.error, undefined, String(result.error));
  assert.equal(result.status, 0, `${command}: ${result.stdout}\n${result.stderr}`);
  return result.stdout;
}
let binary;
function replay(trace) {
  return JSON.parse(run(binary, [], trace.join('\n') + '\n'));
}
function finding(name, evidence) {
  findings.push(name);
  console.log('FINDING ' + name + ' ' + JSON.stringify(evidence));
}
function control(name, evidence) {
  controls++;
  console.log('CONTROL ' + name + ' ' + JSON.stringify(evidence));
}
async function transport() {
  const f = await fixture(undefined, false);
  f.trace = [];
  const create = f.native.createClient, send = f.native.send, stop = f.native.stopReceiveLoop;
  f.native.createClient = () => { f.trace.push('C'); return create(); };
  f.native.send = (id, json) => { f.trace.push(`S ${id} ${JSON.parse(json)['@type']}`); send(id, json); };
  f.native.stopReceiveLoop = () => { f.trace.push('T'); return stop(); };
  f.closed = async (id, envelopes = []) => {
    // Public Closed is emitted only after manager consumed internal Closed + sentinel.
    f.trace.push(`E ${id}`, 'R', 'R');
    f.callbacks.at(-1)(JSON.stringify([...envelopes, auth(id, 'Closed')]));
    await f.flush();
  };
  f.fire = async ms => {
    const timers = [...f.timers].filter(([, value]) => value.ms === ms);
    assert.equal(timers.length, 1, `exactly one active ${ms}ms timeout`);
    f.timers.delete(timers[0][0]); timers[0][1].fn(); await f.flush();
  };
  return f;
}

async function audit() {
  // Known-answer oracle: stopped receive is NOT close; both receive stages matter.
  assert.deepEqual(replay(['C', 'T', 'R']), { slots: 1, initialized: 0, publicClosed: 0 });
  assert.deepEqual(replay(['C', 'S 1 close', 'E 1', 'R']), { slots: 1, initialized: 1, publicClosed: 0 });
  assert.deepEqual(replay(['C', 'S 1 close', 'E 1', 'R', 'R']), { slots: 0, initialized: 0, publicClosed: 1 });
  control('actual-manager-two-phase-release; no-close/one-receive null twins retain ID', { retained: [1, 1, 0] });

  const failed = await transport();
  failed.native.startReceiveLoop = () => { throw new Error('Injected callback startup failure'); };
  for (let attempt = 0; attempt < 3; attempt++) await assert.rejects(failed.gateway.initialize(), /TDLib init failed/);
  await failed.gateway.destroy();
  assert.equal(failed.sends.length, 0);
  assert.equal(failed.gateway.getState(), 'idle');
  const leaked = replay(failed.trace);
  if (leaked.slots === 0 && failed.created() === 0) {
    control('startup-receive-failure-does-not-allocate-IDs', { ...leaked, trace: failed.trace });
  } else {
    finding('startup-failure-orphans-manager-IDs', { ...leaked, gateway: failed.gateway.getState(),
      generation: failed.gateway.getClientGeneration(), trace: failed.trace });
  }
  // Same actual manager + supported explicit close/drain, without changing gateway.
  const repairedTrace = ['C', 'C', 'C'].concat([1, 2, 3].flatMap(id => [`S ${id} close`, `E ${id}`, 'R', 'R']));
  assert.deepEqual(replay(repairedTrace), { slots: 0, initialized: 0, publicClosed: 3 });
  control('retaining IDs and close/drain retires startup allocations', { slots: 0 });

  const rtFailure = await transport();
  rtFailure.native.startReceiveLoop = () => { throw new Error('Injected callback startup failure'); };
  await assert.rejects(runtimeFixture(rtFailure), /Failed to initialize AppCore pipeline/);
  assert.equal(rtFailure.sends.length, 0);
  const rtSlots = replay(rtFailure.trace).slots;
  if (rtSlots === 0 && rtFailure.created() === 0) {
    control('actual-AppCoreRuntime-start-failure-has-no-orphan', { trace: rtFailure.trace, slots: rtSlots });
  } else {
    finding('actual-AppCoreRuntime-init-cleanup-does-not-rescue-ID', { trace: rtFailure.trace, slots: rtSlots });
  }

  for (const closedFirst of [false, true]) {
    const f = await transport(); await f.gateway.initialize();
    const destroyed = observed(f.gateway.destroy());
    const close = f.sends.find(s => s.request['@type'] === 'close'); assert.ok(close);
    if (closedFirst) { await f.closed(1); f.reply(close); await f.flush(); }
    else { f.reply(close); await f.flush(); await f.closed(1); }
    assert.equal(destroyed.settled, true); assert.equal(destroyed.error, undefined);
    assert.deepEqual(replay(f.trace), { slots: 0, initialized: 0, publicClosed: 1 });
    assert.equal(f.gateway.getClientGeneration(), 1);
    control('graceful-destroy-' + (closedFirst ? 'Closed-before-Ok' : 'Ok-before-Closed'), { slots: 0, trace: f.trace });
  }

  for (const acknowledge of [true, false]) {
    const f = await transport(); await f.gateway.initialize();
    const destroyed = observed(f.gateway.destroy());
    if (acknowledge) { f.reply(f.sends[0]); await f.flush(); }
    await f.fire(acknowledge ? 5000 : 10000);
    assert.equal(destroyed.settled, true);
    const retained = replay(f.trace);
    assert.deepEqual(retained, { slots: 1, initialized: 1, publicClosed: 0 });
    if (destroyed.error && f.gateway.getState() === 'destroying' && f.stopped() === 0) {
      const createdBefore = f.created();
      await assert.rejects(f.gateway.initialize());
      assert.equal(f.created(), createdBefore);
      // AppCoreRuntime is allowed to detach its shared dispatcher after failure.
      f.dispatcher.unsubscribe();
      await f.closed(1);
      for (let i = 0; i < 12 && f.gateway.getState() !== 'idle'; i++) await f.flush();
      assert.equal(f.gateway.getState(), 'idle', 'late Closed must finish retirement without an app dispatcher');
      assert.equal(f.stopped(), 1);
      assert.equal(replay(f.trace).slots, 0);
      control(acknowledge ? 'close-Ok-timeout-retains-owner-until-late-Closed' : 'close-request-timeout-retains-owner-until-late-Closed',
        { slots: 0, trace: f.trace });
    } else {
      finding(acknowledge ? 'close-Ok-without-Closed-discards-owner' : 'close-timeout-discards-owner',
        { ...retained, gateway: f.gateway.getState(), generation: f.gateway.getClientGeneration(), trace: f.trace });
      // A later manager receive can retire it: timeout is unknown, not proof of forever-live DB.
      assert.equal(replay(f.trace.concat(['E 1', 'R', 'R'])).slots, 0);
    }
  }

  const concurrent = await transport(); await concurrent.gateway.initialize();
  const firstDestroy = observed(concurrent.gateway.destroy());
  const secondDestroy = observed(concurrent.gateway.destroy()); await tick();
  assert.equal(firstDestroy.settled, false);
  if (secondDestroy.settled) {
    finding('concurrent-gateway-destroy-is-not-a-completion-barrier', { firstSettled: false,
      secondSettled: true, state: concurrent.gateway.getState(), generation: concurrent.gateway.getClientGeneration() });
  } else {
    control('concurrent-gateway-destroy-awaits-completion', { bothPending: true });
  }
  concurrent.reply(concurrent.sends[0]); await concurrent.flush(); await concurrent.closed(1);
  assert.equal(firstDestroy.settled, true);

  // Defer the boundary completion to test Promise<void> integration, NOT native thread timing.
  const future = await transport();
  const runtime = await runtimeFixture(future);
  let resolveStop, stopCompleted = false;
  const stopPromise = new Promise(resolve => { resolveStop = resolve; });
  const stop = future.native.stopReceiveLoop;
  future.native.stopReceiveLoop = () => { stop(); return stopPromise; };
  const shutdown = observed(runtime.runtime.shutdown());
  const close = future.sends.find(s => s.request['@type'] === 'close'); assert.ok(close);
  future.reply(close); await future.flush(); await future.closed(1); await tick();
  const restart = observed(runtime.runtime.initialize()); await future.flush();
  assert.equal(stopCompleted, false);
  const barrierEvidence = { shutdownSettled: shutdown.settled, restartSettled: restart.settled,
    stopCompleted, createdBeforeStopCompletion: future.created() };
  if (shutdown.settled || restart.settled || future.created() !== 1) {
    finding('async-stop-is-not-awaited-through-runtime', barrierEvidence);
  } else {
    control('async-stop-awaited-through-runtime', barrierEvidence);
  }
  stopCompleted = true; resolveStop(); await tick();
  for (let turn = 0; turn < 12 && !restart.settled; turn++) await future.flush();
  assert.equal(restart.settled, true); assert.equal(restart.error, undefined);
  assert.equal(shutdown.settled, true); assert.equal(shutdown.error, undefined);
  assert.equal(future.created(), 2); assert.equal(future.callbacks.length, 2);
  const finalShutdown = observed(runtime.runtime.shutdown());
  const finalClose = future.sends.find(s => s.id === 2 && s.request['@type'] === 'close'); assert.ok(finalClose);
  future.callbacks.at(-1)(JSON.stringify([{ '@type': 'ok', '@client_id': 2, '@extra': finalClose.request['@extra'] }]));
  await future.flush(); await future.closed(2); assert.equal(finalShutdown.settled, true);

  for (const file of sourceFiles) assert.equal(hash(file), hashes[file], `source changed during audit: ${file}`);
  console.log('SOURCE_WITNESS ' + JSON.stringify({ managerLine, managerSha256:
    createHash('sha256').update(managerSource).digest('hex'), hashes }));
  console.log(`AUDIT ${controls} controls; ${findings.length} remaining findings. Audit completion is NOT lifetime acceptance.`);
  console.log('Scope: real source manager control flow + real ArkTS host execution; actor/scheduler/NAPI fixtures; no device, DB, accounts or memory-byte measurement.');
  if (process.argv.includes('--strict') && findings.length) process.exitCode = 1;
}

async function main() {
  const tempRoot = fs.realpathSync(os.tmpdir());
  const build = fs.mkdtempSync(path.join(tempRoot, 'telegram-client-lifetime-'));
  try {
    const cpp = path.join(build, 'manager.cpp');
    binary = path.join(build, process.platform === 'win32' ? 'manager.exe' : 'manager');
    fs.writeFileSync(cpp, cppPrefix + `\n#line ${managerLine} "tdlib/td/telegram/Client.cpp"\n` + managerSource + cppSuffix);
    run(process.env.CXX || (process.platform === 'win32' ? 'g++' : 'c++'), ['-std=c++17', '-Wall', '-Wextra', cpp, '-o', binary]);
    await audit();
  } finally {
    const resolved = fs.realpathSync(build);
    assert.equal(path.dirname(resolved), tempRoot);
    assert.ok(path.basename(resolved).startsWith('telegram-client-lifetime-'));
    fs.rmSync(resolved, { recursive: true, force: true });
  }
}
main().catch(error => { console.error('HARNESS_ERROR', error); process.exitCode = 2; });
