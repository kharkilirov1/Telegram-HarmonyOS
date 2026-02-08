import messagesControllerTest from './MessagesController.test';
import preferencesServiceTest from './PreferencesService.test';
import securityServiceTest from './SecurityService.test';

export default function testsuite() {
  messagesControllerTest();
  preferencesServiceTest();
  securityServiceTest();
}
