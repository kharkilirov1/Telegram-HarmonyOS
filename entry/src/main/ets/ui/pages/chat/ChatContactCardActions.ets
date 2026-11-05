// D26: contact card actions. The card's Message button resolves the user's private chat and pushes it, the
// way iOS opens the conversation; Add Contact writes the card into the device address book after one
// permission prompt.

import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { getAppCoreRuntime } from '../../../app/bootstrap/AppCoreRuntime';
import { createPrivateChatUseCase } from '../../../domain/usecases/createPrivateChat';
import { getTdGatewayAdapter } from '../../../infra/td/adapter/TdGatewayAdapter';
import { CONTACT_WRITE_PERMISSIONS, saveContactToDevice } from '../../../infra/contacts/DeviceContacts';
import { ChatScreenRouteParams } from './ChatScreenRouteParams';
import { pushChatScreenRoute } from './ChatOpenTransaction';

const DOMAIN = 0x00D26;
const TAG = 'ContactCard';

export interface ChatContactCardPort {
  pageStack: NavPathStack;
  getChatUIContext(): UIContext;
  createChatRouteParams(chatId: number, chatTitle: string): ChatScreenRouteParams | undefined;
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
