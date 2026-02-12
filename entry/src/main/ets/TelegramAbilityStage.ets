import { AbilityStage } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TDLibClient } from './services/TDLibClient';
import { AuthController } from './controllers/AuthController';
import { MessagesController } from './controllers/MessagesController';
import { FileController } from './controllers/FileController';
import { ContactsController } from './controllers/ContactsController';
import { CallsController } from './controllers/CallsController';
import { StoriesController } from './controllers/StoriesController';
import { NotificationService } from './services/NotificationService';

const TAG = 'TelegramAbilityStage';
const DOMAIN = 0x0000;

export default class TelegramAbilityStage extends AbilityStage {
  async onCreate(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onCreate — initializing singletons');

    // TDLibClient.initialize() internally initializes SecurityService (HUKS)
    // and sends TDLib parameters. Must be awaited before controllers.
    await TDLibClient.getInstance().initialize();

    AuthController.getInstance();
    MessagesController.getInstance();
    FileController.getInstance();
    ContactsController.getInstance();
    CallsController.getInstance();
    StoriesController.getInstance();

    // Request notification permission (HarmonyOS NotificationKit)
    NotificationService.getInstance().requestPermission();
  }
}
