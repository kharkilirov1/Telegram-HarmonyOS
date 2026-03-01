// Application commands - typed commands to send to TDLib
// These are domain-specific commands that usecases produce

import { ChatId, UserId, MessageId } from './EntityId';

// Base command class
export class AppCommand {
  type: string = '';
}

// Payload classes
export class SetPhoneNumberPayload {
  phoneNumber: string = '';
}

export class CheckAuthCodePayload {
  code: string = '';
}

export class CheckAuthPasswordPayload {
  password: string = '';
}

export class LoadChatsPayload {
  limit: number = 20;
}

export class OpenChatPayload {
  chatId: ChatId = 0;
}

export class SendMessagePayload {
  chatId: ChatId = 0;
  text: string = '';
  replyToMessageId: MessageId = '0';
}

export class ViewMessagesPayload {
  chatId: ChatId = 0;
  messageIds: MessageId[] = [];
}

// Command classes
export class SetPhoneNumberCommand extends AppCommand {
  type: string = 'setPhoneNumber';
  payload: SetPhoneNumberPayload = new SetPhoneNumberPayload();
}

export class CheckAuthCodeCommand extends AppCommand {
  type: string = 'checkAuthCode';
  payload: CheckAuthCodePayload = new CheckAuthCodePayload();
}

export class CheckAuthPasswordCommand extends AppCommand {
  type: string = 'checkAuthPassword';
  payload: CheckAuthPasswordPayload = new CheckAuthPasswordPayload();
}

export class ResendAuthCodeCommand extends AppCommand {
  type: string = 'resendAuthCode';
}

export class LoadChatsCommand extends AppCommand {
  type: string = 'loadChats';
  payload: LoadChatsPayload = new LoadChatsPayload();
}

export class OpenChatCommand extends AppCommand {
  type: string = 'openChat';
  payload: OpenChatPayload = new OpenChatPayload();
}

export class SendMessageCommand extends AppCommand {
  type: string = 'sendMessage';
  payload: SendMessagePayload = new SendMessagePayload();
}

export class ViewMessagesCommand extends AppCommand {
  type: string = 'viewMessages';
  payload: ViewMessagesPayload = new ViewMessagesPayload();
}

export class LogoutCommand extends AppCommand {
  type: string = 'logout';
}

// Unified type for all commands
export type AnyAppCommand =
  | SetPhoneNumberCommand
  | CheckAuthCodeCommand
  | CheckAuthPasswordCommand
  | ResendAuthCodeCommand
  | LoadChatsCommand
  | OpenChatCommand
  | SendMessageCommand
  | ViewMessagesCommand
  | LogoutCommand;

// Helper functions to create commands
export function createSetPhoneNumberCommand(phoneNumber: string): SetPhoneNumberCommand {
  const cmd = new SetPhoneNumberCommand();
  cmd.payload.phoneNumber = phoneNumber;
  return cmd;
}

export function createCheckAuthCodeCommand(code: string): CheckAuthCodeCommand {
  const cmd = new CheckAuthCodeCommand();
  cmd.payload.code = code;
  return cmd;
}

export function createCheckAuthPasswordCommand(password: string): CheckAuthPasswordCommand {
  const cmd = new CheckAuthPasswordCommand();
  cmd.payload.password = password;
  return cmd;
}

export function createResendAuthCodeCommand(): ResendAuthCodeCommand {
  return new ResendAuthCodeCommand();
}

export function createLoadChatsCommand(limit: number = 20): LoadChatsCommand {
  const cmd = new LoadChatsCommand();
  cmd.payload.limit = limit;
  return cmd;
}

export function createOpenChatCommand(chatId: ChatId): OpenChatCommand {
  const cmd = new OpenChatCommand();
  cmd.payload.chatId = chatId;
  return cmd;
}

export function createSendMessageCommand(
  chatId: ChatId,
  text: string,
  replyToMessageId?: MessageId
): SendMessageCommand {
  const cmd = new SendMessageCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.text = text;
  cmd.payload.replyToMessageId = replyToMessageId || '0';
  return cmd;
}

export function createViewMessagesCommand(chatId: ChatId, messageIds: MessageId[]): ViewMessagesCommand {
  const cmd = new ViewMessagesCommand();
  cmd.payload.chatId = chatId;
  cmd.payload.messageIds = messageIds;
  return cmd;
}

export function createLogoutCommand(): LogoutCommand {
  return new LogoutCommand();
}
