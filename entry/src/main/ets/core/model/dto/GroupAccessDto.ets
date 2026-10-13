// Current user's group status, independent of chat list positions/default permissions.
// TDLib: chatMemberStatus*, basicGroup.status and supergroup.status in td_api.tl.
import { TdObject } from '../../utils/tdAccessors';
import { getSlowmodeElapsedMs } from '../../utils/SlowmodeClock';

export type GroupKind = 'supergroup' | 'basicGroup';
export type GroupMemberRole = 'unknown' | 'creator' | 'administrator' | 'member' | 'restricted' | 'left' | 'banned';

// Immutable authoritative FullInfo receipt; consumers age this anchor rather
// than restarting the server-relative duration on each store/UI rebuild.
export class SupergroupSlowmodeDto {
  groupId: number = 0;
  delaySeconds: number = 0;
  expiresInSeconds: number = 0;
  receivedElapsedMs: number = 0;

  clone(): SupergroupSlowmodeDto {
    const copy = new SupergroupSlowmodeDto();
    copy.groupId = this.groupId;
    copy.delaySeconds = this.delaySeconds;
    copy.expiresInSeconds = this.expiresInSeconds;
    copy.receivedElapsedMs = this.receivedElapsedMs;
    return copy;
  }
}

export function createSupergroupSlowmodeDtoFromTd(td: TdObject, groupId: number,
  receivedElapsedMs: number = getSlowmodeElapsedMs()): SupergroupSlowmodeDto | undefined {
  if (!Number.isSafeInteger(groupId) || groupId <= 0 ||
    td.getTopLevelStringStrict('@type') !== 'supergroupFullInfo') return undefined;
  const delay = td.getTopLevelNumberStrict('slow_mode_delay');
  const expires = td.getTopLevelNumberStrict('slow_mode_delay_expires_in');
  if (typeof delay !== 'number' || !Number.isInteger(delay) || delay < 0 || delay > 3600 ||
    typeof expires !== 'number' || !Number.isFinite(expires) || expires < 0 || expires > 3601 ||
    !Number.isFinite(receivedElapsedMs) || receivedElapsedMs < 0) return undefined;
  const snapshot = new SupergroupSlowmodeDto();
  snapshot.groupId = groupId;
  snapshot.delaySeconds = delay;
  snapshot.expiresInSeconds = delay === 0 ? 0 : expires;
  snapshot.receivedElapsedMs = receivedElapsedMs;
  return snapshot;
}

// FullInfo has no own group ID. Direct responses use the captured request ID;
// updates use their strict outer supergroup_id. Absence is not a zero snapshot.
export class SupergroupBoostsDto {
  groupId: number = 0;
  myBoostCount: number = 0;
  unrestrictBoostCount: number = 0;

  clone(): SupergroupBoostsDto {
    const copy = new SupergroupBoostsDto();
    copy.groupId = this.groupId;
    copy.myBoostCount = this.myBoostCount;
    copy.unrestrictBoostCount = this.unrestrictBoostCount;
    return copy;
  }
}

export function createSupergroupBoostsDtoFromTd(td: TdObject, groupId: number): SupergroupBoostsDto | undefined {
  if (!Number.isSafeInteger(groupId) || groupId <= 0 ||
    td.getTopLevelStringStrict('@type') !== 'supergroupFullInfo') return undefined;
  const count = td.getTopLevelNumberStrict('my_boost_count');
  const threshold = td.getTopLevelNumberStrict('unrestrict_boost_count');
  if (typeof count !== 'number' || !Number.isInteger(count) || count < 0 || count > 2147483647 ||
    typeof threshold !== 'number' || !Number.isInteger(threshold) || threshold < 0 || threshold > 2147483647) return undefined;
  const boosts = new SupergroupBoostsDto();
  boosts.groupId = groupId;
  boosts.myBoostCount = count;
  boosts.unrestrictBoostCount = threshold;
  return boosts;
}

// Sending subset of TDLib chatPermissions, not effective permissions. Group
// defaults, membership and admin exceptions must be resolved by the consumer.
export class GroupSendPermissionsDto {
  canSendBasicMessages: boolean = false;
  canSendAudios: boolean = false;
  canSendDocuments: boolean = false;
  canSendPhotos: boolean = false;
  canSendVideos: boolean = false;
  canSendVideoNotes: boolean = false;
  canSendVoiceNotes: boolean = false;
  canSendPolls: boolean = false;
  canSendOtherMessages: boolean = false;

