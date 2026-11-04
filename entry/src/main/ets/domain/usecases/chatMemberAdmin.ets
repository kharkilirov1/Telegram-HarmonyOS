// Per-member moderation actions (G6).
// TDLib: setChatMemberStatus (td_api.tl:12281) with chatMemberStatusMember / Banned / Restricted.
// A restricted member stays in the chat but loses every send permission; 0 untilDate means forever.

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatId, UserId } from '../../core/model/EntityId';
import {
  ChatAdminRightsPayload,
  createGetChatMemberCommand,
  createSetChatMemberStatusCommand
} from '../../core/model/AppCommand';
import {
  ChatPermissionsDto,
  chatPermissionsToJson,
  createChatPermissionsFromTd
} from '../../core/model/dto/ChatPermissionsDto';
import { TdObject } from '../../models/TdTypes';
import { AppError, AppErrorKind } from '../../core/model/AppError';
import { TdGatewayPort } from '../ports/TdGatewayPort';

const DOMAIN = 0x0048;
const TAG = 'ChatMemberAdmin';

export type ChatMemberModerationAction = 'ban' | 'unban' | 'restrict' | 'promote' | 'demote';

export const MEMBER_ACTION_KINDS: string[] = ['member', 'banned', 'restricted', 'administrator'];

// iOS offers 1 hour / 1 day / 1 week / forever when restricting or banning; 0 means forever.
export const MODERATION_DURATION_SECONDS: number[] = [3600, 86400, 7 * 86400, 0];

export interface ModerationDurationOption {
  labelKey: string;
  fallback: string;
  seconds: number;
}

export const MODERATION_DURATION_OPTIONS: ModerationDurationOption[] = [
  { labelKey: 'moderation_duration_1h', fallback: '1 hour', seconds: 3600 },
  { labelKey: 'moderation_duration_1d', fallback: '1 day', seconds: 86400 },
  { labelKey: 'moderation_duration_1w', fallback: '1 week', seconds: 7 * 86400 },
  { labelKey: 'moderation_duration_forever', fallback: 'Forever', seconds: 0 }
];

// TDLib expects an absolute Unix timestamp; 0 is 'forever' for ban and restrict.
export function moderationUntilDate(nowSeconds: number, durationSeconds: number): number {
  if (!Number.isSafeInteger(nowSeconds) || nowSeconds < 0) {
    return 0;
  }
  if (!Number.isSafeInteger(durationSeconds) || durationSeconds <= 0) {
    return 0;
  }
  return nowSeconds + durationSeconds;
}

export function memberStatusKind(action: ChatMemberModerationAction): string {
  if (action === 'ban') {
    return 'banned';
  }
  if (action === 'restrict') {
    return 'restricted';
  }
  if (action === 'promote') {
    return 'administrator';
  }
  return 'member';
}

// Current moderation state of one member; the rights/restrict screens use it to pre-fill their toggles.
export class ChatMemberModerationState {
  statusKind: string = 'member';
  untilDate: number = 0;
  rights: ChatAdminRightsPayload = new ChatAdminRightsPayload();
  permissions: ChatPermissionsDto = new ChatPermissionsDto();
}

function rightsFromTd(td: TdObject): ChatAdminRightsPayload {
  const rights = new ChatAdminRightsPayload();
  rights.canManageChat = td.getTopLevelBooleanStrict('can_manage_chat') === true;
  rights.canChangeInfo = td.getTopLevelBooleanStrict('can_change_info') === true;
  rights.canPostMessages = td.getTopLevelBooleanStrict('can_post_messages') === true;
  rights.canEditMessages = td.getTopLevelBooleanStrict('can_edit_messages') === true;
  rights.canDeleteMessages = td.getTopLevelBooleanStrict('can_delete_messages') === true;
  rights.canInviteUsers = td.getTopLevelBooleanStrict('can_invite_users') === true;
  rights.canRestrictMembers = td.getTopLevelBooleanStrict('can_restrict_members') === true;
  rights.canPinMessages = td.getTopLevelBooleanStrict('can_pin_messages') === true;
  rights.canManageTopics = td.getTopLevelBooleanStrict('can_manage_topics') === true;
  rights.canPromoteMembers = td.getTopLevelBooleanStrict('can_promote_members') === true;
  rights.canManageVideoChats = td.getTopLevelBooleanStrict('can_manage_video_chats') === true;
  rights.canPostStories = td.getTopLevelBooleanStrict('can_post_stories') === true;
  rights.canEditStories = td.getTopLevelBooleanStrict('can_edit_stories') === true;
  rights.canDeleteStories = td.getTopLevelBooleanStrict('can_delete_stories') === true;
  rights.canManageDirectMessages = td.getTopLevelBooleanStrict('can_manage_direct_messages') === true;
  rights.isAnonymous = td.getTopLevelBooleanStrict('is_anonymous') === true;
  return rights;
}

