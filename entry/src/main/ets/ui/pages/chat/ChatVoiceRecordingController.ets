// ChatVoiceRecordingController — microphone permission, AVRecorder lifecycle and voice-note send.
// UI state remains page-owned; this class owns only platform resources and coordination.

import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import {
  SendMediaMessageParams,
  SendMediaMessageUseCase
} from '../../../domain/usecases/sendMediaMessage';
import {
  isVoiceRecordingDurationSendable,
  TgVoiceRecordingState
} from '../../tg_ui/utils/TgVoiceRecordingPolicy';

const DOMAIN = 0x0021;
const TAG = 'ChatVoiceRecorder';
const VOICE_TIMER_INTERVAL_MS = 250;
// Retained chat pages share the output directory, but not operation tokens.
let voiceOutputSequence: number = 0;

type PendingVoiceResolution = 'none' | 'send' | 'cancel' | 'lock';

// Startup owns this bundle locally until start succeeds for the current operation.
// Cleanup retains the same bundle across awaits, never the controller's next one.
class VoiceRecordingResources {
  recorder?: media.AVRecorder;
  outputFile?: fileIo.File;
  outputPath: string = '';
  releasePromise?: Promise<void>;
}

export interface ChatVoiceRecordingHost {
  canSendNewMessages(sendKind?: string): boolean;
  getActiveChatId(): number;
  getLifecycleToken(): number;
  getChatUIContext(): UIContext;
  getSendMediaUseCase(mediaKind?: string): SendMediaMessageUseCase | undefined;
  getReplyToMessageId(): string;
  clearReplyMode(): void;
  isNearBottom(): boolean;
  scrollToBottomSoon(): void;
  setVoiceRecordingState(state: TgVoiceRecordingState, durationMs: number): void;
}

export class ChatVoiceRecordingController {
  private resources?: VoiceRecordingResources;
  private mediaUseCase?: SendMediaMessageUseCase;
  private recorderState: TgVoiceRecordingState = 'idle';
  private startedAt: number = 0;
  private durationMs: number = 0;
  private timerId: number = -1;
  private operationToken: number = 0;
  private lifecycleToken: number = 0;
  private chatId: number = 0;
  private pendingResolution: PendingVoiceResolution = 'none';

  begin(host: ChatVoiceRecordingHost): void {
    if (this.recorderState !== 'idle' && this.recorderState !== 'error') {
      return;
    }
    this.pendingResolution = 'none';
    this.durationMs = 0;
    this.chatId = host.getActiveChatId();
    this.lifecycleToken = host.getLifecycleToken();
    this.mediaUseCase = host.getSendMediaUseCase('voice');
    if (this.chatId === 0 || this.mediaUseCase === undefined || !host.canSendNewMessages('voice')) {
      return;
    }

    const token = ++this.operationToken;
    this.setState(host, 'preparing', 0);
    this.beginAsync(host, token).catch(async (error: Error) => {
      if (!this.canResetOwnedPage(host, token)) {
        return;
      }
      hilog.error(DOMAIN, TAG, 'Voice recording start failed: %{public}s', error.message);
      await this.failAndReset(host, localized($r('app.string.composer_voice_record_failed').id,
        'Could not start voice recording'));
    });
  }

  finishAndSend(host: ChatVoiceRecordingHost): void {
    if (this.recorderState === 'preparing') {
      this.pendingResolution = 'send';
      return;
    }
    if (this.recorderState !== 'recording' && this.recorderState !== 'locked' && this.recorderState !== 'preview') {
      return;
    }
    const token = this.operationToken;
    this.finishAndSendAsync(host, token).catch(async (error: Error) => {
      if (!this.canResetOwnedPage(host, token)) {
        return;
      }
      hilog.error(DOMAIN, TAG, 'Voice recording send failed: %{public}s', error.message);
      await this.failAndReset(host, localized($r('app.string.composer_voice_send_failed').id,
        'Could not send voice message'));
    });
  }

  lock(host: ChatVoiceRecordingHost): void {
    if (this.recorderState === 'preparing') {
      this.pendingResolution = 'lock';
      return;
    }
    if (this.recorderState === 'recording') {
      this.setState(host, 'locked', this.currentDurationMs());
    }
  }

