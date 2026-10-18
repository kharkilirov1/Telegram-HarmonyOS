import { image } from '@kit.ImageKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AnyAppCommand } from '../../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../../main/ets/core/model/AppEvent';
import { AppState, Chat, ReducerAction, createInitialAppState } from '../../../../main/ets/core/model/AppState';
import { AppStore } from '../../../../main/ets/core/store/AppStore';
import { TdGatewayPort } from '../../../../main/ets/domain/ports/TdGatewayPort';
import { SendMediaMessageUseCase } from '../../../../main/ets/domain/usecases/sendMediaMessage';
import { ChatScreenSession } from '../../../../main/ets/ui/pages/chat/ChatScreenSession';
import { ChatScreenViewState } from '../../../../main/ets/ui/pages/chat/ChatScreenViewState';
import { ChatComposerState } from '../../../../main/ets/ui/pages/chat/ChatComposerState';
import { TgPhotoSelectionPreview, resolvePhotoSelectionPreviewColor } from '../../../../main/ets/ui/tg_ui/atoms/TgPhotoSelectionPreview';
import { TgPhotoSelectionPreviewDemo } from '../../../../main/ets/ui/tg_ui/demos/TgPhotoSelectionPreviewDemo';
import { TgUiTokens } from '../../../../main/ets/ui/tg_ui/tokens/TgUiTokens';

@ObservedV2
export class PhotoSelectionPreviewState {
  @Trace ready: boolean = false;
  @Trace preparing: boolean = false;
  @Trace preparationError: string = '';
  @Trace sampleUris: string[] = [];
  @Trace missingUri: string = '';
  @Trace loadedUri: string = '';
  @Trace loadSuccess: boolean = false;
  @Trace decodedWidth: number = 0;
  @Trace decodedHeight: number = 0;
  @Trace contentWidth: number = 0;
  @Trace contentHeight: number = 0;
  @Trace textColor: number = 0;
  @Trace primaryBackgroundColor: number = 0;
  @Trace secondaryBackgroundColor: number = 0;
  @Trace decodeCount: number = 0;
  @Trace moveCalls: number = 0;
  @Trace removeCalls: number = 0;
  @Trace lastMoveUri: string = '';
  @Trace lastMoveDirection: number = 0;
  @Trace lastRemovedUri: string = '';
  @Trace gatewayCalls: number = 0;
  @Trace showDemo: boolean = false;
}

// Real permission/state/controller code runs; no transport may be used.
class UnusedPreviewGateway implements TdGatewayPort {
  private failure(): Error {
    PhotoSelectionPreviewFixture.state.gatewayCalls++;
    return new Error('PhotoSelectionPreviewFixture forbids gateway access');
  }
  initialize(): Promise<void> { return Promise.reject(this.failure()); }
  send(_command: AnyAppCommand): Promise<Object> { return Promise.reject(this.failure()); }
  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void { throw this.failure(); }
  getConnectionState(): 'connecting' | 'ready' | 'updating' | 'waitingForNetwork' { throw this.failure(); }
  destroy(): Promise<void> { return Promise.reject(this.failure()); }
}

export class PhotoSelectionPreviewFixture {
  static readonly state: PhotoSelectionPreviewState = new PhotoSelectionPreviewState();
  static readonly view: ChatScreenViewState = new ChatScreenViewState();
  private static uiContext?: UIContext;
  static readonly session: ChatScreenSession = new ChatScreenSession(PhotoSelectionPreviewFixture.view,
    (): UIContext => PhotoSelectionPreviewFixture.mountedContext(), () => undefined);
  private static filesDir: string = '';

  // Test-only root viewport. This binding exists before Prepare is clicked.
  static readonly viewportScroller: Scroller = new Scroller();
  private static viewportContext?: UIContext;
  private static viewportGeneration: number = 0;

  static bindViewport(context: UIContext): number {
    PhotoSelectionPreviewFixture.viewportContext = context;
    PhotoSelectionPreviewFixture.viewportGeneration++;
    return PhotoSelectionPreviewFixture.viewportGeneration;
  }

  static unbindViewport(owner: number): void {
    if (owner !== PhotoSelectionPreviewFixture.viewportGeneration) return;
    PhotoSelectionPreviewFixture.viewportContext = undefined;
    PhotoSelectionPreviewFixture.viewportGeneration++;
  }

  static viewportOwner(): number {
    if (PhotoSelectionPreviewFixture.viewportContext === undefined) throw new Error('Photo fixture viewport is not mounted');
    return PhotoSelectionPreviewFixture.viewportGeneration;
  }

