// Recommended chat folders — "Recommended folders" section of the folder screen (B7 / S13i).
// TDLib: getRecommendedChatFolders (td_api.tl:12075), recommendedChatFolder (:3133),
// recommendedChatFolders (:3136). A recommended folder is added by creating a normal folder from its
// chatFolder payload, so no invite link is involved here.

import { TdObject as TdObjectType } from '../../../models/TdTypes';
import { ChatFolderDto, createChatFolderDtoFromTd } from './ChatFolderDto';

export class RecommendedChatFolderDto {
  folder: ChatFolderDto = new ChatFolderDto();
  description: string = '';
}

export function createRecommendedChatFolderFromTd(td: TdObjectType): RecommendedChatFolderDto | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'recommendedChatFolder') {
    return undefined;
  }
  const rawFolder = td.getTopLevelObjectStrict('folder');
  if (rawFolder === undefined) {
    return undefined;
  }
  const dto = new RecommendedChatFolderDto();
  const parsed: ChatFolderDto | undefined = createChatFolderDtoFromTd(rawFolder);
  if (parsed === undefined) {
    return undefined;
  }
  dto.folder = parsed;
  dto.description = td.getTopLevelStringStrict('description') ?? '';
  return dto.folder.title.length > 0 ? dto : undefined;
}

export class RecommendedChatFoldersDto {
  folders: RecommendedChatFolderDto[] = [];
}

export function createRecommendedChatFoldersFromTd(td: TdObjectType): RecommendedChatFoldersDto {
  const dto = new RecommendedChatFoldersDto();
  if (td.getTopLevelStringStrict('@type') !== 'recommendedChatFolders') {
    return dto;
  }
  const rawItems = td.getTopLevelRawItemArrayStrict('chat_folders');
  if (rawItems === undefined) {
    return dto;
  }
  for (const raw of rawItems) {
    if (raw === null) {
      continue;
    }
    const item = createRecommendedChatFolderFromTd(TdObjectType.fromJSON(raw));
    if (item !== undefined) {
      dto.folders.push(item);
    }
  }
  return dto;
}