  static fromTd(td: TdObject): GroupSendPermissionsDto {
    const permissions = new GroupSendPermissionsDto();
    // No coercion or nested fallback. A missing/invalid bit never grants a send.
    permissions.canSendBasicMessages = td.getTopLevelBooleanStrict('can_send_basic_messages') === true;
    permissions.canSendAudios = td.getTopLevelBooleanStrict('can_send_audios') === true;
    permissions.canSendDocuments = td.getTopLevelBooleanStrict('can_send_documents') === true;
    permissions.canSendPhotos = td.getTopLevelBooleanStrict('can_send_photos') === true;
    permissions.canSendVideos = td.getTopLevelBooleanStrict('can_send_videos') === true;
    permissions.canSendVideoNotes = td.getTopLevelBooleanStrict('can_send_video_notes') === true;
    permissions.canSendVoiceNotes = td.getTopLevelBooleanStrict('can_send_voice_notes') === true;
    permissions.canSendPolls = td.getTopLevelBooleanStrict('can_send_polls') === true;
    permissions.canSendOtherMessages = td.getTopLevelBooleanStrict('can_send_other_messages') === true;
    return permissions;
  }

  clone(): GroupSendPermissionsDto {
    const copy = new GroupSendPermissionsDto();
    copy.canSendBasicMessages = this.canSendBasicMessages;
    copy.canSendAudios = this.canSendAudios;
    copy.canSendDocuments = this.canSendDocuments;
    copy.canSendPhotos = this.canSendPhotos;
    copy.canSendVideos = this.canSendVideos;
    copy.canSendVideoNotes = this.canSendVideoNotes;
    copy.canSendVoiceNotes = this.canSendVoiceNotes;
    copy.canSendPolls = this.canSendPolls;
    copy.canSendOtherMessages = this.canSendOtherMessages;
    return copy;
  }
}

export class GroupAccessDto {
  groupId: number = 0;
  kind: GroupKind = 'supergroup';
  role: GroupMemberRole = 'unknown';
  isMember: boolean = false;
  // basicGroup.is_active: an upgraded/deactivated group cannot send, even as
  // creator/admin. Supergroups do not have this field and keep the neutral true.
  isActive: boolean = true;
  // Missing/malformed bits are unavailable, never an authoritative disable.
  isSlowModeEnabled?: boolean;
  // Channel administrator rights, NOT a group's default can_send_basic_messages.
  canPostMessages: boolean = false;
  canEditMessages: boolean = false;
  // Present only for restricted status with an actual permissions object.
  // Undefined is unavailable, never unrestricted. Stored values are deep-cloned.
  permissions?: GroupSendPermissionsDto;
}

export function createGroupAccessDtoFromTd(td: TdObject, kind: GroupKind): GroupAccessDto | undefined {
  if (td.getTopLevelStringStrict('@type') !== kind) return undefined;
  // td_json_client.h: int53 is a JSON Number, unlike int64/string fields.
  const groupId = td.getTopLevelNumberStrict('id');
  if (typeof groupId !== 'number' || !Number.isSafeInteger(groupId) || groupId <= 0) return undefined;

  const status = td.getTopLevelObjectStrict('status');
  if (status === undefined) return undefined;
  const access = new GroupAccessDto();
  access.groupId = groupId;
  access.kind = kind;
  if (kind === 'supergroup') {
    access.isSlowModeEnabled = td.getTopLevelBooleanStrict('is_slow_mode_enabled');
  }
  if (kind === 'basicGroup') {
    const isActive = td.getTopLevelBooleanStrict('is_active');
    if (typeof isActive !== 'boolean') return undefined;
    access.isActive = isActive;
  }
  switch (status.getTopLevelStringStrict('@type')) {
    case 'chatMemberStatusCreator': {
      const isMember = status.getTopLevelBooleanStrict('is_member');
      if (typeof isMember !== 'boolean') return undefined;
      access.role = 'creator';
      access.isMember = isMember;
      access.canPostMessages = isMember;
      access.canEditMessages = isMember;
      break;
    }
    case 'chatMemberStatusAdministrator': {
      const rights = status.getTopLevelObjectStrict('rights');
      access.role = 'administrator';
      access.isMember = true;
      access.canPostMessages = rights?.getTopLevelBooleanStrict('can_post_messages') === true;
      access.canEditMessages = rights?.getTopLevelBooleanStrict('can_edit_messages') === true;
      break;
    }
    case 'chatMemberStatusMember':
      access.role = 'member';
      access.isMember = true;
      break;
    case 'chatMemberStatusRestricted': {
      const isMember = status.getTopLevelBooleanStrict('is_member');
      if (typeof isMember !== 'boolean') return undefined;
      access.role = 'restricted';
      access.isMember = isMember;
      const permissions = status.getTopLevelObjectStrict('permissions');
      if (permissions !== undefined) access.permissions = GroupSendPermissionsDto.fromTd(permissions);
      break;
    }
    case 'chatMemberStatusLeft':
      access.role = 'left';
      break;
    case 'chatMemberStatusBanned':
      access.role = 'banned';
      break;
    default:
      // Missing/unsupported status is not an authoritative revocation of known access.
      return undefined;
  }
  return access;
}
