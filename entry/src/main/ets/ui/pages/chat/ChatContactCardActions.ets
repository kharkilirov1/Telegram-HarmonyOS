// D26: contact card actions. The card's Message button opens the known user's profile; Add Contact writes
// the card into the device address book after one permission prompt.

import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { localized } from '../../../core/utils/AppResource';
import { CONTACT_WRITE_PERMISSIONS, saveContactToDevice } from '../../../infra/contacts/DeviceContacts';
import { ProfileRouteParams } from '../profile/TgProfilePage';

const DOMAIN = 0x00D26;
const TAG = 'ContactCard';
const PROFILE_ROUTE = 'TgProfilePage';

export interface ChatContactCardPort {
  pageStack: NavPathStack;
  getChatUIContext(): UIContext;
}

export function openContactProfile(host: ChatContactCardPort, userId: number): void {
  if (userId <= 0) {
    return;
  }
  try {
    host.pageStack.pushPathByName(PROFILE_ROUTE, new ProfileRouteParams(0, userId));
  } catch (error) {
    hilog.error(DOMAIN, TAG, 'Opening the contact profile failed: %{public}s', String(error));
  }
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
