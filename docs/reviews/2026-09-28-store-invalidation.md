# AppStore: синхронный observer отзыва account scope

Дата: 2026-09-28. **Реализовано и проверено на host; ArkTS build/device acceptance не заявлены.**

## Граница изменения

Worker изменяет только:
- `entry/src/main/ets/core/store/AppStore.ets`;
- `scripts/test-app-store-invalidation.cjs`;
- этот отчёт.

Runtime/media/page, общие STATUS/TODO/LESSONS, SDK implementation и default singleton не изменялись этим worker. Сборки, эмулятор, credentials, реальные сообщения, commits/push не запускались. Родитель независимо интегрирует API в media/page.

Прочитаны AGENTS, STATUS/TODO/DECISIONS, ARCHITECTURE, REFERENCES, активный AGENT_EXECUTION_PLAN → PRODUCTION_PARITY_PLAN (фаза надёжности), планы native-media/playback 09-28. Сохранена архитектура single-writer AppStore и существующие account epochs.

Grounding: `harmonyos_docs`, запрос `ArkTS "function types"`, раздел ArkTS / `arkts-no-ctor-signatures-iface` показывает типизированные callback-функции. Новых SDK APIs нет. Локальный iOS reference: `C:/Refs/Telegram/Telegram-iOS-current/submodules/SSignalKit/SwiftSignalKit/Source/Disposable.swift`, `ActionDisposable.dispose()` (строки 71–80): action обнуляется до вызова. Это ориентир one-shot/reentry, не доказательство iOS/runtime parity и не перенос Swift locks в однопоточный store.

## Контракт

`subscribeScopeInvalidation(listener: () => void): () => void`:
- root и current scope регистрируют одноразовый observer текущей эпохи;
- `invalidateScopes()` сначала повышает generation и удаляет прежние scoped state listeners, затем синхронно уведомляет observer до возврата;
- snapshot плюс удаление записи **до** callback обеспечивают one-shot, отмену следующего callback в том же проходе и повторный вход;
- новая root/scoped регистрация из callback принадлежит новой эпохе и не удаляется завершением внешнего прохода; отдельная вложенная invalidation вправе отозвать её;
- stale scope немедленно вызывает callback один раз, не регистрируя его в B; stale `invalidateScopes()` остаётся no-op;
- unsubscribe идемпотентен; одинаковая функция в разных регистрациях имеет независимые handles;
- exceptions callback, форматирования ошибки и диагностического sink изолированы.

Отдельный instance-owned Set, без polling/timers и нового singleton. Методы dispatch/batch, state subscribe/notify, reset/queued reset и clearState не переписаны. Root state subscriptions по-прежнему переживают invalidate; invalidation observer — нет. Observer означает отзыв scope, **не** завершение queued clear и не готовность нового аккаунта. Callback должен быть синхронным; завершение Promise, возвращённого вопреки void-контракту, не ожидается.

## RED → GREEN и проверка

Node `v24.12.0`; реальный AppStore.ets исполняется через `stripTypeScriptTypes`, не через дубликат observer. Загружаются настоящие AppState/authReducer/stateClone/invariants; hilog — host sink, основной fixture имеет devMode=false. Это не ArkTS compiler.

- До production edit: **0/22**, exit **1**, `TypeError: ...subscribeScopeInvalidation is not a function`.
- Первый patch: **22/22**, exit **0**.
- Дополнительный adversarial case: **22/23**, exit **1**, `Got unwanted exception. Actual message: "format failure"`.
- Guard диагностического пути: **23/23**, exit **0**.
- Финальный harness повторно проверен на точной сохранённой dirty baseline в памяти: **0/23**, exit **1**. HEAD как baseline не использовался.

| Проверка | Результат, exit 0 |
|---|---:|
| `node scripts/test-app-store-invalidation.cjs --negative-controls` | 23/23; 13/13 mutations отвергнуты |
| `node scripts/test-app-store-session.cjs` | 18/18 |
| `node scripts/test-app-core-runtime.cjs` | 6/6 |
| `node scripts/test-runtime-account-recovery.cjs` | 7/7 |
| `node scripts/test-full-account-recovery.cjs` | 3/3 |
| `node scripts/test-runtime-lifecycle.cjs` | 5/5 |
| `node scripts/test-recovery-supersession.cjs` | 2/2 |
| Отдельные host probes actual runtime shutdown / beforeRestart / onFailure через существующий runtime fixture | 3/3: root и scoped callbacks inline, старый scope.isScopeCurrent()=false, по одному вызову после await/cleanup |
| `git diff --check -- entry/src/main/ets/core/store/AppStore.ets` | Без ошибок whitespace |