  cancel(host: ChatVoiceRecordingHost): void {
    if (this.recorderState === 'idle') {
      return;
    }
    if (this.recorderState === 'preparing') {
      this.pendingResolution = 'cancel';
    }
    const token = ++this.operationToken;
    this.cancelAsync(host, token).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'Voice recording cancel cleanup failed: %{public}s', error.message);
      if (this.canResetOwnedPage(host, token)) {
        this.setState(host, 'idle', 0);
      }
    });
  }

  dispose(): void {
    ++this.operationToken;
    const resources = this.resources;
    this.resetFields();
    this.releaseRecorder(resources, true).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'Voice recorder dispose failed: %{public}s', error.message);
    });
    this.recorderState = 'idle';
  }

  private async beginAsync(host: ChatVoiceRecordingHost, token: number): Promise<void> {
    const granted = await this.requestMicrophonePermission(host);
    if (!this.isActive(host, token) || !host.canSendNewMessages('voice')) {
      this.resetUnstartedOwnedPage(host, token);
      return;
    }
    if (!granted) {
      this.setState(host, 'idle', 0);
      this.showToast(host, localized($r('app.string.composer_voice_permission_denied').id,
        'Microphone access is required for voice messages'));
      return;
    }

    const context = host.getChatUIContext().getHostContext() as common.UIAbilityContext;
    const outputDir = `${context.filesDir}/composer_voice`;
    this.ensureDirectory(outputDir);
    const resources = new VoiceRecordingResources();
    let published = false;
    try {
      resources.outputPath = `${outputDir}/tg_voice_${Date.now()}_${++voiceOutputSequence}.m4a`;
      resources.outputFile = fileIo.openSync(resources.outputPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);

      const recorder = await media.createAVRecorder();
      resources.recorder = recorder;
      if (!this.isActive(host, token) || !host.canSendNewMessages('voice')) {
        this.resetUnstartedOwnedPage(host, token);
        return;
      }
      const profile: media.AVRecorderProfile = {
        audioBitrate: 64_000,
        audioChannels: 1,
        audioCodec: media.CodecMimeType.AUDIO_AAC,
        audioSampleRate: 48_000,
        fileFormat: media.ContainerFormatType.CFT_MPEG_4A
      };
      const config: media.AVRecorderConfig = {
        audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
        profile: profile,
        url: `fd://${resources.outputFile.fd}`
      };
      await recorder.prepare(config);
      if (!this.isActive(host, token) || !host.canSendNewMessages('voice')) {
        this.resetUnstartedOwnedPage(host, token);
        return;
      }
      await recorder.start();
      if (!this.isActive(host, token) || !host.canSendNewMessages('voice')) {
        this.resetUnstartedOwnedPage(host, token);
        return;
      }
      this.resources = resources;
      published = true;
    } finally {
      if (!published) {
        await this.releaseRecorder(resources, true);
      }
    }

    this.startedAt = Date.now();
    this.startTimer(host, token);
    const pending = this.pendingResolution;
    this.pendingResolution = 'none';
    if (pending === 'cancel') {
      this.cancel(host);
      return;
    }
    if (pending === 'send') {
      this.setState(host, 'recording', 0);
      this.finishAndSend(host);
      return;
    }
    if (pending === 'lock') {
      this.setState(host, 'locked', 0);
      return;
    }
    this.setState(host, 'recording', 0);
  }

  private async finishAndSendAsync(host: ChatVoiceRecordingHost, token: number): Promise<void> {
    const resources = this.resources;
    this.durationMs = this.currentDurationMs();
    this.setState(host, 'sending', this.durationMs);
    this.stopTimer();
    await this.releaseRecorder(resources, false);
    if (!this.isActive(host, token)) {
      await this.releaseRecorder(resources, true);
      this.resetRevokedOwnedPage(host, token);
      return;
    }
    if (!isVoiceRecordingDurationSendable(this.durationMs)) {
      this.deleteOutputFile(resources);
      this.resetFields();
      this.setState(host, 'idle', 0);
      this.showToast(host, localized($r('app.string.composer_voice_too_short').id,
        'Recording is too short'));
      return;
    }

    const useCase = host.getSendMediaUseCase('voice');
    if (useCase === undefined || resources === undefined || resources.outputPath.length === 0) {
      throw new Error('Voice send use case or output path is unavailable');
    }
    if (!host.canSendNewMessages('voice')) {
      // Recorder is stopped, but this owned file is still an unsent draft.
      // Reuse the existing Send/Delete controls; expiry never sends it itself.
      this.startedAt = 0;
      this.setState(host, 'preview', this.durationMs);
      return;
    }
    const params = new SendMediaMessageParams();
    params.chatId = this.chatId;
    params.mediaKind = 'voice';
    params.localPath = resources.outputPath;
    params.durationSeconds = Math.max(1, Math.ceil(this.durationMs / 1000));
    params.waveformBase64 = '';
    const replyToMessageId = host.getReplyToMessageId();
    if (replyToMessageId !== '0') {
      params.replyToMessageId = replyToMessageId;
    }

    const wasNearBottom = host.isNearBottom();
    await useCase.execute(params);
    if (!this.isActive(host, token)) {
      this.resetRevokedOwnedPage(host, token);
      return;
    }
    host.clearReplyMode();
    if (wasNearBottom) {
      host.scrollToBottomSoon();
    }
    this.resetFields();
    this.setState(host, 'idle', 0);
  }

  private async cancelAsync(host: ChatVoiceRecordingHost, token: number): Promise<void> {
    const resources = this.resources;
    this.stopTimer();
    await this.releaseRecorder(resources, true);
    if (!this.canResetOwnedPage(host, token)) {
      return;
    }
    this.resetFields();
    this.setState(host, 'idle', 0);
  }

  private async requestMicrophonePermission(host: ChatVoiceRecordingHost): Promise<boolean> {
    const context = host.getChatUIContext().getHostContext() as common.UIAbilityContext;
    const result = await abilityAccessCtrl.createAtManager()
      .requestPermissionsFromUser(context, ['ohos.permission.MICROPHONE']);
    return result.authResults.length > 0 && result.authResults[0] === 0;
  }

  private ensureDirectory(path: string): void {
    try {
      if (fileIo.accessSync(path)) {
        return;
      }
    } catch (_error) {}
    fileIo.mkdirSync(path, true);
  }

  private startTimer(host: ChatVoiceRecordingHost, token: number): void {
    this.stopTimer();
    this.timerId = setInterval(() => {
      if (!this.isActive(host, token) ||
        (this.recorderState !== 'recording' && this.recorderState !== 'locked')) {
        return;
      }
      this.durationMs = this.currentDurationMs();
      host.setVoiceRecordingState(this.recorderState, this.durationMs);
    }, VOICE_TIMER_INTERVAL_MS) as number;
  }

  private stopTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private currentDurationMs(): number {
    if (this.startedAt <= 0) {
      return this.durationMs;
    }
    return Math.max(this.durationMs, Date.now() - this.startedAt);
  }

  private async releaseRecorder(resources: VoiceRecordingResources | undefined, deleteFile: boolean): Promise<void> {
    if (resources === undefined) {
      return;
    }
    if (resources.releasePromise === undefined) {
      resources.releasePromise = this.releaseResources(resources);
    }
    await resources.releasePromise;
    if (deleteFile) {
      this.deleteOutputFile(resources);
    }
  }

  private async releaseResources(resources: VoiceRecordingResources): Promise<void> {
    const recorder = resources.recorder;
    const outputFile = resources.outputFile;
    resources.recorder = undefined;
    resources.outputFile = undefined;
    if (recorder !== undefined) {
      try {
        if (recorder.state === 'started' || recorder.state === 'paused') {
          await recorder.stop();
        }
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'AVRecorder stop failed: %{public}s', String(error));
      }
      try {
        if (recorder.state !== 'released') {
          await recorder.release();
        }
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'AVRecorder release failed: %{public}s', String(error));
      }
    }
    if (outputFile !== undefined) {
      try {
        fileIo.closeSync(outputFile);
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'Voice output close failed: %{public}s', String(error));
      }
    }
  }

  private deleteOutputFile(resources: VoiceRecordingResources | undefined): void {
    if (resources === undefined || resources.outputPath.length === 0) {
      return;
    }
    try {
      if (fileIo.accessSync(resources.outputPath)) {
        fileIo.unlinkSync(resources.outputPath);
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Voice output delete failed: %{public}s', String(error));
    }
    resources.outputPath = '';
  }

  private async failAndReset(host: ChatVoiceRecordingHost, message: string): Promise<void> {
    const token = ++this.operationToken;
    const resources = this.resources;
    this.stopTimer();
    await this.releaseRecorder(resources, true);
    if (!this.canResetOwnedPage(host, token)) {
      return;
    }
    this.recorderState = 'error';
    host.setVoiceRecordingState('error', 0);
    this.showToast(host, message);
    this.resetFields();
    this.setState(host, 'idle', 0);
  }

  private resetFields(): void {
    this.stopTimer();
    this.resources = undefined;
    this.mediaUseCase = undefined;
    this.startedAt = 0;
    this.durationMs = 0;
    this.pendingResolution = 'none';
  }

  private setState(host: ChatVoiceRecordingHost, state: TgVoiceRecordingState, durationMs: number): void {
    this.recorderState = state;
    host.setVoiceRecordingState(state, durationMs);
  }

  private isActive(host: ChatVoiceRecordingHost, token: number): boolean {
    return this.isOwnedPage(host, token) &&
      (this.mediaUseCase === undefined || host.getSendMediaUseCase('voice') === this.mediaUseCase);
  }

  private canResetOwnedPage(host: ChatVoiceRecordingHost, token: number): boolean {
    const current = host.getSendMediaUseCase('voice');
    return this.isOwnedPage(host, token) &&
      (this.mediaUseCase === undefined || current === undefined || current === this.mediaUseCase);
  }

  private resetUnstartedOwnedPage(host: ChatVoiceRecordingHost, token: number): void {
    if (this.canResetOwnedPage(host, token)) {
      this.resetFields();
      this.setState(host, 'idle', 0);
    }
  }

  private resetRevokedOwnedPage(host: ChatVoiceRecordingHost, token: number): void {
    if (this.isOwnedPage(host, token) && host.getSendMediaUseCase('voice') === undefined) {
      this.resetFields();
      this.setState(host, 'idle', 0);
    }
  }

  private isOwnedPage(host: ChatVoiceRecordingHost, token: number): boolean {
    return token === this.operationToken && this.lifecycleToken === host.getLifecycleToken() &&
      this.chatId === host.getActiveChatId();
  }

  private showToast(host: ChatVoiceRecordingHost, message: string): void {
    try {
      host.getChatUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
    } catch (_error) {}
  }
}
