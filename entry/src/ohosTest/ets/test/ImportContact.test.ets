import { describe, expect, it } from '@ohos/hypium';
import { AnyAppCommand, ImportContactsCommand } from '../../../main/ets/core/model/AppCommand';
import { AnyAppEvent } from '../../../main/ets/core/model/AppEvent';
import { TdGatewayPort } from '../../../main/ets/domain/ports/TdGatewayPort';
import {
  ImportContactUseCase,
  parseImportContactResponse
} from '../../../main/ets/domain/usecases/importContact';
import { TdObject } from '../../../main/ets/models/TdTypes';

class FakeImportContactGateway implements TdGatewayPort {
  sentCommands: AnyAppCommand[] = [];
  private response: Object;

  constructor(response: Object) {
    this.response = response;
  }

  initialize(): Promise<void> {
    return Promise.resolve();
  }

  send(command: AnyAppCommand): Promise<Object> {
    this.sentCommands.push(command);
    return Promise.resolve(this.response);
  }

  subscribeUpdates(_handler: (event: AnyAppEvent) => void): () => void {
    return (): void => {};
  }

  getConnectionState(): 'connecting' | 'ready' | 'updating' | 'waitingForNetwork' {
    return 'ready';
  }

  destroy(): Promise<void> {
    return Promise.resolve();
  }
}

export default function importContactTest() {
  describe('ImportContact', () => {
    it('parses registered and unregistered contacts without inventing a user', 0, () => {
      const registered = parseImportContactResponse(TdObject.fromJSON(
        '{"@type":"importedContacts","user_ids":[42],"importer_count":[7]}'
      ));
      expect(registered?.userId ?? 0).assertEqual(42);
      expect(registered?.importerCount ?? 0).assertEqual(7);
      expect(registered?.isRegistered() ?? false).assertTrue();

      const unregistered = parseImportContactResponse(TdObject.fromJSON(
        '{"@type":"importedContacts","user_ids":[0],"importer_count":[13]}'
      ));
      expect(unregistered?.userId ?? -1).assertEqual(0);
      expect(unregistered?.isRegistered() ?? true).assertFalse();
    });

    it('normalizes one contact and sends importContacts', 0, async () => {
      const gateway = new FakeImportContactGateway(TdObject.fromJSON(
        '{"@type":"importedContacts","user_ids":[42],"importer_count":[0]}'
      ));
      const result = await new ImportContactUseCase(gateway).execute(' +123 ', ' Alice ', ' Smith ');

      expect(result.userId).assertEqual(42);
      expect(gateway.sentCommands.length).assertEqual(1);
      const command = gateway.sentCommands[0] as ImportContactsCommand;
      expect(command.type).assertEqual('importContacts');
      expect(command.payload.contacts.length).assertEqual(1);
      expect(command.payload.contacts[0].phoneNumber).assertEqual('+123');
      expect(command.payload.contacts[0].firstName).assertEqual('Alice');
      expect(command.payload.contacts[0].lastName).assertEqual('Smith');
    });

    it('rejects invalid local input before TDLib', 0, async () => {
      const gateway = new FakeImportContactGateway(TdObject.empty());
      let failed = false;
      try {
        await new ImportContactUseCase(gateway).execute('', '', '');
      } catch (_error) {
        failed = true;
      }
      expect(failed).assertTrue();
      expect(gateway.sentCommands.length).assertEqual(0);
    });

    it('rejects a malformed ImportedContacts result', 0, async () => {
      const gateway = new FakeImportContactGateway(TdObject.fromJSON(
        '{"@type":"importedContacts","user_ids":[],"importer_count":[]}'
      ));
      let failed = false;
      try {
        await new ImportContactUseCase(gateway).execute('+123', 'Alice');
      } catch (_error) {
        failed = true;
      }
      expect(failed).assertTrue();
    });
  });
}
