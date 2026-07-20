declare module 'libtg_rlottie.so' {
  export interface TgRlottieAnimation {
    handle: number;
    frameCount: number;
    frameRate: number;
  }

  export interface TgRlottieModule {
    createAnimation(json: string, key: string): TgRlottieAnimation | null;
    renderFrame(handle: number, frame: number, width: number, height: number,
      output: Uint8ClampedArray): boolean;
    destroyAnimation(handle: number): void;
    getRendererInfo(): string;
  }

  const tgRlottie: TgRlottieModule;
  export default tgRlottie;
}
