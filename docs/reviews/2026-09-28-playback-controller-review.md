# Независимое focused review playback controller — 2026-09-28

**Итог финального recheck: F1/F2 RESOLVED в проверенной host-границе.** На frozen controller штатные **22/22**, **8/8 negative controls rejected**, исходные независимые probes **3/3**, дополнительные проверки **9/9**, actual controller+Global pair **4/4**. Новых подтверждённых controller-регрессий в этом focused recheck не найдено. Это host boundary probes, не воспроизведение звука на устройстве и не общая media/account готовность.

## Граница и зафиксированная версия

- Production read-only: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/VoicePlaybackController.ets`, diff от HEAD `faf66b3e066afccdbbfa36442eb9122073f509b2`.
- Harness read-only: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-media-playback-ownership.cjs`; файл untracked, поэтому его содержимое прочитано отдельно от `git diff`.
- Frozen controller SHA256: `496A9DDD8252DC775F434072014E1FF5E415524DBE0F24039841D1F0B64C9E92`.
- Controller harness SHA256: `70557EC870B64569C17E2FA182FED40C98385C1CDB79845BF827EE8179B4F323`.
- Pair harness `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-media-playback-integration.cjs` SHA256: `FA069E0E7A3621BA1A13D9BB0F8EA5A63EBF3CE38B5536F1EAC005FEDE26B013`.
- Global source SHA256 только для идентификации pair run: `187C105A3B81DC664E8B792B4DA19FC3B4176442497EF4CB8CC7AEA47654C35F`.
- Node `v24.12.0`. Ни production, ни tests reviewer не изменял. Единственный созданный файл — этот отчёт.
- GlobalMediaPlayback отдельно не ревьюился, его standalone suite reviewer не запускал; **41/41 не заявляется**. Прочитан и запущен только pair harness с actual controller. Не запускались builds, emulator/install, account/mic/message операции или commits. Late-cleanup error suppression parent проверен штатным case и не дублируется как finding.

## Resolution на frozen source

Production: `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/VoicePlaybackController.ets`.

- **F1 resolved:** ownership и metadata публикуются после prepare, до play (`:318–326`). Original release/pause probes теперь PASS. Local ownership и generation checks create/prepare сохранены; штатные delayed create/prepare/stop cases PASS.
- **F2 resolved:** после play settlement обновляется только isPlaying (`:332–335`), без обнуления terminal time/progress. Original completion probe PASS: один callback V, progress=1, currentTimeMs=10000.
- **Prepared snapshot/reentrancy:** release или replacement B из prepared listener останавливают A до вызова SDK play; guard после emit (`:328–330`) реально участвует. Его удаление в памяти ломает обе независимые проверки (`A.plays=1` вместо 0).
- **Финальный parent completion fix:** captured resource/callback проверяются после emit (`:51–56`). Штатный release-from-completion case и дополнительные replacement-B / callback-replacement probes PASS; удаление post-emit guards в памяти возвращает **21 PASS / 1 FAIL**.
- **False-green контроль F1/F2:** восьмая мутация возвращает hidden-until-play-settlement ownership и получает **3 FAIL**; прочие семь дают 5, 1, 3, 9, 1, 4, 7 FAIL соответственно. Ни одна мутация не выжила.

Проверено заново на указанном frozen hash (exit 0):

| Witness | Результат |
|---|---|
| `node scripts/test-media-playback-ownership.cjs --negative-controls` | 22 PASS; 8 mutations rejected |
| Сохранённый ниже исходный reviewer repro, без редактирования его логики | 3 PASS, ранее 3 FAIL |
| `node scripts/test-media-playback-integration.cjs` | 4 PASS |
| Prepared snapshot: A/path/audio/duration=10000/isPlaying=false + setSpeed доступен до play settlement | PASS |
| Prepared listener release / replacement B, A.plays=0, cleanup once | 2 PASS |
| Early completed → auto-advance B → позднее отклонение A.play не трогает B | PASS |
| timeUpdate(4000) до settlement сохраняет progress=0.4/time=4000 | PASS |
| Current play failure очищает published resource и отклоняет startup | PASS |
| Publication + reset listener throws: исходная ошибка, один release/close, A.plays=0 | PASS |
| Completion snapshot заменяет track на B / заменяет completion callback | 2 PASS |

Дополнительные 9 probes выполнялись через actual ETS fixture в памяти; SDK assertion violations пусты. Null twins reentrancy и completion guards также выполнялись только в памяти.

## История исходных findings

Следующие секции сохраняют исходный RED witness, а не описывают текущее состояние. Defective controller SHA256 был `992A809A2C68714EBAD847475EDACF3DAC78F22FE8C5440AE84422A8C8C31073`, harness — `5AC84615067F30D5497A62E8BD2ABB58FF19A31B567CE8593D4F3A5FC1CE61B1`. Тогда штатные 18/18 сосуществовали с тремя reviewer FAIL.

## F1 — P1 — RESOLVED: release/pause теряли уже играющий startup-плеер

