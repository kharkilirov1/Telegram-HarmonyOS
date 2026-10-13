import media from '@ohos.multimedia.media';
import fs from '@ohos.file.fs';

export type MediaContentType = 'voice' | 'audio';

export class MediaPlaybackSnapshot {
  messageId: string = '0';
  path: string = '';
  contentType: MediaContentType = 'voice';
  isPlaying: boolean = false;
  progress: number = 0;
  durationMs: number = 0;
  currentTimeMs: number = 0;
}

// Legacy alias for backward compat
export type VoicePlaybackSnapshot = MediaPlaybackSnapshot;

class PlaybackResources {
  player?: media.AVPlayer;
  openedFile?: fs.File;
  stateHandler?: (state: media.AVPlayerState) => void;
  timeHandler?: (timeMs: number) => void;
  releasePromise?: Promise<void>;
}

export class MediaPlaybackController {
  private resources?: PlaybackResources;
  private operationId: number = 0;
  private pendingRelease?: Promise<void>;
  private currentMessageId: string = '0';
  private currentPath: string = '';
  private currentContentType: MediaContentType = 'voice';
  private currentDurationMs: number = 0;
  private currentTimeMs: number = 0;
  private currentProgress: number = 0;
  private isPlaying: boolean = false;
  private listener?: (snapshot: MediaPlaybackSnapshot) => void;
  private onCompletedCallback?: (messageId: string, contentType: MediaContentType) => void;
  private readonly stateChangeHandler = (state: media.AVPlayerState): void => {
    if (state === 'prepared') {
      this.updateDurationFromPlayer();
    } else if (state === 'playing') {
      this.isPlaying = true;
    } else if (state === 'paused') {
      this.isPlaying = false;
    } else if (state === 'completed') {
      this.isPlaying = false;
      this.currentProgress = 1;
      this.currentTimeMs = this.currentDurationMs;
      const resources = this.resources;
      const completed = this.onCompletedCallback;
      this.emit();
      // A snapshot listener can stop/replace playback before auto-advance.
      if (this.resources === resources && this.onCompletedCallback === completed && completed) {
        completed(this.currentMessageId, this.currentContentType);
      }
      return;
    } else if (state === 'stopped' || state === 'released' || state === 'idle') {
      this.isPlaying = false;
    } else if (state === 'error') {
      this.isPlaying = false;
    }
    this.emit();
  };
  private readonly timeUpdateHandler = (timeMs: number): void => {
    this.currentTimeMs = Math.max(0, timeMs);
    if (this.currentDurationMs <= 0 && this.resources?.player) {
      this.updateDurationFromPlayer();
    }
    if (this.currentDurationMs > 0) {
      this.currentProgress = Math.max(0, Math.min(1, this.currentTimeMs / this.currentDurationMs));
    } else {
      this.currentProgress = 0;
    }
    // stateChange('playing') has been observed getting lost (progress ticking with
    // isPlaying=false) — sync the flag from the player's actual state on every tick
    if (this.resources?.player) {
      this.isPlaying = this.resources.player.state === 'playing';
    }
    this.emit();
  };

  setListener(listener?: (snapshot: MediaPlaybackSnapshot) => void): void {
    this.listener = listener;
    this.emit();
  }

  setOnCompleted(callback?: (messageId: string, contentType: MediaContentType) => void): void {
    this.onCompletedCallback = callback;
  }

  getActiveMessageId(): string {
    return this.currentMessageId;
  }

  getIsPlaying(): boolean {
    return this.isPlaying;
  }

  async toggle(messageId: string, filePath: string, contentType: MediaContentType = 'voice'): Promise<void> {
    if (filePath.trim().length === 0) {
      return;
    }
    const resources = this.resources;
    const player = resources?.player;
    if (this.currentMessageId === messageId && this.currentPath === filePath && resources && player) {
      const state = player.state;
      if (state === 'playing') {
        await this.pause();
        return;
      }
      if (state === 'completed') {
        try {
          await player.seek(0);
        } catch (_error) {
          if (this.resources === resources) {
            await this.play(messageId, filePath, contentType);
          }
          return;
        }
        if (this.resources !== resources) {
          return;
        }
        this.currentTimeMs = 0;
        this.currentProgress = 0;
      }
      if (state === 'prepared' || state === 'paused' || state === 'completed') {
        try {
          await player.play();
        } catch (_error) {
          if (this.resources === resources) {
            await this.play(messageId, filePath, contentType);
          }
        }
        return;
      }
    }
    await this.play(messageId, filePath, contentType);
  }

