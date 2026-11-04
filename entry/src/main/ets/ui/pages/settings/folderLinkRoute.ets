// Route contract for TgFolderLinkPage (B7 / S14).
// The page is reachable from the folder screen (manual entry) and from an external t.me/addlist link
// consumed by MainTabsPage.

export class FolderLinkRouteParams {
  // Pre-filled invite link; the page checks it automatically when present.
  inviteLink: string = '';
}