**Место:** `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/VoicePlaybackController.ets:316–321`; потребители ресурса — `:184–205`, `:246–262`.

Плеер становится доступен через `this.resources` только после settlement `player.play()`. Если native state уже `playing`, но Promise ещё pending, `release()` успешно возвращается, не останавливая и не освобождая этот плеер. `pause()` также становится no-op. Generation check после await обеспечивает последующий cleanup, но не выполнение stop/pause в этом окне.

**Witness:** SDK stub переводит плеер в `playing` и отдельно задерживает resolution Promise; production ETS неизменён.

| Наблюдение до settlement play | HEAD | Patch |
|---|---|---|
| После `await release()` | state=released, stops=1, releases=1, closed=[1] | state=playing, stops=0, releases=0, closed=[] |
| После `await pause()` | state=paused, pauses=1 | state=playing, pauses=0 |
| После stop и запуска B при pending A | A=released, B=playing | A=playing, B=playing |

Snapshot patch при первом stop уже `{messageId:'0', isPlaying:false}`. Следовательно, UI-запрет публикации stale-состояния не доказывает прекращение playback. Реальная длительность такого окна на устройстве не измерялась.

**Исходная рекомендация, выполнена:** сохранить cancellation ownership так, чтобы stop не сообщал завершение, пока его уже играющий ресурс остаётся активным. Не возвращать общий shared cleanup старой реализации.

## F2 — P2 — RESOLVED: terminal callback текущего startup терялся

**Место:** `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/VoicePlaybackController.ets:286–290`, `:321–329`.

До присвоения `this.resources` оба callback отбрасываются даже для **текущей**, не отменённой операции. При `playing → timeUpdate(duration) → completed`, доставленных до resolution `play()`, terminal event теряется; при публикации принудительно записываются time=0 и progress=0. Проверка generation здесь недостаточна: это не stale-player callback.

**Witness после settlement:**

- HEAD: `completed=[{id:'V',type:'voice'}]`, progress=1, currentTimeMs=10000.
- Patch: `completed=[]`, progress=0, currentTimeMs=0; SDK state при этом `completed`.
- В обоих прогонах SDK assertion violations пусты.

**Интеграция:** `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets:1776–1814` принимает snapshot/completion; `:1883–1913` запускает следующий voice/audio из completion. Потерянное событие значит отсутствие этого вызова auto-advance, а не просто неверную анимацию. Сам GlobalMediaPlayback не исследовался.

**Исходная рекомендация, выполнена:** обработать или сохранить terminal state текущего startup с generation guard, затем доставить корректный terminal snapshot/completion ровно один раз. Не включать callbacks старых операций.

## Почему исходный green не ловил это

- `C:/Users/Kharki/Desktop/Telegram-HarmonyOS/scripts/test-media-playback-ownership.cjs:45` задерживает сам переход в `playing` до resolution gate. Нет независимо управляемых native state/event и Promise settlement.
- Case `late play completion after stop` (`:95–99`) проверяет результат только после окончания startup cleanup. Нет проверки физического состояния stub-плеера в момент завершения `release()` и нет параллельного B в этом окне.
- Completion case (`:149–153`) начинает события только после `await work`.
- Семь мутаций действительно меняют source и отвергаются: соответственно 6, 2, 3, 8, 1, 2, 8 failing cases. Они полезны, но не покрывают эти порядки событий.
- Дополнительная граница точности: mock `seek` (`:47`) — async Promise, реальный `AVPlayer.seek(timeMs, mode?)` возвращает void; фактическое завершение определяется `seekDone`. Эти тесты проверяют continuation ownership, а не реальное завершение SDK seek. Это замечание к силе witness, не новый production regression.

## Grounding

