# Независимое review: account/page ownership и AVSession

2026-09-28. **Повторное независимое review: F1/F2 закрыты на текущем source.** Исходные пять reviewer probes: **5/5 PASS** вместо прежних 2 PASS / 3 FAIL. Восемь дополнительных вариантов outer toggle: **8/8 PASS**. Новых production findings в проверенном delta не обнаружено. После test-only исправления fixture все перечисленные ниже host suites и negative controls прошли заново, exit 0.

Reviewer не изменял production, fixtures или tests. Единственный записанный файл — этот отчёт. Builds/emulator, реальные SDK/аккаунты/сообщения не запускались.

## Итоговый snapshot и повторная проверка

SHA256 после исправления F1/F2 и обновления operation fixture:

- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/GlobalMediaPlayback.ets`: `80e201d1433ac95b84f9863a0adc9ef338d1dec415f8ad41cc6e9afb128f4fdb`.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-media-account-ownership.cjs`: `17293ba4294dde6416951a265231ab1ca6db4ba9b26b61d1a4bd761c4483d58f`.
- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-global-media-ownership.cjs`: `ef284b91c6efa3ab5d71b6ac66686797cb05d875cd4c7469afa270e853c5a23e`.
- Controller и AppStore: SHA остались прежними, приведены в исходном snapshot ниже. Global/account test/fixture повторно проверены после запусков; SHA совпадают.

| Лично повторённая проверка | Результат |
| --- | --- |
| Исходные пять probes из этого отчёта, без изменения их кода | 5/5 PASS, exit 0 |
| Дополнительная матрица outer toggle, код ниже | 8/8 PASS, exit 0 |
| `node scripts/test-media-account-ownership.cjs` | 37/37 PASS; 19/19 source controls rejected; exit 0 |
| `node scripts/test-global-media-ownership.cjs` | 41/41 PASS; 14/14 source controls rejected; exit 0 |
| `node scripts/test-media-playback-integration.cjs` | 4/4 PASS, exit 0 |
| `node scripts/test-app-store-invalidation.cjs --negative-controls` | 23/23 PASS; 13/13 source controls rejected; exit 0 |

### Почему F1/F2 закрыты

- **F1, порядок publication:** `publishForPage` проверяет delta `playbackGeneration === generation + 1` после собственного `retireAccount()` и cross-chat `stop()`. Более новый синхронный intent меняет generation дальше и прерывает outer publication. Теперь исходные probes сохраняют `newer user intent` / `newer first-bind intent`, messageId=30 и playing=true.
- **F1, следующий outer toggle:** handle запоминает результат publication; superseded возвращает 0, а `toggleForPage` отклоняет 0 и чужую generation. Проверены initial bind / cross-chat × до/после завершения вложенного запуска × тот же/другой ID и path. Старый toggle не ставит новый трек на pause и не создаёт лишний player. Во всех восьми случаях отдельный последующий свежий publish+toggle на том же handle успешно запускает id40; это не ложный PASS из-за блокировки всех intents.
- **F2, handler новой эпохи:** `retireAccount()` сохраняет любую current page registration. Probe с более ранним AppStore observer создаёт B до cleanup A: handler B остаётся current, получает messageId=10 и следующий tick. Stale account/page tests остаются зелёными.
- Account suite заново проверила lifecycle shutdown/recovery/failure через настоящий AppCoreRuntime, same ID cross-chat, pending AVSession create/activate/destroy, stale system commands и same-account retry. Это host behavioral witness, не native service acceptance.

Source anchors текущего Global: handle token — строки 52, 74–81; publication delta — 201–203 и 220–222; toggle guard — 231–234; сохранение current page — 257–265.

### Operation fixture: отдельная test-only регрессия закрыта

До обновления fixture основной Global suite проходил 41/41, но контроль `stop generation disabled` обрывал runner с `failures must be behavioral, not harness errors`, exit 1: mutant ломал начальный реальный page/account bind, и тест далее обращался к отсутствующему `finds[0]`. Это не было названо product bug.

Родитель заменил только `bindTestAccount=true` setup на явную установку fake account/scope, отделив operation boundary от account binding. Account fixture по-прежнему вызывает `fixture(activeSource, true, false)` и использует настоящий AppStore + page handle; этот путь не обойдён.

Причинный read-only probe воспроизвёл старый setup **в памяти** на текущем source с тем же stop mutant: `account=false, finds=0`; новый setup: `account=true, finds=1`. После исправления именованный mutant даёт 6/41 ожидаемых assertion failures вместо TypeError, весь Global runner завершился exit 0 с 14/14 rejected controls. Проверены не только зелёные штатные тесты, но и сохранение чувствительности suite.

## Исходный RED snapshot (история findings)

- GlobalMediaPlayback.ets: `f3824ae10d0684478ec36781d640ec180f53684430ac5d119109a581a0ec0c87`.
- test-media-account-ownership.cjs: `12ab1c9f6c61bd36674654bd764b651a06ccc1f6c8eb158d0a2fe05c94464a2f`.
- test-global-media-ownership.cjs (fixture): `433974c95a951ff267c22e6552d8793cf2d114b9c52827550b0dd832da7cbba4`.
- VoicePlaybackController.ets: `496a9ddd8252dc775f434072014e1ff5e415524dbe0f24039841d1f0b64c9e92`.
- AppStore.ets: `cd598b4d56b08c99697599effb8915f04ad1e43ca558c53d4729530a8b1d261c`.

Родитель параллельно менял source/tests; findings привязаны именно к snapshot с guard после cross-chat stop. Во время отдельного прогона probes SHA Global до/после совпал.

Прочитан активный `TASKS/MEDIA_ACCOUNT_OWNERSHIP_2026-09-28.md`; изучены Global, account tests, SDK fixture, controller release/emit и AppStore observer loop. Platform grounding: harmonyos_docs, `AVSession activate(): Promise<void>` — session доступна после активации, ошибка возвращается через Promise. Локальный iOS `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/MediaManager.swift` хранит account вместе с playback state и использует playlist disposables. Это источники контракта, не native/device witness.

## Исходные findings — оба закрыты повторной проверкой выше

### F1 [P2, закрыто] Валидный, но более старый publish перезаписывал новый intent после синхронного callback

Место: `entry/src/main/ets/ui/pages/chat/GlobalMediaPlayback.ets:217–220`; ещё одна точка reentry — `198–199` при первом account bind.

Guard проверяет account/handle, но не порядок metadata intents. `stop()` синхронно вызывает настоящий controller `release()` → zero snapshot → page callback. Если callback вызывает `setNowPlaying` и `toggle` для более нового трека **тем же действующим handle**, вложенный intent успешно запускает новый track. Внешний publish затем проходит все проверки current и перезаписывает его title. Отзыв account для этого не нужен.

Воспроизведено в двух вариантах:
1. A играет в чате -100; handle чата -200 при zero snapshot запускает messageId=30 с title=`newer user intent`; внешний publish восстанавливает `older user intent`.
2. Первый account bind: zero snapshot из `retireAccount()` запускает вложенный messageId=30; внешний publish восстанавливает `older first-bind intent`.

Фактический output:
```text
REENTRY_CURRENT_HANDLE {"current":true,"messageId":"30","title":"older user intent","playing":true}
FAIL: 'older user intent' !== 'newer user intent'
REENTRY_INITIAL_BIND {"current":true,"messageId":"30","title":"older first-bind intent","playing":true}
FAIL: 'older first-bind intent' !== 'newer first-bind intent'
```

Это не SDK-fixture error: setup использует actual Global/controller/AppStore, reentry приходит из настоящего синхронного release/emit. Production page отдельно допускает reentry при repaint (комментарий возле setup handlers); конкретная native UI последовательность здесь не воспроизводилась.

Нужное свойство исправления: старый publish после любого callback-capable teardown не может продолжить commit поверх нового intent. Одной повторной проверки `owner.isCurrent()` недостаточно; обе приведённые проверки оставляют её true. Проверять token/revision нужно также после initial `retireAccount()`, а не только после cross-chat stop. Production patch reviewer не делал.

### F2 [P2, закрыто] Очистка A удаляла уже зарегистрированный page handler новой эпохи B

Место: `entry/src/main/ets/ui/pages/chat/GlobalMediaPlayback.ets:247–251`, вызов из invalidation callback на строке 203.

Условие:
1. До первого playback зарегистрирован более ранний AppStore invalidation observer.
2. При отзыве A этот observer создаёт current scope B и регистрирует новый page handler, **ещё не начиная playback**.
3. Следующий observer — Global cleanup A — вызывает `retireAccount()` без preservePageAccount. Условие `pageOwner.accountStore !== undefined` истинно даже для current handler B, поэтому новый handler удаляется.
4. После возврата invalidation тот же handle B начинает нормально играть, но page callback уже потерян.

Фактический output:
```text
{"current":true,"seen":["0"],"receivedTick":false,"playing":true}
FAIL: '0' !== '10'
```

Контроль: регистрация того же handler **после** invalidateScopes проходит и получает messageId=10 / следующий tick. Дополнительный scope observer B переживает внешний проход AppStore и уведомляется на следующей invalidation — это не потеря observer в core store. Если ранний callback успевает полностью опубликовать playback B, старая media invalidation subscription отменяется, и такой вариант тоже проходит.

Нужное свойство исправления: teardown старого account удаляет его page ownership, но не более новую current registration, появившуюся во время того же прохода. Этот host witness доказывает API reentrancy contract; факт появления такого порядка в реальном login/navigation на устройстве не заявляется.

## Проверки исходного review (исторические результаты)

На исходном RED snapshot лично воспроизведены:
- `node scripts/test-media-account-ownership.cjs`: **32/32**, **17/17** controls; exit 0.
- `node scripts/test-app-store-invalidation.cjs --negative-controls`: **23/23**, **13/13** controls; exit 0.
- Синхронная invalidation внутри cross-chat zero callback с немедленным запуском account C: **PASS** — title C и chatId=-300 сохраняются. До последнего guard этот дополнительный probe показывал messageId=30/C audio с metadata старого account; это уже не открытый finding.
- Создание/активация AVSession после временного отказа на следующем same-account intent: **PASS**. Первоначальный source давал два FAIL (`1 !== 2`); перенос attach вне account branch исправил их.
- Дополнительные трёхэпоховые A→B→C probes при pending **create / activate / destroy**: **3/3 PASS** на предыдущем retry snapshot `afcf9d65...`: промежуточный create B пропущен, старая session уничтожена один раз, шесть stale system commands не управляют C. Последующий guard меняет только publication после stop.
- Non-reentrant first bind / replacement handlers / same IDs across chats покрыты зелёными actual-code tests; обычный page detach не останавливает global playback.

## Воспроизводимый read-only probe

Из корня репозитория передать следующий JavaScript в `node -` (PowerShell here-string). Никаких файлов не меняет. На исходном RED snapshot получено **2 PASS / 3 FAIL**, exit 1; на итоговом snapshot повторено без изменения кода: **5/5 PASS**, exit 0.

```javascript
const assert=require('node:assert/strict');
const fs=require('node:fs'),crypto=require('node:crypto');
const p='entry/src/main/ets/ui/pages/chat/GlobalMediaPlayback.ets';
const sha=()=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const before=sha();
const {setup}=require('./scripts/test-media-account-ownership.cjs');
const {flush}=require('./scripts/test-global-media-ownership.cjs');
const tests=[
 ['new epoch page handler survives old invalidation cleanup',async()=>{
  const f=setup();let b;const seen=[];
  f.root.subscribeScopeInvalidation(()=>{b=f.handle(f.root.createScope());b.setHandlers(s=>seen.push(s.messageId));});
  await f.play();f.root.invalidateScopes();await f.play(b,'10','B');const count=seen.length;f.players.at(-1).tick();
  console.log('REENTRY_HANDLER',JSON.stringify({current:b.isCurrent(),seen,receivedTick:seen.length>count,playing:f.ui.isPlaying}));
  assert.equal(seen.at(-1),'10');
 }],
 ['same-handle newer publish survives cross-chat release callback',async()=>{
  const f=setup();await f.play();const b=f.handle(undefined,-200);let armed=false,fired=false,newer;
  b.setHandlers(s=>{if(armed&&!fired&&s.messageId==='0'){fired=true;b.setNowPlaying('newer user intent','');newer=b.toggle('30','/audio/30','audio');}});
  armed=true;b.setNowPlaying('older user intent','');await newer;await flush();
  console.log('REENTRY_CURRENT_HANDLE',JSON.stringify({current:b.isCurrent(),messageId:f.ui.messageId,title:f.ui.title,playing:f.ui.isPlaying}));
  assert.equal(f.ui.title,'newer user intent');
 }],
 ['same-handle newer publish survives initial account binding',async()=>{
  const f=setup();const a=f.handle();let armed=false,fired=false,newer;
  a.setHandlers(s=>{if(armed&&!fired&&s.messageId==='0'){fired=true;a.setNowPlaying('newer first-bind intent','');newer=a.toggle('30','/audio/30','audio');}});
  armed=true;a.setNowPlaying('older first-bind intent','');await newer;await flush();
  console.log('REENTRY_INITIAL_BIND',JSON.stringify({current:a.isCurrent(),messageId:f.ui.messageId,title:f.ui.title,playing:f.ui.isPlaying}));
  assert.equal(f.ui.title,'newer first-bind intent');
 }],
 ['revoked account outer publish does not overwrite account C',async()=>{
  const f=setup();await f.play();const b=f.handle(undefined,-200);let armed=false,fired=false,next;
  f.root.subscribeScopeInvalidation(()=>{next=f.play(f.handle(f.root.createScope(),-300),'30','Account C');});
  b.setHandlers(s=>{if(armed&&!fired&&s.messageId==='0'){fired=true;f.root.invalidateScopes();}});
  armed=true;b.setNowPlaying('revoked secret','');await next;await flush();
  assert.equal(b.isCurrent(),false);assert.equal(f.ui.title,'Account C');assert.equal(f.ui.chatId,-300);assert.equal(f.ui.isPlaying,true);
 }],
 ['without reentry cross-chat publication stays correct',async()=>{
  const f=setup();await f.play();const b=f.handle(undefined,-200);const seen=[];
  b.setHandlers(s=>seen.push(s.messageId));await f.play(b,'30','B');
  assert.equal(f.ui.title,'B');assert.equal(f.ui.chatId,-200);assert.equal(f.ui.isPlaying,true);assert.equal(seen.at(-1),'30');
 }]
];
(async()=>{let failed=0;for(const[name,run]of tests){try{await run();console.log('PASS',name);}catch(e){failed++;console.error('FAIL',name,e.stack);}}
 assert.equal(sha(),before,'source changed during review probe');
 console.log(JSON.stringify({passed:tests.length-failed,failed,globalSha256:before}));process.exitCode=failed?1:0;
})().catch(e=>{console.error(e.stack);process.exitCode=2;});
```

## Дополнительный read-only probe: восемь вариантов outer toggle

Каждый вариант проверяет сохранение нового id30/title/playing, отсутствие лишнего player и SDK violations, затем успешный свежий id40 на том же handle. Результат на итоговом snapshot: **8/8 PASS**, exit 0. Передать JavaScript в `node -` из корня репозитория; файлов не меняет.

```javascript
const assert = require('node:assert/strict');
const fs=require('node:fs'),crypto=require('node:crypto');
const p='entry/src/main/ets/ui/pages/chat/GlobalMediaPlayback.ets';
const before=crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const {setup}=require('./scripts/test-media-account-ownership.cjs');
const {flush}=require('./scripts/test-global-media-ownership.cjs');
(async()=>{
 let passed=0;
 for(const initial of [true,false])for(const settleFirst of [false,true])for(const sameId of [false,true]){
  const f=setup();if(!initial)await f.play();
  const handle=f.handle(undefined,-200);let armed=false,fired=false,newer;
  handle.setHandlers(s=>{if(armed&&!fired&&s.messageId==='0'){
   fired=true;handle.setNowPlaying('newer intent','');newer=handle.toggle('30','/audio/30','audio');
  }});
  armed=true;handle.setNowPlaying('superseded intent','');
  if(settleFirst){await newer;await flush();}
  const id=sameId?'30':'20';await handle.toggle(id,'/audio/'+id,'audio');
  await newer;await flush();
  assert.equal(fired,true);assert.equal(handle.isCurrent(),true);
  assert.equal(f.ui.messageId,'30');assert.equal(f.ui.title,'newer intent');assert.equal(f.ui.isPlaying,true);
  assert.equal(f.players.length,initial?1:2,'outer toggle must not create a player');
  assert.deepEqual(f.violations,[]);
  // A new explicit publication must still be usable on that same handle.
  handle.setNowPlaying('fresh admitted intent','');await handle.toggle('40','/audio/40','audio');await flush();
  assert.equal(f.ui.messageId,'40');assert.equal(f.ui.title,'fresh admitted intent');assert.equal(f.ui.isPlaying,true);
  assert.equal(f.players.length,initial?2:3);
  console.log('PASS outer toggle '+JSON.stringify({initial,settleFirst,sameId})+'; new explicit intent admitted');passed++;
 }
 assert.equal(crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'),before);
 console.log(JSON.stringify({passed,failed:0,globalSha256:before}));
})().catch(e=>{console.error(e.stack);process.exitCode=1});
```

## Границы результата

- Это source/host review, не ArkTS compile, AVSession service lifecycle acceptance или реальное аудио.
- AppStore implementation настоящая; initial state и invariant sink в account fixture упрощены, SDK/files/network заменены явными doubles. Подтверждённые дефекты не зависят от этих state buckets и не требуют выдуманных SDK переходов.
- Rejected destroy в fixture оставляет destroyed=false: тест подтверждает fencing команд и продолжение JS queue, **не** успешное освобождение native session. Постоянные ошибки сервиса / native утечки этим review не закрыты и не названы новым product bug.
- Fixture хранит command callbacks после destroy, что позволяет проверить stale callbacks. Его отсутствие собственного AVSession FSM само по себе не является дефектом продукта.
- По запросу reviewer не исправлял production/tests. Родитель добавил регрессии, и они лично повторены вместе с независимыми probes; оба исходных finding закрыты только в этих проверенных границах.
- Родитель сообщил о двух успешных production builds. Reviewer их не запускал и логи сборок лично не проверял; это сообщение родителя, не независимый build witness данного отчёта.

