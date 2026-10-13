import { describe, it, expect } from '@ohos/hypium';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ChatAttachmentFilePreparer } from '../../../main/ets/ui/pages/chat/ChatAttachmentFilePreparer';

// Real native image packing, sandbox files and production preparation. No picker,
// gateway, account or file-I/O stub. Self-bundle file URI is not a media-provider grant.
// Preserved native history: photo-preview/sdk-focused-v1.log reported 7/9 IO
// passes and two descriptor-probe permission errors. The former process-FD
// enumeration is replaced with production's protected exact-handle observer.
// Only the source handle is observed; no process scan, FD guessing or native
// operation replacement. Missing capture and every error except EBADF fail.
let fixtureSequence: number = 0;

class NativePhotoSource {
  path: string;
  bytes: Uint8Array;
  constructor(path: string, bytes: Uint8Array) { this.path = path; this.bytes = bytes; }
}

class NativePreparedPhoto {
  owner: ChatAttachmentFilePreparer;
  path: string;
  constructor(owner: ChatAttachmentFilePreparer, path: string) { this.owner = owner; this.path = path; }
}

function readBytes(path: string): Uint8Array {
  const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
  try {
    const buffer = new ArrayBuffer(fileIo.statSync(file.fd).size);
    expect(fileIo.readSync(file.fd, buffer)).assertEqual(buffer.byteLength);
    return new Uint8Array(buffer);
  } finally { fileIo.closeSync(file); }
}

function assertSourceUnchanged(source: NativePhotoSource): void {
  expect(fileIo.accessSync(source.path)).assertTrue();
  expect(readBytes(source.path).join(',')).assertEqual(source.bytes.join(','));
}

async function abilityContext(): Promise<common.UIAbilityContext> {
  // Hypium starts in TestAbility.onCreate, before the ability becomes visible.
  // Public SDK application/AbilityDelegator.d.ts:742 returns the displayed
  // UIAbility; error 16000100 means GetCurrentTopAbility is not available yet.
  // UIAbility.context and UIAbilityContext.abilityInfo identify its real owner.
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  const deadline = Date.now() + 10000;
  let waiting = true;
  let timeoutId: number = -1;
  const readinessError = 'Real TestAbility context was not ready within 10000 ms';
  const ready = async (): Promise<common.UIAbilityContext> => {
    while (waiting && Date.now() < deadline) {
      try {
        const ability = await delegator.getCurrentTopAbility();
        if (!waiting) break;
        if (ability !== undefined && ability !== null &&
          ability.context !== undefined && ability.context !== null &&
          ability.context.abilityInfo.name === 'TestAbility' && ability.context.filesDir.length > 0) {
          return ability.context;
        }
      } catch (error) {
        const native = error as BusinessError;
        if (native.code !== 16000100) {
          throw new Error('Cannot obtain real TestAbility context: ' + native.message);
        }
      }
      await new Promise<void>((resolve) => { setTimeout(() => resolve(), 100); });
    }
    throw new Error(readinessError);
  };
  const timeout = new Promise<common.UIAbilityContext>((_resolve, reject) => {
    timeoutId = setTimeout(() => {
      waiting = false;
      reject(new Error(readinessError));
    }, 10000);
  });
  try { return await Promise.race([ready(), timeout]); }
  finally {
    waiting = false;
    clearTimeout(timeoutId);
  }
}

