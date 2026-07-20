Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$composerPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgComposerInput.ets'
$attachmentSheetPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/atoms/TgAttachmentSheet.ets'
$tokensPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/tokens/TgUiTokens.ets'
$baseColorsPath = Join-Path $root 'entry/src/main/resources/base/element/color.json'
$darkColorsPath = Join-Path $root 'entry/src/main/resources/dark/element/color.json'
$policyPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/utils/TgComposerMaterialPolicy.ets'
$featureFlagsPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/TgUiFeatureFlags.ets'
$demoPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/demos/TgComposerInputDemo.ets'
$passportPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/spec/TgIosNativeLiquidComposer.md'
$chatPagePath = Join-Path $root 'entry/src/main/ets/ui/pages/chat/TgChatScreenPage.ets'
$controllerPath = Join-Path $root 'entry/src/main/ets/ui/pages/chat/ChatComposerController.ets'
$messageActionsControllerPath = Join-Path $root 'entry/src/main/ets/ui/pages/chat/ChatMessageActionsController.ets'
$voiceControllerPath = Join-Path $root 'entry/src/main/ets/ui/pages/chat/ChatVoiceRecordingController.ets'
$voicePolicyPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/utils/TgVoiceRecordingPolicy.ets'
$motionPolicyPath = Join-Path $root 'entry/src/main/ets/ui/tg_ui/utils/TgComposerMotionPolicy.ets'
$botMenuPath = Join-Path $root 'entry/src/main/ets/domain/usecases/loadBotMenu.ets'
$serializerPath = Join-Path $root 'entry/src/main/ets/infra/td/serialization/CommandSerializer.ets'
$userDtoPath = Join-Path $root 'entry/src/main/ets/core/model/dto/UserDto.ets'
$policyTestPath = Join-Path $root 'entry/src/ohosTest/ets/test/TgComposerMaterialPolicy.test.ets'

$requiredFiles = @(
  $composerPath,
  $attachmentSheetPath,
  $tokensPath,
  $baseColorsPath,
  $darkColorsPath,
  $policyPath,
  $featureFlagsPath,
  $demoPath,
  $passportPath,
  $chatPagePath,
  $controllerPath,
  $messageActionsControllerPath,
  $voiceControllerPath,
  $voicePolicyPath,
  $motionPolicyPath,
  $botMenuPath,
  $serializerPath,
  $userDtoPath,
  $policyTestPath
)

foreach ($file in $requiredFiles) {
  if (-not (Test-Path -LiteralPath $file)) {
    throw "Required native-liquid composer artifact is missing: $file"
  }
}

$composer = Get-Content -LiteralPath $composerPath -Raw -Encoding UTF8
$requiredComposerFragments = @(
  "import { uiMaterial } from '@kit.ArkUI';",
  "import { inputMethod } from '@kit.IMEKit';",
  "import { Available, deviceInfo } from '@kit.BasicServicesKit';",
  "@Available({ minApiVersion: '26.0.0' })",
  "deviceInfo.apiAvailable('26.0.0')",
  'resolveComposerMaterialMode(',
  'new uiMaterial.ImmersiveMaterial({',
  'style: uiMaterial.ImmersiveStyle.THIN',
  'style: uiMaterial.ImmersiveStyle.REGULAR',
  'interactive: true',
  '.backgroundBlurStyle(',
  '.style(TextContentStyle.DEFAULT)',
  'LongPressGesture(',
  'PanGesture(',
  'resolveVoiceRecordingGesture(',
  'buildRecordingComposer()',
  'buildBotMenu()',
  '@Param botMenuOpen: boolean = false;',
  'private botMenuExpanded(): boolean',
  '@Local private inputFocused: boolean = false;',
  '.onFocus(() => {',
  '.onBlur(() => {',
  'return !this.inputFocused && this.textBuffer.length === 0;',
  'if (this.botMenuExpanded())',
  '.transition(composerMenuLabelTransition())',
  'COMPOSER_MENU_LINE_WIDTH',
  'buildBotMenuPanel()',
  'if (this.botMenuOpen)',
  'onBotMenuOpenChange(false)',
  'onBotMenuCommandPress(index)',
  '@Param attachmentMenuLabels: string[]',
  '@Param emojiPanelOpen: boolean = false;',
  '@Param attachmentRecentItems: TgAttachmentRecentItem[] = [];',
  '@Event onKeyboardModePress:',
  'inputMethod.getController().showTextInput()',
  '@Event onAttachmentMenuOpenChange:',
  '@Event onAttachmentRecentPress:',
  'buildAttachmentSheet()',
  'TgAttachmentSheet({',
  '.bindSheet(this.attachmentMenuOpen',
  'height: TgUiTokens.ATTACHMENT_SHEET_HEIGHT',
  'dragBar: false',
  'backgroundColor: TgUiTokens.ATTACHMENT_SHEET_BG',
  'preferType: SheetType.BOTTOM',
  'mode: SheetMode.OVERLAY',
  'onAttachmentMenuItemPress(index)',
  'width: TgUiTokens.COMPOSER_RESPONSE_SIZE',
  'height: TgUiTokens.COMPOSER_RESPONSE_SIZE',
  'onVoiceRecordStart()',
  'onVoiceRecordSend()',
  'onVoiceRecordCancel()',
  'onVoiceRecordLock()'
)

