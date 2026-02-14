import { ProxyInfo } from '../../../services/ProxyService';

@ComponentV2
export struct ProxyListSection {
  @Param proxies: ProxyInfo[] = [];
  @Param isLoading: boolean = false;

  @Event onEnableProxy: (index: number) => void = (_index: number) => {};
  @Event onShowProxyActions: (proxy: ProxyInfo, index: number) => void = (_proxy: ProxyInfo, _index: number) => {};

  build() {
    Column() {
      Text($r('app.string.proxy_settings'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 32, bottom: 6, top: 2 })

      if (this.proxies.length === 0 && !this.isLoading) {
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
        .borderRadius(24)
        .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
        .margin({ left: 12, right: 12 })
      } else {
        Column() {
          ForEach(this.proxies, (proxy: ProxyInfo, index: number) => {
            if (index > 0) {
              Divider()
                .strokeWidth(0.5)
                .color($r('app.color.separator'))
                .margin({ left: 16 })
            }

            Row() {
              Circle()
                .width(10)
                .height(10)
                .fill(this.getStatusColor(proxy))
                .margin({ right: 12 })

              Column() {
                Text(`${proxy.server}:${proxy.port}`)
                  .fontSize(16)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Row() {
                  Text(this.getTypeLabel(proxy.type))
                    .fontSize(14)
                    .fontColor($r('app.color.text_secondary'))

                  if (proxy.isEnabled) {
                    Text(' \u2022 ')
                      .fontSize(14)
                      .fontColor($r('app.color.text_secondary'))
                    Text($r('app.string.proxy_connected'))
                      .fontSize(14)
                      .fontColor($r('app.color.settings_icon_green'))
                  }

                  if (proxy.lastPingMs >= 0) {
                    Text(' \u2022 ')
                      .fontSize(14)
                      .fontColor($r('app.color.text_secondary'))
                    Text(`${proxy.lastPingMs}`)
                      .fontSize(14)
                      .fontColor($r('app.color.text_secondary'))
                    Text($r('app.string.proxy_ping_ms'))
                      .fontSize(14)
                      .fontColor($r('app.color.text_secondary'))
                  } else if (proxy.lastPingMs === -1) {
                    Text(' \u2022 ')
                      .fontSize(14)
                      .fontColor($r('app.color.text_secondary'))
                    Text($r('app.string.proxy_checking'))
                      .fontSize(14)
                      .fontColor($r('app.color.settings_icon_orange'))
                  } else if (proxy.lastPingMs === -2) {
                    Text(' \u2022 ')
                      .fontSize(14)
                      .fontColor($r('app.color.text_secondary'))
                    Text($r('app.string.proxy_unavailable'))
                      .fontSize(14)
                      .fontColor($r('app.color.settings_icon_red'))
                  }
                }
                .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Radio({ value: proxy.id.toString(), group: 'proxyGroup' })
                .checked(proxy.isEnabled)
                .onChange((isChecked: boolean) => {
                  if (isChecked) {
                    this.onEnableProxy(index);
                  }
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .gesture(
              LongPressGesture()
                .onAction(() => {
                  this.onShowProxyActions(proxy, index);
                })
            )
            .onClick(() => {
              this.onEnableProxy(index);
            })
            .hoverEffect(HoverEffect.Highlight)
            .opacity(1.0)
            .stateStyles({
              pressed: {
                .opacity(0.6)
              },
              normal: {
                .opacity(1.0)
              }
            })
            .accessibilityText(`${proxy.server}:${proxy.port}`)
          }, (proxy: ProxyInfo) => proxy.id.toString())
        }
        .width('100%')
        .backgroundColor($r('app.color.glass_card_bg'))
        .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
        .borderRadius(24)
        .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
        .margin({ left: 12, right: 12 })
      }
    }
    .width('100%')
  }

  private getStatusColor(proxy: ProxyInfo): ResourceColor {
    if (proxy.isEnabled && proxy.lastPingMs >= 0) {
      return $r('app.color.settings_icon_green');
    }
    if (proxy.lastPingMs === -1) {
      return $r('app.color.settings_icon_orange');
    }
    if (proxy.lastPingMs === -2) {
      return $r('app.color.settings_icon_red');
    }
    if (proxy.lastPingMs >= 0) {
      return $r('app.color.settings_icon_green');
    }
    return $r('app.color.text_secondary');
  }

  private getTypeLabel(type: string): Resource {
    if (type === 'socks5') {
      return $r('app.string.proxy_socks5');
    }
    if (type === 'http') {
      return $r('app.string.proxy_http');
    }
    return $r('app.string.proxy_mtproto');
  }
}
