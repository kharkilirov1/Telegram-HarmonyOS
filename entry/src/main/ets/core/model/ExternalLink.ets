// External link intake and classification (S14).
// The app is opened with a t.me link through App Linking or an explicit want. EntryAbility stores the
// link here; MainTabsPage consumes it once the navigation stacks exist and pushes the right page.
// Only folder links (t.me/addlist/...) are routed today; the other kinds are classified so the debt is
// explicit instead of being silently treated as unknown.

export type ExternalLinkKind = 'folderInvite' | 'chatInvite' | 'username' | 'unknown';

export class ExternalLinkTarget {
  kind: ExternalLinkKind = 'unknown';
  // Normalized link for folder/chat invites, or the bare username for usernames.
  value: string = '';
}

// Matching is case-insensitive, but the addlist slug itself is case-sensitive: scheme detection works on
// a lower-cased copy while the value keeps the original text.
function stripSchemePrefix(value: string): string {
  const lower = value.toLowerCase();
  if (lower.startsWith('https://')) {
    return value.slice(8);
  }
  if (lower.startsWith('http://')) {
    return value.slice(7);
  }
  return value;
}

export function classifyExternalLink(uri: string): ExternalLinkTarget {
  const target = new ExternalLinkTarget();
  const trimmed = uri.trim();
  if (trimmed.length === 0) {
    return target;
  }
  const withoutScheme = stripSchemePrefix(trimmed);
  const lower = withoutScheme.toLowerCase();

  const folderPrefixes: string[] = ['t.me/addlist/', 'telegram.me/addlist/'];
  for (const prefix of folderPrefixes) {
    if (lower.startsWith(prefix)) {
      const slug = withoutScheme.slice(prefix.length).replace(/\/+$/, '');
      if (slug.length > 0) {
        target.kind = 'folderInvite';
        target.value = 'https://t.me/addlist/' + slug;
      }
      return target;
    }
  }

  const invitePrefixes: string[] = ['t.me/+', 't.me/joinchat/', 'telegram.me/+', 'telegram.me/joinchat/'];
  for (const prefix of invitePrefixes) {
    if (lower.startsWith(prefix) && lower.length > prefix.length) {
      target.kind = 'chatInvite';
      target.value = trimmed;
      return target;
    }
  }

  const usernamePrefixes: string[] = ['t.me/', 'telegram.me/'];
  for (const prefix of usernamePrefixes) {
    if (!lower.startsWith(prefix)) {
      continue;
    }
    const name = withoutScheme.slice(prefix.length).replace(/\/+$/, '');
    const reserved: string = name.toLowerCase();
    // A slash after the name means a post/message link; Telegram reserves addlist/joinchat paths.
    if (name.length > 0 && !name.includes('/') && !name.startsWith('$') &&
      reserved !== 'addlist' && reserved !== 'joinchat') {
      target.kind = 'username';
      target.value = name.startsWith('@') ? name.slice(1) : name;
    }
    return target;
  }

  return target;
}

// One-shot handoff between the ability (which sees the want) and the page tree (which owns navigation).
export class ExternalLinkIntakeStore {
  private pending: string = '';

  set(uri: string): void {
    if (uri.trim().length > 0) {
      this.pending = uri.trim();
    }
  }

  hasPending(): boolean {
    return this.pending.length > 0;
  }

  take(): ExternalLinkTarget | undefined {
    if (this.pending.length === 0) {
      return undefined;
    }
    const uri = this.pending;
    this.pending = '';
    return classifyExternalLink(uri);
  }

  clear(): void {
    this.pending = '';
  }
}

export const externalLinkIntake: ExternalLinkIntakeStore = new ExternalLinkIntakeStore();