  async play(messageId: string, filePath: string, contentType: MediaContentType = 'voice'): Promise<void> {
    await this.openAndStart(messageId, filePath, contentType);
  }

  // 1 / 1.5 / 2 — applied immediately and re-applied by the caller after a
  // track change (a fresh AVPlayer always starts at 1x).
  async setPlaybackSpeed(multiplier: number): Promise<void> {
    const player = this.resources?.player;
    if (!player) {
      return;
    }
    let mode: media.PlaybackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    if (multiplier >= 1.99) {
      mode = media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
    } else if (multiplier >= 1.49) {
      mode = media.PlaybackSpeed.SPEED_FORWARD_1_50_X;
    }
    try {
      player.setSpeed(mode);
    } catch (_error) {}
  }

  async seekToProgress(progress: number): Promise<void> {
    const resources = this.resources;
    const player = resources?.player;
    if (!resources || !player) {
      return;
    }
    const clamped = Math.max(0, Math.min(1, progress));
    if (this.currentDurationMs <= 0) {
      return;
    }
    const targetMs = Math.floor(clamped * this.currentDurationMs);
    try {
      await player.seek(targetMs);
      if (this.resources !== resources) {
        return;
      }
      this.currentTimeMs = targetMs;
      this.currentProgress = clamped;
      this.emit();
    } catch (_error) {}
  }

  async pause(): Promise<void> {
    const resources = this.resources;
    const player = resources?.player;
    if (!resources || !player) {
      return;
    }
    if (player.state === 'playing') {
      try {
        await player.pause();
      } catch (_error) {}
      if (this.resources !== resources) {
        return;
      }
      // Don't rely on the stateChange('paused') event alone (see timeUpdateHandler)
      this.isPlaying = false;
      this.emit();
    }
  }

  async release(): Promise<void> {
    ++this.operationId;
    await this.releaseActive();
  }

  private async releaseResources(resources: PlaybackResources): Promise<void> {
    if (!resources.releasePromise) {
      resources.releasePromise = this.disposeResources(resources);
    }
    await resources.releasePromise;
  }

  private async disposeResources(resources: PlaybackResources): Promise<void> {
    // Capture before awaiting: another operation may already own the controller.
    const player = resources.player;
    const openedFile = resources.openedFile;
    if (player) {
      try {
        if (resources.stateHandler) player.off('stateChange', resources.stateHandler);
      } catch (_error) {}
      try {
        if (resources.timeHandler) player.off('timeUpdate', resources.timeHandler);
      } catch (_error) {}
      // Stop before release if player is active — prevents "unsupport release" errors
      const state = player.state;
      if (state === 'playing' || state === 'paused' || state === 'completed') {
        try {
          await player.stop();
        } catch (_error) {}
      }
      try {
        if (player.state !== 'released') await player.release();
      } catch (_error) {}
      resources.player = undefined;
    }
    if (openedFile) {
      try {
        fs.closeSync(openedFile);
      } catch (_error) {}
      resources.openedFile = undefined;
    }
  }

  private async releaseActive(): Promise<void> {
    const resources = this.resources;
    this.resources = undefined;
    // Join prior cleanup without allowing its completion to reset a new track.
    const previous = this.pendingRelease;
    const current = resources ? this.releaseResources(resources) : Promise.resolve();
    const pending = previous ? previous.then(() => current) : current;
    this.pendingRelease = pending;
    this.currentMessageId = '0';
    this.currentPath = '';
    this.currentContentType = 'voice';
    this.currentDurationMs = 0;
    this.currentTimeMs = 0;
    this.currentProgress = 0;
    this.isPlaying = false;
    this.emit();
    await pending;
    if (this.pendingRelease === pending) {
      this.pendingRelease = undefined;
    }
  }

