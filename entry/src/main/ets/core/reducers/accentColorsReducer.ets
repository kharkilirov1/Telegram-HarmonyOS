import { AccentColorsUpdatedEvent } from '../model/AppEvent';
import { AccentColorDefinition, AppState, ReducerAction } from '../model/AppState';
import { cloneStateForAccentColors } from '../utils/stateClone';

function isAccentColorEvent(type: string): boolean {
  return type === 'accentColorsUpdated';
}

export function accentColorsReducer(state: AppState, action: ReducerAction): AppState {
  if (!isAccentColorEvent(action.type)) {
    return state;
  }

  const newState = cloneStateForAccentColors(state);

  switch (action.type) {
    case 'accentColorsUpdated': {
      const event = action as AccentColorsUpdatedEvent;
      const nextColors = new Map<number, AccentColorDefinition>();

      for (const colorDto of event.colors) {
        const color = new AccentColorDefinition();
        color.id = colorDto.id;
        color.builtInAccentColorId = colorDto.builtInAccentColorId;
        color.lightThemeColors = colorDto.lightThemeColors.slice();
        color.darkThemeColors = colorDto.darkThemeColors.slice();
        color.minChannelChatBoostLevel = colorDto.minChannelChatBoostLevel;
        nextColors.set(color.id, color);
      }

      newState.accentColors.colors = nextColors;
      newState.accentColors.availableAccentColorIds = event.availableAccentColorIds.slice();
      break;
    }
  }

  newState.version = state.version + 1;
  newState.lastEvent = action;
  return newState;
}
