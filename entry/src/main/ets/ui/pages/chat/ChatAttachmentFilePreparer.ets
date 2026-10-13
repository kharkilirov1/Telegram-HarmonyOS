// Picker URI -> unique application-owned file. The caller captures the ability
// context and decides whether an unsubmitted file can be discarded safely.
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0021;
const TAG = 'ChatAttachmentFilePreparer';

export class ChatAttachmentFilePreparer {
  private static fileSequence: number = 0;
  private readonly ownedPaths: Set<string> = new Set<string>();

  async prepare(kind: string, sourceUri: string, context: common.UIAbilityContext): Promise<string> {
    if (kind !== 'photo' && kind !== 'video' && kind !== 'document') {
      throw new Error('Unsupported picked attachment kind');
    }
    if (typeof sourceUri !== 'string' || sourceUri.trim().length === 0) {
      throw new Error('Picked attachment URI is empty');
    }
    const targetDir = this.ensureDirectory(context);
    const targetPath = this.newTargetPath(targetDir, kind, sourceUri);
    this.ownedPaths.add(targetPath);
    let sourceFile: fileIo.File | undefined = undefined;
    let copyCompleted = false;
    try {
      // Keep provider URIs intact: rewriting file://media/... into a filesystem
      // path would lose the media provider identity and its temporary grant.
      sourceFile = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
      this.onSourceOpened(sourceFile.fd);
      fileIo.copyFileSync(sourceFile.fd, targetPath);
      copyCompleted = true;
    } catch (error) {
      this.discard(targetPath);
      const detail = error instanceof Error ? error.message : 'Native file operation failed';
      throw new Error('Prepare picked attachment failed: ' + detail);
    } finally {
      if (sourceFile !== undefined) {
        try {
          fileIo.closeSync(sourceFile);
        } catch (_error) {
          this.discard(targetPath);
          if (copyCompleted) throw new Error('Close picked attachment source failed');
          // Preserve the primary copy/open failure while reporting failed close.
          hilog.warn(DOMAIN, TAG, 'Attachment source close failed');
        }
      }
    }
    return targetPath;
  }

  // Observe the exact owned handle for native verification without replacing IO.
  // Called only after assignment so a throwing observer still reaches finally.
  protected onSourceOpened(_fd: number): void {}

  discard(path: string): void {
    // Never delete a picker source, caller-supplied arbitrary file, or a path
    // created by another preparer. Submitted files stay owned but are retained.
    if (!this.ownedPaths.has(path)) return;
    try {
      if (fileIo.accessSync(path)) fileIo.unlinkSync(path);
      this.ownedPaths.delete(path);
    } catch (_error) {
      // Retain ownership so an explicit later cleanup can retry safely.
      hilog.warn(DOMAIN, TAG, 'Prepared attachment cleanup failed');
    }
  }

  private ensureDirectory(context: common.UIAbilityContext): string {
    if (context === undefined || context === null || typeof context.filesDir !== 'string' ||
      context.filesDir.length === 0) throw new Error('Attachment ability context is unavailable');
    const targetDir = context.filesDir + '/composer_send_media';
    if (!fileIo.accessSync(targetDir)) fileIo.mkdirSync(targetDir, true);
    return targetDir;
  }

  private newTargetPath(directory: string, kind: string, sourceUri: string): string {
    const rawName = this.safeFileName(sourceUri);
    const dotIndex = rawName.lastIndexOf('.');
    const stem = dotIndex > 0 ? rawName.substring(0, dotIndex) : rawName;
    const extension = dotIndex >= 0 && dotIndex < rawName.length - 1 && rawName.length - dotIndex <= 12
      ? rawName.substring(dotIndex) : kind === 'photo' ? '.jpg' : kind === 'video' ? '.mp4' : '.bin';
    // Shared sequence keeps different preparer instances distinct even when
    // Date.now() is identical and provider URIs have the same final segment.
    for (let attempt = 0; attempt < 100; attempt++) {
      const target = directory + '/tg_send_' + kind + '_' + Date.now().toString() + '_' +
        (++ChatAttachmentFilePreparer.fileSequence).toString() + '_' + stem + extension;
      if (!fileIo.accessSync(target)) return target;
    }
    throw new Error('Unable to allocate a unique attachment path');
  }

  private safeFileName(sourceUri: string): string {
    const parts = sourceUri.split('?')[0].split('/');
    let name = parts.length > 0 ? parts[parts.length - 1] : '';
    try { name = decodeURIComponent(name); } catch (_error) {}
    const safe = name.replace(/[^A-Za-z0-9._-]/g, '_');
    return safe.length > 0 ? safe.substring(0, 48) : 'attachment';
  }
}
