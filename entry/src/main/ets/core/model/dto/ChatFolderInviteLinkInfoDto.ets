// Chat folder invite-link info — preview before adding the folder (B7 / S13j).
// TDLib: checkChatFolderInviteLink (td_api.tl:12105), chatFolderInviteLinkInfo (:3130),
// chatFolderInfo (:3115).

import { TdObject as TdObjectType } from '../../../models/TdTypes';
import { TdObject } from '../../../models/TdTypes';

function readChatIdArray(td: TdObjectType, prop: string): number[] {
  const result: number[] = [];
  const items = td.getTopLevelRawItemArrayStrict(prop);
  if (items === undefined) {
    return result;
  }
  for (const raw of items) {
    if (raw === null) {
      continue;
    }
    const value = Number(raw);
    if (Number.isSafeInteger(value) && value !== 0) {
      result.push(value);
    }
  }
  return result;
}

export class ChatFolderInviteLinkInfoDto {
  folderId: number = 0;
  title: string = '';
  iconName: string = '';
  colorId: number = 0;
  isShareable: boolean = false;
  hasMyInviteLinks: boolean = false;
  missingChatIds: number[] = [];
  addedChatIds: number[] = [];
}

export function createChatFolderInviteLinkInfoFromTd(
  td: TdObjectType
): ChatFolderInviteLinkInfoDto | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'chatFolderInviteLinkInfo') {
    return undefined;
  }
  const rawInfo = td.getTopLevelObjectStrict('chat_folder_info');
  if (rawInfo === undefined) {
    return undefined;
  }
  const info = rawInfo;
  const dto = new ChatFolderInviteLinkInfoDto();
  const folderId = info.getTopLevelNumberStrict('id');
  dto.folderId = folderId !== undefined && Number.isSafeInteger(folderId) ? folderId : 0;
  const name = info.getTopLevelObjectStrict('name');
  const text = name === undefined ? undefined : name.getTopLevelObjectStrict('text');
  dto.title = text === undefined ? '' : (text.getTopLevelStringStrict('text') ?? '');
  const icon = info.getTopLevelObjectStrict('icon');
  dto.iconName = icon === undefined ? '' : (icon.getTopLevelStringStrict('name') ?? '');
  const colorId = info.getTopLevelNumberStrict('color_id');
  dto.colorId = colorId !== undefined && Number.isSafeInteger(colorId) ? colorId : 0;
  dto.isShareable = info.getTopLevelBooleanStrict('is_shareable') ?? false;
  dto.hasMyInviteLinks = info.getTopLevelBooleanStrict('has_my_invite_links') ?? false;
  dto.missingChatIds = readChatIdArray(td, 'missing_chat_ids');
  dto.addedChatIds = readChatIdArray(td, 'added_chat_ids');
  return dto;
}

export function createChatFolderInviteLinkInfoFromJson(text: string): ChatFolderInviteLinkInfoDto | undefined {
  return createChatFolderInviteLinkInfoFromTd(TdObject.fromJSON(text));
}
