import { AnyAppCommand } from '../../../../main/ets/core/model/AppCommand';
import { TdObject } from '../../../../main/ets/models/TdTypes';
import { SendMediaMessageUseCase } from '../../../../main/ets/domain/usecases/sendMediaMessage';
import { SendMessageUseCase } from '../../../../main/ets/domain/usecases/sendMessage';
import { ChatScreenSession } from '../../../../main/ets/ui/pages/chat/ChatScreenSession';
import { ChatScreenViewState } from '../../../../main/ets/ui/pages/chat/ChatScreenViewState';
import { TgChatComposerDock } from '../../../../main/ets/ui/pages/chat/TgChatComposerDock';
import { SlowmodeFixture } from '../../test/Slowmode.test';
import { WriteGateway } from '../../test/WritePathErrors.test';
import { navigationUIState, NavigationUIState } from '../../../../main/ets/core/model/UIStateModels';
import { TgUiTokens } from '../../../../main/ets/ui/tg_ui/tokens/TgUiTokens';
import { BusinessError } from '@kit.BasicServicesKit';
import { application, common } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';

@ObservedV2
export class SlowmodeNativeState {
  @Trace view: ChatScreenViewState = new ChatScreenViewState();
  @Trace page?: SlowmodeNativeSession;
  @Trace mutations: number = 0;
  @Trace generations: number = 0;
}
class SlowmodeNativeGateway extends WriteGateway {
  unknown: boolean = false;
  private state: SlowmodeNativeState;
  constructor(state: SlowmodeNativeState) { super(); this.state = state; }
  send(command: AnyAppCommand): Promise<Object> {
    if (command.type !== 'sendMessage' && command.type !== 'sendMediaMessage') {
      throw new Error('Mounted slowmode fixture forbids all non-send transport requests');
    }
    const promise = super.send(command); const request = this.requests[this.requests.length - 1];
    this.state.mutations = this.requests.length;
    if (this.unknown) request.reject?.(new Error('Controlled unknown write outcome'));
    else request.resolve?.(TdObject.fromJSON('{"@type":"message","id":' + (900 + this.requests.length).toString() + ',"chat_id":42}'));
    return promise;
  }
}
class SlowmodeNativeSession extends ChatScreenSession {
  nativeSelectionEvents: number = 0;
  goToNewerSearchResult(): void { throw new Error('Synthetic slowmode Dock forbids search navigation'); }
  goToOlderSearchResult(): void { throw new Error('Synthetic slowmode Dock forbids search navigation'); }
  handleComposerSelectionChange(start: number, end: number): void {
    super.handleComposerSelectionChange(start, end); this.nativeSelectionEvents++;
  }
}
// Actual Dock/atom, Context/Session, controller, use case and scoped store are
// composed here. Only the transport and document preparation are synthetic.
// This page never runs account bootstrap, providers or authenticated ChatPage.
export class SlowmodeNativeFixture {
  static readonly state: SlowmodeNativeState = new SlowmodeNativeState();
  private static nativeConfigurationReady: boolean = false;
  static setConfigurationReady(value: boolean): void { SlowmodeNativeFixture.nativeConfigurationReady = value; }
  static configurationReady(): boolean { return SlowmodeNativeFixture.nativeConfigurationReady; }
  private static context?: UIContext;
  private static active?: SlowmodeFixture;
  private static unsubscribe?: () => void;
  private static inputSealed: boolean = false;
  private static readonly moduleContexts: Map<string, common.Context> = new Map();
  private static moduleContextAttempts: boolean = false;
  private static navigation?: NavPathStack;
  private static navigationGeneration: number = 0;
  static bindNavigation(stack: NavPathStack): void { SlowmodeNativeFixture.navigation = stack; }
  static navigationBound(): boolean { return SlowmodeNativeFixture.navigation !== undefined; }
  static beforeRoutePush(stack: NavPathStack): void {
    SlowmodeNativeFixture.navigation = stack;
    console.info('[SlowmodeNative] beforePush depth=' + stack.size().toString() +
      ' generation=' + SlowmodeNativeFixture.navigationGeneration.toString());
    if (stack.size() !== 0) throw new Error('Slowmode fixture can only be pushed from the actual empty Index stack');
  }
  static afterRoutePush(stack: NavPathStack): void {
    if (stack.size() !== 1 || stack.getAllPathName()[0] !== 'SlowmodeNativeFixtureRoute') {
      throw new Error('Slowmode fixture push did not install exactly one owned route');
    }
    SlowmodeNativeFixture.navigationGeneration++;
    console.info('[SlowmodeNative] afterPush depth=' + stack.size().toString() +
      ' generation=' + SlowmodeNativeFixture.navigationGeneration.toString());
  }
  static navigationDepth(): number {
    const stack = SlowmodeNativeFixture.navigation;
    if (stack === undefined) throw new Error('Actual Index NavPathStack authority is not bound');
    return stack.size();
  }
  static routeGeneration(): number { return SlowmodeNativeFixture.navigationGeneration; }
  static bind(context: UIContext): void { SlowmodeNativeFixture.context = context; }
  static fixture(): SlowmodeFixture {
    const value = SlowmodeNativeFixture.active;
    if (value === undefined) throw new Error('Slowmode fixture has not been prepared');
    return value;
  }
  static uiContext(): UIContext {
    const context = SlowmodeNativeFixture.context;
    if (context === undefined) throw new Error('Slowmode Dock is not mounted');
    return context;
  }
  // Numeric cross-HAP lookup requires the corresponding module context. The
  // unscoped mounted manager is diagnostic; the actual entry_test context must
  // resolve production/local resources consistently. Rendering stays untouched.
  static async assertNativeColorContext(): Promise<void> {
    const host = SlowmodeNativeFixture.uiContext().getHostContext();
    if (host === undefined) throw new Error('Mounted slowmode resource host is unavailable');
    const ability = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
    const compiledModule = TgUiTokens.COLOR_BG_PRIMARY.moduleName;
    if (compiledModule !== 'entry' && compiledModule !== 'entry_test') throw new Error('Compiled Resource module is absent or invalid');
    if (ability.context.abilityInfo.name !== 'TestAbility' || ability.context.currentHapModuleInfo.name !== compiledModule) {
      throw new Error('Native fixture ability and compiled Resource namespace do not match');
    }
    console.info('[SlowmodeNative] resourceHost ability=' + ability.context.abilityInfo.name +
      ' module=' + ability.context.currentHapModuleInfo.name + ' resourceDir=' + host.resourceDir);
    if (!SlowmodeNativeFixture.moduleContextAttempts) {
      SlowmodeNativeFixture.moduleContextAttempts = true;
      for (const name of ['entry_test', 'entry']) {
        try { SlowmodeNativeFixture.moduleContexts.set(name, await application.createModuleContext(host, name)); }
        catch (error) {
          const failure = error as BusinessError;
          console.info('[SlowmodeNative] createModuleContext=' + name + ' errorCode=' + failure.code.toString() +
            ' message=' + failure.message);
        }
      }
    }
    const imported: Resource[] = [TgUiTokens.COLOR_BG_PRIMARY, TgUiTokens.COLOR_TEXT_TITLE, TgUiTokens.COLOR_ICON_PRIMARY];
    const local: Resource[] = [$r('app.color.background_primary'), $r('app.color.text_primary'), $r('app.color.telegram_blue')];
    const names: string[] = [TgUiTokens.COLOR_BG_PRIMARY_RESOURCE_NAME,
      TgUiTokens.COLOR_TEXT_TITLE_RESOURCE_NAME, TgUiTokens.COLOR_ICON_PRIMARY_RESOURCE_NAME];
    const failures: string[] = []; const colors: number[] = []; const resourceColors: number[] = [];
    const contexts: Map<string, common.Context> = new Map(SlowmodeNativeFixture.moduleContexts);
    contexts.set('mounted', host);
    contexts.forEach((context: common.Context, label: string): void => {
      console.info('[SlowmodeNative] manager=' + label + ' resourceDir=' + context.resourceDir);
      try {
        console.info('[SlowmodeNative] manager=' + label + ' configurationColorMode=' +
          context.resourceManager.getConfigurationSync().colorMode.toString());
      } catch (error) {
        const failure = error as BusinessError;
        console.info('[SlowmodeNative] manager=' + label + ' configurationErrorCode=' + failure.code.toString() +
          ' message=' + failure.message);
      }
      for (let index = 0; index < names.length; index++) {
        const token = imported[index]; const testToken = local[index]; const name = names[index];
        const prefix = label + '.' + name + ' importedId=0x' + token.id.toString(16) + ' localId=0x' + testToken.id.toString(16) +
          ' importedBundle=' + token.bundleName + ' importedModule=' + token.moduleName +
          ' localBundle=' + testToken.bundleName + ' localModule=' + testToken.moduleName;
        const manager = context.resourceManager;
        const named = SlowmodeNativeFixture.readNativeColor(prefix + '.name', (): number => manager.getColorByNameSync(name));
        const importedId = SlowmodeNativeFixture.readNativeColor(prefix + '.importedId', (): number => manager.getColorSync(token.id));
        const importedResource = SlowmodeNativeFixture.readNativeColor(prefix + '.importedResource', (): number => manager.getColorSync(token));
        const localId = SlowmodeNativeFixture.readNativeColor(prefix + '.localId', (): number => manager.getColorSync(testToken.id));
        const localResource = SlowmodeNativeFixture.readNativeColor(prefix + '.localResource', (): number => manager.getColorSync(testToken));
        if (label === compiledModule) {
          if (named === undefined || named >>> 24 !== 255 || importedId !== named || localId !== named) {
            failures.push(name + ' numeric/name is unresolved, nonopaque or inconsistent in the corresponding compiled module');
          }
          // The deprecated Resource overload is measured separately: native v9
          // resolves a base palette while numeric/name follow current theme.
          if (importedResource === undefined || importedResource >>> 24 !== 255 || localResource !== importedResource) {
            failures.push(name + ' imported/local Resource is unresolved, nonopaque or inconsistent');
          }
          if (named !== undefined) colors.push(named);
          if (importedResource !== undefined) resourceColors.push(importedResource);
        }
      }
    });
    if (!contexts.has(compiledModule)) failures.push('corresponding compiled module context could not be created');
    if (colors.length === 3 && (colors[0] === colors[1] || colors[0] === colors[2] || colors[1] === colors[2])) {
      failures.push('background, text and telegram blue must be distinct');
    }
    if (resourceColors.length === 3 && (resourceColors[0] === resourceColors[1] ||
      resourceColors[0] === resourceColors[2] || resourceColors[1] === resourceColors[2])) {
      failures.push('Resource background, text and telegram blue must be distinct');
    }
    if (failures.length > 0) throw new Error('Native slowmode color witness failed: ' + failures.join('; '));
  }
  private static readNativeColor(label: string, read: () => number): number | undefined {
    try {
      const value = read() >>> 0; console.info('[SlowmodeNative] color=' + label + ' value=#' + value.toString(16)); return value;
    } catch (error) {
      const failure = error as BusinessError;
      console.info('[SlowmodeNative] color=' + label + ' errorCode=' + failure.code.toString() + ' message=' + failure.message);
      return undefined;
    }
  }
  static async reset(expires: string = '0', unknown: boolean = false): Promise<void> {
    SlowmodeNativeFixture.dispose();
    SlowmodeNativeFixture.inputSealed = false;
    const state = SlowmodeNativeFixture.state; state.view = new ChatScreenViewState(); state.mutations = 0; state.generations++;
    const uiContext = (): UIContext => SlowmodeNativeFixture.uiContext();
    const page = new SlowmodeNativeSession(state.view, uiContext, () => undefined);
    const f = new SlowmodeFixture('member', 'supergroup', state.view, uiContext, page);
    const gateway = new SlowmodeNativeGateway(state); gateway.unknown = unknown; f.gateway = gateway;
    f.page.sendUseCase = new SendMessageUseCase(gateway); f.page.sendMediaUseCase = new SendMediaMessageUseCase(gateway);
    f.page.pendingAttachmentKind = 'document'; f.page.pendingAttachmentTitle = 'fixture.txt';
    f.page.pendingAttachmentPreview = 'Selected document'; f.page.pendingAttachmentUris = ['fixture:slowmode-document'];
    f.page.replyToAuthor = 'Fixture reply'; f.page.replyToPreview = 'Preserved reply';
    f.page.timelineContainerWidth = 400;
    SlowmodeNativeFixture.active = f; state.page = page;
    SlowmodeNativeFixture.unsubscribe = f.store.subscribe((): void => { SlowmodeNativeFixture.refresh(); });
    await f.updateFullInfo(expires); SlowmodeNativeFixture.refresh();
  }
  static refresh(): void {
    const f = SlowmodeNativeFixture.active; if (f === undefined) return;
    const state = f.store.getState(); const chat = state.chats.chats.get(42);
    if (chat !== undefined) f.page.deriveChatBottomBar(chat, state);
  }
  static requestNativeCaret(): number {
    if (SlowmodeNativeFixture.inputSealed) throw new Error('Native input setup is sealed after cooldown starts');
    const page = SlowmodeNativeFixture.state.page;
    if (page === undefined) throw new Error('Native Session missing during caret setup');
    const before = page.nativeSelectionEvents; page.setDraftSelection(2, 2); return before;
  }
  static selectionEvents(): number { return SlowmodeNativeFixture.state.page?.nativeSelectionEvents ?? 0; }
  static async cooldown(expires: string): Promise<void> {
    SlowmodeNativeFixture.inputSealed = true; await SlowmodeNativeFixture.fixture().updateFullInfo(expires);
  }
  static async expire(): Promise<void> { await SlowmodeNativeFixture.cooldown('0'); }
  static applicationChanged(foreground: boolean): void {
    const owner = SlowmodeNativeFixture.active?.page.slowmodeController;
    if (foreground) owner?.resume(); else owner?.pause();
  }
  static acceptNextWrites(): void {
    const gateway = SlowmodeNativeFixture.fixture().gateway;
    if (!(gateway instanceof SlowmodeNativeGateway)) throw new Error('Slowmode fixture gateway owner changed');
    gateway.unknown = false;
  }
  static dispose(): void {
    SlowmodeNativeFixture.unsubscribe?.(); SlowmodeNativeFixture.unsubscribe = undefined;
    SlowmodeNativeFixture.active?.page.slowmodeController.dispose(); SlowmodeNativeFixture.active = undefined;
    SlowmodeNativeFixture.state.page = undefined;
  }
  static screenshotPath(name: string): string {
    const context = SlowmodeNativeFixture.uiContext().getHostContext();
    if (context === undefined || context.filesDir.length === 0) throw new Error('Slowmode fixture filesDir missing');
    const run = abilityDelegatorRegistry.getArguments().parameters['-s nativeRunLabel'];
    if (run !== undefined && !/^[a-z0-9-]+$/.test(run)) throw new Error('Invalid native screenshot run label');
    return context.filesDir + '/' + (run === undefined ? '' : run + '-') + 'tg-slowmode-' + name + '.png';
  }
}
@ComponentV2
export struct SlowmodeFixtureView {
  @Local private state: SlowmodeNativeState = SlowmodeNativeFixture.state;
  @Local private application: NavigationUIState = navigationUIState;
  // The fixture observes the same UI signal as production ChatPage. Real
  // TestAbility callbacks publish it; this does not simulate an account page.
  @Monitor('application.applicationForeground')
  private applicationChanged(): void { SlowmodeNativeFixture.applicationChanged(this.application.applicationForeground); }
  aboutToAppear(): void { SlowmodeNativeFixture.bind(this.getUIContext()); }
  build() {
    Column({ space: 4 }) {
      Text('Mounted synthetic slowmode composer').id('slowmode-fixture-ready')
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
      if (this.state.page !== undefined) {
        TgChatComposerDock({
          chrome: this.state.view.chrome, composer: this.state.view.composer, media: this.state.view.media,
          panels: this.state.view.panels, pinnedSearch: this.state.view.pinnedSearch, timeline: this.state.view.timeline,
          bindings: this.state.page
        })
        .height(250)
        .width('100%')
        .id('slowmode-fixture-dock')
      }
      Text('slowmode mutations:' + this.state.mutations.toString()).id('slowmode-fixture-mutations')
        .fontColor(TgUiTokens.COLOR_TEXT_TITLE)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    // The isolated TestAbility supplies the real production background token;
    // actual Dock/atom materials, icons and foreground resources stay intact.
    .backgroundColor(TgUiTokens.COLOR_BG_PRIMARY)
    .padding(16)
  }
}
