// Proxy settings page
// Reference: Telegram iOS ProxyListController, Android ProxyListActivity

import { TDLibClient } from '../../services/TDLibClient';

interface ProxyInfo {
  id: number;
  server: string;
  port: number;
  type: string;
  isEnabled: boolean;
  lastPingMs: number;
  username: string;
}

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

  // Add/Edit form fields
  @Local formServer: string = '';
  @Local formPort: string = '';
  @Local formType: string = 'socks5';
  @Local formUsername: string = '';
  @Local formPassword: string = '';
  @Local formSecret: string = '';

  private tdlib: TDLibClient = TDLibClient.getInstance();

  aboutToAppear(): void {
    this.loadProxies();
  }

  private async loadProxies(): Promise<void> {
    this.isLoading = true;
    try {
      const result = await this.tdlib.send('getProxies') as Record<string, Object>;
      const rawProxies = result['proxies'] as Record<string, Object>[];
      if (rawProxies) {
        const parsed: ProxyInfo[] = [];
        for (const raw of rawProxies) {
          const proxyType = raw['type'] as Record<string, Object>;
          const typeStr = this.parseProxyType(proxyType);
          const proxy: ProxyInfo = {
            id: raw['id'] as number,
            server: raw['server'] as string,
            port: raw['port'] as number,
            type: typeStr,
            isEnabled: raw['is_enabled'] as boolean,
            lastPingMs: -1,
            username: this.parseUsername(proxyType)
          };
          parsed.push(proxy);
          if (proxy.isEnabled) {
            this.useProxy = true;
          }
        }
        this.proxies = parsed;
        // Ping all proxies to get latency
        for (let i = 0; i < this.proxies.length; i++) {
          this.pingProxy(i);
        }
      }
    } catch (e) {
      // Failed to load proxies
    }
    this.isLoading = false;
  }

  private parseProxyType(proxyType: Record<string, Object>): string {
    const typeName = proxyType['@type'] as string;
    if (typeName === 'proxyTypeSocks5') {
      return 'socks5';
    } else if (typeName === 'proxyTypeHttp') {
      return 'http';
    } else if (typeName === 'proxyTypeMtproto') {
      return 'mtproto';
    }
    return 'socks5';
  }

  private parseUsername(proxyType: Record<string, Object>): string {
    const username = proxyType['username'] as string;
    return username ? username : '';
  }

  private async pingProxy(index: number): Promise<void> {
    try {
      const proxy = this.proxies[index];
      const pingParams: Record<string, Object> = {};
      pingParams['proxy_id'] = proxy.id;
      const result: Record<string, Object> = await this.tdlib.send('pingProxy', pingParams);
      const seconds = result['seconds'] as number;
      const updated = this.proxies.slice();
      updated[index] = {
        id: proxy.id,
        server: proxy.server,
        port: proxy.port,
        type: proxy.type,
        isEnabled: proxy.isEnabled,
        lastPingMs: Math.round(seconds * 1000),
        username: proxy.username
      };
      this.proxies = updated;
    } catch (e) {
      const proxy = this.proxies[index];
      const updated = this.proxies.slice();
      updated[index] = {
        id: proxy.id,
        server: proxy.server,
        port: proxy.port,
        type: proxy.type,
        isEnabled: proxy.isEnabled,
        lastPingMs: -2,
        username: proxy.username
      };
      this.proxies = updated;
    }
  }

  private async toggleUseProxy(enable: boolean): Promise<void> {
    this.useProxy = enable;
    if (!enable) {
      await this.tdlib.send('disableProxy');
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
    } else {
      // Enable the first available proxy
      if (this.proxies.length > 0) {
        await this.enableProxy(0);
      }
    }
  }

  private async enableProxy(index: number): Promise<void> {
    const proxy = this.proxies[index];
    const enableParams: Record<string, Object> = {};
    enableParams['proxy_id'] = proxy.id;
    await this.tdlib.send('enableProxy', enableParams);
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
    const removeParams: Record<string, Object> = {};
    removeParams['proxy_id'] = proxy.id;
    await this.tdlib.send('removeProxy', removeParams);
    const updated = this.proxies.slice();
    updated.splice(index, 1);
    this.proxies = updated;
    // If no proxies remain, disable proxy usage
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

  private buildProxyTypeParam(): Record<string, Object> {
    if (this.formType === 'socks5') {
      const socks5Type: Record<string, Object> = {};
      socks5Type['@type'] = 'proxyTypeSocks5';
      socks5Type['username'] = this.formUsername;
      socks5Type['password'] = this.formPassword;
      return socks5Type;
    } else if (this.formType === 'http') {
      const httpType: Record<string, Object> = {};
      httpType['@type'] = 'proxyTypeHttp';
      httpType['username'] = this.formUsername;
      httpType['password'] = this.formPassword;
      httpType['http_only'] = false;
      return httpType;
    } else {
      const mtprotoType: Record<string, Object> = {};
      mtprotoType['@type'] = 'proxyTypeMtproto';
      mtprotoType['secret'] = this.formSecret;
      return mtprotoType;
    }
  }

  private async saveProxy(): Promise<void> {
    const portNum = parseInt(this.formPort);
    if (!this.formServer || isNaN(portNum) || portNum <= 0 || portNum > 65535) {
      return;
    }

    if (this.editingProxy) {
      // Remove old proxy then add updated one
      const removeEditParams: Record<string, Object> = {};
      removeEditParams['proxy_id'] = this.editingProxy.id;
      await this.tdlib.send('removeProxy', removeEditParams);
    }

    const addProxyParams: Record<string, Object> = {};
    addProxyParams['server'] = this.formServer;
    addProxyParams['port'] = portNum;
    addProxyParams['enable'] = true;
    addProxyParams['type'] = this.buildProxyTypeParam();
    await this.tdlib.send('addProxy', addProxyParams);

    this.showAddDialog = false;
    this.editingProxy = null;
    await this.loadProxies();
  }

  private getStatusColor(proxy: ProxyInfo): ResourceColor {
    if (proxy.isEnabled && proxy.lastPingMs >= 0) {
      return $r('app.color.settings_icon_green');
    } else if (proxy.lastPingMs === -1) {
      return $r('app.color.settings_icon_orange');
    } else if (proxy.lastPingMs === -2) {
      return $r('app.color.settings_icon_red');
    } else if (proxy.lastPingMs >= 0) {
      return $r('app.color.settings_icon_green');
    }
    return $r('app.color.text_secondary');
  }

  private getTypeLabel(type: string): Resource {
    if (type === 'socks5') {
      return $r('app.string.proxy_socks5');
    } else if (type === 'http') {
      return $r('app.string.proxy_http');
    }
    return $r('app.string.proxy_mtproto');
  }

  build() {
    NavDestination() {
      Column() {
        // Top bar
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .accessibilityText($r('app.string.accessibility_back'))
            .onClick(() => this.navPathStack.pop())

          Text($r('app.string.proxy_settings'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })

        Scroll() {
          Column() {
            // --- Use Proxy toggle ---
            Column() {
              Row() {
                Text($r('app.string.use_proxy'))
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: this.useProxy })
                  .selectedColor($r('app.color.telegram_blue'))
                  .accessibilityText($r('app.string.accessibility_toggle_proxy'))
                  .onChange((isOn: boolean) => {
                    this.toggleUseProxy(isOn);
                  })
              }
              .width('100%').height(48)
              .padding({ left: 16, right: 16 })
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16, top: 16 })

            Blank().height(24)

            // --- Proxy list section ---
            this.sectionHeader($r('app.string.proxy_settings'))

            if (this.proxies.length === 0 && !this.isLoading) {
              // Empty state
              Column() {
                Text($r('app.string.no_proxies'))
                  .fontSize(15)
                  .fontColor($r('app.color.text_secondary'))
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .padding({ top: 24, bottom: 24 })
              }
              .width('100%')
              .backgroundColor($r('app.color.glass_card_bg'))
              .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
              .borderRadius(16)
              .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
              .margin({ left: 16, right: 16 })
            } else {
              // Proxy list
              Column() {
                ForEach(this.proxies, (proxy: ProxyInfo, index: number) => {
                  if (index > 0) {
                    Divider()
                      .strokeWidth(0.5)
                      .color($r('app.color.separator'))
                      .margin({ left: 16 })
                  }

                  Row() {

                    // Status indicator dot
                    Circle()
                      .width(10).height(10)
                      .fill(this.getStatusColor(proxy))
                      .margin({ right: 12 })

                    // Proxy info
                    Column() {
                      Text(`${proxy.server}:${proxy.port}`)
                        .fontSize(16)
                        .fontColor($r('app.color.text_primary'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })

                      Row() {
                        Text(this.getTypeLabel(proxy.type))
                          .fontSize(13)
                          .fontColor($r('app.color.text_secondary'))

                        if (proxy.isEnabled) {
                          Text(' \u2022 ')
                            .fontSize(13)
                            .fontColor($r('app.color.text_secondary'))
                          Text($r('app.string.proxy_connected'))
                            .fontSize(13)
                            .fontColor($r('app.color.settings_icon_green'))
                        }

                        if (proxy.lastPingMs >= 0) {
                          Text(' \u2022 ')
                            .fontSize(13)
                            .fontColor($r('app.color.text_secondary'))
                          Text(`${proxy.lastPingMs}`)
                            .fontSize(13)
                            .fontColor($r('app.color.text_secondary'))
                          Text($r('app.string.proxy_ping_ms'))
                            .fontSize(13)
                            .fontColor($r('app.color.text_secondary'))
                        } else if (proxy.lastPingMs === -1) {
                          Text(' \u2022 ')
                            .fontSize(13)
                            .fontColor($r('app.color.text_secondary'))
                          Text($r('app.string.proxy_checking'))
                            .fontSize(13)
                            .fontColor($r('app.color.settings_icon_orange'))
                        } else if (proxy.lastPingMs === -2) {
                          Text(' \u2022 ')
                            .fontSize(13)
                            .fontColor($r('app.color.text_secondary'))
                          Text($r('app.string.proxy_unavailable'))
                            .fontSize(13)
                            .fontColor($r('app.color.settings_icon_red'))
                        }
                      }
                      .margin({ top: 2 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    // Radio selection indicator
                    Radio({ value: proxy.id.toString(), group: 'proxyGroup' })
                      .checked(proxy.isEnabled)
                      .onChange((isChecked: boolean) => {
                        if (isChecked) {
                          this.enableProxy(index);
                        }
                      })
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                  .gesture(
                    LongPressGesture()
                      .onAction(() => {
                        this.showProxyActions(proxy, index);
                      })
                  )
                  .onClick(() => {
                    this.enableProxy(index);
                  })
                  .accessibilityText(`${proxy.server}:${proxy.port}`)
                }, (proxy: ProxyInfo) => proxy.id.toString())
              }
              .width('100%')
              .backgroundColor($r('app.color.glass_card_bg'))
              .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
              .borderRadius(16)
              .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
              .margin({ left: 16, right: 16 })
            }

            Blank().height(24)

            // --- Add Proxy button ---
            Column() {
              Row() {
                Text('+')
                  .fontSize(20)
                  .fontColor($r('app.color.telegram_blue'))
                  .margin({ right: 8 })

                Text($r('app.string.add_proxy'))
                  .fontSize(16)
                  .fontColor($r('app.color.telegram_blue'))
              }
              .width('100%').height(48)
              .justifyContent(FlexAlign.Center)
            }
            .width('100%')
            .backgroundColor($r('app.color.glass_card_bg'))
            .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
            .borderRadius(16)
            .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
            .margin({ left: 16, right: 16 })
            .accessibilityText($r('app.string.accessibility_add_proxy'))
            .onClick(() => {
              this.openAddDialog();
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

      // Add/Edit proxy dialog overlay
      if (this.showAddDialog) {
        this.addProxyDialog()
      }
    }
    .hideTitleBar(true)
  }

  @Builder
  sectionHeader(title: Resource) {
    Text(title)
      .fontSize(13)
      .fontColor($r('app.color.text_secondary'))
      .margin({ left: 32, bottom: 6, top: 2 })
  }

  @Builder
  addProxyDialog() {
    Column() {
      // Semi-transparent backdrop
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

    // Dialog card
    Column() {
      // Dialog title
      Text(this.editingProxy ? $r('app.string.edit_proxy') : $r('app.string.add_proxy'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 20 })

      // Server address
      Text($r('app.string.proxy_server'))
        .fontSize(13)
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

      // Port
      Text($r('app.string.proxy_port'))
        .fontSize(13)
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

      // Proxy type selector
      Text($r('app.string.proxy_type'))
        .fontSize(13)
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

      // Credentials fields (SOCKS5 / HTTP only)
      if (this.formType === 'socks5' || this.formType === 'http') {
        Text($r('app.string.proxy_username'))
          .fontSize(13)
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
          .fontSize(13)
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

      // Secret field (MTProto only)
      if (this.formType === 'mtproto') {
        Text($r('app.string.proxy_secret'))
          .fontSize(13)
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

      // Action buttons
      Row() {
        // Cancel
        Text($r('app.string.delete_proxy'))
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.showAddDialog = false;
          })
          .visibility(this.editingProxy ? Visibility.Visible : Visibility.Hidden)
          .layoutWeight(1)

        Blank()

        // Save
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
