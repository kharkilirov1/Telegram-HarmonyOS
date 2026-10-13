import { Chat } from '../../../core/model/AppState';
import { GroupAccessDto, GroupSendPermissionsDto, SupergroupBoostsDto } from '../../../core/model/dto/GroupAccessDto';

export type ChatInputPanelKind = 'composer' | 'mute' | 'unmute' | 'join' | 'restricted' | 'banned' | 'unknown';

function permitsKind(permissions: GroupSendPermissionsDto | undefined, kind: string): boolean {
  if (permissions === undefined) return false;
  switch (kind) {
    case 'text': return permissions.canSendBasicMessages === true;
    case 'audio': return permissions.canSendAudios === true;
    case 'document': return permissions.canSendDocuments === true;
    case 'photo': return permissions.canSendPhotos === true;
    case 'video': return permissions.canSendVideos === true;
    case 'videoNote': return permissions.canSendVideoNotes === true;
    case 'voice': return permissions.canSendVoiceNotes === true;
    case 'poll': return permissions.canSendPolls === true;
    case 'other': return permissions.canSendOtherMessages === true;
    default: return false;
  }
}

// iOS ChatInterfaceStateInputPanels.swift:234-255,351-365. Broadcast posting
// rights belong to the current member, never to list order or default permissions.
export function selectChatInputPanel(chat: Chat, access?: GroupAccessDto,
  isEditing: boolean = false, sendKind: string = '', boosts?: SupergroupBoostsDto): ChatInputPanelKind {
  let kinds: string[] = ['text', 'audio', 'document', 'photo', 'video', 'videoNote', 'voice', 'poll', 'other'];
  if (sendKind === 'attachment') {
    kinds = ['photo', 'video', 'document'];
  } else if (sendKind === 'media') {
    kinds = ['photo', 'video', 'document', 'voice'];
  } else if (sendKind.length > 0) {
    if (kinds.indexOf(sendKind) < 0) return 'restricted';
    kinds = [sendKind];
  }
  if (chat.type === 'group') {
    if (!access || access.kind !== 'basicGroup' || !Number.isSafeInteger(chat.basicGroupId) || chat.basicGroupId <= 0 ||
      access.groupId !== chat.basicGroupId || access.role === 'unknown' || typeof access.isActive !== 'boolean') return 'unknown';
    // iOS basic-group Removed/Left uses DeleteChatInputPanel, not channel Join.
    // Until that destructive action has its own acceptance, show unavailable.
    if (!access.isActive || !access.isMember || access.role === 'banned') return 'banned';
    if (access.role === 'creator' || access.role === 'administrator') return 'composer';
    // iOS TelegramGroup.hasPermission(.sendSomething): any allowed send kind
    // retains the composer. A caption belongs to its media, not to text rights.
    if (chat.sendPermissions === undefined) return 'unknown';
    for (let i = 0; i < kinds.length; i++) {
      if (permitsKind(chat.sendPermissions, kinds[i]) &&
        (access.role !== 'restricted' || permitsKind(access.permissions, kinds[i]))) return 'composer';
    }
    return 'restricted';
  }
  if (chat.type === 'supergroup') {
    if (!access || access.kind !== 'supergroup' || !Number.isSafeInteger(chat.supergroupId) || chat.supergroupId <= 0 ||
      access.groupId !== chat.supergroupId || access.role === 'unknown') return 'unknown';
    if (access.role === 'banned') return 'banned';
    if (!access.isMember) return 'join';
    if (access.role === 'creator' || access.role === 'administrator') return 'composer';
    const knownBoosts = boosts !== undefined && boosts.groupId === chat.supergroupId &&
      Number.isInteger(boosts.myBoostCount) && boosts.myBoostCount >= 0 && boosts.myBoostCount <= 2147483647 &&
      Number.isInteger(boosts.unrestrictBoostCount) && boosts.unrestrictBoostCount >= 0 && boosts.unrestrictBoostCount <= 2147483647;
    // TDLib DialogParticipant::apply_restrictions / ChatManager::get_channel_permissions:
    // qualifying boosts bypass defaults, never the user's individual restrictions.
    // Missing AppStore FullInfo is NOT proof that TDLib's internal cache is empty.
    const isBooster = knownBoosts && boosts !== undefined && boosts.unrestrictBoostCount > 0 &&
      boosts.myBoostCount >= boosts.unrestrictBoostCount;
    let needsBoosts = false;
    for (let i = 0; i < kinds.length; i++) {
      const individualAllowed = access.role !== 'restricted' || permitsKind(access.permissions, kinds[i]);
      if (!individualAllowed) continue;
      if (isBooster || permitsKind(chat.sendPermissions, kinds[i])) return 'composer';
      needsBoosts = true;
    }
    if (needsBoosts && (chat.sendPermissions === undefined || !knownBoosts)) return 'unknown';
    return 'restricted';
  }
  if (chat.type !== 'channel') {
    if (chat.type === 'private' || chat.type === 'secret' || chat.peerUserId > 0) return 'composer';
    return chat.canSendBasicMessages ? 'composer' : 'restricted';
  }
  if (!access || access.kind !== 'supergroup' || !Number.isSafeInteger(chat.supergroupId) || chat.supergroupId <= 0 ||
    access.groupId !== chat.supergroupId || access.role === 'unknown') return 'unknown';
  if (access.role === 'banned') return 'banned';
  if (!access.isMember) return 'join';
  if (access.role === 'creator' || (access.role === 'administrator' &&
    (access.canPostMessages || (isEditing && access.canEditMessages)))) return 'composer';
  return chat.muteForSeconds > 0 ? 'unmute' : 'mute';
}

// Hydrate only when a currently unavailable boost snapshot could enable a kind.
// The overall panel may already be composer (e.g. text allowed, media unknown).
export function needsSupergroupBoosts(chat: Chat, access?: GroupAccessDto, boosts?: SupergroupBoostsDto): boolean {
  if (chat.type !== 'supergroup' || chat.sendPermissions === undefined) return false;
  const kinds: string[] = ['text', 'audio', 'document', 'photo', 'video', 'videoNote', 'voice', 'poll', 'other'];
  for (let i = 0; i < kinds.length; i++) {
    if (selectChatInputPanel(chat, access, false, kinds[i], boosts) === 'unknown') return true;
  }
  return false;
}
