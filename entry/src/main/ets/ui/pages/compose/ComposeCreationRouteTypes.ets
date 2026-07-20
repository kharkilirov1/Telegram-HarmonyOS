export class ComposeCreationResult {
  chatId: number = 0;
  chatTitle: string = '';
  failedMemberCount: number = 0;
  contactImportedUnregistered: boolean = false;

  constructor(
    chatId: number = 0,
    chatTitle: string = '',
    failedMemberCount: number = 0,
    contactImportedUnregistered: boolean = false
  ) {
    this.chatId = chatId;
    this.chatTitle = chatTitle;
    this.failedMemberCount = Math.max(0, Math.trunc(failedMemberCount));
    this.contactImportedUnregistered = contactImportedUnregistered;
  }
}

export class ComposeCreationRouteParams {
}

export class NewGroupInfoRouteParams {
  userIds: number[] = [];

  constructor(userIds: number[] = []) {
    this.userIds = userIds.slice();
  }
}
