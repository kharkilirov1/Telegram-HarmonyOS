// Full chat folder DTO — getChatFolder (td_api.tl:12051) returns the whole ChatFolder (:3106),
// including the exclude/include flags and the chat id vectors that chatFolderInfo omits.
// Editing must start from these values; otherwise renaming a folder would silently reset its filters.

import { TdObject as TdObjectType } from '../../../models/TdTypes';

export class ChatFolderDto {
  title: string = '';
  iconName: string = '';
  colorId: number = 0;
  isShareable: boolean = false;
  pinnedChatIds: number[] = [];
  includedChatIds: number[] = [];
  excludedChatIds: number[] = [];
  excludeMuted: boolean = false;
  excludeRead: boolean = false;
  excludeArchived: boolean = false;
  includeContacts: boolean = false;
  includeNonContacts: boolean = false;
  includeBots: boolean = false;
  includeGroups: boolean = false;
  includeChannels: boolean = false;
}

function readChatIdArray(td: TdObjectType, prop: string): number[] {
  const ids: number[] = [];
  const rawItems = td.getTopLevelRawItemArrayStrict(prop);
  if (rawItems === undefined) {
    return ids;
  }
  for (const raw of rawItems) {
    if (raw === null) {
      continue;
    }
    const value = Number(raw);
    if (Number.isSafeInteger(value) && value !== 0) {
      ids.push(value);
    }
  }
  return ids;
}

export function createChatFolderDtoFromTd(td: TdObjectType): ChatFolderDto | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'chatFolder') {
    return undefined;
  }
  const dto = new ChatFolderDto();
  const name = td.getTopLevelObjectStrict('name');
  const text = name === undefined ? undefined : name.getTopLevelObjectStrict('text');
  dto.title = text === undefined ? '' : (text.getTopLevelStringStrict('text') ?? '');
  const icon = td.getTopLevelObjectStrict('icon');
  dto.iconName = icon === undefined ? '' : (icon.getTopLevelStringStrict('name') ?? '');
  const colorId = td.getTopLevelNumberStrict('color_id');
  dto.colorId = colorId !== undefined && Number.isSafeInteger(colorId) ? colorId : 0;
  dto.isShareable = td.getTopLevelBooleanStrict('is_shareable') ?? false;
  dto.pinnedChatIds = readChatIdArray(td, 'pinned_chat_ids');
  dto.includedChatIds = readChatIdArray(td, 'included_chat_ids');
  dto.excludedChatIds = readChatIdArray(td, 'excluded_chat_ids');
  dto.excludeMuted = td.getTopLevelBooleanStrict('exclude_muted') ?? false;
  dto.excludeRead = td.getTopLevelBooleanStrict('exclude_read') ?? false;
  dto.excludeArchived = td.getTopLevelBooleanStrict('exclude_archived') ?? false;
  dto.includeContacts = td.getTopLevelBooleanStrict('include_contacts') ?? false;
  dto.includeNonContacts = td.getTopLevelBooleanStrict('include_non_contacts') ?? false;
  dto.includeBots = td.getTopLevelBooleanStrict('include_bots') ?? false;
  dto.includeGroups = td.getTopLevelBooleanStrict('include_groups') ?? false;
  dto.includeChannels = td.getTopLevelBooleanStrict('include_channels') ?? false;
  return dto;
}