Negative controls меняют source **только в памяти**. Каждая замена проверяет единственное совпадение; syntax/loader failure не считается пойманным behavioral regression.

| Мутация | Упавших проверок из 23 |
|---|---:|
| no-notification | 22 |
| async-notification | 20 |
| generation-after-notification | 5 |
| cancel-ignored | 3 |
| consume-after-call | 2 |
| live-set-iteration | 3 |
| clear-new-epoch | 3 |
| stale-captures-B | 3 |
| stale-notification-deferred | 3 |
| unsubscribe-noop | 5 |
| exceptions-escape | 3 |
| stale-invalidate-delegates | 2 |
| generation-never-revoked | 9 |

Независимый read-only reviewer не обнаружил замечаний в исходном observer и финальном guard диагностики. Последний re-review был статическим; приведённые финальные результаты тестов worker воспроизвёл самостоятельно.

## Source witness и сохранение dirty tree

До worker AppStore уже имел незакоммиченные изменения; они сохранены. Точный worker delta: **34 добавленных строки, 0 удалённых**, 271 → 305 строк. Нижний diff — к сохранённой dirty baseline, а не ко всему HEAD diff.

SHA-256:
- baseline AppStore: `054135a70a3aaff70a20b2ae87dd7b9df2975a725f5c7425cd32934c44cda1c9`;
- final AppStore: `cd598b4d56b08c99697599effb8915f04ad1e43ca558c53d4729530a8b1d261c`;
- final harness: `41aff91cdf257db66922ca795bac7e10d3c19b7256bd861bf0e7468e3f71d075`.

```diff
--- worker-baseline/AppStore.ets
+++ worker-current/AppStore.ets
@@ -24,6 +24,7 @@
   private generation: number = 0;
   private scopeRoot: AppStore | null = null;
   private scopedListeners: Set<StateListener> = new Set();
+  private scopeInvalidationListeners: Set<() => void> = new Set();
 
   // Serial dispatch queue
   private pendingPromise: Promise<void> = Promise.resolve();
@@ -72,6 +73,39 @@
       this.listeners.delete(listener);
     }
     this.scopedListeners.clear();
+    // Snapshot after revocation. Registrations made by callbacks belong to the
+    // new epoch; removing before delivery makes reentry and cancellation safe.
+    const snapshot: (() => void)[] = Array.from(this.scopeInvalidationListeners);
+    for (const listener of snapshot) {
+      if (!this.scopeInvalidationListeners.delete(listener)) continue;
+      listener();
+    }
+  }
+
+  /** One-shot synchronous revocation observer, epoch-bound even on the root. */
+  subscribeScopeInvalidation(listener: () => void): () => void {
+    // A distinct wrapper gives each registration its own cancellation handle.
+    const observer = (): void => {
+      try {
+        listener();
+      } catch (error) {
+        try {
+          hilog.error(DOMAIN, TAG, 'Scope invalidation listener error: %{public}s', String(error));
+        } catch (_) {
+          // Diagnostics must not interrupt delivery to the remaining observers.
+        }
+      }
+    };
+    // Never delegate stale registration to the root: that would capture B.
+    if (!this.isScopeCurrent()) {
+      observer();
+      return (): void => {};
+    }
+    const root = this.scopeRoot || this;
+    root.scopeInvalidationListeners.add(observer);
+    return (): void => {
+      root.scopeInvalidationListeners.delete(observer);
+    };
   }
 
   /**
```

## Ограничения и повторяемый приём

Нет build/emulator/AVSession/native-audio acceptance. Runtime probes используют явные gateway/platform/network fixtures; это не проверка реальных аккаунтов. Связка новых media/page callbacks остаётся задачей родителя. Не требуется менять runtime triggers: существующие shutdown/recovery/failure уже доходят до нового observer.

Приём для подобных observers: snapshot реестра, consume-before-call, проверка отмены во время прохода, inline stale path и новая регистрация из callback; не делать общий clear после callback, иначе потеряется новая эпоха. Rollback — обратный только приведённый worker delta, не git reset/restore dirty файла.

