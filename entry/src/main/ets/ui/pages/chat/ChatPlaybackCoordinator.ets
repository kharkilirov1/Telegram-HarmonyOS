// Extracted chat-page behavior. The per-page session supplies this narrow port.

import { AppStore } from '../../../core/store/AppStore';
import { ChatTimelineDataSource } from './ChatTimelineDataSource';
import { MediaPlaybackSnapshot, MediaContentType } from './VoicePlaybackController';
import { globalMediaPlayback, MediaPlaybackPageHandle } from './GlobalMediaPlayback';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { localized } from '../../../core/utils/AppResource';

export interface ChatPlaybackCoordinatorPort {
  accountStore?: AppStore;
  activeAudioMessageId: string;
  activeAudioPlaying: boolean;
  activeAudioProgress: number;
  activeChatId: number;
  activeVoiceMessageId: string;
  activeVoicePlaying: boolean;
  activeVoiceProgress: number;
  dataSource: ChatTimelineDataSource;
  isClosing: boolean;
  locallyListenedVoiceIds: Set<string>;
  mediaPlaybackHandle?: MediaPlaybackPageHandle;
  mediaPlaybackIsCurrent?: () => boolean;
  mediaPlaybackUnsubscribe?: () => void;
  pageLifecycleToken: number;
  routeActivated: boolean;
  routeContext?: ChatScreenRouteParams;
  getCurrentMediaPlaybackHandle(): MediaPlaybackPageHandle | undefined;
  handlePlaybackCompleted(messageId: string, contentType: MediaContentType): void;
  isRouteContextCurrent(route: ChatScreenRouteParams): boolean;
  notifyPlaybackRows(prevVoiceId: string, prevAudioId: string, currentId: string): void;
  ownsNavigationContext(): boolean;
  publishNowPlayingMeta(messageId: string, contentType: MediaContentType): void;
  resetPlaybackState(preserveListened?: boolean): void;
  resolveOwnedChatTitle(): string;
  teardownMediaPlaybackController(preserveListened?: boolean): void;
}

export function resetPlaybackState(host: ChatPlaybackCoordinatorPort, preserveListened: boolean = false): void {
    host.activeVoiceMessageId = '0';
    host.activeVoiceProgress = 0;
    host.activeVoicePlaying = false;
    host.activeAudioMessageId = '0';
    host.activeAudioProgress = 0;
    host.activeAudioPlaying = false;
    if (!preserveListened) host.locallyListenedVoiceIds.clear();
  }

export function setupMediaPlaybackController(host: ChatPlaybackCoordinatorPort): void {
    const previousVoiceId: string = host.activeVoiceMessageId;
    const previousAudioId: string = host.activeAudioMessageId;
    host.teardownMediaPlaybackController(true);
    const route = host.routeContext;
    const owner = host.accountStore;
    const lifecycleToken: number = host.pageLifecycleToken;
    const chatId: number = host.activeChatId;
    if (route === undefined || owner === undefined || route.accountStore !== owner ||
      route.chatId !== chatId) return;
    // The registration identity also fences repeated setup within one lifecycle.
    // Revoking the page must not revoke legitimate app-global playback.
    const isCurrent = (): boolean => host.mediaPlaybackIsCurrent === isCurrent &&
      host.routeActivated && !host.isClosing && lifecycleToken === host.pageLifecycleToken &&
      host.routeContext === route && host.accountStore === owner && host.activeChatId === chatId &&
      owner.isScopeCurrent() && host.isRouteContextCurrent(route) && host.ownsNavigationContext();
    host.mediaPlaybackIsCurrent = isCurrent;
    if (!isCurrent()) {
      host.mediaPlaybackIsCurrent = undefined;
      return;
    }
    const handle: MediaPlaybackPageHandle = globalMediaPlayback.createPageHandle(owner, chatId, isCurrent);
    host.mediaPlaybackHandle = handle;
    let initialSnapshot: boolean = true;
    const unsubscribe = handle.setHandlers((snapshot: MediaPlaybackSnapshot): void => {
      if (host.getCurrentMediaPlaybackHandle() !== handle) {
        return;
      }
      // Reattachment reset local state; the old LazyForEach row still needs
      // its repaint if another page changed/stopped playback while we were away.
      const prevVoiceId: string = initialSnapshot ? previousVoiceId : host.activeVoiceMessageId;
      const prevAudioId: string = initialSnapshot ? previousAudioId : host.activeAudioMessageId;
      initialSnapshot = false;
      if (snapshot.contentType === 'voice') {
        host.activeVoiceMessageId = snapshot.messageId;
        host.activeVoiceProgress = snapshot.progress;
        host.activeVoicePlaying = snapshot.isPlaying;
        // Also clear on paused/zero snapshots (including another chat's audio).
        host.activeAudioMessageId = '0';
        host.activeAudioProgress = 0;
        host.activeAudioPlaying = false;
      } else {
        host.activeAudioMessageId = snapshot.messageId;
        host.activeAudioProgress = snapshot.progress;
        host.activeAudioPlaying = snapshot.isPlaying;
        host.activeVoiceMessageId = '0';
        host.activeVoiceProgress = 0;
        host.activeVoicePlaying = false;
      }
      // Playback state lives on the page — LazyForEach rows only repaint via
      // an explicit notify (lesson 65), so poke every affected row.
      host.notifyPlaybackRows(prevVoiceId, prevAudioId, snapshot.messageId);
    }, (messageId: string, contentType: MediaContentType): void => {
      if (host.getCurrentMediaPlaybackHandle() !== handle) {
        return;
      }
      host.handlePlaybackCompleted(messageId, contentType);
    });
    // setHandlers may synchronously publish the initial snapshot. Its repaint
    // can re-enter setup/disappear before the unsubscribe has been returned.
    if (host.getCurrentMediaPlaybackHandle() === handle) {
      host.mediaPlaybackUnsubscribe = unsubscribe;
    } else {
      unsubscribe();
    }
  }

