// Known-defect review reproductions for production dev@2d2f683 (2026-09-26).
// These assertions confirm defects at the reviewed base; they do not assert
// corrected behavior and are not regression tests for the eventual fixes.
// Executes actual production ETS after removing imports/types. Platform
// collaborators are mocks: this validates JavaScript control flow, not SDK or
// device behavior. Requires Node.js with node:module.stripTypeScriptTypes.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const repo = path.resolve(__dirname, '../../..');
const root = path.join(repo, 'entry/src/main/ets/ui/pages/chat');
const log = {info(){},debug(){},warn(){},error(){}};
function load(file, names, dependencies = {}) {
  let src = fs.readFileSync(path.join(root, file), 'utf8')
    .replace(/^import[\s\S]*?;\s*/gm, '')
    .replace(/@ObservedV2\s*/g, '').replace(/@Trace\s*/g, '');
  const js = stripTypeScriptTypes(src, { mode: 'strip' }).replace(/\bexport /g, '');
  const context = {console, setTimeout, clearTimeout, setInterval, clearInterval,
    hilog: log, ...dependencies};
  vm.runInNewContext(js + '\nthis.exports = {' + names.join(',') + '};', context, {filename: file});
  return context.exports;
}
function deferred() { let resolve, reject; const promise = new Promise((a,b) => {resolve=a;reject=b}); return {promise,resolve,reject}; }
async function flush() { for(let i=0;i<12;i++) await Promise.resolve(); }

async function downloadRetry() {
  const requests = [];
  const { ChatMediaDownloadController } = load('ChatMediaDownloadController.ets', ['ChatMediaDownloadController'], {
    FileDownloadedEvent: class {}, FileTransferUpdatedEvent: class {},
    getAppCoreRuntime: () => ({getStore: () => ({dispatch(){}})}),
    createDownloadFileCommand: id => ({kind:'download', id}),
    createCancelDownloadFileCommand: id => ({kind:'cancel', id}),
    getTdGatewayAdapter: () => ({send(command) {
      if(command.kind === 'cancel') return Promise.resolve({});
      const d = deferred(); requests.push(d); return d.promise;
    }})
  });
  const ctrl = new ChatMediaDownloadController();
  ctrl.requestMediaDownload(5, 1);
  ctrl.cancelMediaDownload(5);
  ctrl.requestMediaDownload(5, 1);
  requests[0].reject(new Error('old canceled request'));
  await flush();
  assert.equal(ctrl.isDownloadPending(5), false);
  assert.equal(ctrl.isDownloadFailed(5), true);
  console.log('REPRO download retry: old canceled request marks new request failed and removes its pending state');
}

function playerStub(name) {
  return {name,state:'idle',duration:1000,released:false, handlers:{},
    on(event, handler){ (this.handlers[event]??=[]).push(handler) },
    off(event, handler){this.handlers[event]=(this.handlers[event]??[]).filter(x=>x!==handler)},
    set fdSrc(value){this.source=value;this.state='initialized'},
    async prepare(){this.state='prepared'}, async play(){this.state='playing'},
    async stop(){this.state='stopped'}, async release(){this.state='released';this.released=true}
  };
}
async function playbackRaces() {
  const creations = [], closed = [];
  const { MediaPlaybackController } = load('VoicePlaybackController.ets', ['MediaPlaybackController'], {
    media:{createAVPlayer(){const d=deferred();creations.push(d);return d.promise}},
    fs:{openSync(path){return {fd:path}},statSync(){return {size:100}},closeSync(file){closed.push(file.fd)}}
  });
  const ctrl = new MediaPlaybackController();
  const first = ctrl.play('a','/a');
  const second = ctrl.play('b','/b');
  await flush();
  assert.equal(creations.length,2);
  const a=playerStub('a'), b=playerStub('b');
  creations[0].resolve(a); creations[1].resolve(b);
  await Promise.all([first,second]);
  assert.equal(a.state,'playing'); assert.equal(b.state,'playing');
  await ctrl.release();
  assert.equal(a.released,false); assert.equal(b.released,true);
  assert.deepEqual(closed,['/b']);
  console.log('REPRO playback overlap: both AVPlayers play; release only disposes latest player/FD');

  const third = ctrl.play('c','/c');
  await flush();
  await ctrl.release();
  const c=playerStub('c'); creations[2].resolve(c);
  await third;
  assert.equal(c.state,'playing');
  assert.equal(ctrl.getActiveMessageId(),'c');
  console.log('REPRO playback stop: pending AVPlayer creation resumes playback after release');
  await ctrl.release();
}

