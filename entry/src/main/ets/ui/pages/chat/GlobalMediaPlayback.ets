// Global, app-scoped voice/audio playback. One AVPlayer survives chat
// navigation so the root island mini player can keep owning the sound after
// the chat page is torn down; the page registers row-repaint handlers here
// instead of creating a controller per visit.
import {
  MediaPlaybackController,
  MediaPlaybackSnapshot,
  MediaContentType
} from './VoicePlaybackController';
import {
  SearchChatMessagesUseCase,
  createSearchChatMessagesUseCase
} from '../../../domain/usecases/searchChatMessages';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { avSession as AVSessionManager } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';
import { AppStore } from '../../../core/store/AppStore';

const DOMAIN = 0x0020;
const TAG = 'GlobalMediaPlayback';
// Covers the inter-track gap including a blocking downloadFile of the next
// audio; a genuine session end without stop() still releases after this.
const BG_TASK_STOP_LINGER_MS = 4000;

@ObservedV2
export class MediaPlaybackUIState {
  @Trace hasActive: boolean = false;
  @Trace isPlaying: boolean = false;
  @Trace progress: number = 0;
  @Trace messageId: string = '0';
  @Trace contentType: string = 'voice';
  @Trace title: string = '';
  @Trace subtitle: string = '';
  @Trace chatId: number = 0;
  @Trace durationMs: number = 0;
  @Trace coverPath: string = '';
  @Trace speed: number = 1;
}

export const mediaPlaybackUIState: MediaPlaybackUIState = new MediaPlaybackUIState();

// A page gets a revocable capability, never the app-global raw AVPlayer owner.
export class MediaPlaybackPageHandle {
  readonly accountScope: AppStore;
  readonly accountStore: AppStore;
  readonly chatId: number;
  private readonly playback: GlobalMediaPlayback;
  private readonly pageCurrent: () => boolean;
  private playbackIntent: number = 0;

  constructor(playback: GlobalMediaPlayback, accountStore: AppStore,
    chatId: number, pageCurrent: () => boolean) {
    this.playback = playback;
    this.accountStore = accountStore;
    this.chatId = chatId;
    this.pageCurrent = pageCurrent;
    this.accountScope = accountStore.createScope();
  }

  isCurrent(): boolean {
    try {
      return this.accountScope.isScopeCurrent() && this.pageCurrent();
    } catch (_error) { return false; }
  }

  setHandlers(listener?: (snapshot: MediaPlaybackSnapshot) => void,
    onCompleted?: (messageId: string, contentType: MediaContentType) => void): () => void {
    return this.playback.bindPageHandlers(this, listener, onCompleted);
  }

  setNowPlaying(title: string, subtitle: string, coverPath: string = '', coverFileId: number = 0): void {
    // If synchronous repaint supersedes this call, its following toggle must
    // not take ownership back from the newer intent (even on the same handle).
    this.playbackIntent = this.playback.publishForPage(this, title, subtitle, coverPath, coverFileId);
  }

  async toggle(messageId: string, path: string, type: MediaContentType = 'voice'): Promise<void> {
    await this.playback.toggleForPage(this, messageId, path, type, this.playbackIntent);
  }

  getActiveMessageId(): string { return this.playback.messageIdForPage(this); }
  getIsPlaying(): boolean { return this.playback.isPlayingForPage(this); }
  async seekToProgress(progress: number): Promise<void> { await this.playback.seekForPage(this, progress); }
}

export class GlobalMediaPlayback {
  private readonly controller: MediaPlaybackController = new MediaPlaybackController();
  private pageListener?: (snapshot: MediaPlaybackSnapshot) => void;
  private pageCompleted?: (messageId: string, contentType: MediaContentType) => void;
  private pageOwner?: MediaPlaybackPageHandle;
  private pageSubscriptionId: number = 0;
  private playbackAccount?: AppStore;
  private playbackScope?: AppStore;
  private unsubscribeAccount?: () => void;
  private lastSnapshot?: MediaPlaybackSnapshot;
  private lastPath: string = '';
  private lastType: MediaContentType = 'voice';
  // Meta lives here, not only in the UI state: openAndStart() begins with a
  // release() whose '0' snapshot would wipe a just-published title before the
  // new track's first emit (witnessed empty island player header).
  private metaTitle: string = '';
  private metaSubtitle: string = '';
  private metaChatId: number = 0;
  private metaCoverPath: string = '';
  private metaCoverFileId: number = 0;
  private playbackSpeed: number = 1;
  // Metadata/stop ownership is independent of message ids (including '0' and
  // repeated ids). Adjacent requests also compete with each other before commit.
  private playbackGeneration: number = 0;
  private adjacentRequestId: number = 0;

