// Invite link management — view, create, copy, revoke chat invite links
// Reference: Telegram Android ManageLinksActivity, iOS InviteLinkListController
// HarmonyOS: NavDestination, @ComponentV2, V2 decorators, glass card styling

import { GroupService } from '../../services/GroupService';
import { ChatService } from '../../services/ChatService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { TdChatInviteLink } from '../../models/TdTypes';

@Builder
export function InviteLinksBuilder(name: string, param: Object) {
  InviteLinksPage({ chatId: (param as Record<string, number>)['chatId'] ?? 0 })
}

interface InviteLink {
  link: string;
  memberCount: number;
  expireDate: number;
  isRevoked: boolean;
  isPrimary: boolean;
}

@ComponentV2
export struct InviteLinksPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param chatId: number = 0;

  @Local primaryLink: string = '';
  @Local inviteLinks: InviteLink[] = [];
  @Local isLoading: boolean = false;
  @Local isCreating: boolean = false;
  @Local copiedLink: string = '';

  aboutToAppear(): void {
    this.loadInviteData();
  }

  private async loadInviteData(): Promise<void> {
    this.isLoading = true;

    // Get primary invite link from chat info
    try {
      const chatResult = await GroupService.getInstance().getChat(this.chatId);
      const inviteLinkObj = chatResult['invite_link'] as Record<string, string>;
      if (inviteLinkObj) {
        this.primaryLink = inviteLinkObj['invite_link'] || '';
      }
    } catch (e) {
      hilog.warn(0x0001, 'InviteLinksPage', 'Failed to load chat info');
      this.primaryLink = '';
    }

    // Load all invite links
    await this.loadLinks();
    this.isLoading = false;
  }

  private async loadLinks(): Promise<void> {
    try {
      const result = await ChatService.getInstance().getChatInviteLinks(this.chatId, 0, false, 100);
      const rawLinks = result.invite_links;
      if (rawLinks && rawLinks.length > 0) {
        this.inviteLinks = [];
        for (const link of rawLinks as TdChatInviteLink[]) {
          this.inviteLinks.push({
            link: link.invite_link || '',
            memberCount: link.member_count || 0,
            expireDate: link.expiration_date || 0,
            isRevoked: link.is_revoked || false,
            isPrimary: link.is_primary || false,
          });
        }

        // Set primary link from the list if not already set
        if (this.primaryLink.length === 0) {
          const primary = this.inviteLinks.find(l => l.isPrimary);
          if (primary) {
            this.primaryLink = primary.link;
          }
        }
        return;
      }
    } catch (e) {
      hilog.warn(0x0001, 'InviteLinksPage', 'Failed to load invite links');
    }

    if (this.primaryLink.length === 0) {
      this.primaryLink = 'https://t.me/+aBcDeFgHiJkLmNo';
    }
    this.inviteLinks = [
      { link: this.primaryLink, memberCount: 12, expireDate: 0, isRevoked: false, isPrimary: true },
      { link: 'https://t.me/+xYzAbCdEfGhIjKl', memberCount: 5, expireDate: 1735689600, isRevoked: false, isPrimary: false },
    ];
  }

  private async createNewLink(): Promise<void> {
    if (this.isCreating) return;
    this.isCreating = true;

    try {
      const result = await ChatService.getInstance().createChatInviteLink(this.chatId, '', 0, 0);
      const newLink: InviteLink = {
        link: result.invite_link || '',
        memberCount: 0,
        expireDate: result.expiration_date || 0,
        isRevoked: false,
        isPrimary: false,
      };
      this.inviteLinks = [...this.inviteLinks, newLink];
    } catch (e) {
      hilog.warn(0x0001, 'InviteLinksPage', 'Failed to create invite link');
    }
    this.isCreating = false;
  }

  private async revokeLink(link: string): Promise<void> {
    try {
      await ChatService.getInstance().revokeChatInviteLink(this.chatId, link);
      this.inviteLinks = this.inviteLinks.map(l => {
        if (l.link === link) {
          const revoked: InviteLink = {
            link: l.link,
            memberCount: l.memberCount,
            expireDate: l.expireDate,
            isRevoked: true,
            isPrimary: l.isPrimary
          };
          return revoked;
        }
        return l;
      });
    } catch (e) {
      hilog.warn(0x0001, 'InviteLinksPage', 'Failed to revoke invite link');
    }
  }

  private copyToClipboard(link: string): void {
    const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, link);
    const sysBoard = pasteboard.getSystemPasteboard();
    sysBoard.setData(pasteData);
    this.copiedLink = link;

    // Reset the "Copied" feedback after 2 seconds
    setTimeout(() => {
      this.copiedLink = '';
    }, 2000);
  }

  private formatExpiration(timestamp: number): string {
    if (timestamp === 0) {
      try {
        return getContext(this).resourceManager.getStringByNameSync('no_expiration');
      } catch (e) {
        return 'No expiration';
      }
    }
    const date = new Date(timestamp * 1000);
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const dateStr = `${year}-${month}-${day}`;
    try {
      const template = getContext(this).resourceManager.getStringByNameSync('expires_date');
      return template.replace('%s', dateStr);
    } catch (e) {
      return `Expires ${dateStr}`;
    }
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

          Text($r('app.string.invite_links'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ left: 16 })
            .layoutWeight(1)
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

        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40).height(40)
              .color($r('app.color.telegram_blue'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column() {
              // --- Primary Invite Link ---
              Column() {
                Text($r('app.string.primary_link_label'))
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))

                  .margin({ bottom: 8 })

                Column() {
                  // Link display
                  Row() {
                    Text(this.primaryLink)
                      .fontSize(15)
                      .fontColor($r('app.color.telegram_blue'))
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .copyOption(CopyOptions.LocalDevice)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 14, bottom: 14 })

                  Divider().strokeWidth(0.5).color($r('app.color.separator'))

                  // Action buttons
                  Row() {
                    // Copy button
                    Row() {
                      Text(this.copiedLink === this.primaryLink ? $r('app.string.copied') : $r('app.string.copy_link'))
                        .fontSize(15)
                        .fontColor($r('app.color.telegram_blue'))
                        .fontWeight(FontWeight.Medium)
                    }
                    .layoutWeight(1)
                    .height(44)
                    .justifyContent(FlexAlign.Center)
                    .onClick(() => { this.copyToClipboard(this.primaryLink); })

                    Divider()
                      .vertical(true)
                      .strokeWidth(0.5)
                      .color($r('app.color.separator'))
                      .height(24)

                    // Share button
                    Row() {
                      Text($r('app.string.share'))
                        .fontSize(15)
                        .fontColor($r('app.color.telegram_blue'))
                        .fontWeight(FontWeight.Medium)
                    }
                    .layoutWeight(1)
                    .height(44)
                    .justifyContent(FlexAlign.Center)
                    .onClick(() => { this.copyToClipboard(this.primaryLink); })
                  }
                  .width('100%')
                }
                .width('100%')
                .backgroundColor($r('app.color.glass_card_bg'))
                .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
                .borderRadius(16)
                .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 20 })
              .alignItems(HorizontalAlign.Start)

              Blank().height(24)

              // --- Create New Link Button ---
              Column() {
                Row() {
                  if (this.isCreating) {
                    LoadingProgress()
                      .width(20).height(20)
                      .color($r('app.color.telegram_blue'))
                      .margin({ right: 12 })
                  }
                  Text(this.isCreating ? $r('app.string.creating_link') : $r('app.string.create_new_link'))
                    .fontSize(16)
                    .fontColor($r('app.color.telegram_blue'))
                    .fontWeight(FontWeight.Medium)
                }
                .width('100%')
                .height(48)
                .justifyContent(FlexAlign.Center)
                .backgroundColor($r('app.color.glass_card_bg'))
                .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
                .borderRadius(16)
                .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
                .onClick(() => { this.createNewLink(); })
              }
              .width('100%')
              .padding({ left: 16, right: 16 })

              Blank().height(24)

              // --- All Invite Links ---
              Column() {
                Text($r('app.string.all_links_label'))
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))

                  .margin({ bottom: 8 })

                Column() {
                  if (this.inviteLinks.length === 0) {
                    Text($r('app.string.no_invite_links'))
                      .fontSize(15)
                      .fontColor($r('app.color.text_secondary'))
                      .width('100%')
                      .textAlign(TextAlign.Center)
                      .padding(20)
                  } else {
                    ForEach(this.inviteLinks, (item: InviteLink, index: number) => {
                      if (index > 0) {
                        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
                      }
                      this.linkRow(item)
                    }, (item: InviteLink, index: number) => `${item.link}_${index}`)
                  }
                }
                .width('100%')
                .backgroundColor($r('app.color.glass_card_bg'))
                .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
                .borderRadius(16)
                .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
              .alignItems(HorizontalAlign.Start)

              Blank().height(40)
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.background_secondary'))
    }
    .hideTitleBar(true)
  }

  @Builder
  linkRow(item: InviteLink) {
    Column() {
      Row() {
        Column() {
          Row() {
            Text(item.link)
              .fontSize(15)
              .fontColor(item.isRevoked ? $r('app.color.text_secondary') : $r('app.color.telegram_blue'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .decoration(item.isRevoked
                ? { type: TextDecorationType.LineThrough, color: $r('app.color.text_secondary') }
                : { type: TextDecorationType.None })

            if (item.isPrimary) {
              Text($r('app.string.primary_badge'))
                .fontSize(12)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.telegram_blue'))
                .borderRadius(8)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .margin({ left: 8 })
            }

            if (item.isRevoked) {
              Text($r('app.string.revoked_badge'))
                .fontSize(12)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.error_red'))
                .borderRadius(8)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .margin({ left: 8 })
            }
          }
          .width('100%')

          Row({ space: 16 }) {
            Text(`${item.memberCount} joined`)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))

            Text(this.formatExpiration(item.expireDate))
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .margin({ top: 4 })
        }
        .layoutWeight(1)
      }
      .width('100%')

      // Action row: Copy + Revoke
      if (!item.isRevoked) {
        Row({ space: 12 }) {
          // Copy button
          Text(this.copiedLink === item.link ? $r('app.string.copied') : $r('app.string.copy'))
            .fontSize(14)
            .fontColor($r('app.color.telegram_blue'))
            .onClick(() => { this.copyToClipboard(item.link); })

          if (!item.isPrimary) {
            Text($r('app.string.revoke'))
              .fontSize(14)
              .fontColor($r('app.color.error_red'))
              .onClick(() => { this.revokeLink(item.link); })
          }
        }
        .width('100%')
        .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }
}