  static assertViewportOwner(owner: number): void {
    if (PhotoSelectionPreviewFixture.viewportContext === undefined || owner !== PhotoSelectionPreviewFixture.viewportGeneration) {
      throw new Error('Photo fixture viewport owner changed');
    }
  }

  static positionInViewport(id: string, owner: number): void {
    PhotoSelectionPreviewFixture.assertViewportOwner(owner);
    if (!/^photo-preview-fixture-(prepare|reset|busy|missing|ten|image|position|strip|move-earlier|move-later|remove|error|count|busy-state|decoded|demo|thumb-[0-9]|ordinal-[0-9])$/.test(id)) {
      throw new Error('Unexpected photo fixture viewport target: ' + id);
    }
    // Vertical positioning reveals the strip; native bounds still prove child clipping.
    const nested = id.startsWith('photo-preview-fixture-thumb-') || id.startsWith('photo-preview-fixture-ordinal-');
    const targetId = nested ? 'photo-preview-fixture-strip' : id;
    const context = PhotoSelectionPreviewFixture.viewportContext!;
    const utils = context.getComponentUtils();
    const viewport = utils.getRectangleById('chat-test-fixture-scroll');
    const target = utils.getRectangleById(targetId);
    const values: number[] = [viewport.windowOffset.x, viewport.windowOffset.y, viewport.size.width, viewport.size.height,
      target.windowOffset.x, target.windowOffset.y, target.size.width, target.size.height];
    if (values.some((value: number): boolean => !Number.isFinite(value))) throw new Error('Invalid photo fixture layout coordinates');
    // A just-created component may not have laid out yet. The native observation deadline is shared across retries.
    if (viewport.size.width <= 0 || viewport.size.height <= 0 || target.size.width <= 0 || target.size.height <= 0) return;
    if (target.size.height > viewport.size.height || target.windowOffset.x < viewport.windowOffset.x ||
      target.windowOffset.x + target.size.width > viewport.windowOffset.x + viewport.size.width) {
      throw new Error('Photo fixture target cannot fit the viewport: ' + id);
    }
    const topDelta = target.windowOffset.y - viewport.windowOffset.y;
    const bottomDelta = topDelta + target.size.height - viewport.size.height;
    const deltaPx = topDelta < 0 ? topDelta : (bottomDelta > 0 ? bottomDelta : 0);
    if (deltaPx === 0) return;
    const offset = PhotoSelectionPreviewFixture.viewportScroller.currentOffset();
    if (offset === undefined || offset === null) throw new Error('Photo fixture Scroller is not bound');
    const deltaVp = context.px2vp(deltaPx);
    if (!Number.isFinite(offset.xOffset) || !Number.isFinite(offset.yOffset) || !Number.isFinite(deltaVp)) {
      throw new Error('Invalid photo fixture scroll offset');
    }
    PhotoSelectionPreviewFixture.assertViewportOwner(owner);
    PhotoSelectionPreviewFixture.viewportScroller.scrollTo({ xOffset: offset.xOffset,
      yOffset: Math.max(0, offset.yOffset + deltaVp), animation: false });
  }

  private static mountedContext(): UIContext {
    if (PhotoSelectionPreviewFixture.uiContext === undefined) throw new Error('Preview fixture UIContext is not mounted');
    return PhotoSelectionPreviewFixture.uiContext;
  }

  static async prepare(context: UIContext): Promise<void> {
    const state = PhotoSelectionPreviewFixture.state;
    if (state.preparing) return;
    state.preparing = true;
    state.preparationError = '';
    state.ready = false;
    PhotoSelectionPreviewFixture.uiContext = context;
    try {
      const host = context.getHostContext();
      if (host === undefined || host.filesDir.length === 0) throw new Error('Mounted TestAbility filesDir is unavailable');
      PhotoSelectionPreviewFixture.filesDir = host.filesDir;
      state.textColor = resolvePhotoSelectionPreviewColor(context, TgUiTokens.COLOR_TEXT_TITLE_RESOURCE_NAME);
      state.primaryBackgroundColor = resolvePhotoSelectionPreviewColor(context, TgUiTokens.COLOR_BG_PRIMARY_RESOURCE_NAME);
      state.secondaryBackgroundColor = resolvePhotoSelectionPreviewColor(context, TgUiTokens.COLOR_BG_SECONDARY_RESOURCE_NAME);
      if (state.sampleUris.length === 0) {
        const uris: string[] = [];
        for (let index = 0; index < 10; index++) {
          const path = host.filesDir + '/tg-photo-preview-fixture-' + index.toString() + '.png';
          await PhotoSelectionPreviewFixture.writeOriginalPng(path, index);
          uris.push(fileUri.getUriFromPath(path));
        }
        state.sampleUris = uris;
      }
      state.missingUri = fileUri.getUriFromPath(host.filesDir + '/tg-photo-preview-fixture-missing.png');
      PhotoSelectionPreviewFixture.reset();
      state.ready = true;
    } catch (error) {
      state.preparationError = (error as Error).message;
    } finally {
      state.preparing = false;
    }
  }

