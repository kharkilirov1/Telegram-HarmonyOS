// I6: audience picker for a story. Pure helpers keep the search/toggle rules testable; the page only
// renders private chats as selectable rows.

export class StoryAudienceCandidate {
  chatId: number = 0;
  title: string = '';
  initials: string = '';
  username: string = '';
}

export class StoryAudienceState {
  selectedIds: number[] = [];
}

export function filterAudienceCandidates(candidates: StoryAudienceCandidate[], query: string): StoryAudienceCandidate[] {
  const needle = query.trim().toLowerCase();
  if (needle.length === 0) {
    return candidates.slice();
  }
  return candidates.filter((candidate) => {
    if (candidate.title.toLowerCase().includes(needle)) {
      return true;
    }
    return candidate.username.toLowerCase().includes(needle);
  });
}

export function toggleAudienceSelection(selectedIds: number[], chatId: number): number[] {
  if (chatId === 0) {
    return selectedIds.slice();
  }
  if (selectedIds.includes(chatId)) {
    return selectedIds.filter((id) => id !== chatId);
  }
  const next = selectedIds.slice();
  next.push(chatId);
  return next;
}

export function isAudienceSelected(selectedIds: number[], chatId: number): boolean {
  return selectedIds.includes(chatId);
}

// iOS shows the count in the header and the done button is disabled for an empty selection.
export function audienceSelectionLabel(count: number): string {
  if (count <= 0) {
    return 'Select People';
  }
  return count === 1 ? '1 Person' : count.toString() + ' People';
}

export function canConfirmAudience(selectedIds: number[]): boolean {
  return selectedIds.length > 0;
}

export function audienceInitials(title: string): string {
  const parts = title.trim().split(' ').filter((part) => part.length > 0);
  if (parts.length === 0) {
    return '';
  }
  if (parts.length === 1) {
    return parts[0].substring(0, 1).toUpperCase();
  }
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}
