// TgTgsPlayer — animated .tgs sticker renderer.
// .tgs is gzipped Lottie JSON. Telegram's native rlottie renderer owns the
// preferred frame path; @ohos/lottie stays as the compatibility fallback.
// Both paths are visibility-bound and MUST stop in aboutToDisappear because
// LazyForEach can retain Canvas nodes outside the visible viewport.

import lottie, { AnimationItem } from '@ohos/lottie';
import zlib from '@ohos.zlib';
import { util } from '@kit.ArkTS';
import { displaySync } from '@kit.ArkGraphics2D';
import { hilog } from '@kit.PerformanceAnalysisKit';
import tgRlottie, { TgRlottieAnimation } from 'libtg_rlottie.so';
import { TgUiTokens } from '../tokens/TgUiTokens';

const DOMAIN = 0x0021;
const TAG = 'TgTgsPlayer';
const READ_CHUNK_BYTES = 65536;

// Names must be unique per living instance: the same sticker can appear in
// several messages, and lottie.destroy(name) is name-scoped.
let tgsInstanceSeq = 0;

@ComponentV2
export struct TgTgsPlayer {
  @Param tgsPath: string = '';
  @Param renderWidth: number = 160;
  @Param renderHeight: number = 160;

  private readonly settings: RenderingContextSettings = new RenderingContextSettings(true);
  private readonly ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private readonly nativeDisplaySync: displaySync.DisplaySync = displaySync.create();
  private anim: AnimationItem | undefined = undefined;
  private animName: string = '';
  private loadedForPath: string = '';
  private loadedJson: string = '';
  private nativeAnimation: TgRlottieAnimation | undefined = undefined;
  private nativeImageData: ImageData | undefined = undefined;
  private nativeWidth: number = 0;
  private nativeHeight: number = 0;
  private nativeFrameSubscribed: boolean = false;
  private nativePlaybackStarted: boolean = false;
  private nativeVisible: boolean = false;
  private nativeEpochNs: number = 0;
  private nativePlayheadFrame: number = 0;
  private nativeLastRenderedFrame: number = -1;

  private readonly nativeFrameCallback = (frameInfo: displaySync.IntervalInfo): void => {
    const animation: TgRlottieAnimation | undefined = this.nativeAnimation;
    const imageData = this.nativeImageData;
    if (!this.nativeVisible || animation === undefined || imageData === undefined) {
      return;
    }
    if (this.nativeEpochNs === 0) {
      const heldFrameNs = this.nativePlayheadFrame / animation.frameRate * 1_000_000_000;
      this.nativeEpochNs = frameInfo.timestamp - heldFrameNs;
    }
    const elapsedNs = Math.max(0, frameInfo.timestamp - this.nativeEpochNs);
    const frame = Math.floor(elapsedNs / 1_000_000_000 * animation.frameRate) % animation.frameCount;
    if (frame === this.nativeLastRenderedFrame) {
      return;
    }
    if (!this.renderNativeFrame(frame)) {
      this.fallbackAfterNativeRenderFailure();
    }
  };

  aboutToAppear(): void {
    // LazyForEach keeps cached Canvas nodes attached outside the visible area.
    // The Lottie coordinator pauses their drawing until the Canvas is visible.
    lottie.bindContext2dToCoordinator(this.ctx);
  }

  aboutToDisappear(): void {
    this.stopNativePlayback();
    this.destroyAnim();
    lottie.unbindContext2dFromCoordinator(this.ctx);
  }

  private destroyAnim(): void {
    this.destroyNativeAnimation();
    if (this.animName.length > 0) {
      try {
        lottie.destroy(this.animName);
      } catch (_e) {
      }
      this.animName = '';
      this.anim = undefined;
    }
    this.loadedForPath = '';
    this.loadedJson = '';
  }

