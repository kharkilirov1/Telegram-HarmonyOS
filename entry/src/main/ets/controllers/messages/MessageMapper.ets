import { Message, MessageReaction } from '../../models/Message';
import { safeString, tdType } from '../../models/TdTypes';
import { TdMessageInteractionInfo, TdMessageReactionInfo } from './TdUpdateParser';

export interface ChatActionState {
  isActive: boolean;
  description: string;
}

export function applyInteractionInfo(msg: Message, info: TdMessageInteractionInfo): void {
  const reactions: TdMessageReactionInfo[] | undefined = info.reactions;
  if (!reactions) {
    msg.reactions = [];
    return;
  }

  const mappedReactions: MessageReaction[] = [];
  for (const reactionInfo of reactions) {
    const count: number = reactionInfo.total_count || 0;
    if (count <= 0) continue;

    const emoji: string = resolveReactionEmoji(reactionInfo.reaction);
    if (emoji.length === 0) continue;

    const mapped: MessageReaction = {
      emoji: emoji,
      count: count,
      isMine: reactionInfo.is_chosen === true
    };
    mappedReactions.push(mapped);
  }

  msg.reactions = mappedReactions;
}

function resolveReactionEmoji(reaction: Record<string, Object> | undefined): string {
  if (!reaction) return '';

  const reactionType: string = tdType(reaction);
  if (reactionType === 'reactionTypeEmoji') {
    return safeString(reaction['emoji']);
  }
  if (reactionType === 'reactionTypeCustomEmoji') {
    return '⭐';
  }
  if (reactionType === 'reactionTypePaid') {
    return '⭐';
  }
  return '';
}

export function mapChatActionState(actionType: string): ChatActionState {
  switch (actionType) {
    case 'chatActionTyping':
      return { isActive: true, description: 'typing...' };
    case 'chatActionRecordingVoiceNote':
      return { isActive: true, description: 'recording voice...' };
    case 'chatActionUploadingVoiceNote':
      return { isActive: true, description: 'uploading voice...' };
    case 'chatActionRecordingVideoNote':
      return { isActive: true, description: 'recording video message...' };
    case 'chatActionUploadingVideoNote':
      return { isActive: true, description: 'uploading video message...' };
    case 'chatActionRecordingVideo':
      return { isActive: true, description: 'recording video...' };
    case 'chatActionUploadingVideo':
      return { isActive: true, description: 'uploading video...' };
    case 'chatActionUploadingPhoto':
      return { isActive: true, description: 'uploading photo...' };
    case 'chatActionUploadingDocument':
      return { isActive: true, description: 'uploading file...' };
    case 'chatActionChoosingSticker':
      return { isActive: true, description: 'choosing sticker...' };
    case 'chatActionChoosingLocation':
      return { isActive: true, description: 'choosing location...' };
    case 'chatActionChoosingContact':
      return { isActive: true, description: 'choosing contact...' };
    case 'chatActionStartPlayingGame':
      return { isActive: true, description: 'playing game...' };
    case 'chatActionWatchingAnimations':
      return { isActive: true, description: 'watching animations...' };
    case 'chatActionImportingMessages':
      return { isActive: true, description: 'importing messages...' };
    case 'chatActionCancel':
    default:
      return { isActive: false, description: '' };
  }
}
