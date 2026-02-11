export function openForwardPicker(navPathStack: NavPathStack, chatId: number, messageId: number): void {
  const fwdMsgParam: Record<string, unknown> = {};
  fwdMsgParam['messageId'] = messageId;
  fwdMsgParam['chatId'] = chatId;
  navPathStack.pushPath(new NavPathInfo('ForwardPicker', fwdMsgParam));
}

export function openCallUi(navPathStack: NavPathStack, chatId: number, chatTitle: string, targetUserId: number = 0): void {
  const callParam: Record<string, unknown> = {};
  callParam['userId'] = targetUserId > 0 ? targetUserId : chatId;
  callParam['userName'] = chatTitle;
  callParam['isVideo'] = false;
  callParam['isIncoming'] = false;
  navPathStack.pushPath(new NavPathInfo('CallUI', callParam));
}

export function openMediaViewer(
  navPathStack: NavPathStack,
  url: string,
  messageId: number = 0,
  chatId: number = 0
): void {
  const mediaParam: Record<string, unknown> = {};
  mediaParam['url'] = url;
  if (messageId > 0) {
    mediaParam['messageId'] = messageId;
  }
  if (chatId > 0) {
    mediaParam['chatId'] = chatId;
  }
  navPathStack.pushPath(new NavPathInfo('MediaViewer', mediaParam));
}

export function openVideoPlayer(navPathStack: NavPathStack, url: string, duration: number): void {
  const videoParam: Record<string, unknown> = {};
  videoParam['videoUrl'] = url;
  videoParam['duration'] = duration;
  navPathStack.pushPath(new NavPathInfo('VideoPlayer', videoParam));
}

export function openCreatePoll(navPathStack: NavPathStack, chatId: number): void {
  const pollParam: Record<string, unknown> = {};
  pollParam['chatId'] = chatId;
  navPathStack.pushPath(new NavPathInfo('CreatePoll', pollParam));
}

export function openChatInfo(
  navPathStack: NavPathStack,
  chatId: number,
  isGroupChat: boolean,
  isChannelChat: boolean,
  privateUserId: number = 0
): void {
  if (isGroupChat || isChannelChat) {
    const groupParam: Record<string, unknown> = {};
    groupParam['chatId'] = chatId;
    navPathStack.pushPath(new NavPathInfo('GroupInfo', groupParam));
    return;
  }

  const userParam: Record<string, unknown> = {};
  userParam['userId'] = privateUserId > 0 ? privateUserId : chatId;
  navPathStack.pushPath(new NavPathInfo('UserInfo', userParam));
}