  private destroyNativeAnimation(): void {
    this.stopNativePlayback();
    if (this.nativeAnimation !== undefined) {
      try {
        tgRlottie.destroyAnimation(this.nativeAnimation.handle);
      } catch (_e) {
      }
    }
    this.nativeAnimation = undefined;
    this.nativeImageData = undefined;
    this.nativeWidth = 0;
    this.nativeHeight = 0;
    this.nativeEpochNs = 0;
    this.nativePlayheadFrame = 0;
    this.nativeLastRenderedFrame = -1;
  }

  private startNativePlayback(): void {
    if (!this.nativeVisible || this.nativeAnimation === undefined || this.nativePlaybackStarted) {
      return;
    }
    try {
      if (!this.nativeFrameSubscribed) {
        this.nativeDisplaySync.setExpectedFrameRateRange({
          min: TgUiTokens.TGS_PLAYBACK_FRAME_RATE,
          max: TgUiTokens.TGS_PLAYBACK_FRAME_RATE,
          expected: TgUiTokens.TGS_PLAYBACK_FRAME_RATE
        });
        this.nativeDisplaySync.on('frame', this.nativeFrameCallback);
        this.nativeFrameSubscribed = true;
      }
      this.getUIContext().runScopedTask(() => {
        if (this.nativeVisible && this.nativeAnimation !== undefined && !this.nativePlaybackStarted) {
          this.nativeDisplaySync.start();
          this.nativePlaybackStarted = true;
          hilog.info(DOMAIN, TAG, 'native rlottie DisplaySync started at %{public}d Hz',
            TgUiTokens.TGS_PLAYBACK_FRAME_RATE);
        }
      });
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'native DisplaySync start failed: %{public}s', String(error));
      this.fallbackAfterNativeRenderFailure();
    }
  }

  private stopNativePlayback(): void {
    if (this.nativePlaybackStarted) {
      try {
        this.nativeDisplaySync.stop();
      } catch (_e) {
      }
      this.nativePlaybackStarted = false;
      this.nativeEpochNs = 0;
      hilog.info(DOMAIN, TAG, 'native rlottie DisplaySync stopped');
    }
    if (this.nativeFrameSubscribed) {
      try {
        this.nativeDisplaySync.off('frame', this.nativeFrameCallback);
      } catch (_e) {
      }
      this.nativeFrameSubscribed = false;
    }
  }

  private renderNativeFrame(frame: number): boolean {
    const animation: TgRlottieAnimation | undefined = this.nativeAnimation;
    const imageData = this.nativeImageData;
    if (animation === undefined || imageData === undefined) {
      return false;
    }
    try {
      const rendered: boolean = tgRlottie.renderFrame(animation.handle, frame, this.nativeWidth, this.nativeHeight,
        imageData.data);
      if (!rendered) {
        return false;
      }
      this.ctx.putImageData(imageData, 0, 0);
      this.nativePlayheadFrame = frame;
      this.nativeLastRenderedFrame = frame;
      return true;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'native rlottie render failed: %{public}s', String(error));
      return false;
    }
  }

  private tryStartNative(json: string, name: string): boolean {
    try {
      const animation: TgRlottieAnimation | null = tgRlottie.createAnimation(json, name);
      if (animation === null || animation.frameCount <= 0 || animation.frameRate <= 0) {
        return false;
      }
      // ImageData dimensions are expressed in vp by the default Canvas context,
      // while its backing Uint8ClampedArray is allocated in physical pixels.
      // rlottie must therefore render the whole physical backing store rather
      // than only the top-left 1 / density strip.
      const width = Math.max(1, Math.round(this.getUIContext().vp2px(this.renderWidth)));
      const height = Math.max(1, Math.round(this.getUIContext().vp2px(this.renderHeight)));
      this.nativeAnimation = animation;
      this.nativeWidth = width;
      this.nativeHeight = height;
      this.nativeImageData = this.ctx.createImageData(this.renderWidth, this.renderHeight);
      if (this.nativeImageData.data.length < width * height * 4) {
        hilog.warn(DOMAIN, TAG, 'native ImageData backing is too small: %{public}d < %{public}d',
          this.nativeImageData.data.length, width * height * 4);
        this.destroyNativeAnimation();
        return false;
      }
      if (!this.renderNativeFrame(0)) {
        this.destroyNativeAnimation();
        return false;
      }
      hilog.info(DOMAIN, TAG,
        'native rlottie engaged handle=%{public}d frames=%{public}d fps=%{public}s size=%{public}dx%{public}d',
        animation.handle, animation.frameCount, animation.frameRate.toFixed(2), width, height);
      this.startNativePlayback();
      return true;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'native rlottie create failed: %{public}s', String(error));
      this.destroyNativeAnimation();
      return false;
    }
  }

  private startLottieFallback(json: string): void {
    const data: object = JSON.parse(json) as object;
    this.anim = lottie.loadAnimation({
      container: this.ctx,
      renderer: 'canvas',
      loop: true,
      autoplay: true,
      name: this.animName,
      frameRate: TgUiTokens.TGS_PLAYBACK_FRAME_RATE,
      animationData: data
    });
    hilog.warn(DOMAIN, TAG, 'using @ohos/lottie fallback for %{public}s', this.animName);
  }

  private fallbackAfterNativeRenderFailure(): void {
    const json = this.loadedJson;
    if (json.length === 0 || this.anim !== undefined) {
      return;
    }
    this.destroyNativeAnimation();
    try {
      this.startLottieFallback(json);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'fallback activation failed: %{public}s', String(error));
    }
  }

  // Timeline hands us the same file:// URI it feeds to Image; zlib only
  // accepts POSIX sandbox paths, so strip the scheme and bundle authority.
  private toPosixPath(uri: string): string {
    if (!uri.startsWith('file://')) {
      return uri;
    }
    const rest = uri.substring('file://'.length);
    const slash = rest.indexOf('/');
    return slash >= 0 ? rest.substring(slash) : uri;
  }

  private async readTgsJson(path: string): Promise<string> {
    const gz = await zlib.createGZip();
    await gz.gzopen(this.toPosixPath(path), 'rb');
    const chunks: Uint8Array[] = [];
    let total = 0;
    try {
      while (true) {
        const buf = new ArrayBuffer(READ_CHUNK_BYTES);
        const read = await gz.gzread(buf);
        if (read <= 0) {
          break;
        }
        chunks.push(new Uint8Array(buf, 0, read));
        total += read;
      }
    } finally {
      await gz.gzclose();
    }
    const joined = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) {
      joined.set(chunk, offset);
      offset += chunk.length;
    }
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(joined);
  }

  private async loadAndPlay(): Promise<void> {
    const path = this.tgsPath;
    if (path.length === 0 || this.loadedForPath === path) {
      return;
    }
    this.destroyAnim();
    try {
      const json = await this.readTgsJson(path);
      if (this.tgsPath !== path) {
        return; // param changed while reading — a newer load owns the canvas
      }
      tgsInstanceSeq += 1;
      this.animName = 'tgs_' + tgsInstanceSeq.toString();
      this.loadedJson = json;
      if (!TgUiTokens.TGS_NATIVE_RLOTTIE_ENABLED || !this.tryStartNative(json, this.animName)) {
        this.startLottieFallback(json);
      }
      this.loadedForPath = path;
    } catch (error) {
      hilog.debug(DOMAIN, TAG, 'tgs load failed for %{public}s: %{public}s',
        path, String(error));
    }
  }

  build() {
    Canvas(this.ctx)
      .width(this.renderWidth)
      .height(this.renderHeight)
      .backgroundColor(Color.Transparent)
      .onVisibleAreaChange([0.0], (isVisible: boolean) => {
        this.nativeVisible = isVisible;
        if (isVisible) {
          this.startNativePlayback();
        } else {
          this.stopNativePlayback();
        }
      })
      .onReady(() => {
        this.loadAndPlay();
      })
  }
}
