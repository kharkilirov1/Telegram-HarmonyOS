import messagesControllerTest from './MessagesController.test';
import preferencesServiceTest from './PreferencesService.test';
import securityServiceTest from './SecurityService.test';
import tdMessageParserTest from './TdMessageParser.test';
import messageUtilsTest from './MessageUtils.test';
import tdFallbackRegistryTest from './TdFallbackRegistry.test';
import appErrorTest from './AppError.test';
import proxyServiceTest from './ProxyService.test';
import sessionServiceTest from './SessionService.test';
import notificationCenterTest from './NotificationCenter.test';
import contactsControllerTest from './ContactsController.test';
import callsControllerTest from './CallsController.test';
import chatServiceTest from './ChatService.test';
import userServiceTest from './UserService.test';
import fileControllerTest from './FileController.test';
import storiesControllerTest from './StoriesController.test';
import tdUpdateParserTest from './TdUpdateParser.test';

export default function testsuite() {
  messagesControllerTest();
  preferencesServiceTest();
  securityServiceTest();
  tdMessageParserTest();
  messageUtilsTest();
  tdFallbackRegistryTest();
  appErrorTest();
  proxyServiceTest();
  sessionServiceTest();
  notificationCenterTest();
  contactsControllerTest();
  callsControllerTest();
  chatServiceTest();
  userServiceTest();
  fileControllerTest();
  storiesControllerTest();
  tdUpdateParserTest();
}
