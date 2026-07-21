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
      if (snapshot.messageId === '0') {
        mediaPlaybackUIState.title = '';
        mediaPlaybackUIState.subtitle = '';
        mediaPlaybackUIState.chatId = 0;
        this.lastPath = '';
      } else {
        mediaPlaybackUIState.title = this.metaTitle;
        mediaPlaybackUIState.subtitle = this.metaSubtitle;
        mediaPlaybackUIState.chatId = this.metaChatId;
      }
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
    const chatId = this.metaChatId !== 0 ? this.metaChatId : mediaPlaybackUIState.chatId;
    const messageId = mediaPlaybackUIState.messageId;
    hilog.debug(DOMAIN, TAG,
      `playNextAudio: chat=${chatId} anchor=${messageId} type=${mediaPlaybackUIState.contentType}`);
    if (chatId === 0 || messageId === '0' || mediaPlaybackUIState.contentType !== 'audio') {
      return false;
    }
    const useCase = this.ensureSearchUseCase();
    const track = await useCase.findNextAudioNewer(chatId, messageId);
    if (!track) {
      hilog.debug(DOMAIN, TAG, 'playNextAudio: no newer track');
      return false;
    }
    hilog.debug(DOMAIN, TAG,
      `playNextAudio: next=${track.messageId} file=${track.fileId} local=${track.localPath.length > 0}`);
    const path = track.localPath.length > 0
      ? track.localPath
      : await useCase.downloadAudioSync(track.fileId);
    if (path.length === 0) {
      return false;
    }
    const title = track.title.length > 0 ? track.title : this.metaTitle;
    this.setNowPlaying(title, track.performer, chatId);
    await this.controller.toggle(track.messageId, path, 'audio');
    return true;
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

  setNowPlaying(title: string, subtitle: string, chatId: number): void {
    this.metaTitle = title;
    this.metaSubtitle = subtitle;
    this.metaChatId = chatId;
    mediaPlaybackUIState.title = title;
    mediaPlaybackUIState.subtitle = subtitle;
    mediaPlaybackUIState.chatId = chatId;
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
}

export const globalMediaPlayback: GlobalMediaPlayback = new GlobalMediaPlayback();
