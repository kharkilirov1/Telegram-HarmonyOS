import messagesControllerTest from './MessagesController.test';
import preferencesServiceTest from './PreferencesService.test';
import securityServiceTest from './SecurityService.test';
import tdMessageParserTest from './TdMessageParser.test';
import messageUtilsTest from './MessageUtils.test';
import tdFallbackRegistryTest from './TdFallbackRegistry.test';
import appErrorTest from './AppError.test';
import proxyServiceTest from './ProxyService.test';
import sessionServiceTest from './SessionService.test';

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
}
