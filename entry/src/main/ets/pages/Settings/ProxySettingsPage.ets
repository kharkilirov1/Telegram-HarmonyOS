// Proxy settings page
// Reference: Telegram iOS ProxyListController, Android ProxyListActivity

import { ProxyService, ProxyInfo } from '../../services/ProxyService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ProxyAddButtonCard } from './components/ProxyAddButtonCard';
import { ProxyListSection } from './components/ProxyListSection';
import { ProxyTopBar } from './components/ProxyTopBar';
import { ProxyUseToggleCard } from './components/ProxyUseToggleCard';

const TAG = 'ProxySettingsPage';
const DOMAIN = 0x0001;

@Builder
export function ProxySettingsBuilder(name: string, param: Object) {
  ProxySettingsPage()
}

@ComponentV2
export struct ProxySettingsPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  @Local useProxy: boolean = false;
  @Local proxies: ProxyInfo[] = [];
  @Local isLoading: boolean = false;
  @Local showAddDialog: boolean = false;
  @Local editingProxy: ProxyInfo | null = null;

  @Local formServer: string = '';
  @Local formPort: string = '';
  @Local formType: string = 'socks5';
  @Local formUsername: string = '';
  @Local formPassword: string = '';
  @Local formSecret: string = '';

  private proxyService: ProxyService = ProxyService.getInstance();

  aboutToAppear(): void {
    this.loadProxies();
  }

  private async loadProxies(): Promise<void> {
    this.isLoading = true;
    try {
      const parsed = await this.proxyService.getProxies();
      this.proxies = parsed;
      this.useProxy = false;
      for (const proxy of parsed) {
        if (proxy.isEnabled) {
          this.useProxy = true;
        }
      }

      for (let i = 0; i < this.proxies.length; i++) {
        this.pingProxy(i);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Failed to load proxies: %{public}s', String(e));
    }
    this.isLoading = false;
  }

  private async pingProxy(index: number): Promise<void> {
    const proxy = this.proxies[index];
    const pingMs = await this.proxyService.pingProxy(proxy.id);
    const updated = this.proxies.slice();
    updated[index] = {
      id: proxy.id,
      server: proxy.server,
      port: proxy.port,
      type: proxy.type,
      isEnabled: proxy.isEnabled,
      lastPingMs: pingMs,
      username: proxy.username
    };
    this.proxies = updated;
  }

  private async toggleUseProxy(enable: boolean): Promise<void> {
    this.useProxy = enable;
    if (!enable) {
      await this.proxyService.disableProxy();
      const updated: ProxyInfo[] = [];
      for (const p of this.proxies) {
        updated.push({
          id: p.id,
          server: p.server,
          port: p.port,
          type: p.type,
          isEnabled: false,
          lastPingMs: p.lastPingMs,
          username: p.username
        });
      }
      this.proxies = updated;
      return;
    }

    if (this.proxies.length > 0) {
      await this.enableProxy(0);
    }
  }

  private async enableProxy(index: number): Promise<void> {
    const proxy = this.proxies[index];
    await this.proxyService.enableProxy(proxy.id);
    this.useProxy = true;

    const updated: ProxyInfo[] = [];
    for (let i = 0; i < this.proxies.length; i++) {
      const p = this.proxies[i];
      updated.push({
        id: p.id,
        server: p.server,
        port: p.port,
        type: p.type,
        isEnabled: i === index,
        lastPingMs: p.lastPingMs,
        username: p.username
      });
    }
    this.proxies = updated;
  }

  private async deleteProxy(index: number): Promise<void> {
    const proxy = this.proxies[index];
    await this.proxyService.removeProxy(proxy.id);
    const updated = this.proxies.slice();
    updated.splice(index, 1);
    this.proxies = updated;
    if (this.proxies.length === 0) {
      this.useProxy = false;
    }
  }

  private openAddDialog(): void {
    this.editingProxy = null;
    this.formServer = '';
    this.formPort = '';
    this.formType = 'socks5';
    this.formUsername = '';
    this.formPassword = '';
    this.formSecret = '';
    this.showAddDialog = true;
  }

  private openEditDialog(proxy: ProxyInfo): void {
    this.editingProxy = proxy;
    this.formServer = proxy.server;
    this.formPort = proxy.port.toString();
    this.formType = proxy.type;
    this.formUsername = proxy.username;
    this.formPassword = '';
    this.formSecret = '';
    this.showAddDialog = true;
  }

  private async saveProxy(): Promise<void> {
    const portNum = parseInt(this.formPort);
    if (!this.formServer || isNaN(portNum) || portNum <= 0 || portNum > 65535) {
      return;
    }

    if (this.editingProxy) {
      await this.proxyService.removeProxy(this.editingProxy.id);
    }

    const proxyType = ProxyService.buildProxyTypeParam(
      this.formType,
      this.formUsername,
      this.formPassword,
      this.formSecret
    );

    await this.proxyService.addProxy(this.formServer, portNum, true, proxyType);

    this.showAddDialog = false;
    this.editingProxy = null;
    await this.loadProxies();
  }

  build() {
    NavDestination() {
      Column() {
        ProxyTopBar({
          onBack: () => {
            this.navPathStack.pop();
          }
        })

        Scroll() {
          Column() {
            ProxyUseToggleCard({
              useProxy: this.useProxy,
              onToggle: (isOn: boolean) => {
                this.toggleUseProxy(isOn);
              }
            })

            Blank().height(24)

            ProxyListSection({
              proxies: this.proxies,
              isLoading: this.isLoading,
              onEnableProxy: (index: number) => {
                this.enableProxy(index);
              },
              onShowProxyActions: (proxy: ProxyInfo, index: number) => {
                this.showProxyActions(proxy, index);
              }
            })

            Blank().height(24)

            ProxyAddButtonCard({
              onAdd: () => {
                this.openAddDialog();
              }
            })

            Blank().height(40)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))

      if (this.showAddDialog) {
        this.addProxyDialog()
      }
    }
    .hideTitleBar(true)
  }

  @Builder
  addProxyDialog() {
    Column() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.overlay_dark'))
        .onClick(() => {
          this.showAddDialog = false;
        })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .justifyContent(FlexAlign.Center)

    Column() {
      Text(this.editingProxy ? $r('app.string.edit_proxy') : $r('app.string.add_proxy'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 20 })

      Text($r('app.string.proxy_server'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 4 })
      TextInput({ text: this.formServer, placeholder: '0.0.0.0' })
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.background_secondary'))
        .borderRadius(10)
        .height(44)
        .width('100%')
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.formServer = value;
        })

      Blank().height(12)

      Text($r('app.string.proxy_port'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 4 })
      TextInput({ text: this.formPort, placeholder: '1080' })
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.background_secondary'))
        .borderRadius(10)
        .height(44)
        .width('100%')
        .padding({ left: 12, right: 12 })
        .type(InputType.Number)
        .onChange((value: string) => {
          this.formPort = value;
        })

      Blank().height(12)

      Text($r('app.string.proxy_type'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 4 })
      Row() {
        this.typeButton('socks5', $r('app.string.proxy_socks5'))
        Blank().width(8)
        this.typeButton('http', $r('app.string.proxy_http'))
        Blank().width(8)
        this.typeButton('mtproto', $r('app.string.proxy_mtproto'))
      }
      .width('100%')

      Blank().height(12)

      if (this.formType === 'socks5' || this.formType === 'http') {
        Text($r('app.string.proxy_username'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 4 })
        TextInput({ text: this.formUsername })
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.background_secondary'))
          .borderRadius(10)
          .height(44)
          .width('100%')
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.formUsername = value;
          })

        Blank().height(12)

        Text($r('app.string.proxy_password'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 4 })
        TextInput({ text: this.formPassword })
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.background_secondary'))
          .borderRadius(10)
          .height(44)
          .width('100%')
          .padding({ left: 12, right: 12 })
          .type(InputType.Password)
          .onChange((value: string) => {
            this.formPassword = value;
          })
      }

      if (this.formType === 'mtproto') {
        Text($r('app.string.proxy_secret'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 4 })
        TextInput({ text: this.formSecret })
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.background_secondary'))
          .borderRadius(10)
          .height(44)
          .width('100%')
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.formSecret = value;
          })
      }

      Blank().height(20)

      Row() {
        Text($r('app.string.delete_proxy'))
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.showAddDialog = false;
          })
          .visibility(this.editingProxy ? Visibility.Visible : Visibility.Hidden)
          .layoutWeight(1)

        Blank()

        Button($r('app.string.save'))
          .type(ButtonType.Capsule)
          .fontSize(16)
          .fontColor($r('app.color.icon_on_primary'))
          .backgroundColor($r('app.color.telegram_blue'))
          .height(40)
          .padding({ left: 24, right: 24 })
          .onClick(() => {
            this.saveProxy();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('90%')
    .padding(24)
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(20)
    .shadow({ radius: 16, color: $r('app.color.glass_card_shadow'), offsetY: 4 })
    .position({ x: '5%', y: '15%' })
  }

  @Builder
  typeButton(type: string, label: Resource) {
    Text(label)
      .fontSize(14)
      .fontColor(this.formType === type ? $r('app.color.icon_on_primary') : $r('app.color.telegram_blue'))
      .backgroundColor(this.formType === type ? $r('app.color.telegram_blue') : $r('app.color.background_secondary'))
      .borderRadius(8)
      .height(36)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        this.formType = type;
      })
  }

  private showProxyActions(proxy: ProxyInfo, index: number): void {
    AlertDialog.show({
      title: `${proxy.server}:${proxy.port}`,
      message: '',
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      primaryButton: {
        value: getContext(this).resourceManager.getStringSync($r('app.string.edit_proxy')),
        action: () => {
          this.openEditDialog(proxy);
        }
      },
      secondaryButton: {
        value: getContext(this).resourceManager.getStringSync($r('app.string.delete_proxy')),
        fontColor: $r('app.color.settings_icon_red'),
        action: () => {
          this.deleteProxy(index);
        }
      }
    });
  }
}
