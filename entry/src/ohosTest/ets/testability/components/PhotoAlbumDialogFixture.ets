import { AnyAppCommand, CustomEmojiTextEntity } from '../../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../../main/ets/core/model/AppEvent';
import { TdGatewayPort } from '../../../../main/ets/domain/ports/TdGatewayPort';
import { SendMediaMessageParams, SendMediaMessageUseCase } from '../../../../main/ets/domain/usecases/sendMediaMessage';
import { SendMediaAlbumError, SendMediaAlbumParams, SendMediaAlbumUseCase } from '../../../../main/ets/domain/usecases/sendMediaAlbum';
import { ChatPhotoAlbumController, ChatPhotoAlbumHost } from '../../../../main/ets/ui/pages/chat/ChatPhotoAlbumController';
import { localized } from '../../../../main/ets/core/utils/AppResource';
import { TgUiTokens } from '../../../../main/ets/ui/tg_ui/tokens/TgUiTokens';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { application, common } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';

// Native dialogs are real. All input, local-file preparation and send acceptance
// below are deterministic fixtures; no account, picker, file IO or TDLib exists.
@ObservedV2
export class PhotoAlbumDialogState {
  @Trace mutations: number = 0;
  @Trace preparedFiles: number = 0;
  @Trace discardedFiles: number = 0;
  @Trace gatewayCalls: number = 0;
  @Trace singleSends: number = 0;
  @Trace sending: boolean = false;
  @Trace selectedPhotos: number = 2;
  @Trace draftText: string = 'album fixture caption';
  @Trace selectionClears: number = 0;
  @Trace nativePromptDiagnostic: string = 'not attempted';
}

class UnusedAlbumGateway implements TdGatewayPort {
  private state: PhotoAlbumDialogState;
  constructor(state: PhotoAlbumDialogState) { this.state = state; }
  private unexpected(): Error {
    this.state.gatewayCalls++;
    return new Error('PhotoAlbumDialogFixture must never call a gateway');
  }
  initialize(): Promise<void> { return Promise.reject(this.unexpected()); }
  send(_command: AnyAppCommand): Promise<Object> { return Promise.reject(this.unexpected()); }
  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void { throw this.unexpected(); }
  getConnectionState(): 'connecting' | 'ready' | 'updating' | 'waitingForNetwork' { throw this.unexpected(); }
  destroy(): Promise<void> { return Promise.reject(this.unexpected()); }
}

class CapturedAlbumUseCase extends SendMediaAlbumUseCase {
  readonly attempts: SendMediaAlbumParams[] = [];
  private state: PhotoAlbumDialogState;
  constructor(state: PhotoAlbumDialogState, gateway: TdGatewayPort) {
    super(gateway);
    this.state = state;
  }
  async execute(input: SendMediaAlbumParams): Promise<void> {
    const captured = new SendMediaAlbumParams();
    captured.chatId = input.chatId;
    captured.localPaths = input.localPaths.slice();
    captured.caption = input.caption;
    captured.replyToMessageId = input.replyToMessageId;
    this.attempts.push(captured);
    this.state.mutations++;
    if (this.attempts.length === 1) {
      throw new SendMediaAlbumError(true, 'Fixture: acceptance of first mutation is unknown');
    }
    if (this.attempts.length !== 2) throw new Error('Unexpected extra fake album mutation');
  }
}

class CapturedMediaUseCase extends SendMediaMessageUseCase {
  readonly album: CapturedAlbumUseCase;
  private state: PhotoAlbumDialogState;
  constructor(state: PhotoAlbumDialogState) {
    const gateway = new UnusedAlbumGateway(state);
    super(gateway);
    this.state = state;
    this.album = new CapturedAlbumUseCase(state, gateway);
  }
  getPhotoAlbumUseCase(): SendMediaAlbumUseCase { return this.album; }
  execute(_params: SendMediaMessageParams): Promise<void> {
    this.state.singleSends++;
    return Promise.reject(new Error('PhotoAlbumDialogFixture forbids sequential media sends'));
  }
}

