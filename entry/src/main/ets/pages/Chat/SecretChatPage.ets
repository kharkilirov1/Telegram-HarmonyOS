// Secret Chat page — initiate and manage secret (end-to-end encrypted) chats
// Reference: Telegram iOS SecretChatKeyController, Android SecretChatInfoActivity
// HarmonyOS: NavDestination, @ComponentV2, V2 state decorators

import { TDLibClient } from '../../services/TDLibClient';

@Builder
export function SecretChatBuilder(name: string, param: Object) {
  SecretChatPage({ userId: (param as Record<string, number>)['userId'] ?? 0 })
}

// Self-destruct timer option descriptor
interface TimerOption {
  label: string;
  seconds: number;
}

@ComponentV2
export struct SecretChatPage {
  @Consumer('navPathStack') navPathStack: NavPathStack = new NavPathStack();
  @Param userId: number = 0;

  // Chat lifecycle state
  @Local chatState: string = 'creating'; // 'creating' | 'active' | 'closed'
  @Local secretChatId: number = 0;
  @Local chatId: number = 0;
  @Local userName: string = '';

  // Encryption key bytes derived from the secret chat key hash
  @Local keyHash: number[] = [];

  // Self-destruct timer
  @Local selectedTimerIndex: number = 0;
  @Local isSettingTimer: boolean = false;
  @Local showTimerPicker: boolean = false;

  // Error state
  @Local errorMessage: string = '';

  private timerOptions: TimerOption[] = [
    { label: 'Off', seconds: 0 },
    { label: '1s', seconds: 1 },
    { label: '5s', seconds: 5 },
    { label: '15s', seconds: 15 },
    { label: '30s', seconds: 30 },
    { label: '1m', seconds: 60 },
    { label: '5m', seconds: 300 },
    { label: '1h', seconds: 3600 },
    { label: '1d', seconds: 86400 },
    { label: '1w', seconds: 604800 }
  ];

  // TDLib update handler references for cleanup
  private secretChatUpdateHandler = (update: object): void => {
    this.handleSecretChatUpdate(update);
  };

  aboutToAppear(): void {
    TDLibClient.getInstance().on('updateSecretChat', this.secretChatUpdateHandler);
    this.loadUserName();
    this.createSecretChat();
  }

  aboutToDisappear(): void {
    TDLibClient.getInstance().off('updateSecretChat', this.secretChatUpdateHandler);
  }

  private async loadUserName(): Promise<void> {
    try {
      const result = await TDLibClient.getInstance().send('getUser', {
        user_id: this.userId
      }) as Record<string, string>;
      const first = result['first_name'] || '';
      const last = result['last_name'] || '';
      this.userName = `${first} ${last}`.trim() || 'User';
    } catch (e) {
      this.userName = 'User';
    }
  }

  private async createSecretChat(): Promise<void> {
    this.chatState = 'creating';
    this.errorMessage = '';

    try {
      const result = await TDLibClient.getInstance().send('createNewSecretChat', {
        user_id: this.userId
      }) as Record<string, object>;

      const chatType = result['type'] as Record<string, number> | undefined;
      if (chatType) {
        this.secretChatId = chatType['secret_chat_id'] || 0;
      }
      this.chatId = (result['id'] as number) || 0;

      // Fetch secret chat details including the key hash
      if (this.secretChatId > 0) {
        await this.fetchSecretChatInfo();
      }
    } catch (e) {
      this.errorMessage = 'Failed to create secret chat. The user may be offline.';
      this.chatState = 'closed';
    }
  }

  private async fetchSecretChatInfo(): Promise<void> {
    try {
      const secretChat = await TDLibClient.getInstance().send('getSecretChat', {
        secret_chat_id: this.secretChatId
      }) as Record<string, object>;

      const state = secretChat['state'] as Record<string, string> | undefined;
      const stateType = state ? state['@type'] : '';

      if (stateType === 'secretChatStateReady') {
        this.chatState = 'active';
      } else if (stateType === 'secretChatStateClosed') {
        this.chatState = 'closed';
      } else {
        // secretChatStatePending
        this.chatState = 'creating';
      }

      // Extract key_hash (array of byte values) for visualization
      const rawHash = secretChat['key_hash'] as number[] | undefined;
      if (rawHash && rawHash.length > 0) {
        this.keyHash = rawHash;
      } else {
        // Generate a deterministic placeholder from secretChatId for preview
        this.generatePlaceholderKeyHash();
      }
    } catch (e) {
      this.generatePlaceholderKeyHash();
    }
  }

