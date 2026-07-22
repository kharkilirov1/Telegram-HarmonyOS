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

const DOMAIN = 0x0020;
const TAG = 'GlobalMediaPlayback';

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

export class GlobalMediaPlayback {
  private readonly controller: MediaPlaybackController = new MediaPlaybackController();
  private pageListener?: (snapshot: MediaPlaybackSnapshot) => void;
  private pageCompleted?: (messageId: string, contentType: MediaContentType) => void;
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
      if (this.pageListener) {
        this.pageListener(snapshot);
      }
    });
    this.controller.setOnCompleted((messageId: string, contentType: MediaContentType): void => {
      if (this.pageCompleted) {
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
  private avMetadataDirty: boolean = false;
  private avAssetId: string = '0';
  private avLastState: boolean | undefined = undefined;
  private avLastPositionSec: number = -10;
  private bgTaskActive: boolean = false;

  // Called once from the root page with its UIAbility context. Safe to call
  // again — the session is created only once per ability.
  attachAvSession(context: common.UIAbilityContext): void {
    if (this.avSession || !context) {
      return;
    }
    this.avContext = context;
    AVSessionManager.createAVSession(context, 'TgIslandPlayer', 'audio')
      .then((session: AVSessionManager.AVSession) => {
        this.avSession = session;
        session.on('play', (): void => {
          hilog.debug(DOMAIN, TAG, 'avSession cmd: play');
          this.toggleCurrent().catch((_error: Object) => {});
        });
        session.on('pause', (): void => {
          hilog.debug(DOMAIN, TAG, 'avSession cmd: pause');
          this.toggleCurrent().catch((_error: Object) => {});
        });
        session.on('stop', (): void => {
          this.stop().catch((_error: Object) => {});
        });
        session.on('playNext', (): void => {
          this.playNextAudio().catch((_error: Object) => {});
        });
        session.on('playPrevious', (): void => {
          this.playPrevAudio().catch((_error: Object) => {});
        });
        session.on('seek', (positionMs: number): void => {
          const duration = mediaPlaybackUIState.durationMs;
          if (duration > 0) {
            this.seekToProgress(positionMs / duration).catch((_error: Object) => {});
          }
        });
        session.activate().catch((_error: Object) => {});
        hilog.debug(DOMAIN, TAG, 'avSession created and activated');
      })
      .catch((error: Object) => {
        hilog.warn(DOMAIN, TAG, `avSession create failed: ${String(error)}`);
      });
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
    if (snapshot.messageId !== '0' && snapshot.isPlaying && !this.bgTaskActive) {
      this.bgTaskActive = true;
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: context.abilityInfo.bundleName,
          abilityName: context.abilityInfo.name
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      wantAgent.getWantAgent(wantAgentInfo)
        .then((agent) => backgroundTaskManager.startBackgroundRunning(context,
          backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent))
        .then(() => {
          hilog.debug(DOMAIN, TAG, 'audio background task started');
        })
        .catch((error: Object) => {
          this.bgTaskActive = false;
          hilog.warn(DOMAIN, TAG, `bg task start failed: ${String(error)}`);
        });
      return;
    }
    if (snapshot.messageId === '0' && this.bgTaskActive) {
      this.bgTaskActive = false;
      backgroundTaskManager.stopBackgroundRunning(context).catch((_error: Object) => {});
    }
  }

  controllerRef(): MediaPlaybackController {
    return this.controller;
  }

  // Replaying the last snapshot lets a (re)opened chat paint the correct row
  // state immediately instead of waiting for the next timeUpdate tick.
  setPageHandlers(
    listener?: (snapshot: MediaPlaybackSnapshot) => void,
    onCompleted?: (messageId: string, contentType: MediaContentType) => void
  ): void {
    this.pageListener = listener;
    this.pageCompleted = onCompleted;
    if (listener && this.lastSnapshot) {
      listener(this.lastSnapshot);
    }
  }

  setNowPlaying(title: string, subtitle: string, chatId: number,
    coverPath: string = '', coverFileId: number = 0): void {
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
    const requestedFor = mediaPlaybackUIState.messageId;
    this.ensureSearchUseCase().requestThumbDownload(coverFileId, 32)
      .then((path: string) => {
        if (path.length > 0 && mediaPlaybackUIState.messageId === requestedFor) {
          this.metaCoverPath = path;
          mediaPlaybackUIState.coverPath = path;
          this.avMetadataDirty = true;
        }
      })
      .catch((_error: Object) => {});
  }

  async toggleCurrent(): Promise<void> {
    const messageId = mediaPlaybackUIState.messageId;
    if (messageId === '0' || this.lastPath.length === 0) {
      return;
    }
    await this.controller.toggle(messageId, this.lastPath, this.lastType);
  }

  async stop(): Promise<void> {
    await this.controller.release();
  }

  async seekToProgress(progress: number): Promise<void> {
    await this.controller.seekToProgress(progress);
  }

  // 1x → 1.5x → 2x → 1x; survives track switches (re-applied after toggle).
  async cyclePlaybackSpeed(): Promise<number> {
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

  async playAdjacentAudio(newer: boolean): Promise<boolean> {
    const chatId = this.metaChatId !== 0 ? this.metaChatId : mediaPlaybackUIState.chatId;
    const messageId = mediaPlaybackUIState.messageId;
    hilog.debug(DOMAIN, TAG,
      `playAdjacentAudio(newer=${newer}): chat=${chatId} anchor=${messageId}`);
    if (chatId === 0 || messageId === '0' || mediaPlaybackUIState.contentType !== 'audio') {
      return false;
    }
    const useCase = this.ensureSearchUseCase();
    const track = await useCase.findAdjacentAudio(chatId, messageId, newer);
    if (!track) {
      hilog.debug(DOMAIN, TAG, 'playAdjacentAudio: no adjacent track');
      return false;
    }
    const path = track.localPath.length > 0
      ? track.localPath
      : await useCase.downloadAudioSync(track.fileId);
    if (path.length === 0) {
      return false;
    }
    const title = track.title.length > 0 ? track.title : this.metaTitle;
    this.setNowPlaying(title, track.performer, chatId, track.coverPath, track.coverFileId);
    await this.controller.toggle(track.messageId, path, 'audio');
    await this.reapplySpeed();
    return true;
  }
}

export const globalMediaPlayback: GlobalMediaPlayback = new GlobalMediaPlayback();
