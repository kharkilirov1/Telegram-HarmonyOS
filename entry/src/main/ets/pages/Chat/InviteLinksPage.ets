// Invite link management — view, create, copy, revoke chat invite links
// Reference: Telegram Android ManageLinksActivity, iOS InviteLinkListController
// HarmonyOS: NavDestination, @ComponentV2, V2 decorators, glass card styling

import { GroupService } from '../../services/GroupService';
import { ChatService } from '../../services/ChatService';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { TdChatInviteLink } from '../../models/TdTypes';
import { CreateInviteLinkCard } from './components/CreateInviteLinkCard';
import { InviteLinkModel } from './components/InviteLinkModel';
import { InviteLinkRow } from './components/InviteLinkRow';
import { InviteLinksTopBar } from './components/InviteLinksTopBar';
import { PrimaryInviteLinkCard } from './components/PrimaryInviteLinkCard';

@Builder
export function InviteLinksBuilder(name: string, param: Object) {
  InviteLinksPage({ chatId: (param as Record<string, number>)['chatId'] ?? 0 })
}

@ComponentV2
export struct InviteLinksPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param chatId: number = 0;

  @Local primaryLink: string = '';
  @Local inviteLinks: InviteLinkModel[] = [];
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
    this.inviteLinks = [];
    try {
      const result = await ChatService.getInstance().getChatInviteLinks(this.chatId, 0, false, 100);
      const rawLinks = result.invite_links;
      if (rawLinks && rawLinks.length > 0) {
        for (const link of rawLinks as TdChatInviteLink[]) {
          this.inviteLinks.push(new InviteLinkModel(
            link.invite_link || '',
            link.member_count || 0,
            link.expiration_date || 0,
            link.is_revoked || false,
            link.is_primary || false
          ));
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
  }

  private async createNewLink(): Promise<void> {
    if (this.isCreating) return;
    this.isCreating = true;

    try {
      const result = await ChatService.getInstance().createChatInviteLink(this.chatId, '', 0, 0);
      const newLink: InviteLinkModel = new InviteLinkModel(
        result.invite_link || '',
        0,
        result.expiration_date || 0,
        false,
        false
      );
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
          const revoked: InviteLinkModel = new InviteLinkModel(
            l.link,
            l.memberCount,
            l.expireDate,
            true,
            l.isPrimary
          );
          return revoked;
        }
        return l;
      });
    } catch (e) {
      hilog.warn(0x0001, 'InviteLinksPage', 'Failed to revoke invite link');
    }
  }

  private copyToClipboard(link: string): void {
    if (link.length === 0) {
      return;
    }
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
        InviteLinksTopBar({
          onBack: () => {
            this.navPathStack.pop();
          }
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
              if (this.primaryLink.length > 0) {
                PrimaryInviteLinkCard({
                  primaryLink: this.primaryLink,
                  copiedLink: this.copiedLink,
                  onCopy: () => {
                    this.copyToClipboard(this.primaryLink);
                  },
                  onShare: () => {
                    this.copyToClipboard(this.primaryLink);
                  }
                })

                Blank().height(24)
              } else {
                Blank().height(20)
              }

              CreateInviteLinkCard({
                isCreating: this.isCreating,
                onCreate: () => {
                  this.createNewLink();
                }
              })

              Blank().height(24)

              // --- All Invite Links ---
              Column() {
                Text($r('app.string.all_links_label'))
                  .fontSize(14)
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
                    ForEach(this.inviteLinks, (item: InviteLinkModel, index: number) => {
                      if (index > 0) {
                        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })
                      }
                      InviteLinkRow({
                        item: item,
                        copiedLink: this.copiedLink,
                        expirationText: this.formatExpiration(item.expireDate),
                        onCopy: (link: string) => {
                          this.copyToClipboard(link);
                        },
                        onRevoke: (link: string) => {
                          this.revokeLink(link);
                        }
                      })
                    }, (item: InviteLinkModel, index: number) => `${item.link}_${index}`)
                  }
                }
                .width('100%')
                .backgroundColor($r('app.color.glass_card_bg'))
                .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
                .borderRadius(24)
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

}