foreach ($fragment in $requiredComposerFragments) {
  if (-not $composer.Contains($fragment)) {
    throw "Native-liquid composer contract missing: $fragment"
  }
}

if ($composer.Contains('HdsActionBar')) {
  throw 'The live TgComposerInput must remain custom and must not contain HdsActionBar.'
}
if ($composer.Contains('COMPOSER_MENU_DOT_SIZE')) {
  throw 'Closed bot Menu glyph must be the iOS three-line icon, not three dots.'
}
if ($composer.Contains('COMPOSER_BOT_POPUP_MAX_ITEMS')) {
  throw 'Bot command popup must render the complete TDLib command list; the viewport handles scrolling.'
}
foreach ($forbiddenPopup in @('.bindPopup(this.botMenuOpen', '.bindPopup(this.attachmentMenuOpen')) {
  if ($composer.Contains($forbiddenPopup)) {
    throw "Bot commands and attachments must be in-flow full-width panels, not anchored popups: $forbiddenPopup"
  }
}
if ($composer -notmatch 'this\.attachmentMenuOpen\s*=\s*false;[\s\S]*?this\.onAttachmentMenuOpenChange\(false\);[\s\S]*?this\.onBotMenuOpenChange\(false\);[\s\S]*?this\.textController\.stopEditing\(\);[\s\S]*?this\.onEmojiPress\(\);') {
  throw 'Opening the emoji keyboard must close attachment and bot panels first.'
}

$tokens = Get-Content -LiteralPath $tokensPath -Raw -Encoding UTF8
foreach ($fragment in @('COMPOSER_BUTTON_SIZE: number = 34', 'COMPOSER_ICON_SIZE: number = 21',
    'COMPOSER_TEXT_SIZE: number = 16', 'COMPOSER_MIN_CAPSULE_HEIGHT: number = 34',
    'COMPOSER_CAPSULE_RADIUS: number = 17', 'COMPOSER_ELEMENT_GAP: number = 4',
    'COMPOSER_RESPONSE_SIZE: number = 40', 'COMPOSER_SIDE_INSET: number = 18',
    'COMPOSER_VERTICAL_INSET: number = 1', 'COMPOSER_KEYBOARD_PANEL_HEIGHT: number = 292',
    "ATTACHMENT_SHEET_HEIGHT: string = '67%'",
    "ATTACHMENT_SHEET_BG: Resource = `$r('app.color.attachment_sheet_bg')",
    'ATTACHMENT_SHEET_GRABBER_WIDTH: number = 36',
    'ATTACHMENT_SHEET_GRABBER_HEIGHT: number = 4',
    'ATTACHMENT_SHEET_GRABBER_OPACITY: number = 0.55',
    "ATTACHMENT_SHEET_ACTIVE_BG: Resource = `$r('app.color.attachment_sheet_active_bg')",
    'COMPOSER_LAYOUT_TRANSITION_MS: number = 220', 'COMPOSER_POPUP_ENTER_MS: number = 180',
    'COMPOSER_POPUP_EXIT_MS: number = 140')) {
  if (-not $tokens.Contains($fragment)) {
    throw "Compact composer geometry contract missing: $fragment"
  }
}
$attachmentSheet = Get-Content -LiteralPath $attachmentSheetPath -Raw -Encoding UTF8
foreach ($fragment in @('export class TgAttachmentRecentItem', 'export struct TgAttachmentSheet',
    "columnsTemplate('1fr 1fr 1fr')", "columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')",
    'Image(item.uri)', '@Event onRecentPress:',
    '@Event onCategoryPress:', 'sticker_packs_recent', 'attach_gallery', 'attach_camera',
    'attach_file', 'attach_location', 'attach_poll', 'attach_contact',
    'TgUiTokens.COMPOSER_CAPSULE_FALLBACK_BG', 'TgUiTokens.COMPOSER_CAPSULE_BORDER',
    'private buildGrabber()', 'this.buildGrabber()',
    'TgUiTokens.ATTACHMENT_SHEET_ACTIVE_BG',
    '.backgroundColor(TgUiTokens.ATTACHMENT_SHEET_BG)')) {
  if (-not $attachmentSheet.Contains($fragment)) {
    throw "iOS attachment sheet contract missing: $fragment"
  }
}

