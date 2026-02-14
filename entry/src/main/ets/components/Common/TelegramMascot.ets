import lottie, { AnimationItem } from '@ohos/lottie';
import { util } from '@kit.ArkTS';

export enum MascotState {
  IDLE = 'idle',
  TRACKING = 'tracking',
  CLOSE = 'close',
  PEEK = 'peek',
  CLOSE_AND_PEEK = 'close_and_peek',
  CLOSE_PEEK_TO_IDLE = 'close_peek_to_idle'
}

// Map animation state to rawfile name
function getAnimationFile(state: MascotState): string {
  switch (state) {
    case MascotState.IDLE:
      return 'animations/monkey_idle.json';
    case MascotState.TRACKING:
      return 'animations/monkey_tracking.json';
    case MascotState.CLOSE:
      return 'animations/monkey_close.json';
    case MascotState.PEEK:
      return 'animations/monkey_peek.json';
    case MascotState.CLOSE_AND_PEEK:
      return 'animations/monkey_close_and_peek.json';
    case MascotState.CLOSE_PEEK_TO_IDLE:
      return 'animations/monkey_close_peek_to_idle.json';
  }
}

// Cache parsed animation data to avoid repeated file reads
const animationDataCache = new Map<string, Object>();

@ComponentV2
export struct TelegramMascot {
  @Param mascotState: MascotState = MascotState.IDLE;
  @Param mascotSize: number = 120;

  private renderingSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.renderingSettings);
  private animationItem: AnimationItem | null = null;
  private canvasName: string = `mascot_${Date.now()}`;
  @Local private currentFile: string = '';

  aboutToDisappear(): void {
    if (this.animationItem) {
      this.animationItem.destroy();
      this.animationItem = null;
    }
    lottie.destroy(this.canvasName);
  }

  build() {
    Canvas(this.canvasCtx)
      .width(this.mascotSize)
      .height(this.mascotSize)
      .backgroundColor(Color.Transparent)
      .onReady(() => {
        this.canvasCtx.imageSmoothingEnabled = true;
        this.canvasCtx.imageSmoothingQuality = 'medium';
        this.playAnimation(this.mascotState);
      })
  }

  @Monitor('mascotState')
  onStateChange(): void {
    this.playAnimation(this.mascotState);
  }

  private loadAnimationData(fileName: string): Object | null {
    // Return from cache if already loaded
    const cached = animationDataCache.get(fileName);
    if (cached) {
      return cached;
    }

    try {
      const rawData = getContext(this).resourceManager.getRawFileContentSync(fileName);
      const decoder = new util.TextDecoder('utf-8');
      const jsonStr = decoder.decodeToString(rawData);
      const data: Object = JSON.parse(jsonStr) as Object;
      animationDataCache.set(fileName, data);
      return data;
    } catch (e) {
      return null;
    }
  }

  private playAnimation(state: MascotState): void {
    const fileName = getAnimationFile(state);

    // Don't reload if same animation is playing
    if (fileName === this.currentFile && this.animationItem) {
      return;
    }
    this.currentFile = fileName;

    // Destroy previous animation
    if (this.animationItem) {
      this.animationItem.destroy();
      this.animationItem = null;
    }

    const animData = this.loadAnimationData(fileName);
    if (!animData) {
      return;
    }

    const loopStates: MascotState[] = [MascotState.IDLE, MascotState.TRACKING];
    const shouldLoop = loopStates.includes(state);

    this.animationItem = lottie.loadAnimation({
      container: this.canvasCtx,
      renderer: 'canvas',
      loop: shouldLoop,
      autoplay: true,
      animationData: animData,
      name: this.canvasName
    });

    // After non-looping transitions complete, go back to idle or appropriate state
    if (!shouldLoop && this.animationItem) {
      this.animationItem.addEventListener('complete', () => {
        if (state === MascotState.CLOSE_PEEK_TO_IDLE) {
          this.playAnimation(MascotState.IDLE);
        }
      });
    }
  }
}