async function recordingCancelRace() {
  const create = deferred(); const deleted = [], closed = [];
  const { ChatVoiceRecordingController } = load('ChatVoiceRecordingController.ets', ['ChatVoiceRecordingController'], {
    media:{createAVRecorder:()=>create.promise, CodecMimeType:{AUDIO_AAC:1},ContainerFormatType:{CFT_MPEG_4A:1},AudioSourceType:{AUDIO_SOURCE_TYPE_MIC:1}},
    abilityAccessCtrl:{createAtManager:()=>({requestPermissionsFromUser:async()=>({authResults:[0]})})},
    fileIo:{OpenMode:{READ_WRITE:1,CREATE:2,TRUNC:4}, accessSync:()=>true, mkdirSync(){},
      openSync:path=>({fd:1,path}), closeSync:f=>closed.push(f), unlinkSync:p=>deleted.push(p)},
    localized:(_id,fallback)=>fallback, $r:()=>({id:1}),
    isVoiceRecordingDurationSendable:n=>n>=500, SendMediaMessageParams:class {}
  });
  const host = {getActiveChatId:()=>1,getLifecycleToken:()=>1,getSendMediaUseCase:()=>({}),
    getChatUIContext:()=>({getHostContext:()=>({filesDir:'/files'}),getPromptAction:()=>({showToast(){}})}),
    setVoiceRecordingState(){}};
  const ctrl = new ChatVoiceRecordingController();
  ctrl.begin(host); await flush();
  ctrl.cancel(host); await flush();
  let released = false;
  create.resolve({state:'idle',async release(){released=true}});
  await flush();
  assert.equal(closed.length,1); assert.equal(deleted.length,1);
  assert.equal(released,false);
  assert.ok(ctrl.recorder); assert.equal(ctrl.recorderState,'idle');
  console.log('REPRO recording cancel: late createAVRecorder result remains owned in idle without release');
  ctrl.dispose(); await flush();
}

async function recordingFailureCleanup() {
  const release=deferred(), closed=[], deleted=[];
  const recorder={state:'prepared',async prepare(){throw new Error('prepare failure')},release:()=>release.promise};
  const { ChatVoiceRecordingController } = load('ChatVoiceRecordingController.ets', ['ChatVoiceRecordingController'], {
    media:{createAVRecorder:async()=>recorder, CodecMimeType:{AUDIO_AAC:1},ContainerFormatType:{CFT_MPEG_4A:1},AudioSourceType:{AUDIO_SOURCE_TYPE_MIC:1}},
    abilityAccessCtrl:{createAtManager:()=>({requestPermissionsFromUser:async()=>({authResults:[0]})})},
    fileIo:{OpenMode:{READ_WRITE:1,CREATE:2,TRUNC:4}, accessSync:()=>true,mkdirSync(){},
      openSync:path=>({fd:1,path}),closeSync:f=>closed.push(f),unlinkSync:p=>deleted.push(p)},
    localized:(_id,fallback)=>fallback,$r:()=>({id:1}),
    isVoiceRecordingDurationSendable:n=>n>=500,SendMediaMessageParams:class {}
  });
  const host={getActiveChatId:()=>1,getLifecycleToken:()=>1,getSendMediaUseCase:()=>({}),
    getChatUIContext:()=>({getHostContext:()=>({filesDir:'/files'}),getPromptAction:()=>({showToast(){}})}),setVoiceRecordingState(){}};
  const ctrl = new ChatVoiceRecordingController();
  ctrl.begin(host); await flush();
  assert.equal(ctrl.recorderState,'idle');
  release.resolve(); await flush();
  assert.equal(closed.length,0); assert.equal(deleted.length,0);
  console.log('REPRO recording error: resetFields erases FD/path while asynchronous release awaits, leaking both');
}

