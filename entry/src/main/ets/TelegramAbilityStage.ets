import { AbilityStage } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SecurityService } from './services/SecurityService';
import { TDLibClient } from './services/TDLibClient';
import { AuthController } from './controllers/AuthController';
import { MessagesController } from './controllers/MessagesController';
import { FileController } from './controllers/FileController';

const TAG = 'TelegramAbilityStage';
const DOMAIN = 0x0000;

export default class TelegramAbilityStage extends AbilityStage {
  async onCreate(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onCreate — initializing singletons');

    // Security must be initialized first (HUKS key derivation)
    await SecurityService.getInstance().initialize();

    // Initialize TDLib, then controllers that depend on it
    TDLibClient.getInstance().initialize();
    AuthController.getInstance();
    MessagesController.getInstance();
    FileController.getInstance();
  }
}
