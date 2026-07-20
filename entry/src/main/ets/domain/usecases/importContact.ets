// Imports one contact by phone number.
// TDLib contract: importContacts(vector<importedContact>) -> ImportedContacts.

import {
  createImportContactsCommand,
  ImportedContactInput
} from '../../core/model/AppCommand';
import { UserId } from '../../core/model/EntityId';
import { TdObject } from '../../models/TdTypes';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const MAX_CONTACT_NAME_LENGTH = 64;

export class ImportContactResult {
  userId: UserId = 0;
  importerCount: number = 0;

  constructor(userId: UserId = 0, importerCount: number = 0) {
    this.userId = userId;
    this.importerCount = importerCount;
  }

  isRegistered(): boolean {
    return this.userId > 0;
  }
}

export function normalizeImportedContact(
  phoneNumber: string,
  firstName: string,
  lastName: string = ''
): ImportedContactInput {
  const normalizedPhone: string = phoneNumber.trim();
  const normalizedFirstName: string = firstName.trim();
  const normalizedLastName: string = lastName.trim();

  if (normalizedPhone.length === 0) {
    throw new Error('ImportContactUseCase: phone number is required');
  }
  if (normalizedFirstName.length === 0 || normalizedFirstName.length > MAX_CONTACT_NAME_LENGTH) {
    throw new Error('ImportContactUseCase: first name must contain 1-64 characters');
  }
  if (normalizedLastName.length > MAX_CONTACT_NAME_LENGTH) {
    throw new Error('ImportContactUseCase: last name must contain at most 64 characters');
  }

  return new ImportedContactInput(normalizedPhone, normalizedFirstName, normalizedLastName);
}

export function parseImportContactResponse(response: TdObject): ImportContactResult | undefined {
  if (response.getType() !== 'importedContacts') {
    return undefined;
  }

  const userIds: number[] = response.getNumberArray('user_ids');
  const importerCounts: number[] = response.getNumberArray('importer_count');
  if (userIds.length !== 1 || importerCounts.length !== 1) {
    return undefined;
  }

  const userId: number = Math.max(0, Math.trunc(userIds[0]));
  const importerCount: number = Math.max(0, Math.trunc(importerCounts[0]));
  return new ImportContactResult(userId, importerCount);
}

export class ImportContactUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async execute(
    phoneNumber: string,
    firstName: string,
    lastName: string = ''
  ): Promise<ImportContactResult> {
    const contact: ImportedContactInput = normalizeImportedContact(phoneNumber, firstName, lastName);
    const response = await this.gateway.send(createImportContactsCommand([contact]));
    if (!(response instanceof TdObject)) {
      throw new Error('Contact import failed');
    }

    const result: ImportContactResult | undefined = parseImportContactResponse(response);
    if (result === undefined) {
      throw new Error('Contact import failed');
    }
    return result;
  }
}

export function importContactUseCase(gateway: TdGatewayPort): ImportContactUseCase {
  return new ImportContactUseCase(gateway);
}