  constructor() {
    this.controller.setListener((snapshot: MediaPlaybackSnapshot): void => {
      this.lastSnapshot = snapshot;
      if (snapshot.path.length > 0) {
        this.lastPath = snapshot.path;
        this.lastType = snapshot.contentType;
      }
      mediaPlaybackUIState.hasActive = snapshot.messageId !== '0';
      mediaPlaybackUIState.isPlaying = snapshot.isPlaying;
      mediaPlaybackUIState.progress = snapshot.progress;
      mediaPlaybackUIState.messageId = snapshot.messageId;
      mediaPlaybackUIState.contentType = snapshot.contentType;
      mediaPlaybackUIState.durationMs = snapshot.durationMs;
      if (snapshot.messageId === '0') {
        mediaPlaybackUIState.title = '';
        mediaPlaybackUIState.subtitle = '';
        mediaPlaybackUIState.chatId = 0;
        mediaPlaybackUIState.coverPath = '';
        this.lastPath = '';
      } else {
        mediaPlaybackUIState.title = this.metaTitle;
        mediaPlaybackUIState.subtitle = this.metaSubtitle;
        mediaPlaybackUIState.chatId = this.metaChatId;
        mediaPlaybackUIState.coverPath = this.metaCoverPath;
      }
      this.syncAvSessionFromSnapshot(snapshot);
      this.syncBackgroundTask(snapshot);
      this.deliverPageSnapshot(snapshot);
    });
    this.controller.setOnCompleted((messageId: string, contentType: MediaContentType): void => {
      if (this.pageCompleted && (!this.pageOwner || this.ownsPageTrack(this.pageOwner))) {
        this.pageCompleted(messageId, contentType);
        return;
      }
      // No chat page alive — keep the music playlist going globally. Voice
      // auto-advance stays page-only: it also marks rows as listened, which
      // needs the page's timeline state.
      if (contentType === 'audio') {
        this.playNextAudio().catch((_error: Object) => {});
      }
    });
  }

  private searchUseCase?: SearchChatMessagesUseCase;

  createPageHandle(account: AppStore, chatId: number, isCurrent: () => boolean): MediaPlaybackPageHandle {
    return new MediaPlaybackPageHandle(this, account, chatId, isCurrent);
  }

  private hasCurrentAccount(): boolean {
    return this.playbackScope !== undefined && this.playbackScope.isScopeCurrent();
  }

  private ownsPageTrack(owner: MediaPlaybackPageHandle): boolean {
    return owner.isCurrent() && this.hasCurrentAccount() &&
      owner.accountStore === this.playbackAccount && owner.chatId === this.metaChatId;
  }

  private deliverPageSnapshot(snapshot: MediaPlaybackSnapshot): void {
    const owner = this.pageOwner;
    if (this.pageListener && (!owner || owner.isCurrent())) {
      this.pageListener(!owner || this.ownsPageTrack(owner) ? snapshot : new MediaPlaybackSnapshot());
    }
  }

  bindPageHandlers(owner: MediaPlaybackPageHandle, listener?: (snapshot: MediaPlaybackSnapshot) => void,
    completed?: (messageId: string, contentType: MediaContentType) => void): () => void {
    if (!owner.isCurrent()) return (): void => {};
    const subscription = ++this.pageSubscriptionId;
    this.pageOwner = owner;
    this.pageListener = listener;
    this.pageCompleted = completed;
    if (this.lastSnapshot) this.deliverPageSnapshot(this.lastSnapshot);
    return (): void => {
      if (this.pageSubscriptionId !== subscription) return;
      this.pageSubscriptionId++;
      this.pageOwner = undefined;
      this.pageListener = undefined;
      this.pageCompleted = undefined;
    };
  }

