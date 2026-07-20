// Bot menu metadata for the iOS-style leading composer pill.

import { createGetUserFullInfoCommand } from '../../core/model/AppCommand';
import { tdGetArray, tdGetObject, tdGetString } from '../../core/utils/tdAccessors';
import { getTdGatewayAdapter } from '../../infra/td/adapter/TdGatewayAdapter';
import { TdObject } from '../../models/TdTypes';

export class BotMenuCommandEntry {
  command: string = '';
  description: string = '';
}

export class BotMenuInfo {
  isAvailable: boolean = false;
  title: string = '';
  url: string = '';
  commands: BotMenuCommandEntry[] = [];
}

export function parseBotMenuInfo(response: TdObject): BotMenuInfo {
  const result = new BotMenuInfo();
  if (tdGetString(response, '@type') !== 'userFullInfo') {
    return result;
  }
  const botInfo = tdGetObject(response, 'bot_info');
  if (!botInfo.hasType()) {
    return result;
  }
  const menuButton = tdGetObject(botInfo, 'menu_button');
  result.title = tdGetString(menuButton, 'text');
  result.url = tdGetString(menuButton, 'url');
  const commands = tdGetArray(botInfo, 'commands');
  for (const commandObject of commands) {
    const command = tdGetString(commandObject, 'command').trim();
    if (command.length === 0) {
      continue;
    }
    const entry = new BotMenuCommandEntry();
    entry.command = command;
    entry.description = tdGetString(commandObject, 'description');
    result.commands.push(entry);
  }
  result.isAvailable = result.url.length > 0 || result.commands.length > 0;
  return result;
}

export async function loadBotMenuInfo(userId: number): Promise<BotMenuInfo> {
  if (userId <= 0) {
    return new BotMenuInfo();
  }
  const response = await getTdGatewayAdapter().send(createGetUserFullInfoCommand(userId)) as TdObject;
  return parseBotMenuInfo(response);
}