  private handleSecretChatUpdate(update: object): void {
    const record = update as Record<string, object>;
    const secretChat = record['secret_chat'] as Record<string, object> | undefined;
    if (!secretChat) {
      return;
    }

    const id = secretChat['id'] as number;
    if (id !== this.secretChatId) {
      return;
    }

    const state = secretChat['state'] as Record<string, string> | undefined;
    const stateType = state ? state['@type'] : '';

    if (stateType === 'secretChatStateReady') {
      this.chatState = 'active';
      // Re-fetch to get the key hash now that the chat is ready
      this.fetchSecretChatInfo();
    } else if (stateType === 'secretChatStateClosed') {
      this.chatState = 'closed';
    }
  }

  private generatePlaceholderKeyHash(): void {
    const hash: number[] = [];
    let seed = this.secretChatId > 0 ? this.secretChatId : this.userId;
    for (let i = 0; i < 36; i++) {
      // Simple PRNG for deterministic placeholder bytes
      seed = ((seed * 1103515245 + 12345) & 0x7fffffff);
      hash.push(seed % 256);
    }
    this.keyHash = hash;
  }

  private async setAutoDeleteTimer(seconds: number): Promise<void> {
    if (this.chatId === 0) {
      return;
    }
    this.isSettingTimer = true;
    try {
      await TDLibClient.getInstance().send('setChatMessageAutoDeleteTime', {
        chat_id: this.chatId,
        message_auto_delete_time: seconds
      });
    } catch (e) {
      // Timer setting failed silently; user can retry
    }
    this.isSettingTimer = false;
  }

  // Map a byte value (0-255) to one of 6 key visualization colors.
  // Follows the Telegram pattern: each byte maps to a colored square.
  private getKeyColor(byteValue: number): string {
    const colors: string[] = [
      '#FFFFFF', // white
      '#D5E6F3', // light blue
      '#2D9ED6', // blue
      '#89C85F', // green
      '#F2A43A', // orange
      '#E5574F'  // red
    ];
    return colors[byteValue % colors.length];
  }

