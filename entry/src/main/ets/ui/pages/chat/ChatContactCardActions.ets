// D26: contact card actions. The card's Message button resolves the user's private chat and pushes it, the
// way iOS opens the conversation; Add Contact writes the card into the device address book after one
// permission prompt.

import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { createPrivateChatUseCase } from '../../../domain/usecases/createPrivateChat';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { createResolveUsernameUseCase } from '../../../domain/usecases/resolveUsername';
import { CONTACT_WRITE_PERMISSIONS, saveContactToDevice } from '../../../infra/contacts/DeviceContacts';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { TdGatewayPort } from '../../../domain/ports/TdGatewayPort';
import { ProfileRouteParams } from '../profile/TgProfilePage';
import { pushChatScreenRoute } from './ChatOpenTransaction';

const DOMAIN = 0x00D26;
const TAG = 'ContactCard';

export interface ChatMessageTargetPort {
  pageStack: NavPathStack;
  setSearchModeActive(value: boolean): void;
  handleSearchQueryChange(query: string): void;
  openSharedMediaLink(value: string): boolean;
  createChatRouteParams(chatId: number, chatTitle: string): ChatScreenRouteParams | undefined;
  chatGateway?: TdGatewayPort;
}

export interface ChatContactCardPort {
  pageStack: NavPathStack;
  getChatUIContext(): UIContext;
  createChatRouteParams(chatId: number, chatTitle: string): ChatScreenRouteParams | undefined;
}

const PROFILE_ROUTE = 'TgProfilePage';

// D18: a tapped target inside a message. "mention:<id>" opens the profile in-app; everything else is a link,
// so it goes through the shared link opener (normalization + openLink live there).
export function openMessageTarget(host: ChatMessageTargetPort, value: string): boolean {
  const target = value.trim();
  if (target.startsWith('mention:')) {
    const userId = Number.parseInt(target.slice('mention:'.length), 10);
    if (Number.isSafeInteger(userId) && userId > 0) {
      try {
        host.pageStack.pushPathByName(PROFILE_ROUTE, new ProfileRouteParams(0, userId));
        return true;
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Opening the mention profile failed: %{public}s', String(error));
        return false;
      }
    }
    return false;
  }
  if (target.startsWith('hashtag:')) {
    // Telegram searches the tag inside the current chat first.
    host.setSearchModeActive(true);
    host.handleSearchQueryChange(target.slice('hashtag:'.length));
    return true;
  }
  if (target.startsWith('geo:')) {
    return openGeoPoint(host, target);
  }
  if (isTelegramUsernameLink(target)) {
    return openResolvedUsername(host, target);
  }
  return host.openSharedMediaLink(target);
}

// t.me/<name> written as a mention is a Telegram profile, not a web page: resolve it in-app first.
// "geo:lat,lon" is the platform shape for a point; maps apps accept it, and a maps URL is the fallback that
// every device can open.
function openGeoPoint(host: ChatMessageTargetPort, target: string): boolean {
  const coords = target.slice('geo:'.length).split(',');
  const latitude = Number.parseFloat(coords[0] ?? '');
  const longitude = Number.parseFloat(coords[1] ?? '');
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return false;
  }
  return host.openSharedMediaLink('https://maps.google.com/?q=' + latitude + ',' + longitude);
}

function isTelegramUsernameLink(target: string): boolean {
  const lowered = target.toLowerCase();
  return lowered.startsWith('https://t.me/') || lowered.startsWith('https://telegram.me/');
}

function openResolvedUsername(host: ChatMessageTargetPort, target: string): boolean {
  const name = target.slice(target.indexOf('/') + 2).replace(/^\/+|\/+$/g, '');
  const username = name.split('?')[0].split('/')[0];
  const gateway = host.chatGateway;
  if (username.length === 0 || gateway === undefined) {
    return host.openSharedMediaLink(target);
  }
  createResolveUsernameUseCase(gateway).resolve(username)
    .then((chat) => {
      const params = host.createChatRouteParams(chat.id, chat.title);
      if (params !== undefined) {
        pushChatScreenRoute(params, host.pageStack, getAppCoreRuntime().getStore());
      }
    })
    .catch((error: Error) => {
      hilog.info(DOMAIN, TAG, 'Username resolution failed, opening externally: %{public}s', String(error));
      host.openSharedMediaLink(target);
    });
  return true;
}

export function openContactChat(host: ChatContactCardPort, userId: number): void {
  if (userId <= 0) {
    return;
  }
  const runtime = getAppCoreRuntime();
  createPrivateChatUseCase(getTdGatewayAdapter()).execute(userId)
    .then((chat) => {
      const params = host.createChatRouteParams(chat.id, chat.title);
      if (params === undefined) {
        return;
      }
      pushChatScreenRoute(params, host.pageStack, runtime.getStore());
    })
    .catch((error: Error) => {
      hilog.error(DOMAIN, TAG, 'Opening the contact chat failed: %{public}s', String(error));
      host.getChatUIContext().getPromptAction().showToast({
        message: localized($r('app.string.contact_card_open_failed').id, 'Could not open the chat')
      });
    });
}

export function addContactCard(host: ChatContactCardPort, firstName: string, lastName: string,
  phoneNumber: string): void {
  if (phoneNumber.trim().length === 0) {
    return;
  }
  const uiContext = host.getChatUIContext();
  const context = uiContext.getHostContext() as common.UIAbilityContext;
  abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, CONTACT_WRITE_PERMISSIONS)
    .then((result) => {
      if (result.authResults.length === 0 || result.authResults[0] !== 0) {
        uiContext.getPromptAction().showToast({
          message: localized($r('app.string.contact_card_add_denied').id, 'Contacts access is off')
        });
        return;
      }
      saveContactToDevice(firstName, lastName, phoneNumber).then((saved: boolean) => {
        uiContext.getPromptAction().showToast({
          message: saved
            ? localized($r('app.string.contact_card_added').id, 'Contact added')
            : localized($r('app.string.contact_card_add_failed').id, 'Could not add the contact')
        });
      });
    })
    .catch((error: Error) => {
      hilog.info(DOMAIN, TAG, 'Adding a contact was rejected: %{public}s', String(error));
    });
}