- Выполнены запросы `harmonyos_docs` по AVPlayer release/play/stateChange/seek. Release разрешён во всех состояниях кроме released; stop допускается при playing; seek возвращает void. Документация не задаёт контракт «stateChange доставляется только после resolution play Promise».
- Дополнительная проверка первичного upstream: [OpenHarmony AVPlayer NAPI](https://raw.githubusercontent.com/openharmony/multimedia_player_framework/master/frameworks/js/avplayer/avplayer_napi.cpp), `PlayTask`/`JsPlay` (строки 426–511), завершает Promise через async work; [AVPlayer callback](https://raw.githubusercontent.com/openharmony/multimedia_player_framework/master/frameworks/js/avplayer/avplayer_callback.cpp), `OnStateChangeCb` (1261–1289) и callback delivery (748–760), отправляет state event отдельным механизмом. Это обосновывает независимое моделирование каналов, но не подтверждает конкретный порядок в установленном HarmonyOS binary.
- Локальный HarmonyOS пример прочитан: `C:/Refs/Telegram/HarmonyOS-Codelabs/Media/AudioPlayer/entry/src/main/ets/controller/AudioPlayerControllerl.ets`, обработка stateChange/COMPLETED и release.
- Локальный iOS reference прочитан: `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Sources/MediaManager.swift:506–536`, replacement stop и identity-guard terminal callback. Не является device/visual witness.

### Отклонённая гипотеза / не выдавать за finding

Upstream OpenHarmony хранит один callback на event. In-memory single-listener stub оставляет штатные 17/17 зелёными, но async-initialized normal startup теряет completion: listeners=0, completed=[], snapshot.isPlaying=true при SDK completed. Однако Harmony docs `off('stateChange', callback)` прямо описывает выборочное удаление callback; эквивалентность upstream реализации целевому HarmonyOS не доказана. Кроме того, соответствующий waitForState существовал до patch. Это только portability/harness-граница, не третий подтверждённый regression.

## Воспроизводимые дополнительные probes

Из корня repo выполнить следующий JavaScript через `node -`; для HEAD — `node - --head`. Работает в памяти через экспортированный actual ETS fixture, не пишет файлы. Ожидание, зафиксированное до запуска: release не завершён либо player уже не playing; pause достигает playing-плеера; completed доставляется один раз с progress=1. Исходный результат: HEAD exit 0 (3 PASS), defective patch exit 1 (3 FAIL). Финальный frozen patch: **exit 0, 3 PASS**. Логика этих probes не менялась ради GREEN.

```javascript
const assert = require('node:assert/strict');
const fs = require('node:fs');
const cp = require('node:child_process');
const { fixture, deferred, flush } = require('./scripts/test-media-playback-ownership.cjs');
const sourcePath = 'entry/src/main/ets/ui/pages/chat/VoicePlaybackController.ets';
const source = process.argv.includes('--head')
  ? cp.execFileSync('git', ['show', 'HEAD:' + sourcePath], { encoding: 'utf8' })
  : fs.readFileSync(sourcePath, 'utf8');

async function begin() {
  const f = fixture(source), gate = deferred();
  const work = f.controller.play('V', '/V', 'voice');
  await flush();
  const p = f.player('V');
  p.play = async function () {
    assert.ok(['prepared', 'paused', 'completed'].includes(this.state));
    this.plays++;
    this.emit('stateChange', 'playing');
    await gate.promise;
  };
  f.creates[0].resolve(p);
  await flush();
  return { f, gate, work, p };
}

(async () => {
  let failed = 0;
  async function check(name, run) {
    try { await run(); console.log('PASS ' + name); }
    catch (error) { failed++; console.error('FAIL ' + name + '\n' + error.stack); }
  }
  await check('release does not finish while startup player is playing', async () => {
    const { f, gate, work, p } = await begin();
    let done = false;
    const release = f.controller.release().then(() => { done = true; });
    await flush();
    const before = { done, state: p.state, stops: p.stops, releases: p.releases };
    gate.resolve(); await Promise.all([work, release]);
    assert.deepEqual(f.violations, []);
    assert.equal(before.done && before.state === 'playing', false, JSON.stringify(before));
  });
  await check('pause reaches already playing startup', async () => {
    const { f, gate, work, p } = await begin();
    await f.controller.pause();
    const before = { state: p.state, pauses: p.pauses };
    gate.resolve(); await work; await f.controller.release();
    assert.deepEqual(f.violations, []);
    assert.equal(before.state, 'paused', JSON.stringify(before));
  });
  await check('completion before play settlement is preserved', async () => {
    const { f, gate, work, p } = await begin();
    p.emit('timeUpdate', 10000); p.emit('stateChange', 'completed');
    gate.resolve(); await work;
    const observed = {
      completed: [...f.completed], progress: f.snapshot().progress,
      currentTimeMs: f.snapshot().currentTimeMs
    };
    await f.controller.release();
    assert.deepEqual(f.violations, []);
    assert.deepEqual(observed, {
      completed: [{ id: 'V', type: 'voice' }], progress: 1, currentTimeMs: 10000
    });
  });
  console.log((3 - failed) + ' passed, ' + failed + ' failed');
  process.exitCode = failed ? 1 : 0;
})().catch(error => { console.error(error); process.exitCode = 1; });
```

## Историческая перепроверка parent listener-cleanup fix

Изменение catch `:330–340` (cleanup при исключении publication listener) прочитано и проверено: штатный suite 18 PASS, negative controls 7 rejected. Удаление только этого блока в памяти возвращает **17 PASS / 1 FAIL**. Дополнительный probe с исключением и в publication, и в reset listener даёт исходный publish error, active='0', state=released, releases=1, closed=[1], violations=[]. На HEAD текущий suite — 5 PASS / 13 FAIL. Исправление listener cleanup подтверждено; F1/F2 оно не устраняет.

## Оставшиеся gates

F1/F2 закрыты по исходным RED→GREEN witnesses и frozen hash выше; это не declared limitations. Lifecycle/account-wide, полный Global suite, SDK-wide failure recovery, физический звук, AVSession/background task, device acceptance и build compatibility этим review не закрыты. Отдельный `seek(): void` caveat и неподтверждённая upstream single-listener гипотеза не объявляются новыми regressions текущего patch.