  publishForPage(owner: MediaPlaybackPageHandle, title: string, subtitle: string,
    coverPath: string, coverFileId: number): number {
    if (!owner.isCurrent()) return 0;
    if (this.playbackAccount !== owner.accountStore || !this.hasCurrentAccount()) {
      const generation = this.playbackGeneration;
      this.retireAccount();
      if (this.playbackGeneration !== generation + 1 || !owner.isCurrent()) return 0;
      this.playbackAccount = owner.accountStore;
      const scope = owner.accountScope;
      this.playbackScope = scope;
      const unsubscribe = scope.subscribeScopeInvalidation((): void => {
        if (this.playbackScope === scope) this.retireAccount();
      });
      if (this.playbackScope === scope) this.unsubscribeAccount = unsubscribe;
      else unsubscribe();
    }
    if (!this.hasCurrentAccount() || !owner.isCurrent()) return 0;
    // A transient creation/activation failure may retry on a new user intent,
    // never on every timeUpdate tick and never for a revoked account.
    if (this.avContext) this.attachAvSession(this.avContext);
    if (this.metaChatId !== 0 && this.metaChatId !== owner.chatId) {
      // Message ids (and even file paths) are not globally unique track owners.
      // release() revokes synchronously before its native cleanup settles.
      const generation = this.playbackGeneration;
      this.stop().catch((_error: Object): void => {});
      if (this.playbackGeneration !== generation + 1) return 0;
    }
    // release delivers a zero snapshot synchronously; a page observer may
    // navigate or invalidate the account while handling that notification.
    if (!this.hasCurrentAccount() || !owner.isCurrent() || this.playbackAccount !== owner.accountStore) return 0;
    this.setNowPlaying(title, subtitle, owner.chatId, coverPath, coverFileId);
    return this.playbackGeneration;
  }

  async toggleForPage(owner: MediaPlaybackPageHandle, id: string, path: string, type: MediaContentType,
    intent: number): Promise<void> {
    if (intent === 0 || intent !== this.playbackGeneration || !this.ownsPageTrack(owner)) return;
    await this.controller.toggle(id, path, type);
  }

  messageIdForPage(owner: MediaPlaybackPageHandle): string {
    return this.ownsPageTrack(owner) ? this.controller.getActiveMessageId() : '0';
  }

  isPlayingForPage(owner: MediaPlaybackPageHandle): boolean {
    return this.ownsPageTrack(owner) && this.controller.getIsPlaying();
  }

  async seekForPage(owner: MediaPlaybackPageHandle, progress: number): Promise<void> {
    if (this.ownsPageTrack(owner)) await this.controller.seekToProgress(progress);
  }

  private retireAccount(): void {
    const unsubscribe = this.unsubscribeAccount;
    this.unsubscribeAccount = undefined;
    if (unsubscribe) unsubscribe();
    this.playbackAccount = undefined;
    this.playbackScope = undefined;
    this.searchUseCase = undefined;
    // An earlier invalidation observer can register B before this A observer
    // runs. Preserve any still-current registration, including a reused root.
    if (!this.pageOwner || !this.pageOwner.isCurrent()) {
      this.pageSubscriptionId++;
      this.pageOwner = undefined;
      this.pageListener = undefined;
      this.pageCompleted = undefined;
    }
    this.retireAvSession();
    this.metaTitle = '';
    this.metaSubtitle = '';
    this.metaChatId = 0;
    this.metaCoverPath = '';
    this.metaCoverFileId = 0;
    this.playbackSpeed = 1;
    mediaPlaybackUIState.speed = 1;
    this.stop().catch((error: Object): void => {
      hilog.warn(DOMAIN, TAG, 'Account playback cleanup failed: %{public}s', String(error));
    });
  }

  private ensureSearchUseCase(): SearchChatMessagesUseCase {
    if (!this.searchUseCase) {
      this.searchUseCase = createSearchChatMessagesUseCase(getTdGatewayAdapter());
    }
    return this.searchUseCase;
  }

  // Island ⏭ and out-of-chat auto-advance: play the next (newer) audio of the
  // same chat, downloading it first when needed. Returns false at playlist end.
  async playNextAudio(): Promise<boolean> {
    return this.playAdjacentAudio(true);
  }