$baseColors = Get-Content -LiteralPath $baseColorsPath -Raw -Encoding UTF8
$darkColors = Get-Content -LiteralPath $darkColorsPath -Raw -Encoding UTF8
if (-not $baseColors.Contains('"name": "attachment_sheet_bg"')) {
  throw 'Light attachment sheet surface resource is missing.'
}
if (-not $baseColors.Contains('"name": "attachment_sheet_active_bg"')) {
  throw 'Light selected attachment category resource is missing.'
}
if (-not $darkColors.Contains('"name": "attachment_sheet_bg"')) {
  throw 'Dark attachment sheet surface resource is missing.'
}
if (-not $darkColors.Contains('"name": "attachment_sheet_active_bg"')) {
  throw 'Dark selected attachment category resource is missing.'
}

$motionPolicy = Get-Content -LiteralPath $motionPolicyPath -Raw -Encoding UTF8
foreach ($fragment in @('export function composerPopupTransition(): TransitionEffect',
    'TransitionEffect.asymmetric(', 'TransitionEffect.OPACITY', 'TransitionEffect.translate(',
    'TransitionEffect.scale(', 'export function composerMenuLabelTransition(): TransitionEffect')) {
  if (-not $motionPolicy.Contains($fragment)) {
    throw "Composer motion policy contract missing: $fragment"
  }
}
if ($tokens.Contains('COMPOSER_BOT_POPUP_MAX_ITEMS')) {
  throw 'The artificial bot command count cap must be removed from tokens.'
}

if ($composer -match 'if\s*\(this\.canSend\(\)\)\s*\{\s*this\.buildActionButton\(\)') {
  throw 'Send action must not be embedded inside the text capsule.'
}
if ($composer -notmatch 'this\.buildTextCapsule\(\)\s*this\.buildActionButton\(\)') {
  throw 'The external action slot must remain mounted after the text capsule.'
}

$flags = Get-Content -LiteralPath $featureFlagsPath -Raw -Encoding UTF8
if (-not $flags.Contains('USE_NATIVE_IMMERSIVE_COMPOSER_MATERIAL: boolean = true')) {
  throw 'Native immersive composer material feature flag is missing or disabled.'
}

$policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8
foreach ($mode in @('nativeImmersive', 'realtimeBlur', 'fallback')) {
  if (-not $policy.Contains($mode)) {
    throw "Composer material policy mode is missing: $mode"
  }
}

$policyTest = Get-Content -LiteralPath $policyTestPath -Raw -Encoding UTF8
foreach ($mode in @('nativeImmersive', 'realtimeBlur', 'fallback')) {
  if (-not $policyTest.Contains($mode)) {
    throw "Composer material policy test does not cover: $mode"
  }
}

$chatPage = Get-Content -LiteralPath $chatPagePath -Raw -Encoding UTF8
if (-not $chatPage.Contains('TgComposerInput({')) {
  throw 'The live chat page must still compose TgComposerInput.'
}
if ($chatPage.Contains('HdsActionBar')) {
  throw 'The live chat page must not integrate HdsActionBar.'
}

