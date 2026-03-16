// TgPhotoViewerPage — fullscreen photo viewer with pinch-to-zoom and pan.
// Based on official HarmonyOS "Image Scaling with Finger Tracking" example.
// Uses Matrix4 transform + PinchGesture + PanGesture in parallel GestureGroup.

import { matrix4 } from '@kit.ArkUI';
import { display } from '@kit.ArkUI';
import { TgUiTokens } from '../../tg_ui/tokens/TgUiTokens';

const MIN_SCALE = 1.0;
const MAX_SCALE = 5.0;
const DISMISS_THRESHOLD = 100; // vp vertical drag to dismiss

@Component
export struct TgPhotoViewerPage {
  @Prop photoPath: string = '';
  @Prop photoPaths: string[] = [];
  @Prop initialIndex: number = 0;
  @Prop caption: string = '';
  onDismiss: () => void = () => {};

  @State private matrix: matrix4.Matrix4Transit = matrix4.identity();
  @State private curScale: number = 1.0;
  @State private offsetX: number = 0;
  @State private offsetY: number = 0;
  @State private bgOpacity: number = 1.0;
  @State private showControls: boolean = true;
  @State private currentIndex: number = 0;

  private lastScale: number = 1.0;
  private lastOffsetX: number = 0;
  private lastOffsetY: number = 0;
  private screenWidth: number = 360;
  private screenHeight: number = 780;
  private contentWidth: number = 0;
  private contentHeight: number = 0;
  private panStartY: number = 0;
  private isDismissing: boolean = false;

  private updateMatrix(): void {
    this.matrix = matrix4.identity()
      .scale({ x: this.curScale, y: this.curScale })
      .translate({ x: this.offsetX, y: this.offsetY });
  }

  aboutToAppear(): void {
    try {
      const screenSize = display.getDefaultDisplaySync();
      this.screenWidth = px2vp(screenSize.width);
      this.screenHeight = px2vp(screenSize.height);
    } catch (_e) {
      // fallback values are fine
    }
    this.currentIndex = this.normalizedInitialIndex();
    this.resetTransform();
  }

  private effectivePhotoPaths(): string[] {
    const result: string[] = [];
    for (let i = 0; i < this.photoPaths.length; i++) {
      const current = this.photoPaths[i];
      if (current.trim().length > 0) {
        result.push(current);
      }
    }
    if (result.length === 0 && this.photoPath.trim().length > 0) {
      result.push(this.photoPath);
    }
    return result;
  }

  private hasGallery(): boolean {
    return this.effectivePhotoPaths().length > 1;
  }

  private normalizedInitialIndex(): number {
    const paths = this.effectivePhotoPaths();
    if (paths.length === 0) {
      return 0;
    }
    return Math.max(0, Math.min(paths.length - 1, this.initialIndex));
  }

  private activePhotoPath(): string {
    const paths = this.effectivePhotoPaths();
    if (paths.length === 0) {
      return '';
    }
    const index = Math.max(0, Math.min(paths.length - 1, this.currentIndex));
    return paths[index];
  }

  private galleryCounterText(): string {
    const paths = this.effectivePhotoPaths();
    if (paths.length <= 1) {
      return '';
    }
    const index = Math.max(0, Math.min(paths.length - 1, this.currentIndex));
    return (index + 1).toString() + ' / ' + paths.length.toString();
  }

  private clampOffset(): void {
    if (this.curScale <= 1.0) {
      this.offsetX = 0;
      this.offsetY = 0;
      return;
    }
    // Limit pan to scaled content bounds
    const maxPanX = (this.curScale - 1) * this.screenWidth / 2;
    const maxPanY = (this.curScale - 1) * this.screenHeight / 2;
    this.offsetX = Math.max(-maxPanX, Math.min(maxPanX, this.offsetX));
    this.offsetY = Math.max(-maxPanY, Math.min(maxPanY, this.offsetY));
  }

  private resetTransform(): void {
    this.curScale = 1.0;
    this.lastScale = 1.0;
    this.offsetX = 0;
    this.offsetY = 0;
    this.lastOffsetX = 0;
    this.lastOffsetY = 0;
    this.bgOpacity = 1.0;
    this.updateMatrix();
  }