export function getCurrentMediaPlaybackHandle(host: ChatPlaybackCoordinatorPort): MediaPlaybackPageHandle | undefined {
    return host.mediaPlaybackIsCurrent?.() === true ? host.mediaPlaybackHandle : undefined;
  }

export function notifyPlaybackRows(host: ChatPlaybackCoordinatorPort, prevVoiceId: string, prevAudioId: string, currentId: string): void {
    const ids = new Set<string>();
    if (prevVoiceId !== '0') {
      ids.add(prevVoiceId);
    }
    if (prevAudioId !== '0') {
      ids.add(prevAudioId);
    }
    if (currentId !== '0') {
      ids.add(currentId);
    }
    ids.forEach((id: string): void => {
      host.dataSource.notifyItemChangedByMessageId(id);
    });
  }

export function teardownMediaPlaybackController(host: ChatPlaybackCoordinatorPort, preserveListened: boolean = false): void {
    const unsubscribe = host.mediaPlaybackUnsubscribe;
    host.mediaPlaybackUnsubscribe = undefined;
    host.mediaPlaybackIsCurrent = undefined;
    host.mediaPlaybackHandle = undefined;
    host.resetPlaybackState(preserveListened);
    // Playback intentionally keeps running app-globally — the root island
    // mini player owns it once the page goes away (Telegram iOS behavior);
    // only the page-scoped handlers are detached here.
    unsubscribe?.();
  }

export function publishNowPlayingMeta(host: ChatPlaybackCoordinatorPort, messageId: string, contentType: MediaContentType): void {
    const handle = host.getCurrentMediaPlaybackHandle();
    if (handle === undefined) return;
    let senderName = '';
    let audioTitle = '';
    let audioPerformer = '';
    let coverPath = '';
    let coverFileId = 0;
    const entries = host.dataSource.getAllEntries();
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      if (entry.kind === 'message' && entry.message.messageId === messageId) {
        senderName = entry.message.isOutgoing
          ? localized($r('app.string.chat_you_prefix').id, 'You')
          : entry.message.senderName;
        audioTitle = entry.message.audioTitle.trim();
        audioPerformer = entry.message.audioPerformer.trim();
        coverPath = entry.message.audioCoverPath;
        // iOS parity: ID3 cover first, else the Telegram-served album art
        // looked up by title+performer (external_album_covers).
        coverFileId = entry.message.audioCoverFileId > 0
          ? entry.message.audioCoverFileId
          : entry.message.audioExternalCoverFileId;
        break;
      }
    }
    const fallbackTitle = senderName.length > 0 ? senderName : host.resolveOwnedChatTitle();
    if (contentType === 'audio' && audioTitle.length > 0) {
      handle.setNowPlaying(audioTitle,
        audioPerformer.length > 0 ? audioPerformer : fallbackTitle,
        coverPath, coverFileId);
      return;
    }
    handle.setNowPlaying(
      fallbackTitle,
      localized($r('app.string.voice_message').id, 'Voice message')
    );
  }

export function handlePlaybackCompleted(host: ChatPlaybackCoordinatorPort, messageId: string, contentType: MediaContentType): void {
    const handle = host.getCurrentMediaPlaybackHandle();
    if (handle === undefined) return;
    // Auto-advance: find next voice/audio message and play it
    const entries = host.dataSource.getAllEntries();
    let foundCurrent = false;
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      if (entry.kind !== 'message') continue;
      if (entry.message.messageId === messageId) {
        foundCurrent = true;
        continue;
      }
      if (!foundCurrent) continue;
      // Found next message after current — check if same type
      const msg = entry.message;
      if (contentType === 'voice' && msg.contentType === 'voice' && msg.voicePath.length > 0) {
        host.locallyListenedVoiceIds.add(msg.messageId);
        host.publishNowPlayingMeta(msg.messageId, 'voice');
        handle.toggle(msg.messageId, msg.voicePath, 'voice')
          .catch((_error: Object) => {});
        return;
      }
      if (contentType === 'audio' && msg.contentType === 'audio' && msg.audioPath.length > 0) {
        host.publishNowPlayingMeta(msg.messageId, 'audio');
        handle.toggle(msg.messageId, msg.audioPath, 'audio')
          .catch((_error: Object) => {});
        return;
      }
      // Different type or no local file — stop auto-advance
      break;
    }
  }
