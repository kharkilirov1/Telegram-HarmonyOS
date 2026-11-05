// I6: copy a picked story media file into the sandbox cache. TDLib uploads from a local path, and the
// picker URI is a media-library handle that cannot be read after the picker closes.

import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { storyFileExtension } from './StoryComposerModel';

const DOMAIN = 0x00B6;
const TAG = 'StoryMediaPrep';
const STORY_CACHE_SUBDIR = 'stories';

export class StoryMediaPrep {
  // Returns the cached path, or '' when the file could not be copied.
  static async copyPickedMedia(context: common.UIAbilityContext, sourceUri: string): Promise<string> {
    if (sourceUri.length === 0) {
      return '';
    }
    let source: fileIo.File | undefined;
    let target: fileIo.File | undefined;
    try {
      const cacheDir = context.cacheDir;
      const storyDir = cacheDir + '/' + STORY_CACHE_SUBDIR;
      if (!fileIo.accessSync(storyDir)) {
        fileIo.mkdirSync(storyDir);
      }
      const extension = storyFileExtension(sourceUri);
      const fileName = 'story_' + Date.now().toString() + (extension.length > 0 ? '.' + extension : '.jpg');
      const targetPath = storyDir + '/' + fileName;
      source = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
      target = fileIo.openSync(targetPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);
      fileIo.copyFileSync(source.fd, target.fd);
      return targetPath;
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Copying the picked story media failed: %{public}s', String(error));
      return '';
    } finally {
      if (source !== undefined) {
        try {
          fileIo.closeSync(source);
        } catch (_error) {
        }
      }
      if (target !== undefined) {
        try {
          fileIo.closeSync(target);
        } catch (_error) {
        }
      }
    }
  }
}