  async playPrevAudio(): Promise<boolean> {
    return this.playAdjacentAudio(false);
  }

  // ---- AVSession (Control Center / lock screen / headset) + background ----
  private avSession?: AVSessionManager.AVSession;
  private avContext?: common.UIAbilityContext;
  private avSessionRevision: number = 0;
  private avSessionRequested: boolean = false;
  private avSessionQueue: Promise<void> = Promise.resolve();
  private avMetadataDirty: boolean = false;
  private avAssetId: string = '0';
  private avLastState: boolean | undefined = undefined;
  private avLastPositionSec: number = -10;
  private bgTaskActive: boolean = false;
  private bgTaskWanted: boolean = false;
  private bgTaskLingerStop: boolean = false;
  // The context-wide SDK stop cannot be fenced after it has been issued.
  // Serialize native effects and coalesce queued reconciliations to the latest
  // intent; active describes completed SDK work, not an optimistic start.
  private bgTaskQueue: Promise<void> = Promise.resolve();
  private bgTaskSyncQueued: boolean = false;
  // Deferred stop for the inter-track release snapshot ('0'): the next track
  // starts within moments, so the continuous task must survive the gap instead
  // of a stop/start cycle that opens a background-kill window.
  private bgTaskStopTimer: number = -1;
  private bgTaskStopToken: number = 0;

  // The root supplies the ability context before any account starts playback.
  // Native creation/activation/destruction is serialized across account epochs.
  attachAvSession(context: common.UIAbilityContext): void {
    if (!context) return;
    this.avContext = context;
    if (!this.hasCurrentAccount() || this.avSessionRequested) return;
    this.avSessionRequested = true;
    const revision = ++this.avSessionRevision;
    this.avSessionQueue = this.avSessionQueue.then(async (): Promise<void> => {
      if (!this.isAvSessionRequestCurrent(revision)) return;
      let created: AVSessionManager.AVSession | undefined = undefined;
      try {
        created = await AVSessionManager.createAVSession(context, 'TgIslandPlayer', 'audio');
        if (!this.isAvSessionRequestCurrent(revision)) {
          await this.destroyAvSession(created);
          return;
        }
        this.bindAvSessionCommands(created, revision);
        await created.activate();
        if (!this.isAvSessionRequestCurrent(revision)) {
          await this.destroyAvSession(created);
          return;
        }
        this.avSession = created;
        this.avMetadataDirty = true;
        if (this.lastSnapshot) this.syncAvSessionFromSnapshot(this.lastSnapshot);
        hilog.debug(DOMAIN, TAG, 'avSession created and activated');
      } catch (error) {
        if (created) {
          if (this.avSession === created) this.avSession = undefined;
          await this.destroyAvSession(created);
        }
        if (this.avSessionRevision === revision) this.avSessionRequested = false;
        hilog.warn(DOMAIN, TAG, 'avSession create/activate failed: %{public}s', String(error));
      }
    });
  }

  private isAvSessionRequestCurrent(revision: number): boolean {
    return revision === this.avSessionRevision && this.avSessionRequested && this.hasCurrentAccount();
  }

  private bindAvSessionCommands(session: AVSessionManager.AVSession, revision: number): void {
    const ownsSession = (): boolean => this.isAvSessionRequestCurrent(revision) && this.avSession === session;
    session.on('play', (): void => {
      if (ownsSession()) this.resumeCurrent().catch((_error: Object) => {});
    });
    session.on('pause', (): void => {
      if (ownsSession()) this.pauseCurrent().catch((_error: Object) => {});
    });
    session.on('stop', (): void => {
      if (ownsSession()) this.stop().catch((_error: Object) => {});
    });
    session.on('playNext', (): void => {
      if (ownsSession()) this.playNextAudio().catch((_error: Object) => {});
    });
    session.on('playPrevious', (): void => {
      if (ownsSession()) this.playPrevAudio().catch((_error: Object) => {});
    });
    session.on('seek', (positionMs: number): void => {
      const duration = mediaPlaybackUIState.durationMs;
      if (ownsSession() && duration > 0) this.seekToProgress(positionMs / duration).catch((_error: Object) => {});
    });
  }