class NativePhotoFixture {
  readonly root: string;
  readonly sources: NativePhotoSource[] = [];
  readonly prepared: NativePreparedPhoto[] = [];
  readonly context: common.UIAbilityContext;
  private readonly directories: string[] = [];

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.root = context.filesDir + '/photo_preview_io_' + Date.now().toString() + '_' + (++fixtureSequence).toString();
    fileIo.mkdirSync(this.root);
  }

  async source(format: string, directory: string, name: string, red: number = 255): Promise<NativePhotoSource> {
    const folder = this.root + '/' + directory;
    if (!fileIo.accessSync(folder)) {
      fileIo.mkdirSync(folder);
      this.directories.push(folder);
    }
    const pixels = new Uint8Array([red, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255]);
    const options: image.InitializationOptions = { size: { width: 2, height: 2 }, pixelFormat: image.PixelMapFormat.RGBA_8888 };
    const pixelMap = await image.createPixelMap(pixels.buffer, options);
    const packer = image.createImagePacker();
    let packed: ArrayBuffer = new ArrayBuffer(0);
    try {
      const packing: image.PackingOption = { format: format, quality: 100 };
      packed = await packer.packing(pixelMap, packing);
    } finally {
      await packer.release();
      await pixelMap.release();
    }
    const path = folder + '/' + name;
    const source = new NativePhotoSource(path, new Uint8Array(packed));
    this.sources.push(source);
    const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try { expect(fileIo.writeSync(file.fd, packed)).assertEqual(packed.byteLength); }
    finally { fileIo.closeSync(file); }
    return source;
  }

  async prepare(owner: ChatAttachmentFilePreparer, uri: string): Promise<string> {
    const path = await owner.prepare('photo', uri, this.context);
    this.prepared.push(new NativePreparedPhoto(owner, path));
    return path;
  }

  dispose(): void {
    // Delete only this test's returned copies and its synthetic source tree.
    for (const photo of this.prepared) photo.owner.discard(photo.path);
    for (const source of this.sources) if (fileIo.accessSync(source.path)) fileIo.unlinkSync(source.path);
    for (let index = this.directories.length - 1; index >= 0; index--) fileIo.rmdirSync(this.directories[index]);
    fileIo.rmdirSync(this.root);
  }
}

function composerEntries(context: common.UIAbilityContext): string {
  const directory = context.filesDir + '/composer_send_media';
  return fileIo.accessSync(directory) ? fileIo.listFileSync(directory).sort().join('|') : '';
}

function assertDescriptorClosed(fd: number): void {
  let closed = false;
  try { fileIo.statSync(fd); }
  catch (error) {
    // Public CoreFileKit @ohos.file.fs.d.ts:7079 documents statSync(number)
    // and 13900008 (EBADF). Permission or any other failure is not closure.
    expect((error as BusinessError).code).assertEqual(13900008);
    closed = true;
  }
  expect(closed).assertTrue();
}

class NativeObservedFilePreparer extends ChatAttachmentFilePreparer {
  private readonly openedDescriptors: number[] = [];

  protected onSourceOpened(fd: number): void {
    // Observe the exact handle returned by production's real native openSync;
    // no native operation is replaced. This stat must succeed while it is open.
    expect(fileIo.statSync(fd).ino.toString().length > 0).assertTrue();
    this.openedDescriptors.push(fd);
  }

  assertSourceClosed(expectedOpenCount: number): void {
    // Missing observer wiring must fail, rather than inspecting an assumed FD.
    expect(this.openedDescriptors.length).assertEqual(expectedOpenCount);
    assertDescriptorClosed(this.openedDescriptors[expectedOpenCount - 1]);
    // Never close an observed FD here: the OS may reuse its numeric identifier.
  }
}

function assertDescriptorWitness(path: string): void {
  const control = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
  const fd = control.fd;
  try {
    // Native positive control: this exact own FD is inspectable while open.
    expect(fileIo.statSync(fd).ino.toString()).assertEqual(fileIo.statSync(path).ino.toString());
  } finally { fileIo.closeSync(control); }
  assertDescriptorClosed(fd);
}

async function assertPreparedImage(path: string, source: NativePhotoSource, context: common.UIAbilityContext): Promise<void> {
  expect(path.indexOf(context.filesDir + '/composer_send_media/') === 0).assertTrue();
  expect(path === source.path).assertFalse();
  expect(readBytes(path).join(',')).assertEqual(source.bytes.join(','));
  const decoded = image.createImageSource(path);
  try {
    const info = await decoded.getImageInfo();
    expect(info.size.width).assertEqual(2);
    expect(info.size.height).assertEqual(2);
  } finally { await decoded.release(); }
  assertSourceUnchanged(source);
}