  @Builder
  private buildSingleImageLayer() {
    Column() {
      Image(this.activePhotoPath())
        .objectFit(ImageFit.Contain)
        .draggable(false)
        .width('100%')
        .height('100%')
        .onComplete((event) => {
          if (event) {
            this.contentWidth = px2vp(event.contentWidth);
            this.contentHeight = px2vp(event.contentHeight);
          }
        })
        .transform(this.matrix)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .gesture(
      GestureGroup(GestureMode.Parallel,
        PinchGesture({ fingers: 2 })
          .onActionStart(() => {
            this.lastScale = this.curScale;
          })
          .onActionUpdate((event: GestureEvent) => {
            if (event) {
              const newScale = this.lastScale * event.scale;
              this.curScale = Math.max(MIN_SCALE, Math.min(MAX_SCALE, newScale));
              this.clampOffset();
              this.updateMatrix();
            }
          })
          .onActionEnd(() => {
            if (this.curScale < MIN_SCALE) {
              this.curScale = MIN_SCALE;
              this.clampOffset();
              this.updateMatrix();
            }
            this.lastScale = this.curScale;
          }),
        PanGesture({ fingers: 1, direction: PanDirection.All })
          .onActionStart((event: GestureEvent) => {
            this.lastOffsetX = this.offsetX;
            this.lastOffsetY = this.offsetY;
            this.panStartY = event.offsetY;
            this.isDismissing = false;
          })
          .onActionUpdate((event: GestureEvent) => {
            if (this.curScale > 1.05) {
              this.offsetX = this.lastOffsetX + event.offsetX;
              this.offsetY = this.lastOffsetY + event.offsetY;
              this.clampOffset();
              this.updateMatrix();
            } else {
              const deltaY = event.offsetY;
              this.offsetY = deltaY;
              this.bgOpacity = Math.max(0.3, 1.0 - Math.abs(deltaY) / (this.screenHeight * 0.4));
              this.updateMatrix();
              this.isDismissing = Math.abs(deltaY) > DISMISS_THRESHOLD;
            }
          })
          .onActionEnd(() => {
            if (this.curScale <= 1.05) {
              if (this.isDismissing) {
                this.onDismiss();
                return;
              }
              this.offsetY = 0;
              this.bgOpacity = 1.0;
              this.updateMatrix();
            }
            this.lastOffsetX = this.offsetX;
            this.lastOffsetY = this.offsetY;
          })
      )
    )
    .onClick(() => {
      if (this.curScale <= 1.05) {
        this.showControls = !this.showControls;
      }
    })
  }

  @Builder
  private buildGalleryLayer() {
    Swiper() {
      ForEach(this.effectivePhotoPaths(), (path: string, index: number) => {
        Column() {
          Image(path)
            .objectFit(ImageFit.Contain)
            .draggable(false)
            .width('100%')
            .height('100%')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showControls = !this.showControls;
        })
      }, (path: string, index: number) => path + '#' + index.toString())
    }
    .index(this.currentIndex)
    .indicator(false)
    .loop(false)
    .width('100%')
    .height('100%')
    .onChange((index: number) => {
      this.currentIndex = index;
      this.resetTransform();
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // Black background with opacity (fades on dismiss drag)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .opacity(this.bgOpacity)

      if (this.hasGallery()) {
        this.buildGalleryLayer()
      } else {
        this.buildSingleImageLayer()
      }

      // Top bar with close button
      if (this.showControls) {
        Row() {
          Image($r('app.media.ic_close'))
            .width(24)
            .height(24)
            .fillColor(Color.White)
            .onClick(() => {
              this.onDismiss();
            })

          if (this.hasGallery()) {
            Text(this.galleryCounterText())
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
          } else {
            Blank()
              .layoutWeight(1)
          }

          Blank()
            .width(24)
        }
        .width('100%')
        .padding({
          left: 16,
          right: 16,
          top: 50,
          bottom: 12
        })
        .linearGradient({
          direction: GradientDirection.Top,
          colors: [['rgba(0,0,0,0.5)', 0.0], ['rgba(0,0,0,0)', 1.0]]
        })

        // Caption at bottom
        if (this.caption.trim().length > 0) {
          Column() {
            Blank()
            Text(this.caption)
              .fontSize(15)
              .fontColor(Color.White)
              .maxLines(5)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({
                left: 16,
                right: 16,
                bottom: 40,
                top: 12
              })
              .width('100%')
              .linearGradient({
                direction: GradientDirection.Bottom,
                colors: [['rgba(0,0,0,0.5)', 0.0], ['rgba(0,0,0,0)', 1.0]]
              })
          }
          .width('100%')
          .height('100%')
          .hitTestBehavior(HitTestMode.None)
        }
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

declare function px2vp(value: number): number;