  private async destroyAvSession(session: AVSessionManager.AVSession): Promise<void> {
    try {
      await session.destroy();
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'avSession destroy failed: %{public}s', String(error));
    }
  }

  private retireAvSession(): void {
    this.avSessionRevision++;
    this.avSessionRequested = false;
    const session = this.avSession;
    this.avSession = undefined;
    this.avMetadataDirty = true;
    this.avAssetId = '0';
    this.avLastState = undefined;
    this.avLastPositionSec = -10;
    // An in-flight creator still owns its unpublished session and destroys it
    // before this queue admits another account's createAVSession call.
    if (session) {
      this.avSessionQueue = this.avSessionQueue.then((): Promise<void> => this.destroyAvSession(session));
    }
  }

  private syncAvSessionFromSnapshot(snapshot: MediaPlaybackSnapshot): void {
    const session = this.avSession;
    if (!session) {
      return;
    }
    if (snapshot.messageId === '0') {
      if (this.avLastState !== undefined) {
        this.avLastState = undefined;
        this.avAssetId = '0';
        session.setAVPlaybackState({
          state: AVSessionManager.PlaybackState.PLAYBACK_STATE_STOP
        }).catch((_error: Object) => {});
      }
      return;
    }
    if (this.avMetadataDirty || this.avAssetId !== snapshot.messageId) {
      this.avMetadataDirty = false;
      this.avAssetId = snapshot.messageId;
      const metadata: AVSessionManager.AVMetadata = {
        assetId: snapshot.messageId,
        title: this.metaTitle.length > 0 ? this.metaTitle : ' ',
        artist: this.metaSubtitle,
        duration: snapshot.durationMs
      };
      if (this.metaCoverPath.length > 0) {
        metadata.mediaImage = 'file://' + this.metaCoverPath;
      }
      session.setAVMetadata(metadata).catch((_error: Object) => {});
    }
    // Throttle: report on play/pause flips or every ≥3s of position drift;
    // the controller ticks ~4x/s and the system extrapolates in between.
    const positionSec = Math.floor(snapshot.currentTimeMs / 1000);
    const stateChanged = this.avLastState !== snapshot.isPlaying;
    if (!stateChanged && Math.abs(positionSec - this.avLastPositionSec) < 3) {
      return;
    }
    this.avLastState = snapshot.isPlaying;
    this.avLastPositionSec = positionSec;
    session.setAVPlaybackState({
      state: snapshot.isPlaying
        ? AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY
        : AVSessionManager.PlaybackState.PLAYBACK_STATE_PAUSE,
      position: {
        elapsedTime: snapshot.currentTimeMs,
        updateTime: new Date().getTime()
      },
      speed: this.playbackSpeed
    }).catch((_error: Object) => {});
  }

  // Continuous task keeps the AVPlayer alive while the app is backgrounded;
  // started on first real playback, stopped when the session fully ends.
  private syncBackgroundTask(snapshot: MediaPlaybackSnapshot): void {
    const context = this.avContext;
    if (!context) {
      return;
    }
    if (snapshot.messageId !== '0' && snapshot.isPlaying) {
      this.cancelScheduledBgTaskStop();
      this.bgTaskLingerStop = false;
      this.bgTaskWanted = true;
      this.queueBackgroundTaskSync();
      return;
    }
    if (snapshot.messageId === '0') {
      this.scheduleBgTaskStop();
    }
  }

  private scheduleBgTaskStop(): void {
    if ((this.bgTaskWanted || this.bgTaskActive) && this.bgTaskStopTimer < 0) {
      // Inter-track '0' or a real session end — decided by whether a new track
      // starts before the linger elapses; an explicit stop() skips the wait.
      const generation = this.playbackGeneration;
      const stopToken = this.bgTaskStopToken;
      this.bgTaskStopTimer = setTimeout(() => {
        if (generation !== this.playbackGeneration || stopToken !== this.bgTaskStopToken) {
          return;
        }
        this.bgTaskStopTimer = -1;
        this.stopBackgroundTaskNow(true);
      }, BG_TASK_STOP_LINGER_MS);
    }
  }

  private queueBackgroundTaskSync(): void {
    if (this.bgTaskSyncQueued) {
      return;
    }
    this.bgTaskSyncQueued = true;
    this.bgTaskQueue = this.bgTaskQueue.then(async (): Promise<void> => {
      this.bgTaskSyncQueued = false;
      const context = this.avContext;
      if (!context || this.bgTaskWanted === this.bgTaskActive) {
        if (!this.bgTaskWanted && !this.bgTaskActive) {
          this.bgTaskLingerStop = false;
        }
        return;
      }
      if (!this.bgTaskWanted) {
        await backgroundTaskManager.stopBackgroundRunning(context);
        this.bgTaskActive = false;
        this.bgTaskLingerStop = false;
        return;
      }
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: context.abilityInfo.bundleName,
          abilityName: context.abilityInfo.name
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent = await wantAgent.getWantAgent(wantAgentInfo);
      if (!this.bgTaskWanted) {
        return;
      }
      await backgroundTaskManager.startBackgroundRunning(context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);
      this.bgTaskActive = true;
      hilog.debug(DOMAIN, TAG, 'audio background task started');
    }).catch((error: Object) => {
      // Keep the last confirmed state on failure; a later intent/tick retries.
      hilog.warn(DOMAIN, TAG, `bg task sync failed: ${String(error)}`);
    });
  }

  private cancelScheduledBgTaskStop(): void {
    this.bgTaskStopToken++;
    if (this.bgTaskStopTimer >= 0) {
      clearTimeout(this.bgTaskStopTimer);
      this.bgTaskStopTimer = -1;
    }
  }

  private stopBackgroundTaskNow(linger: boolean = false): void {
    this.cancelScheduledBgTaskStop();
    this.bgTaskLingerStop = linger;
    this.bgTaskWanted = false;
    this.queueBackgroundTaskSync();
  }

  // Replaying the last snapshot lets a (re)opened chat paint the correct row
  // state immediately instead of waiting for the next timeUpdate tick.
  private setPageHandlers(
    listener?: (snapshot: MediaPlaybackSnapshot) => void,
    onCompleted?: (messageId: string, contentType: MediaContentType) => void
  ): void {
    this.pageSubscriptionId++;
    this.pageOwner = undefined;
    this.pageListener = listener;
    this.pageCompleted = onCompleted;
    if (listener && this.lastSnapshot) {
      listener(this.lastSnapshot);
    }
  }

  private setNowPlaying(title: string, subtitle: string, chatId: number,
    coverPath: string = '', coverFileId: number = 0): void {
    this.playbackGeneration++;
    this.cancelScheduledBgTaskStop();
    if (this.bgTaskLingerStop) {
      // Revoke a queued (not yet issued) old linger stop. Keep the inter-track
      // protection, but give failed/new startup its own bounded grace period.
      this.bgTaskLingerStop = false;
      this.bgTaskWanted = true;
      this.queueBackgroundTaskSync();
    }
    this.scheduleBgTaskStop();
    this.metaTitle = title;
    this.metaSubtitle = subtitle;
    this.metaChatId = chatId;
    this.metaCoverPath = coverPath;
    this.metaCoverFileId = coverFileId;
    mediaPlaybackUIState.title = title;
    mediaPlaybackUIState.subtitle = subtitle;
    mediaPlaybackUIState.chatId = chatId;
    mediaPlaybackUIState.coverPath = coverPath;
    this.avMetadataDirty = true;
    if (coverPath.length === 0 && coverFileId > 0) {
      this.resolveCoverArt(coverFileId);
    }
  }

  // Album art usually arrives undownloaded; fetch the small thumb and update
  // the mirror in place when it lands (card and AVSession pick it up).
  private resolveCoverArt(coverFileId: number): void {
    const generation = this.playbackGeneration;
    this.ensureSearchUseCase().requestThumbDownload(coverFileId, 32)
      .then((path: string) => {
        if (path.length > 0 && generation === this.playbackGeneration && this.metaCoverFileId === coverFileId) {
          this.metaCoverPath = path;
          mediaPlaybackUIState.coverPath = path;
          this.avMetadataDirty = true;
        }
      })
      .catch((_error: Object) => {});
  }

  async toggleCurrent(): Promise<void> {
    if (!this.hasCurrentAccount()) return;
    const messageId = mediaPlaybackUIState.messageId;
    if (messageId === '0' || this.lastPath.length === 0) {
      return;
    }
    await this.controller.toggle(messageId, this.lastPath, this.lastType);
  }

  // Strict system-command semantics: the Control Center card's icon can lag
  // the real state, so 'play'/'pause' must be idempotent — a toggle would
  // invert the desync instead of converging on the requested state.
  async pauseCurrent(): Promise<void> {
    if (!this.hasCurrentAccount()) return;
    // controller.pause() itself no-ops unless the player is actually playing.
    await this.controller.pause();
  }

  async resumeCurrent(): Promise<void> {
    if (mediaPlaybackUIState.isPlaying) {
      return;
    }
    // toggle from a paused/prepared/completed player strictly plays.
    await this.toggleCurrent();
  }

  async stop(): Promise<void> {
    const generation = ++this.playbackGeneration;
    // Queue cleanup now: a newer metadata intent can supersede the finally
    // while an old background start is still pending and no player is active.
    this.stopBackgroundTaskNow();
    try {
      await this.controller.release();
    } finally {
      // An old release may settle after the next track starts. It must not
      // revoke that track's context-wide background task, even on rejection.
      if (generation === this.playbackGeneration) {
        this.stopBackgroundTaskNow();
      }
    }
  }

  async seekToProgress(progress: number): Promise<void> {
    if (!this.hasCurrentAccount()) return;
    await this.controller.seekToProgress(progress);
  }

  // 1x → 1.5x → 2x → 1x; survives track switches (re-applied after toggle).
  async cyclePlaybackSpeed(): Promise<number> {
    if (!this.hasCurrentAccount()) return this.playbackSpeed;
    const next = this.playbackSpeed >= 1.99 ? 1 : (this.playbackSpeed >= 1.49 ? 2 : 1.5);
    this.playbackSpeed = next;
    mediaPlaybackUIState.speed = next;
    await this.controller.setPlaybackSpeed(next);
    return next;
  }

  private async reapplySpeed(): Promise<void> {
    if (this.playbackSpeed > 1) {
      await this.controller.setPlaybackSpeed(this.playbackSpeed);
    }
  }

  private isAdjacentCurrent(generation: number, requestId: number): boolean {
    return this.hasCurrentAccount() && generation === this.playbackGeneration && requestId === this.adjacentRequestId;
  }

  async playAdjacentAudio(newer: boolean): Promise<boolean> {
    if (!this.hasCurrentAccount()) return false;
    const chatId = this.metaChatId !== 0 ? this.metaChatId : mediaPlaybackUIState.chatId;
    const messageId = mediaPlaybackUIState.messageId;
    hilog.debug(DOMAIN, TAG,
      `playAdjacentAudio(newer=${newer}): chat=${chatId} anchor=${messageId}`);
    if (chatId === 0 || messageId === '0' || mediaPlaybackUIState.contentType !== 'audio') {
      return false;
    }
    const generation = this.playbackGeneration;
    const requestId = ++this.adjacentRequestId;
    const useCase = this.ensureSearchUseCase();
    const track = await useCase.findAdjacentAudio(chatId, messageId, newer);
    if (!this.isAdjacentCurrent(generation, requestId)) {
      return false;
    }
    if (!track) {
      hilog.debug(DOMAIN, TAG, 'playAdjacentAudio: no adjacent track');
      return false;
    }
    const path = track.localPath.length > 0
      ? track.localPath
      : await useCase.downloadAudioSync(track.fileId);
    if (!this.isAdjacentCurrent(generation, requestId) || path.length === 0) {
      return false;
    }
    const title = track.title.length > 0 ? track.title : this.metaTitle;
    this.setNowPlaying(title, track.performer, chatId, track.coverPath, track.coverFileId);
    const committedGeneration = this.playbackGeneration;
    await this.controller.toggle(track.messageId, path, 'audio');
    if (!this.isAdjacentCurrent(committedGeneration, requestId)) {
      return false;
    }
    await this.reapplySpeed();
    return this.isAdjacentCurrent(committedGeneration, requestId);
  }
}

export const globalMediaPlayback: GlobalMediaPlayback = new GlobalMediaPlayback();