class DialogAlbumHost implements ChatPhotoAlbumHost {
  readonly media: CapturedMediaUseCase;
  private state: PhotoAlbumDialogState;
  private uiContext?: UIContext;
  private operation: number = 0;
  private revision: number = 0;
  private uris: string[] = ['fixture:first-photo', 'fixture:second-photo'];
  constructor(state: PhotoAlbumDialogState) {
    this.state = state;
    this.media = new CapturedMediaUseCase(state);
  }
  bind(context: UIContext): void { this.uiContext = context; }
  getActiveChatId(): number { return 900001; }
  getLifecycleToken(): number { return 1; }
  canSendNewMessages(_kind?: string): boolean { return true; }
  getChatUIContext(): UIContext {
    if (this.uiContext === undefined) throw new Error('Bind the mounted fixture UIContext before sending');
    return this.uiContext;
  }
  getSendMediaUseCase(_kind?: string): SendMediaMessageUseCase | undefined { return this.media; }
  isSendingMessage(): boolean { return this.state.sending; }
  setSendingMessage(value: boolean): void {
    if (value && !this.state.sending) this.operation++;
    this.state.sending = value;
  }
  getSendOperationToken(): number { return this.operation; }
  getComposerInputRevision(): number { return this.revision; }
  hasActiveChatState(): boolean { return true; }
  isEditModeActive(): boolean { return false; }
  isForwardModeActive(): boolean { return false; }
  getDraftText(): string { return this.state.draftText; }
  setDraftText(value: string): void { this.state.draftText = value; this.revision++; }
  setDraftSelection(_start: number, _end: number): void {}
  setCustomEmojiEntities(_entities: CustomEmojiTextEntity[]): void {}
  setEmojiPanelVisible(_visible: boolean): void {}
  getReplyToMessageId(): string { return '0'; }
  clearReplyMode(): void {}
  getPendingAttachmentUris(): string[] { return this.uris; }
  getPendingAttachmentKind(): string { return 'photo'; }
  clearPendingAttachmentState(): void {
    this.uris = [];
    this.state.selectedPhotos = 0;
    this.state.selectionClears++;
    this.revision++;
  }
  isNearBottom(): boolean { return false; }
  scrollToBottomSoon(): void { throw new Error('Fixture must not request timeline scrolling'); }
}

export class PhotoAlbumDialogFixture {
  static readonly state: PhotoAlbumDialogState = new PhotoAlbumDialogState();
  private static controller: ChatPhotoAlbumController = new ChatPhotoAlbumController();
  private static host: DialogAlbumHost = new DialogAlbumHost(PhotoAlbumDialogFixture.state);

  static reset(): void {
    if (PhotoAlbumDialogFixture.state.sending) throw new Error('Close the native dialog before resetting its owner');
    const state = PhotoAlbumDialogFixture.state;
    state.mutations = 0;
    state.preparedFiles = 0;
    state.discardedFiles = 0;
    state.gatewayCalls = 0;
    state.singleSends = 0;
    state.sending = false;
    state.selectedPhotos = 2;
    state.draftText = 'album fixture caption';
    state.selectionClears = 0;
    state.nativePromptDiagnostic = 'not attempted';
    PhotoAlbumDialogFixture.controller = new ChatPhotoAlbumController();
    PhotoAlbumDialogFixture.host = new DialogAlbumHost(state);
  }

  static capturedAttempts(): SendMediaAlbumParams[] { return PhotoAlbumDialogFixture.host.media.album.attempts; }

  static screenshotPath(fileName: string): string {
    if (fileName !== 'tg-photo-album-unknown.png' && fileName !== 'tg-photo-album-resend.png' &&
      fileName !== 'tg-photo-album-missing.png') throw new Error('Unexpected fixture screenshot name');
    const context = PhotoAlbumDialogFixture.host.getChatUIContext().getHostContext();
    if (context === undefined || context.filesDir.length === 0) throw new Error('Mounted TestAbility filesDir is unavailable');
    const path = context.filesDir + '/' + fileName;
    hilog.info(0x0007, 'PhotoAlbumDialog', 'Screenshot path %{public}s', path);
    return path;
  }

  // Failure-only diagnostic: same real context and production unknown options.
  // The valid-color control changes only the button color; neither sends media.
  static startUnknownPromptDiagnostic(validColor: boolean): void {
    const state = PhotoAlbumDialogFixture.state;
    state.nativePromptDiagnostic = 'pending color=' + (validColor ? 'existing token' : 'production empty');
    try {
      let color = '';
      if (validColor) {
        const context = PhotoAlbumDialogFixture.host.getChatUIContext().getHostContext();
        if (context === undefined) throw new Error('Native diagnostic context is unavailable');
        const argb = context.resourceManager.getColorByNameSync(TgUiTokens.COLOR_ICON_PRIMARY_RESOURCE_NAME) >>> 0;
        color = '#' + argb.toString(16).padStart(8, '0');
      }
      PhotoAlbumDialogFixture.host.getChatUIContext().getPromptAction().showDialog({
        title: localized($r('app.string.composer_album_unknown_title').id, 'Sending result unknown'),
        message: localized($r('app.string.composer_album_unknown_message').id,
          'Check the chat before sending these photos again. They may already have been sent.'),
        buttons: [{ text: localized($r('app.string.done').id, 'Done'), color: color }]
      }).then((response) => {
        state.nativePromptDiagnostic = 'resolved index=' + response.index.toString();
      }).catch((error: Object) => {
        PhotoAlbumDialogFixture.recordPromptFailure(error);
      });
    } catch (error) {
      PhotoAlbumDialogFixture.recordPromptFailure(error as Object);
    }
  }

