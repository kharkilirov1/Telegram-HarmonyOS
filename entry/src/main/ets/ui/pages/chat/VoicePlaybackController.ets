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

export class MediaPlaybackController {
  private player?: media.AVPlayer;
  private openedFile?: fs.File;
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
      this.emit();
      // Notify page for auto-advance
      if (this.onCompletedCallback) {
        this.onCompletedCallback(this.currentMessageId, this.currentContentType);
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
    if (this.currentDurationMs <= 0 && this.player) {
      this.updateDurationFromPlayer();
    }
    if (this.currentDurationMs > 0) {
      this.currentProgress = Math.max(0, Math.min(1, this.currentTimeMs / this.currentDurationMs));
    } else {
      this.currentProgress = 0;
    }
    // stateChange('playing') has been observed getting lost (progress ticking with
    // isPlaying=false) — sync the flag from the player's actual state on every tick
    if (this.player) {
      this.isPlaying = this.player.state === 'playing';
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
    if (this.currentMessageId === messageId && this.currentPath === filePath && this.player) {
      const state = this.player.state;
      if (state === 'playing') {
        await this.pause();
        return;
      }
      if (state === 'completed') {
        try {
          await this.player.seek(0);
        } catch (_error) {
          await this.play(messageId, filePath, contentType);
          return;
        }
        this.currentTimeMs = 0;
        this.currentProgress = 0;
      }
      if (state === 'prepared' || state === 'paused' || state === 'completed') {
        try {
          await this.player.play();
        } catch (_error) {
          await this.play(messageId, filePath, contentType);
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
    if (!this.player) {
      return;
    }
    let mode: media.PlaybackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    if (multiplier >= 1.99) {
      mode = media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
    } else if (multiplier >= 1.49) {
      mode = media.PlaybackSpeed.SPEED_FORWARD_1_50_X;
    }
    try {
      this.player.setSpeed(mode);
    } catch (_error) {}
  }

  async seekToProgress(progress: number): Promise<void> {
    if (!this.player) {
      return;
    }
    const clamped = Math.max(0, Math.min(1, progress));
    if (this.currentDurationMs <= 0) {
      return;
    }
    const targetMs = Math.floor(clamped * this.currentDurationMs);
    try {
      await this.player.seek(targetMs);
      this.currentTimeMs = targetMs;
      this.currentProgress = clamped;
      this.emit();
    } catch (_error) {}
  }

  async pause(): Promise<void> {
    if (!this.player) {
      return;
    }
    if (this.player.state === 'playing') {
      try {
        await this.player.pause();
      } catch (_error) {}
      // Don't rely on the stateChange('paused') event alone (see timeUpdateHandler)
      this.isPlaying = false;
      this.emit();
    }
  }

  async release(): Promise<void> {
    if (this.player) {
      try {
        this.player.off('stateChange', this.stateChangeHandler);
      } catch (_error) {}
      try {
        this.player.off('timeUpdate', this.timeUpdateHandler);
      } catch (_error) {}
      // Stop before release if player is active — prevents "unsupport release" errors
      const state = this.player.state;
      if (state === 'playing' || state === 'paused' || state === 'completed') {
        try {
          await this.player.stop();
        } catch (_error) {}
      }
      try {
        await this.player.release();
      } catch (_error) {}
      this.player = undefined;
    }
    if (this.openedFile) {
      try {
        fs.closeSync(this.openedFile);
      } catch (_error) {}
      this.openedFile = undefined;
    }
    this.currentMessageId = '0';
    this.currentPath = '';
    this.currentContentType = 'voice';
    this.currentDurationMs = 0;
    this.currentTimeMs = 0;
    this.currentProgress = 0;
    this.isPlaying = false;
    this.emit();
  }

  private async openAndStart(messageId: string, filePath: string, contentType: MediaContentType): Promise<void> {
    await this.release();

    try {
      const player = await media.createAVPlayer();
      this.player = player;
      this.player.on('stateChange', this.stateChangeHandler);
      this.player.on('timeUpdate', this.timeUpdateHandler);

      const openedFile = fs.openSync(filePath);
      this.openedFile = openedFile;
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
      await player.prepare();

      this.currentMessageId = messageId;
      this.currentPath = filePath;
      this.currentContentType = contentType;
      this.currentDurationMs = Math.max(0, player.duration);
      this.currentTimeMs = 0;
      this.currentProgress = 0;
      this.isPlaying = false;
      this.emit();

      await player.play();
    } catch (error) {
      await this.release();
      throw new Error(String(error));
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
    if (!this.player) {
      return;
    }
    const duration = Math.max(0, this.player.duration);
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
