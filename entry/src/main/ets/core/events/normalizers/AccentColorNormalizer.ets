import { AccentColorsUpdatedEvent, AnyAppEvent } from '../../model/AppEvent';
import { createAccentColorDtosFromTd } from '../../model/dto/AccentColorDto';
import { TdObject } from '../../../models/TdTypes';
import { tdGetNumberArray } from '../../utils/tdAccessors';

function handleAccentColors(events: AnyAppEvent[], update: TdObject): void {
  const event = new AccentColorsUpdatedEvent();
  event.colors = createAccentColorDtosFromTd(update);
  event.availableAccentColorIds = tdGetNumberArray(update, 'available_accent_color_ids');
  event.timestamp = Date.now();
  events.push(event);
}

export function registerAccentColorHandlers(
  handlers: Map<string, (events: AnyAppEvent[], update: TdObject) => void>
): void {
  handlers.set('updateAccentColors', handleAccentColors);
}