  private static recordPromptFailure(error: Object): void {
    const failure = error as BusinessError;
    PhotoAlbumDialogFixture.state.nativePromptDiagnostic = 'rejected code=' + failure.code + ', message=' + failure.message;
  }

  // Failed-run evidence only: inspect real managers without altering the mounted
  // UIContext, native prompt API, resource IDs or production controller.
  static async colorContextDiagnostic(): Promise<string> {
    const token = TgUiTokens.COLOR_ICON_PRIMARY;
    const mounted = PhotoAlbumDialogFixture.host.getChatUIContext().getHostContext();
    if (mounted === undefined) return 'mounted context unavailable';
    const report: string[] = ['token.id=0x' + token.id.toString(16)];
    report.push(PhotoAlbumDialogFixture.inspectColorManager('mounted', mounted));
    for (const name of ['entry_test', 'entry']) {
      try {
        const context = await application.createModuleContext(mounted, name);
        report.push(PhotoAlbumDialogFixture.inspectColorManager('module ' + name, context));
      } catch (error) {
        report.push('module ' + name + ': ' + PhotoAlbumDialogFixture.diagnosticError(error as Object));
      }
    }
    try {
      const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
      report.push('topAbility=' + ability.context.abilityInfo.name + ', module=' + ability.context.currentHapModuleInfo.name);
      report.push(PhotoAlbumDialogFixture.inspectColorManager('top ability', ability.context));
    } catch (error) {
      report.push('top ability: ' + PhotoAlbumDialogFixture.diagnosticError(error as Object));
    }
    const result = report.join(' | ');
    hilog.info(0x0007, 'PhotoAlbumDialog', 'Native color context %{public}s', result);
    return result;
  }

  private static inspectColorManager(label: string, context: common.Context): string {
    const report: string[] = [label + ' filesDir=' + context.filesDir];
    try {
      const value = context.resourceManager.getColorSync(TgUiTokens.COLOR_ICON_PRIMARY.id) >>> 0;
      report.push('id=#' + value.toString(16).padStart(8, '0'));
    } catch (error) { report.push('id=' + PhotoAlbumDialogFixture.diagnosticError(error as Object)); }
    try {
      const value = context.resourceManager.getColorSync(TgUiTokens.COLOR_ICON_PRIMARY) >>> 0;
      report.push('fullResource=#' + value.toString(16).padStart(8, '0'));
    } catch (error) { report.push('fullResource=' + PhotoAlbumDialogFixture.diagnosticError(error as Object)); }
    try {
      const value = context.resourceManager.getColorByNameSync(TgUiTokens.COLOR_ICON_PRIMARY_RESOURCE_NAME) >>> 0;
      report.push('name=#' + value.toString(16).padStart(8, '0'));
    } catch (error) { report.push('name=' + PhotoAlbumDialogFixture.diagnosticError(error as Object)); }
    return report.join(', ');
  }

  private static diagnosticError(error: Object): string {
    const failure = error as BusinessError;
    return 'error code=' + failure.code + ', ' + failure.message.split('\n')[0];
  }

  static send(context: UIContext): void {
    const host = PhotoAlbumDialogFixture.host;
    host.bind(context);
    PhotoAlbumDialogFixture.controller.handleSend(host.getDraftText(), host,
      (uri: string): Promise<string> => {
        PhotoAlbumDialogFixture.state.preparedFiles++;
        if (uri === 'fixture:first-photo') return Promise.resolve('/data/fixture/first-photo.jpg');
        if (uri === 'fixture:second-photo') return Promise.resolve('/data/fixture/second-photo.jpg');
        return Promise.reject(new Error('Unexpected fixture photo URI'));
      },
      (_path: string): void => { PhotoAlbumDialogFixture.state.discardedFiles++; });
  }
}

@ComponentV2
export struct PhotoAlbumDialogFixtureView {
  @Local private state: PhotoAlbumDialogState = PhotoAlbumDialogFixture.state;

  build() {
    Column({ space: 4 }) {
      Button('Send fixture photo album')
        .id('photo-album-fixture-send')
        .onClick(() => PhotoAlbumDialogFixture.send(this.getUIContext()))
      Text('album mutations:' + this.state.mutations.toString()).id('photo-album-fixture-mutations')
      Text('album copies:' + this.state.preparedFiles.toString()).id('photo-album-fixture-copies')
      Text('album busy:' + this.state.sending.toString()).id('photo-album-fixture-busy')
      Text('album photos:' + this.state.selectedPhotos.toString()).id('photo-album-fixture-selection')
    }
  }
}