export default function photoAttachmentFileIOTest() {
  describe('PhotoAttachmentFileIO', () => {
    for (const format of ['image/png', 'image/jpeg']) {
      for (const useUri of [false, true]) {
        it(`prepares native ${format} from ${useUri ? 'self-bundle file URI' : 'sandbox path'} preserving source bytes`, 0, async () => {
          const fixture = new NativePhotoFixture(await abilityContext());
          try {
            const source = await fixture.source(format, 'source', format === 'image/png' ? 'photo.png' : 'photo.jpg');
            const preparer = new ChatAttachmentFilePreparer();
            const input = useUri ? fileUri.getUriFromPath(source.path) : source.path;
            if (useUri) expect(input.indexOf('file://') === 0).assertTrue();
            await assertPreparedImage(await fixture.prepare(preparer, input), source, fixture.context);
          } finally { fixture.dispose(); }
        });
      }
    }

    it('keeps same-name native sources and repeated copies distinct across preparer instances', 0, async () => {
      const fixture = new NativePhotoFixture(await abilityContext());
      try {
        const first = await fixture.source('image/png', 'first', 'same name.png', 255);
        const second = await fixture.source('image/png', 'second', 'same name.png', 32);
        const a = new ChatAttachmentFilePreparer();
        const b = new ChatAttachmentFilePreparer();
        const one = await fixture.prepare(a, first.path);
        const two = await fixture.prepare(a, fileUri.getUriFromPath(second.path));
        const three = await fixture.prepare(b, first.path);
        expect(one !== two && one !== three && two !== three).assertTrue();
        await assertPreparedImage(one, first, fixture.context);
        await assertPreparedImage(two, second, fixture.context);
        await assertPreparedImage(three, first, fixture.context);
      } finally { fixture.dispose(); }
    });

    it('discards only its owned copy and preserves sources and another preparer copy', 0, async () => {
      const fixture = new NativePhotoFixture(await abilityContext());
      try {
        const source = await fixture.source('image/png', 'source', 'preserve.png');
        const owner = new ChatAttachmentFilePreparer();
        const other = new ChatAttachmentFilePreparer();
        const owned = await fixture.prepare(owner, source.path);
        const unrelated = await fixture.prepare(other, source.path);
        owner.discard(source.path);
        owner.discard(unrelated);
        assertSourceUnchanged(source);
        expect(fileIo.accessSync(unrelated)).assertTrue();
        owner.discard(owned);
        owner.discard(owned);
        expect(fileIo.accessSync(owned)).assertFalse();
        expect(fileIo.accessSync(unrelated)).assertTrue();
        assertSourceUnchanged(source);
      } finally { fixture.dispose(); }
    });

    it('native missing-source failure leaves previous copies and sources unchanged without a target', 0, async () => {
      const fixture = new NativePhotoFixture(await abilityContext());
      try {
        const source = await fixture.source('image/png', 'source', 'valid.png');
        const owner = new ChatAttachmentFilePreparer();
        const prior = await fixture.prepare(owner, source.path);
        const before = composerEntries(fixture.context);
        let failed = false;
        try { await owner.prepare('photo', fixture.root + '/missing.png', fixture.context); }
        catch (_error) { failed = true; }
        expect(failed).assertTrue();
        expect(composerEntries(fixture.context)).assertEqual(before);
        expect(fileIo.accessSync(prior)).assertTrue();
        await assertPreparedImage(prior, source, fixture.context);
        assertSourceUnchanged(source);
      } finally { fixture.dispose(); }
    });

    it('real directory-source copy failure leaves no target and closes the opened native source', 0, async () => {
      const fixture = new NativePhotoFixture(await abilityContext());
      try {
        const source = await fixture.source('image/png', 'source', 'valid.png');
        const owner = new NativeObservedFilePreparer();
        const prior = await fixture.prepare(owner, source.path);
        owner.assertSourceClosed(1);
        const directory = fixture.root + '/source';
        assertDescriptorWitness(directory); // Also proves native open succeeds before the failing copy.
        const before = composerEntries(fixture.context);
        let failed = false;
        try { await owner.prepare('photo', directory, fixture.context); }
        catch (_error) { failed = true; }
        owner.assertSourceClosed(2); // Immediately after rejection, before other file operations.
        expect(failed).assertTrue();
        expect(composerEntries(fixture.context)).assertEqual(before);
        expect(fileIo.accessSync(prior)).assertTrue();
        await assertPreparedImage(prior, source, fixture.context);
        assertSourceUnchanged(source);
      } finally { fixture.dispose(); }
    });

    it('native descriptor witness detects its positive control and no retained source after repeated path and URI preparation', 0, async () => {
      const fixture = new NativePhotoFixture(await abilityContext());
      try {
        const source = await fixture.source('image/jpeg', 'source', 'descriptor.jpg');
        assertDescriptorWitness(source.path);
        const owner = new NativeObservedFilePreparer();
        for (let index = 0; index < 8; index++) {
          await fixture.prepare(owner, index % 2 === 0 ? source.path : fileUri.getUriFromPath(source.path));
          owner.assertSourceClosed(index + 1); // Before any subsequent native file operation.
        }
        assertSourceUnchanged(source);
      } finally { fixture.dispose(); }
    });
  });
}