  private static async writeOriginalPng(path: string, index: number): Promise<void> {
    const width = 240;
    const height = 160;
    const pixels = new Uint8Array(width * height * 4);
    const colors: number[][] = [[220, 45, 45], [35, 170, 70], [40, 90, 220], [210, 140, 25], [140, 45, 180]];
    const color = colors[index % colors.length];
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const offset = (y * width + x) * 4;
        const white = Math.abs(x - width / 2) < 5 + index || Math.abs(y - height / 2) < 5 + index;
        pixels[offset] = white ? 255 : color[0];
        pixels[offset + 1] = white ? 255 : color[1];
        pixels[offset + 2] = white ? 255 : color[2];
        pixels[offset + 3] = 255;
      }
    }
    const pixelMap = await image.createPixelMap(pixels.buffer, {
      size: { width: width, height: height }, srcPixelFormat: image.PixelMapFormat.RGBA_8888,
      pixelFormat: image.PixelMapFormat.RGBA_8888, editable: false
    });
    try {
      const packer = image.createImagePacker();
      try {
        const packed = await packer.packing(pixelMap, { format: 'image/png', quality: 100 });
        const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        try {
          if (fileIo.writeSync(file.fd, packed) !== packed.byteLength) throw new Error('Short write of original preview PNG');
        } finally { fileIo.closeSync(file); }
      } finally { await packer.release(); }
    } finally { await pixelMap.release(); }
  }

  static reset(): void {
    const state = PhotoSelectionPreviewFixture.state;
    if (state.sampleUris.length !== 10) throw new Error('Prepare original fixture PNGs first');
    const initial = createInitialAppState();
    const chat = new Chat();
    chat.id = 900002;
    chat.title = 'Synthetic preview fixture';
    initial.chats.chats.set(chat.id, chat);
    const session = PhotoSelectionPreviewFixture.session;
    session.accountStore = new AppStore((current: AppState, _action: ReducerAction): AppState => current, initial, false);
    session.activeChatId = chat.id;
    session.pageLifecycleToken = 1;
    session.sendMediaUseCase = new SendMediaMessageUseCase(new UnusedPreviewGateway());
    session.refreshChatInputPanel();
    session.setSendingMessage(false);
    session.isEditingMessage = false;
    session.isForwardingMessages = false;
    session.setDraftText('preview fixture caption');
    session.setReplyMode('42', 'Fixture reply', 'Original fixture reply', false);
    session.setPendingAttachmentState('photo', 'Photo', '3 original fixture photos', state.sampleUris.slice(0, 3));
    state.loadedUri = '';
    state.loadSuccess = false;
    state.decodedWidth = 0;
    state.decodedHeight = 0;
    state.contentWidth = 0;
    state.contentHeight = 0;
    state.decodeCount = 0;
    state.moveCalls = 0;
    state.removeCalls = 0;
    state.lastMoveUri = '';
    state.lastMoveDirection = 0;
    state.lastRemovedUri = '';
    state.gatewayCalls = 0;
    state.showDemo = false;
  }

  static move(uri: string, direction: number): void {
    PhotoSelectionPreviewFixture.state.moveCalls++;
    PhotoSelectionPreviewFixture.state.lastMoveUri = uri;
    PhotoSelectionPreviewFixture.state.lastMoveDirection = direction;
    PhotoSelectionPreviewFixture.session.movePendingPhoto(uri, direction);
  }

  static remove(uri: string): void {
    PhotoSelectionPreviewFixture.state.removeCalls++;
    PhotoSelectionPreviewFixture.state.lastRemovedUri = uri;
    PhotoSelectionPreviewFixture.session.removePendingPhoto(uri);
  }

  static showMissing(): void {
    PhotoSelectionPreviewFixture.session.setPendingAttachmentState('photo', 'Photo', 'Missing fixture photo',
      [PhotoSelectionPreviewFixture.state.missingUri]);
  }

  static showTen(): void {
    PhotoSelectionPreviewFixture.session.setPendingAttachmentState('photo', 'Photo', '10 original fixture photos',
      PhotoSelectionPreviewFixture.state.sampleUris.slice(0, 10));
  }

  static collapse(): void {
    PhotoSelectionPreviewFixture.session.setSendingMessage(false);
    PhotoSelectionPreviewFixture.session.clearPendingAttachmentState();
    PhotoSelectionPreviewFixture.state.ready = false;
    PhotoSelectionPreviewFixture.state.showDemo = false;
  }

  static screenshotPath(fileName: string): string {
    if (fileName !== 'tg-photo-selection-preview.png' && fileName !== 'tg-photo-selection-preview-reordered.png' &&
      fileName !== 'tg-photo-selection-preview-error.png' && fileName !== 'tg-photo-selection-preview-ten.png') {
      throw new Error('Unexpected preview screenshot name');
    }
    if (PhotoSelectionPreviewFixture.filesDir.length === 0) throw new Error('Preview filesDir is unavailable');
    const path = PhotoSelectionPreviewFixture.filesDir + '/' + fileName;
    hilog.info(0x0007, 'PhotoSelectionPreview', 'Screenshot path %{public}s', path);
    return path;
  }

  static recordImage(uri: string, success: boolean, width: number, height: number,
    contentWidth: number, contentHeight: number): void {
    const state = PhotoSelectionPreviewFixture.state;
    state.loadedUri = uri;
    state.loadSuccess = success;
    state.decodedWidth = width;
    state.decodedHeight = height;
    state.contentWidth = contentWidth;
    state.contentHeight = contentHeight;
    if (success) state.decodeCount++;
  }
}

