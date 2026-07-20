# TgProfileMemberRow

## References
- Telegram iOS: `C:/Refs/Telegram/Telegram-iOS-current/submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/Panes/PeerInfoMembersPane.swift`, `PeerMembersListEntry.member` → `ContactsPeerItem(systemStyle: .glass, peerMode: .memberList)`.
- Telegram iOS role mapping: owner `0x956ac8`, administrator `0x49a355`, custom rank overrides the standard label.
- Telegram Android behavior fallback: `C:/Refs/Telegram/telegram-android/TMessagesProj/src/main/java/org/telegram/ui/ChatUsersActivity.java`.

## Inputs
- Identity: title, subtitle, avatar initials/image/color, online state.
- Role: creator / administrator / member plus optional custom label.
- Interaction: enabled state, separator state, row press.

## State matrix
- Current/online user: accent status and online dot.
- Offline/recent member: secondary presence text.
- Creator: purple role capsule.
- Administrator/custom rank: green role capsule.
- Bot: custom `bot` status.
- Anonymous `messageSenderChat`: non-interactive chat identity row.

## Layout contract
- 60vp row, 44vp avatar, 12vp side inset, 10vp identity gap.
- Name/status are one line each with ellipsis.
- Separator starts at 66vp, aligned to the text column rather than the screen edge.
- The full row owns the interaction zone; the role capsule never becomes a separate action.

## Token mapping
- All reusable geometry and role colors live in `TgUiTokens.PROFILE_MEMBER_*`.