export function parseMemberModerationState(td: TdObject): ChatMemberModerationState | undefined {
  if (td.getTopLevelStringStrict('@type') !== 'chatMember') {
    return undefined;
  }
  const status = td.getTopLevelObjectStrict('status');
  if (status === undefined) {
    return undefined;
  }
  const state = new ChatMemberModerationState();
  const type = status.getTopLevelStringStrict('@type') ?? '';
  if (type === 'chatMemberStatusAdministrator') {
    state.statusKind = 'administrator';
    const rights = status.getTopLevelObjectStrict('rights');
    if (rights !== undefined) {
      state.rights = rightsFromTd(rights);
    }
    return state;
  }
  if (type === 'chatMemberStatusRestricted') {
    state.statusKind = 'restricted';
    const until = status.getTopLevelNumberStrict('restricted_until_date');
    if (typeof until === 'number' && Number.isSafeInteger(until) && until > 0) {
      state.untilDate = until;
    }
    const permissions = status.getTopLevelObjectStrict('permissions');
    if (permissions !== undefined) {
      const parsed = createChatPermissionsFromTd(permissions);
      if (parsed !== undefined) {
        state.permissions = parsed;
      }
    }
    return state;
  }
  if (type === 'chatMemberStatusBanned') {
    state.statusKind = 'banned';
    const until = status.getTopLevelNumberStrict('banned_until_date');
    if (typeof until === 'number' && Number.isSafeInteger(until) && until > 0) {
      state.untilDate = until;
    }
    return state;
  }
  if (type === 'chatMemberStatusCreator') {
    state.statusKind = 'creator';
    return state;
  }
  state.statusKind = 'member';
  return state;
}

export class ChatMemberAdminUseCase {
  private gateway: TdGatewayPort;

  constructor(gateway: TdGatewayPort) {
    this.gateway = gateway;
  }

  async loadState(chatId: ChatId, userId: UserId): Promise<ChatMemberModerationState> {
    this.validateChatIdAndUser(chatId, userId);
    try {
      const response = await this.gateway.send(createGetChatMemberCommand(chatId, userId)) as TdObject;
      const state = parseMemberModerationState(response);
      if (state === undefined) {
        throw new AppError(AppErrorKind.UNKNOWN, 'Unsupported member response', 'Unexpected @type', 0,
          false);
      }
      return state;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Member state load failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to load the member state', err.message, 0, true);
    }
  }

  async apply(chatId: ChatId, userId: UserId, action: ChatMemberModerationAction,
    untilDate: number = 0,
    rights: ChatAdminRightsPayload = new ChatAdminRightsPayload(),
    permissionsJson: string = ''): Promise<void> {
    this.validate(chatId, userId, untilDate);
    const statusKind: string = memberStatusKind(action);
    try {
      await this.gateway.send(createSetChatMemberStatusCommand(chatId, userId, statusKind, untilDate,
        rights, permissionsJson));
      hilog.info(DOMAIN, TAG, 'Member status updated: %{public}s', statusKind);
    } catch (error) {
      const err = error as Error;
      hilog.error(DOMAIN, TAG, 'Member status update failed: %{public}s', err.message);
      throw new AppError(AppErrorKind.UNKNOWN, 'Failed to update the member', err.message, 0, true);
    }
  }

  private validateChatIdAndUser(chatId: ChatId, userId: UserId): void {
    if (!Number.isSafeInteger(chatId) || chatId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400,
        false);
    }
    if (!Number.isSafeInteger(userId) || userId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid userId', 'Input validation failed', 400,
        false);
    }
  }

  private validate(chatId: ChatId, userId: UserId, untilDate: number): void {
    if (!Number.isSafeInteger(chatId) || chatId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid chatId', 'Input validation failed', 400,
        false);
    }
    if (!Number.isSafeInteger(userId) || userId <= 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid userId', 'Input validation failed', 400,
        false);
    }
    if (!Number.isSafeInteger(untilDate) || untilDate < 0) {
      throw new AppError(AppErrorKind.TDLIB_ERROR, 'Invalid until date', 'Input validation failed',
        400, false);
    }
  }
}

export function createChatMemberAdminUseCase(gateway: TdGatewayPort): ChatMemberAdminUseCase {
  return new ChatMemberAdminUseCase(gateway);
}