@ComponentV2
export struct PhotoSelectionPreviewFixtureView {
  @Local private state: PhotoSelectionPreviewState = PhotoSelectionPreviewFixture.state;
  @Local private composer: ChatComposerState = PhotoSelectionPreviewFixture.view.composer;

  build() {
    Column({ space: 8 }) {
      Button('Prepare original preview photos')
        .id('photo-preview-fixture-prepare')
        .enabled(!this.state.preparing)
        .onClick(() => { PhotoSelectionPreviewFixture.prepare(this.getUIContext()); })
      if (this.state.preparationError.length > 0) {
        Text('preview fixture error:' + this.state.preparationError).id('photo-preview-fixture-error')
      }
      if (this.state.ready) {
        Row({ space: 8 }) {
          Button('Reset preview').id('photo-preview-fixture-reset').layoutWeight(1).height(44)
            .labelStyle({ maxLines: 2 }).onClick(() => PhotoSelectionPreviewFixture.reset())
          Button('Toggle busy').id('photo-preview-fixture-busy').layoutWeight(1).height(44).labelStyle({ maxLines: 2 }).onClick(() => {
            const session = PhotoSelectionPreviewFixture.session;
            session.setSendingMessage(!session.isSendingMessage());
          })
          Button('Missing photo').id('photo-preview-fixture-missing').layoutWeight(1).height(44)
            .labelStyle({ maxLines: 2 }).onClick(() => PhotoSelectionPreviewFixture.showMissing())
        }
        .width('100%')
        Button('Show ten preview photos').id('photo-preview-fixture-ten').onClick(() => PhotoSelectionPreviewFixture.showTen())
        if (this.composer.pendingAttachmentKind === 'photo' && this.composer.pendingAttachmentUris.length > 0) {
          TgPhotoSelectionPreview({
            uris: this.composer.pendingAttachmentUris,
            disabled: this.composer.isSending || !PhotoSelectionPreviewFixture.session.composerAllows('photo') ||
              this.composer.isEditingMessage || this.composer.isForwardingMessages,
            idPrefix: 'photo-preview-fixture',
            onRemove: (uri: string): void => PhotoSelectionPreviewFixture.remove(uri),
            onMove: (uri: string, direction: number): void => PhotoSelectionPreviewFixture.move(uri, direction),
            onImageLoad: (uri: string, success: boolean, width: number, height: number,
              contentWidth: number, contentHeight: number): void =>
              PhotoSelectionPreviewFixture.recordImage(uri, success, width, height, contentWidth, contentHeight)
          })
        }
        Text('preview photos:' + this.composer.pendingAttachmentUris.length.toString()).id('photo-preview-fixture-count')
        Text('preview busy:' + this.composer.isSending.toString()).id('photo-preview-fixture-busy-state')
        Text('preview decoded:' + this.state.decodeCount.toString()).id('photo-preview-fixture-decoded')
        Button('Show preview state matrix').id('photo-preview-fixture-demo').onClick(() => {
          this.state.showDemo = !this.state.showDemo;
        })
        if (this.state.showDemo) {
          TgPhotoSelectionPreviewDemo({ sampleUris: this.state.sampleUris, missingUri: this.state.missingUri }).height(480)
        }
      }
    }
    .width('100%')
    .padding(8)
  }
}
