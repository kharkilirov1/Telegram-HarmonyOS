import media from '@ohos.multimedia.media';
import fs from '@ohos.file.fs';

export class VoicePlaybackSnapshot {
  messageId: string = '0';
  path: string = '';
  isPlaying: boolean = false;
  progress: number = 0;
  durationMs: number = 0;
  currentTimeMs: number = 0;
}

export class VoicePlaybackController {
  private player?: media.AVPlayer;
  private openedFile?: fs.File;
  private currentMessageId: string = '0';
  private currentPath: string = '';
  private currentDurationMs: number = 0;
  private currentTimeMs: number = 0;
  private currentProgress: number = 0;
  private isPlaying: boolean = false;
  private listener?: (snapshot: VoicePlaybackSnapshot) => void;
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
    this.emit();
  };

  setListener(listener?: (snapshot: VoicePlaybackSnapshot) => void): void {
    this.listener = listener;
    this.emit();
  }

  async toggle(messageId: string, filePath: string): Promise<void> {
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
          await this.play(messageId, filePath);
          return;
        }
        this.currentTimeMs = 0;
        this.currentProgress = 0;
      }
      if (state === 'prepared' || state === 'paused' || state === 'completed') {
        try {
          await this.player.play();
        } catch (_error) {
          await this.play(messageId, filePath);
        }
        return;
      }
    }
    await this.play(messageId, filePath);
  }

  async play(messageId: string, filePath: string): Promise<void> {
    await this.openAndStart(messageId, filePath);
  }

  async pause(): Promise<void> {
    if (!this.player) {
      return;
    }
    if (this.player.state === 'playing') {
      try {
        await this.player.pause();
      } catch (_error) {}
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
    this.currentDurationMs = 0;
    this.currentTimeMs = 0;
    this.currentProgress = 0;
    this.isPlaying = false;
    this.emit();
  }

  private async openAndStart(messageId: string, filePath: string): Promise<void> {
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
      await player.prepare();

      this.currentMessageId = messageId;
      this.currentPath = filePath;
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
    const snapshot = new VoicePlaybackSnapshot();
    snapshot.messageId = this.currentMessageId;
    snapshot.path = this.currentPath;
    snapshot.isPlaying = this.isPlaying;
    snapshot.progress = this.currentProgress;
    snapshot.durationMs = this.currentDurationMs;
    snapshot.currentTimeMs = this.currentTimeMs;
    this.listener(snapshot);
  }
}
