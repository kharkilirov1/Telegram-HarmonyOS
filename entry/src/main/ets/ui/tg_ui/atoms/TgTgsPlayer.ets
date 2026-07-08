// TgTgsPlayer — animated .tgs sticker renderer.
// .tgs is a gzipped Lottie JSON: system @ohos.zlib GZip streams the file,
// @ohos/lottie plays the parsed data on a Canvas. Every instance owns a
// uniquely named animation and MUST destroy it in aboutToDisappear —
// LazyForEach recycling otherwise leaks render timers (project TODO note).

import lottie, { AnimationItem } from '@ohos/lottie';
import zlib from '@ohos.zlib';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

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
  private anim: AnimationItem | undefined = undefined;
  private animName: string = '';
  private loadedForPath: string = '';

  aboutToDisappear(): void {
    this.destroyAnim();
  }

  private destroyAnim(): void {
    if (this.animName.length > 0) {
      try {
        lottie.destroy(this.animName);
      } catch (_e) {
      }
      this.animName = '';
      this.anim = undefined;
      this.loadedForPath = '';
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
      const data: object = JSON.parse(json) as object;
      tgsInstanceSeq += 1;
      this.animName = 'tgs_' + tgsInstanceSeq.toString();
      this.anim = lottie.loadAnimation({
        container: this.ctx,
        renderer: 'canvas',
        loop: true,
        autoplay: true,
        name: this.animName,
        animationData: data
      });
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
      .onReady(() => {
        this.loadAndPlay();
      })
  }
}