$composerIndex = $chatPage.IndexOf('TgComposerInput({')
$emojiPanelIndex = $chatPage.IndexOf('if (this.showComposerEmojiPanel)', $composerIndex)
$stickerPanelIndex = $chatPage.IndexOf('else if (this.showComposerStickerPanel)', $composerIndex)
if ($composerIndex -lt 0 -or $emojiPanelIndex -lt $composerIndex -or $stickerPanelIndex -lt $composerIndex) {
  throw 'Emoji and sticker keyboard panels must render after the composer, in the keyboard area.'
}
if ($chatPage -notmatch 'TgComposerEmojiPanel\(\{[\s\S]*?\}\)\s*\.transition\(composerPopupTransition\(\)\)') {
  throw 'The Telegram emoji keyboard panel must animate into and out of the shared keyboard slot.'
}
if ($chatPage -notmatch 'TgComposerStickerPanel\(\{[\s\S]*?\}\)\s*\.transition\(composerPopupTransition\(\)\)') {
  throw 'The Telegram sticker keyboard panel must animate into and out of the shared keyboard slot.'
}
foreach ($fragment in @('bottomInset: this.composerKeyboardPanelVisible() ? 0 : this.bottomOverlayInset',
    'bottomInset: this.bottomOverlayInset', 'this.setStickerPanelVisible(false);',
    'emojiPanelOpen: this.composerKeyboardPanelVisible()',
    'onKeyboardModePress:', 'this.setEmojiPanelVisible(false);',
    'this.setStickerPanelVisible(false);', 'attachmentRecentItems:',
    'onAttachmentMenuOpenChange:', 'loadRecentAttachmentMedia(')) {
  if (-not $chatPage.Contains($fragment)) {
    throw "Composer keyboard inset handoff is missing: $fragment"
  }
}

$controller = Get-Content -LiteralPath $controllerPath -Raw -Encoding UTF8
foreach ($fragment in @('cameraPicker.pick(', 'PickerMediaType.PHOTO', 'PickerMediaType.VIDEO')) {
  if (-not $controller.Contains($fragment)) {
    throw "CameraPicker composer contract missing: $fragment"
  }
}
foreach ($fragment in @('handleAttachmentMenuItemPress(index: number', 'openCameraAttachmentPicker(host)',
    "openPhotoAttachmentPicker('photo', host)",
    'openDocumentAttachmentPicker(host)', 'loadRecentAttachmentMedia(',
    'photoAccessHelper.getPhotoAccessHelper(', 'getAssets(', 'PhotoKeys.DATE_ADDED',
    'getObjectByPosition(', 'fetchResult.close()')) {
  if (-not $controller.Contains($fragment)) {
    throw "Attachment popup action contract missing: $fragment"
  }
}
foreach ($forbidden in @("import { promptAction } from '@kit.ArkUI';", 'showActionMenu(')) {
  if ($controller.Contains($forbidden)) {
    throw "Composer attachment chooser must not use the system action menu: $forbidden"
  }
}

$voiceController = Get-Content -LiteralPath $voiceControllerPath -Raw -Encoding UTF8
foreach ($fragment in @('requestPermissionsFromUser(', 'media.createAVRecorder()', 'AUDIO_SOURCE_TYPE_MIC',
    'CFT_MPEG_4A', 'fd://', "params.mediaKind = 'voice'", 'releaseRecorder(')) {
  if (-not $voiceController.Contains($fragment)) {
    throw "Voice recorder contract missing: $fragment"
  }
}

$voicePolicy = Get-Content -LiteralPath $voicePolicyPath -Raw -Encoding UTF8
foreach ($fragment in @('TG_VOICE_CANCEL_THRESHOLD_VP: number = -72',
    'TG_VOICE_LOCK_THRESHOLD_VP: number = -72', 'TG_VOICE_MIN_DURATION_MS: number = 500')) {
  if (-not $voicePolicy.Contains($fragment)) {
    throw "Voice gesture policy contract missing: $fragment"
  }
}

$serializer = Get-Content -LiteralPath $serializerPath -Raw -Encoding UTF8
if (-not $serializer.Contains('"@type":"inputMessageVoiceNote"')) {
  throw 'TDLib voice-note serialization contract is missing.'
}

$userDto = Get-Content -LiteralPath $userDtoPath -Raw -Encoding UTF8
if (-not $userDto.Contains("=== 'userTypeBot'")) {
  throw 'TDLib userTypeBot persistence contract is missing.'
}

$botMenu = Get-Content -LiteralPath $botMenuPath -Raw -Encoding UTF8
foreach ($fragment in @('createGetUserFullInfoCommand(', "tdGetObject(response, 'bot_info')",
    "tdGetArray(botInfo, 'commands')")) {
  if (-not $botMenu.Contains($fragment)) {
    throw "Bot Menu metadata contract missing: $fragment"
  }
}

