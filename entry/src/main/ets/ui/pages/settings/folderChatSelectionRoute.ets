// Route contract for picking the chats of a folder (B7 / S13d).
// The folder editor pushes TgFolderChatsPage and receives the selection through the pop callback.

export class FolderChatSelectionRouteParams {
  selectedChatIds: number[] = [];
  folderTitle: string = '';
}

export class FolderChatSelectionResult {
  selectedChatIds: number[] = [];
}
