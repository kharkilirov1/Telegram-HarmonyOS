// Shared scroll restoration cache, preserving the former page static lifetime.
export class ChatScrollPositionCache {
  static positions: Map<number, string> = new Map<number, string>();
}