foreach ($fragment in @('showBotMenu: this.showBotMenu', 'onBotMenuPress:',
    'botMenuOpen: this.botMenuOpen', 'onBotMenuOpenChange:', 'onBotMenuCommandPress:',
    'this.refreshBotMenuState(state)', 'this.handleBotMenuPress()')) {
  if (-not $chatPage.Contains($fragment)) {
    throw "Live bot Menu integration missing: $fragment"
  }
}

foreach ($fragment in @('attachmentMenuLabels:', 'onAttachmentMenuItemPress:',
    'this.handleComposerAttachmentMenuItemPress(index)')) {
  if (-not $chatPage.Contains($fragment)) {
    throw "Live attachment popup integration missing: $fragment"
  }
}
if ($chatPage.Contains('COMPOSER_BOT_POPUP_MAX_ITEMS')) {
  throw 'Live chat must not truncate the bot command list before rendering or dispatch.'
}

if ($chatPage.Contains('showActionMenu(')) {
  throw 'Bot commands must use the composer-anchored popup instead of the system action menu.'
}

$messageActionsController = Get-Content -LiteralPath $messageActionsControllerPath -Raw -Encoding UTF8
foreach ($fragment in @('buildMessageActionItems(', 'handleMessageActionPress(')) {
  if (-not $messageActionsController.Contains($fragment)) {
    throw "Message action popup contract missing: $fragment"
  }
}
foreach ($forbidden in @("import { promptAction } from '@kit.ArkUI';", 'showActionMenu(')) {
  if ($messageActionsController.Contains($forbidden)) {
    throw "Message actions must use the shared glass popup language: $forbidden"
  }
}
foreach ($fragment in @('.bindPopup(this.messageActionsOpenId === entry.message.messageId',
    'builder: this.buildMessageActionsPopup', 'transition: composerPopupTransition()',
    'this.handleMessageActionPress(index)')) {
  if (-not $chatPage.Contains($fragment)) {
    throw "Live message action popup integration missing: $fragment"
  }
}

foreach ($fragment in @('private scrollTimelineToBottomAligned(): void',
    'scrollToIndex(lastIndex, false, ScrollAlign.END)', '.scrollBar(BarState.Off)')) {
  if (-not $chatPage.Contains($fragment)) {
    throw "Composer bottom-alignment contract missing: $fragment"
  }
}

foreach ($fragment in @('@Event onInputWillFocus: () => void',
    '@Event onInputFocusChange: (focused: boolean) => void',
    'event.type === TouchType.Down', 'this.onInputWillFocus();',
    'this.onInputFocusChange(true);', 'this.onInputFocusChange(false);')) {
  if (-not $composer.Contains($fragment)) {
    throw "Composer focus handoff contract missing: $fragment"
  }
}
foreach ($fragment in @('.padding({ bottom: this.composerTotalHeight })',
    'private shouldKeepTimelineBottomAligned(): boolean',
    'private handleComposerWillFocus(): void',
    'private handleComposerFocusChange(focused: boolean): void',
    'private handleChatViewportAreaChange(newArea: Area): void',
    'onInputWillFocus: (): void => {',
    'this.handleComposerWillFocus();',
    'onInputFocusChange: (focused: boolean): void => {',
    'this.handleComposerFocusChange(focused);')) {
  if (-not $chatPage.Contains($fragment)) {
    throw "Composer must resize the timeline viewport instead of covering it: $fragment"
  }
}
if ($chatPage.Contains('.contentEndOffset(this.composerTotalHeight)')) {
  throw 'Composer height must reduce the timeline viewport, not act only as a scroll-end offset.'
}

foreach ($fragment in @('COMPOSER_CONTROL_BORDER_WIDTH', 'COMPOSER_CONTROL_ICON')) {
  if (-not $composer.Contains($fragment)) {
    throw "Composer visual-control contract missing: $fragment"
  }
}

$demo = Get-Content -LiteralPath $demoPath -Raw -Encoding UTF8
foreach ($state in @('empty idle', 'multiline text', 'reply snippet', 'edit mode',
    'forward mode', 'selected attachment', 'disabled state', 'narrow container',
    'bot menu', 'bot menu typing collapse', 'voice recording', 'voice locked', 'voice sending')) {
  if (-not $demo.Contains($state)) {
    throw "Composer demo state is missing: $state"
  }
}

Write-Host 'Full iOS native-liquid composer source contract passed.'