  private async openAndStart(messageId: string, filePath: string, contentType: MediaContentType): Promise<void> {
    const operationId = ++this.operationId;
    await this.releaseActive();
    if (operationId !== this.operationId) {
      return;
    }

    // Acquisition/prepare resources stay local. Publish ownership before play:
    // native events can arrive before its Promise settles, and stop/pause must
    // already be able to reach a player that is producing sound.
    const resources = new PlaybackResources();
    let startupError: Error | undefined = undefined;
    try {
      const player = await media.createAVPlayer();
      resources.player = player;
      if (operationId !== this.operationId) {
        return;
      }
      resources.stateHandler = (state: media.AVPlayerState): void => {
        if (this.resources === resources) this.stateChangeHandler(state);
      };
      resources.timeHandler = (timeMs: number): void => {
        if (this.resources === resources) this.timeUpdateHandler(timeMs);
      };
      player.on('stateChange', resources.stateHandler);
      player.on('timeUpdate', resources.timeHandler);

      const openedFile = fs.openSync(filePath);
      resources.openedFile = openedFile;
      const stat = fs.statSync(filePath);

      player.fdSrc = {
        fd: openedFile.fd,
        offset: 0,
        length: stat.size
      };

      // Wait for player to reach 'initialized' state before calling prepare().
      // fdSrc assignment triggers async state transition; calling prepare() too early
      // causes "current state is not stopped or initialized" errors.
      await this.waitForState(player, 'initialized', 2000);
      if (operationId !== this.operationId) {
        return;
      }
      await player.prepare();
      if (operationId !== this.operationId) {
        return;
      }
      this.resources = resources;
      this.currentMessageId = messageId;
      this.currentPath = filePath;
      this.currentContentType = contentType;
      this.currentDurationMs = Math.max(0, player.duration);
      this.currentTimeMs = 0;
      this.currentProgress = 0;
      this.isPlaying = false;
      this.emit();
      // Publication callbacks may synchronously stop or replace this intent.
      if (operationId !== this.operationId || this.resources !== resources) {
        return;
      }
      await player.play();
      if (operationId === this.operationId && this.resources === resources) {
        // Keep time/progress/completion delivered while play was pending.
        this.isPlaying = player.state === 'playing';
        this.emit();
      }
    } catch (error) {
      startupError = new Error(String(error));
      if (this.resources === resources) {
        // A subscriber can throw during publication. Retire only this player;
        // finally still joins cleanup if the reset subscriber also throws.
        try { await this.releaseActive(); } catch (_listenerError) {}
      }
    } finally {
      if (this.resources !== resources) {
        await this.releaseResources(resources);
      }
    }
    if (startupError && operationId === this.operationId) {
      throw startupError;
    }
  }

  private waitForState(player: media.AVPlayer, targetState: string, timeoutMs: number): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      if (player.state === targetState) {
        resolve();
        return;
      }
      let resolved = false;
      let timerId: number = -1;
      let handler: (state: media.AVPlayerState) => void = (_state: media.AVPlayerState): void => {};
      const cleanup = (): void => {
        try { player.off('stateChange', handler); } catch (_e) {}
        if (timerId >= 0) {
          clearTimeout(timerId);
          timerId = -1;
        }
      };
      handler = (state: media.AVPlayerState): void => {
        if (state === targetState && !resolved) {
          resolved = true;
          cleanup();
          resolve();
        } else if (state === 'error' && !resolved) {
          resolved = true;
          cleanup();
          reject(new Error('AVPlayer entered error state'));
        }
      };
      player.on('stateChange', handler);
      timerId = setTimeout(() => {
        if (!resolved) {
          resolved = true;
          cleanup();
          // If already in target state by now, resolve anyway
          if (player.state === targetState) {
            resolve();
          } else {
            reject(new Error('AVPlayer state timeout waiting for ' + targetState));
          }
        }
      }, timeoutMs);
    });
  }

  private updateDurationFromPlayer(): void {
    const player = this.resources?.player;
    if (!player) {
      return;
    }
    const duration = Math.max(0, player.duration);
    if (duration > 0) {
      this.currentDurationMs = duration;
      if (this.currentTimeMs > 0) {
        this.currentProgress = Math.max(0, Math.min(1, this.currentTimeMs / duration));
      }
    }
  }

  private emit(): void {
    if (!this.listener) {
      return;
    }
    const snapshot = new MediaPlaybackSnapshot();
    snapshot.messageId = this.currentMessageId;
    snapshot.path = this.currentPath;
    snapshot.contentType = this.currentContentType;
    snapshot.isPlaying = this.isPlaying;
    snapshot.progress = this.currentProgress;
    snapshot.durationMs = this.currentDurationMs;
    snapshot.currentTimeMs = this.currentTimeMs;
    this.listener(snapshot);
  }
}

// Legacy alias
export type VoicePlaybackController = MediaPlaybackController;
