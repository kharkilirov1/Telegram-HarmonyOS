// AppResource — глобальный доступ к ресурсам приложения
// HarmonyOS API 22: UIContext не имеет resourceManager, поэтому храним контекст отдельно

import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

let appContext: common.UIAbilityContext | null = null;

/**
 * Инициализировать контекст приложения при старте
 */
export function setAppContext(context: common.UIAbilityContext): void {
  appContext = context;
}

/**
 * Получить контекст приложения
 */
export function getAppContext(): common.UIAbilityContext | null {
  return appContext;
}

/**
 * Получить строку из ресурсов
 * @param resourceId - ID ресурса (из $r('app.string.xxx').id)
 */
export function getString(resourceId: number): string {
  if (!appContext) {
    console.error('ResourceManager not initialized');
    return '';
  }
  
  try {
    return appContext.resourceManager.getStringSync(resourceId);
  } catch (error) {
    const err: BusinessError = error as BusinessError;
    console.error('getStringSync failed, error code: ' + err.code + ', message: ' + err.message);
    return '';
  }
}

/**
 * Получить строку из ресурсов с fallback
 * @param resourceId - ID ресурса (из $r('app.string.xxx').id)
 * @param fallback - значение по умолчанию, если ресурс пустой
 */
export function localized(resourceId: number, fallback: string): string {
  const value = getString(resourceId);
  return value.length > 0 ? value : fallback;
}

/**
 * Получить singular/plural строку из app.plural.* по количеству
 * (CLDR-формы текущей локали: ru — one/few/many/other).
 */
export function localizedPlural(resourceId: number, count: number, fallback: string): string {
  if (!appContext) {
    console.error('ResourceManager not initialized');
    return fallback;
  }
  try {
    // count дважды: первый выбирает CLDR-форму, второй подставляется в %d
    const value = appContext.resourceManager.getIntPluralStringValueSync(resourceId, count, count);
    return value.length > 0 ? value : fallback;
  } catch (error) {
    const err: BusinessError = error as BusinessError;
    console.error('getIntPluralStringValueSync failed, code: ' + err.code + ', message: ' + err.message);
    return fallback;
  }
}
