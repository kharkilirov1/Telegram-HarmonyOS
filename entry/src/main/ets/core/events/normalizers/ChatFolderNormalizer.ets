// Chat folder normalizer — mirrors TDLib's folder list into one event.
//
// updateChatFolders (td_api.tl:9683) is the only source of truth: it carries the complete
// chatFolderInfo vector, the position of the main chat list and the tags flag. TDLib re-sends the
// whole vector on every change, so the reducer replaces state instead of diffing entries.

import { AnyAppEvent, createChatFoldersUpdatedEvent } from '../../model/AppEvent';
import { ChatFolderInfo } from '../../model/AppState';
import { TdObject } from '../../../models/TdTypes';
import { tdGetArray, tdGetBoolean, tdGetNumber, tdGetObject, tdGetString } from '../../../core/utils/tdAccessors';

function parseFolderIconName(raw: TdObject): string {
  const icon = tdGetObject(raw, 'icon');
  if (icon === undefined) {
    return '';
  }
  return tdGetString(icon, 'name');
}

function parseFolderTitle(raw: TdObject): string {
  const name = tdGetObject(raw, 'name');
  if (name === undefined) {
    return '';
  }
  const text = tdGetObject(name, 'text');
  if (text === undefined) {
    return '';
  }
  return tdGetString(text, 'text');
}

function parseChatFolderInfo(raw: TdObject): ChatFolderInfo {
  const folder = new ChatFolderInfo();
  folder.id = tdGetNumber(raw, 'id');
  folder.title = parseFolderTitle(raw);
  folder.iconName = parseFolderIconName(raw);
  folder.colorId = tdGetNumber(raw, 'color_id');
  folder.isShareable = tdGetBoolean(raw, 'is_shareable');
  return folder;
}

export function handleChatFolders(events: AnyAppEvent[], update: TdObject): void {
  const folders: ChatFolderInfo[] = [];
  for (const raw of tdGetArray(update, 'chat_folders')) {
    if (raw.getType() !== 'chatFolderInfo') {
      continue;
    }
    const folder = parseChatFolderInfo(raw);
    if (folder.id > 0) {
      folders.push(folder);
    }
  }
  const mainPosition = tdGetNumber(update, 'main_chat_list_position');
  const tagsEnabled = tdGetBoolean(update, 'are_tags_enabled');
  events.push(createChatFoldersUpdatedEvent(folders, mainPosition, tagsEnabled));
}

export function registerChatFolderHandlers(
  handlers: Map<string, (events: AnyAppEvent[], update: TdObject) => void>
): void {
  handlers.set('updateChatFolders', handleChatFolders);
}
