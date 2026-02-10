export function openForwardPicker(navPathStack: NavPathStack, chatId: number, messageId: number): void {
  const fwdMsgParam: Record<string, Object> = {};
  fwdMsgParam['messageId'] = messageId;
  fwdMsgParam['chatId'] = chatId;
  navPathStack.pushPath(new NavPathInfo('ForwardPicker', fwdMsgParam));
}

export function openCallUi(navPathStack: NavPathStack, chatId: number, chatTitle: string): void {
  const callParam: Record<string, Object> = {};
  callParam['userId'] = chatId;
  callParam['userName'] = chatTitle;
  callParam['isVideo'] = false;
  callParam['isIncoming'] = false;
  navPathStack.pushPath(new NavPathInfo('CallUI', callParam));
}

export function openMediaViewer(navPathStack: NavPathStack, url: string): void {
  const mediaParam: Record<string, Object> = {};
  mediaParam['url'] = url;
  navPathStack.pushPath(new NavPathInfo('MediaViewer', mediaParam));
}

export function openVideoPlayer(navPathStack: NavPathStack, url: string, duration: number): void {
  const videoParam: Record<string, Object> = {};
  videoParam['videoUrl'] = url;
  videoParam['duration'] = duration;
  navPathStack.pushPath(new NavPathInfo('VideoPlayer', videoParam));
}

export function openCreatePoll(navPathStack: NavPathStack, chatId: number): void {
  const pollParam: Record<string, Object> = {};
  pollParam['chatId'] = chatId;
  navPathStack.pushPath(new NavPathInfo('CreatePoll', pollParam));
}

export function openChatInfo(navPathStack: NavPathStack, chatId: number, isGroupChat: boolean, isChannelChat: boolean): void {
  if (isGroupChat || isChannelChat) {
    const groupParam: Record<string, Object> = {};
    groupParam['chatId'] = chatId;
    navPathStack.pushPath(new NavPathInfo('GroupInfo', groupParam));
    return;
  }

  const userParam: Record<string, Object> = {};
  userParam['userId'] = chatId;
  navPathStack.pushPath(new NavPathInfo('UserInfo', userParam));
}
