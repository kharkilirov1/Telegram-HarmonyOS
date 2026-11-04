// Chat administrators (S12i).
// TDLib: getChatAdministrators (td_api.tl:12315) -> chatAdministrators (:2204) with chatAdministrator
// entries (:2210) that carry only user_id, custom_title and is_owner — names come from the users store.

import { TdObject as TdObjectType } from '../../../models/TdTypes';

export class ChatAdministratorDto {
  userId: number = 0;
  customTitle: string = '';
  isOwner: boolean = false;
}

export class ChatAdministratorsDto {
  administrators: ChatAdministratorDto[] = [];
}

export function createChatAdministratorsFromTd(td: TdObjectType): ChatAdministratorsDto | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'chatAdministrators') {
    return undefined;
  }
  const result = new ChatAdministratorsDto();
  const raw = td.getTopLevelRawItemArrayStrict('administrators');
  if (raw === undefined) {
    return result;
  }
  for (const entry of raw) {
    if (entry === null) {
      continue;
    }
    const item = TdObjectType.fromJSON(entry);
    if (item.getTopLevelStringStrict('@type') !== 'chatAdministrator') {
      continue;
    }
    const userId = item.getTopLevelNumberStrict('user_id') ?? 0;
    if (!Number.isSafeInteger(userId) || userId <= 0) {
      continue;
    }
    const dto = new ChatAdministratorDto();
    dto.userId = userId;
    dto.customTitle = item.getTopLevelStringStrict('custom_title') ?? '';
    dto.isOwner = item.getTopLevelBooleanStrict('is_owner') ?? false;
    result.administrators.push(dto);
  }
  return result;
}