async function recordingRetryRace() {
  const creations=[], closed=[], deleted=[], recorders=[];
  let nextFd=0, nextTime=100000;
  const { ChatVoiceRecordingController } = load('ChatVoiceRecordingController.ets', ['ChatVoiceRecordingController'], {
    Date:{now:()=>++nextTime},
    media:{createAVRecorder(){const d=deferred();creations.push(d);return d.promise},CodecMimeType:{AUDIO_AAC:1},ContainerFormatType:{CFT_MPEG_4A:1},AudioSourceType:{AUDIO_SOURCE_TYPE_MIC:1}},
    abilityAccessCtrl:{createAtManager:()=>({requestPermissionsFromUser:async()=>({authResults:[0]})})},
    fileIo:{OpenMode:{READ_WRITE:1,CREATE:2,TRUNC:4},accessSync:()=>true,mkdirSync(){},
      openSync:path=>({fd:++nextFd,path}),closeSync:f=>closed.push(f.fd),unlinkSync:p=>deleted.push(p)},
    localized:(_id,fallback)=>fallback,$r:()=>({id:1}),
    isVoiceRecordingDurationSendable:n=>n>=500,SendMediaMessageParams:class {}
  });
  const host={getActiveChatId:()=>1,getLifecycleToken:()=>1,getSendMediaUseCase:()=>({}),
    getChatUIContext:()=>({getHostContext:()=>({filesDir:'/files'}),getPromptAction:()=>({showToast(){}})}),setVoiceRecordingState(){}};
  const recorder=()=>({state:'idle',async prepare(){this.state='prepared'},async start(){this.state='started'},async stop(){this.state='stopped'},async release(){this.state='released'}});
  const ctrl=new ChatVoiceRecordingController();
  ctrl.begin(host);await flush();
  ctrl.cancel(host);await flush();
  ctrl.begin(host);await flush();
  const second=recorder();creations[1].resolve(second);await flush();
  assert.equal(second.state,'started');assert.equal(ctrl.recorder,second);
  const first=recorder();creations[0].resolve(first);await flush();
  assert.equal(first.state,'released');
  assert.equal(second.state,'started');
  assert.equal(ctrl.recorder,undefined);assert.equal(ctrl.outputPath,'');
  assert.deepEqual(closed,[1,2]);assert.equal(deleted.length,2);
  console.log('REPRO recording retry: old create replaces active recorder, deletes second output, and loses still-started second recorder');
  ctrl.dispose();await flush();
  assert.equal(second.state,'started');
  await second.release();
}

async function adjacentAfterStop() {
  const find=deferred(), starts=[];
  class Controller {
    setListener(fn){this.listener=fn} setOnCompleted(){}
    async release(){this.listener({messageId:'0',path:'',contentType:'voice',isPlaying:false,progress:0,durationMs:0,currentTimeMs:0})}
    async toggle(id,path,type){starts.push({id,path,type})} async setPlaybackSpeed(){}
  }
  const {globalMediaPlayback:g,mediaPlaybackUIState:ui}=load('GlobalMediaPlayback.ets',['globalMediaPlayback','mediaPlaybackUIState'],{
    MediaPlaybackController:Controller,
    createSearchChatMessagesUseCase:()=>({findAdjacentAudio:()=>find.promise}),getTdGatewayAdapter:()=>({})
  });
  ui.messageId='1';ui.chatId=100;ui.contentType='audio';
  const pending=g.playNextAudio();
  await g.stop();
  find.resolve({messageId:'2',localPath:'/next',title:'next',performer:'artist',coverPath:'',coverFileId:0});
  await pending;
  assert.equal(starts.length,1);assert.equal(starts[0].id,'2');
  console.log('REPRO playlist stop: deferred adjacent search starts another track after explicit stop');
}

(async()=>{await downloadRetry();await playbackRaces();await recordingCancelRace();await recordingFailureCleanup();await recordingRetryRace();await adjacentAfterStop()})()
  .catch(error=>{console.error(error);process.exitCode=1});