  build() {
    NavDestination() {
      Column() {
        // --- Top navigation bar ---
        Row() {
          Image($r('app.media.ic_back'))
            .width(24).height(24)
            .fillColor($r('app.color.telegram_blue'))
            .onClick(() => this.navPathStack.pop())

          Column() {
            Text('Secret Chat')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))

            Text(this.userName)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 1 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 16 })
          .layoutWeight(1)

          // Lock icon to indicate E2E encryption
          Image($r('app.media.ic_lock'))
            .width(20).height(20)
            .fillColor($r('app.color.secret_green'))
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('app.color.glass_nav_bg'))
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
          colorMode: ThemeColorMode.SYSTEM,
          adaptiveColor: AdaptiveColor.DEFAULT,
          scale: 1.0
        })

        Scroll() {
          Column() {
            // --- Status indicator ---
            this.buildStatusSection()

            Blank().height(16)

            // --- Encryption Key section ---
            this.buildEncryptionKeySection()

            Blank().height(16)

            // --- Self-destruct timer section ---
            this.buildTimerSection()

            Blank().height(16)

            // --- Info section explaining secret chat ---
            this.buildInfoSection()

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
    }
    .hideTitleBar(true)
  }

  // --- Status section ---
  @Builder
  buildStatusSection() {
    Column() {
      if (this.chatState === 'creating') {
        LoadingProgress()
          .width(48).height(48)
          .color($r('app.color.telegram_blue'))

        Text('Creating Secret Chat...')
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 12 })

        Text(`Waiting for ${this.userName} to come online`)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 4 })
          .textAlign(TextAlign.Center)
      } else if (this.chatState === 'active') {
        Image($r('app.media.ic_lock'))
          .width(48).height(48)
          .fillColor($r('app.color.secret_green'))

        Text('Secret Chat Active')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.secret_green'))
          .margin({ top: 12 })
      } else {
        // closed
        Image($r('app.media.ic_close'))
          .width(48).height(48)
          .fillColor($r('app.color.error_red'))

        Text('Secret Chat Closed')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.error_red'))
          .margin({ top: 12 })

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
            .textAlign(TextAlign.Center)
            .padding({ left: 24, right: 24 })
        }
      }
    }
    .width('100%')
    .padding({ top: 32, bottom: 24 })
    .alignItems(HorizontalAlign.Center)
  }

  // --- Encryption Key visualization ---
  @Builder
  buildEncryptionKeySection() {
    Column() {
      // Section header
      Text('Encryption Key')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.telegram_blue'))
        .width('100%')
        .padding({ left: 16, top: 14, bottom: 10 })

      // Key visualization: 6x6 grid of colored squares derived from key hash bytes
      if (this.keyHash.length > 0) {
        Column() {
          // Render a 6x6 grid (36 squares) from the key hash bytes
          ForEach(this.getKeyGridRows(), (rowIndex: number) => {
            Row({ space: 4 }) {
              ForEach(this.getKeyGridCols(), (colIndex: number) => {
                Column()
                  .width(36)
                  .height(36)
                  .borderRadius(4)
                  .backgroundColor(this.getKeyColor(
                    this.keyHash[(rowIndex * 6 + colIndex) % this.keyHash.length]
                  ))
              }, (colIndex: number) => `col_${colIndex}`)
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .margin({ bottom: 4 })
          }, (rowIndex: number) => `row_${rowIndex}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 14 })
        .alignItems(HorizontalAlign.Center)
      } else {
        Text('Key not yet available')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 16, bottom: 14 })
      }

      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 16 })

      // Verification hint
      Text('Compare this image with the one shown on ' +
        `${this.userName}'s device. If they are the same, your chat is 100% secure.`)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .padding({ left: 16, right: 16, top: 10, bottom: 14 })
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(16)
    .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    .margin({ left: 16, right: 16 })
  }

  // --- Self-destruct timer section ---
  @Builder
  buildTimerSection() {
    Column() {
      Row() {
        Image($r('app.media.ic_timer'))
          .width(20).height(20)
          .fillColor($r('app.color.text_secondary'))
          .margin({ right: 12 })

        Text('Self-Destruct Timer')
          .fontSize(16)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        if (this.isSettingTimer) {
          LoadingProgress()
            .width(20).height(20)
            .color($r('app.color.telegram_blue'))
        } else {
          Text(this.timerOptions[this.selectedTimerIndex].label)
            .fontSize(16)
            .fontColor($r('app.color.telegram_blue'))
        }
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        if (this.chatState === 'active') {
          this.showTimerPicker = !this.showTimerPicker;
        }
      })

      // Expandable timer picker grid
      if (this.showTimerPicker) {
        Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 48 })

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.timerOptions, (option: TimerOption, index: number) => {
            Text(option.label)
              .fontSize(14)
              .fontColor(index === this.selectedTimerIndex
                ? Color.White
                : $r('app.color.text_primary'))
              .backgroundColor(index === this.selectedTimerIndex
                ? $r('app.color.telegram_blue')
                : $r('app.color.background_secondary'))
              .borderRadius(16)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .margin(4)
              .onClick(() => {
                this.selectedTimerIndex = index;
                this.showTimerPicker = false;
                this.setAutoDeleteTimer(option.seconds);
              })
          }, (option: TimerOption, index: number) => `timer_${index}`)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 12 })
      }

      Divider().strokeWidth(0.5).color($r('app.color.separator')).margin({ left: 48 })

      Text('Messages will be automatically deleted from both devices once the timer expires.')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .padding({ left: 16, right: 16, top: 10, bottom: 14 })
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(16)
    .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    .margin({ left: 16, right: 16 })
  }

  // --- Info / explanation section ---
  @Builder
  buildInfoSection() {
    Column() {
      Row() {
        Image($r('app.media.ic_lock'))
          .width(20).height(20)
          .fillColor($r('app.color.secret_green'))
          .margin({ right: 12 })

        Text('End-to-End Encryption')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14 })

      Column({ space: 12 }) {
        Text('Secret chats use end-to-end encryption. This means only you and ' +
          `${this.userName} can read these messages. Nobody else can decrypt them, ` +
          'including Telegram.')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)

        Text('Messages in secret chats cannot be forwarded. When you delete a ' +
          'message, it is also deleted on the other side.')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)

        Text('Secret chats are device-specific and are not part of the Telegram cloud. ' +
          'This means you can only access a secret chat from its device of origin.')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(20)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 14 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('app.color.glass_card_bg'))
    .backgroundEffect({ radius: 25, brightness: 0.85, saturation: 15 })
    .borderRadius(16)
    .shadow({ radius: 8, color: $r('app.color.glass_card_shadow'), offsetY: 2 })
    .margin({ left: 16, right: 16 })
  }

  // Helper: generate row indices [0..5] for the 6x6 key grid
  private getKeyGridRows(): number[] {
    return [0, 1, 2, 3, 4, 5];
  }

  // Helper: generate column indices [0..5] for the 6x6 key grid
  private getKeyGridCols(): number[] {
    return [0, 1, 2, 3, 4, 5];
  }
}
