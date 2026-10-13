import { describe, it, expect } from '@ohos/hypium';
import { AnyAppCommand, createSendMediaAlbumCommand, SendMediaAlbumCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import { SendMediaAlbumParams, SendMediaAlbumUseCase, SendMediaAlbumError } from '../../../main/ets/domain/usecases/sendMediaAlbum';
import { buildTdlibRequestJson, serializeCommand } from '../../../main/ets/infra/td/serialization/CommandSerializer';
import { TdObject } from '../../../main/ets/models/TdTypes';
import { AppError, isWriteOutcomeUnknown } from '../../../main/ets/core/model/AppError';

const CHAT = -10071;

// Captures actual typed commands. Never initializes TDLib or contacts Telegram.
class AlbumGateway implements TdGatewayPort {
  sentCommands: AnyAppCommand[] = [];
  response: Object = acceptedMessages(2);
  rejectSend: boolean = false;
  throwSynchronously: boolean = false;
  deferSend: boolean = false;
  private resolver: ((value: Object) => void) | undefined = undefined;

  initialize(): Promise<void> { return Promise.resolve(); }
  send(command: AnyAppCommand): Promise<Object> {
    this.sentCommands.push(command);
    if (this.throwSynchronously) throw new Error('synchronous transport failure');
    if (this.rejectSend) return Promise.reject(new Error('transport acceptance unavailable'));
    if (this.deferSend) return new Promise<Object>((resolve) => { this.resolver = resolve; });
    return Promise.resolve(this.response);
  }
  complete(response: Object): void {
    if (this.resolver === undefined) throw new Error('No album request is pending');
    this.resolver(response);
    this.resolver = undefined;
  }
  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void { return (): void => {}; }
  getConnectionState(): 'connecting' | 'ready' | 'updating' | 'waitingForNetwork' { return 'ready'; }
  destroy(): Promise<void> { return Promise.resolve(); }
}

function message(id: string, chatId: number = CHAT): string {
  return `{"@type":"message","id":${id},"chat_id":${chatId}}`;
}

function responseJson(messages: string[]): string {
  // Deliberately unrelated total_count: only returned Messages entries count.
  return `{"@type":"messages","total_count":999,"messages":[${messages.join(',')}]}`;
}

function acceptedMessages(count: number): TdObject {
  const messages: string[] = [];
  for (let index = 0; index < count; index++) messages.push(message((101 + index).toString()));
  return TdObject.fromJSON(responseJson(messages));
}

function input(count: number = 2): SendMediaAlbumParams {
  const params = new SendMediaAlbumParams();
  params.chatId = CHAT;
  for (let index = 0; index < count; index++) params.localPaths.push(`/data/test/photo-${index}.jpg`);
  params.caption = 'first photo caption';
  params.replyToMessageId = '88';
  return params;
}

async function assertRejected(params: SendMediaAlbumParams, gateway: AlbumGateway,
  unknown: boolean, dispatches: number): Promise<void> {
  let actual: AppError | undefined = undefined;
  try { await new SendMediaAlbumUseCase(gateway).execute(params); }
  catch (error) {
    if (error instanceof AppError) actual = error;
    else throw new Error('Expected typed album rejection; received ' + String(error));
  }
  expect(actual !== undefined).assertTrue();
  if (actual !== undefined) expect(actual instanceof SendMediaAlbumError ? actual.outcomeUnknown : isWriteOutcomeUnknown(actual)).assertEqual(unknown);
  expect(gateway.sentCommands.length).assertEqual(dispatches);
}

class InvalidInput {
  name: string;
  change: (params: SendMediaAlbumParams) => void;
  constructor(name: string, change: (params: SendMediaAlbumParams) => void) {
    this.name = name; this.change = change;
  }
}

class InvalidResponse {
  name: string;
  json: string;
  constructor(name: string, json: string) { this.name = name; this.json = json; }
}

export default function sendMediaAlbumTest() {
  describe('SendMediaAlbum', () => {
    it('serializes one ordered photo album with escaped paths and first-only caption', 0, () => {
      const paths = ['/data/test/first "quoted"\\photo.jpg', '/data/test/second.jpg'];
      const caption = 'caption "quoted"\\\nline\t🙂';
      const serialized = serializeCommand(createSendMediaAlbumCommand(CHAT, paths, caption, '88'));
      expect(serialized.method).assertEqual('sendMessageAlbum');
      const raw = buildTdlibRequestJson(serialized.method, serialized.params);
      const wire = TdObject.fromJSON(raw);
      expect(wire.getString('@type')).assertEqual('sendMessageAlbum');
      expect(wire.getNumber('chat_id')).assertEqual(CHAT);
      const contents = wire.getTopLevelObjectArrayStrict('input_message_contents');
      expect(contents !== undefined).assertTrue();
      if (contents === undefined) return;
      expect(contents.length).assertEqual(2);
      for (let index = 0; index < contents.length; index++) {
        const content = contents[index];
        expect(content !== null).assertTrue();
        if (content === null) continue;
        expect(content.getString('@type')).assertEqual('inputMessagePhoto');
        expect(content.getObject('photo').getString('@type')).assertEqual('inputFileLocal');
        expect(content.getObject('photo').getString('path')).assertEqual(paths[index]);
        expect(content.getObject('caption').getString('text')).assertEqual(index === 0 ? caption : '');
        expect(content.getBool('show_caption_above_media')).assertFalse();
      }
      expect(wire.getObject('reply_to').getString('@type')).assertEqual('inputMessageReplyToMessage');
      expect(wire.getObject('reply_to').getNumber('message_id')).assertEqual(88);
      expect(raw.indexOf('"_input_message_contents_json"') === -1).assertTrue();
      expect(raw.indexOf('"topic_id":null') >= 0).assertTrue();
      expect(raw.indexOf('"options":null') >= 0).assertTrue();
    });

    it('serializes exactly ten photo contents in selection order', 0, () => {
      const params = input(10);
      const serialized = serializeCommand(createSendMediaAlbumCommand(CHAT, params.localPaths));
      const wire = TdObject.fromJSON(buildTdlibRequestJson(serialized.method, serialized.params));
      const contents = wire.getTopLevelObjectArrayStrict('input_message_contents');
      expect(contents !== undefined).assertTrue();
      if (contents === undefined) return;
      expect(contents.length).assertEqual(10);
      for (let index = 0; index < contents.length; index++) {
        const content = contents[index];
        expect(content !== null).assertTrue();
        if (content !== null) expect(content.getObject('photo').getString('path')).assertEqual(params.localPaths[index]);
      }
      expect(serialized.params.getString('_reply_to_json')).assertEqual('null');
    });

    it('copies the caller path array when creating the typed command', 0, () => {
      const paths = ['/data/first.jpg', '/data/second.jpg'];
      const command = createSendMediaAlbumCommand(CHAT, paths, 'caption', '88');
      paths[0] = '/data/replacement.jpg';
      paths.push('/data/third.jpg');
      expect(command.type).assertEqual('sendMediaAlbum');
      expect(command.payload.localPaths.join('|')).assertEqual('/data/first.jpg|/data/second.jpg');
      expect(command.payload.caption).assertEqual('caption');
      expect(command.payload.replyToMessageId).assertEqual('88');
    });

    for (const count of [2, 10]) {
      it(`accepts exactly ${count} messages while ignoring unrelated total_count`, 0, async () => {
        const gateway = new AlbumGateway();
        gateway.response = acceptedMessages(count);
        await new SendMediaAlbumUseCase(gateway).execute(input(count));
        expect(gateway.sentCommands.length).assertEqual(1);
        expect(gateway.sentCommands[0].type).assertEqual('sendMediaAlbum');
      });
    }

    it('accepts positive pending ids as request acceptance, not delivery', 0, async () => {
      const gateway = new AlbumGateway();
      gateway.response = TdObject.fromJSON(responseJson([
        `{"@type":"message","id":1,"chat_id":${CHAT},"sending_state":{"@type":"messageSendingStatePending"}}`,
        `{"@type":"message","id":"9","chat_id":${CHAT},"sending_state":{"@type":"messageSendingStatePending"}}`
      ]));
      await new SendMediaAlbumUseCase(gateway).execute(input());
      expect(gateway.sentCommands.length).assertEqual(1);
    });

    it('classifies negative message ids as unknown without retry or fallback', 0, async () => {
      for (const id of ['-102', '"-102"']) {
        const gateway = new AlbumGateway();
        gateway.response = TdObject.fromJSON(responseJson([message('101'), message(id)]));
        await assertRejected(input(), gateway, true, 1);
      }
    });

    it('accepts canonical quoted ids and safe int53 reply and caption boundaries', 0, async () => {
      const params = input();
      params.caption = 'x'.repeat(4096);
      params.replyToMessageId = '9007199254740991';
      const gateway = new AlbumGateway();
      gateway.response = TdObject.fromJSON(responseJson([message('9007199254740991'), message('"102"')]));
      await new SendMediaAlbumUseCase(gateway).execute(params);
      expect(gateway.sentCommands.length).assertEqual(1);
      const command = gateway.sentCommands[0] as SendMediaAlbumCommand;
      expect(command.payload.caption.length).assertEqual(4096);
      expect(command.payload.replyToMessageId).assertEqual('9007199254740991');
    });

    it('snapshots chat paths caption reply and expected count before caller mutation', 0, async () => {
      const gateway = new AlbumGateway();
      gateway.deferSend = true;
      const params = input();
      const execution = new SendMediaAlbumUseCase(gateway).execute(params);
      expect(gateway.sentCommands.length).assertEqual(1);
      params.chatId = 777;
      params.localPaths[0] = '/data/replacement.jpg';
      params.localPaths.push('/data/third.jpg');
      params.caption = 'replacement caption';
      params.replyToMessageId = '99';
      const command = gateway.sentCommands[0] as SendMediaAlbumCommand;
      expect(command.payload.chatId).assertEqual(CHAT);
      expect(command.payload.localPaths.join('|')).assertEqual('/data/test/photo-0.jpg|/data/test/photo-1.jpg');
      expect(command.payload.caption).assertEqual('first photo caption');
      expect(command.payload.replyToMessageId).assertEqual('88');
      gateway.complete(acceptedMessages(2));
      let rejected = false;
      try { await execution; } catch (_error) { rejected = true; }
      expect(rejected).assertFalse();
      expect(gateway.sentCommands.length).assertEqual(1);
    });

    const invalidInputs: InvalidInput[] = [
      new InvalidInput('zero photos', (p: SendMediaAlbumParams): void => { p.localPaths = []; }),
      new InvalidInput('one photo belongs to the unchanged single-message path', (p: SendMediaAlbumParams): void => { p.localPaths.length = 1; }),
      new InvalidInput('eleven photos', (p: SendMediaAlbumParams): void => { p.localPaths = input(11).localPaths; }),
      new InvalidInput('zero chat', (p: SendMediaAlbumParams): void => { p.chatId = 0; }),
      new InvalidInput('fractional chat', (p: SendMediaAlbumParams): void => { p.chatId = 1.5; }),
      new InvalidInput('unsafe chat', (p: SendMediaAlbumParams): void => { p.chatId = 9007199254740992; }),
      new InvalidInput('empty item path', (p: SendMediaAlbumParams): void => { p.localPaths[1] = ''; }),
      new InvalidInput('blank item path', (p: SendMediaAlbumParams): void => { p.localPaths[0] = '   '; }),
      new InvalidInput('too long caption', (p: SendMediaAlbumParams): void => { p.caption = 'x'.repeat(4097); }),
      new InvalidInput('noninteger reply', (p: SendMediaAlbumParams): void => { p.replyToMessageId = '1.5'; }),
      new InvalidInput('negative reply', (p: SendMediaAlbumParams): void => { p.replyToMessageId = '-1'; }),
      new InvalidInput('noncanonical reply', (p: SendMediaAlbumParams): void => { p.replyToMessageId = '00088'; }),
      new InvalidInput('unsafe reply', (p: SendMediaAlbumParams): void => { p.replyToMessageId = '9007199254740992'; })
    ];
    for (const invalid of invalidInputs) {
      it(`rejects ${invalid.name} before any gateway mutation`, 0, async () => {
        const params = input(); invalid.change(params);
        await assertRejected(params, new AlbumGateway(), false, 0);
      });
    }

    const invalidResponses: InvalidResponse[] = [
      new InvalidResponse('wrong top-level type', '{"@type":"ok"}'),
      new InvalidResponse('nested Messages grant', `{"wrapper":${responseJson([message('101'), message('102')])}}`),
      new InvalidResponse('missing message array', '{"@type":"messages"}'),
      new InvalidResponse('null message array', '{"@type":"messages","messages":null}'),
      new InvalidResponse('object instead of array', '{"@type":"messages","messages":{}}'),
      new InvalidResponse('partial one-member response', responseJson([message('101')])),
      new InvalidResponse('extra member response', responseJson([message('101'), message('102'), message('103')])),
      new InvalidResponse('null member slot', responseJson([message('101'), 'null'])),
      new InvalidResponse('primitive member slot', responseJson([message('101'), '42'])),
      new InvalidResponse('wrong member type', responseJson([message('101'), `{"@type":"chat","id":102,"chat_id":${CHAT}}`])),
      new InvalidResponse('wrong target chat', responseJson([message('101'), message('102', 999)])),
      new InvalidResponse('nested-only target', responseJson([message('101'), `{"@type":"message","id":102,"wrapper":{"chat_id":${CHAT}}}`])),
      new InvalidResponse('missing id', responseJson([message('101'), `{"@type":"message","chat_id":${CHAT}}`])),
      new InvalidResponse('nested-only id', responseJson([message('101'), `{"@type":"message","chat_id":${CHAT},"wrapper":{"id":102}}`])),
      new InvalidResponse('zero id', responseJson([message('101'), message('0')])),
      new InvalidResponse('null id', responseJson([message('101'), message('null')])),
      new InvalidResponse('fractional id', responseJson([message('101'), message('102.5')])),
      new InvalidResponse('unsafe id', responseJson([message('101'), message('9007199254740992')])),
      new InvalidResponse('noncanonical string id', responseJson([message('101'), message('"00102"')])),
      new InvalidResponse('signed-plus string id', responseJson([message('101'), message('"+102"')])),
      new InvalidResponse('fractional string id', responseJson([message('101'), message('"102.5"')])),
      new InvalidResponse('negative-zero string id', responseJson([message('101'), message('"-0"')])),
      new InvalidResponse('unsafe string id', responseJson([message('101'), message('"9007199254740992"')])),
      new InvalidResponse('duplicate number and quoted id', responseJson([message('101'), message('"101"')]))
    ];
    for (const invalid of invalidResponses) {
      it(`classifies ${invalid.name} as unknown without retry or fallback`, 0, async () => {
        const gateway = new AlbumGateway();
        gateway.response = TdObject.fromJSON(invalid.json);
        await assertRejected(input(), gateway, true, 1);
      });
    }

    it('rejects a plain untyped object after dispatch as unknown', 0, async () => {
      const gateway = new AlbumGateway(); gateway.response = new Object();
      await assertRejected(input(), gateway, true, 1);
    });
    for (const synchronous of [false, true]) {
      it(`classifies ${synchronous ? 'synchronous' : 'rejected Promise'} transport error as unknown`, 0, async () => {
        const gateway = new AlbumGateway();
        gateway.throwSynchronously = synchronous; gateway.rejectSend = !synchronous;
        await assertRejected(input(), gateway, true, 1);
      });
    }
  });
}
