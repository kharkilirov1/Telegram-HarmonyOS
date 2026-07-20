const MEDIA_GEOMETRY_TRANSITION_PREFIX: string = 'tg_chat_media_';

export function albumMediaSourceId(primaryMessageId: string, memberMessageId: string, albumIndex: number): string {
  const normalizedMemberId = memberMessageId.trim();
  if (normalizedMemberId.length > 0) {
    return normalizedMemberId;
  }
  const normalizedPrimaryId = primaryMessageId.trim();
  const safePrimaryId = normalizedPrimaryId.length > 0 ? normalizedPrimaryId : '0';
  const safeIndex = Math.max(0, Math.floor(albumIndex));
  return safePrimaryId + '_album_' + safeIndex.toString();
}

export function mediaGeometryTransitionId(messageId: string): string {
  const normalizedMessageId = messageId.trim();
  return MEDIA_GEOMETRY_TRANSITION_PREFIX + (normalizedMessageId.length > 0 ? normalizedMessageId : '0');
}
