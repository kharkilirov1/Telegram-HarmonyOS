import { TdObject, tdGetArray, tdGetNumber, tdGetNumberArray } from '../../utils/tdAccessors';

export class AccentColorDto {
  id: number = -1;
  builtInAccentColorId: number = -1;
  lightThemeColors: number[] = [];
  darkThemeColors: number[] = [];
  minChannelChatBoostLevel: number = 0;
}

export function createAccentColorDtoFromTd(tdAccentColor: TdObject): AccentColorDto {
  const dto = new AccentColorDto();
  dto.id = tdGetNumber(tdAccentColor, 'id');
  dto.builtInAccentColorId = tdGetNumber(tdAccentColor, 'built_in_accent_color_id');
  dto.lightThemeColors = tdGetNumberArray(tdAccentColor, 'light_theme_colors');
  dto.darkThemeColors = tdGetNumberArray(tdAccentColor, 'dark_theme_colors');
  dto.minChannelChatBoostLevel = tdGetNumber(tdAccentColor, 'min_channel_chat_boost_level');
  return dto;
}

export function createAccentColorDtosFromTd(update: TdObject): AccentColorDto[] {
  const result: AccentColorDto[] = [];
  const colorObjects = tdGetArray(update, 'colors');
  for (const colorObject of colorObjects) {
    const dto = createAccentColorDtoFromTd(colorObject);
    if (dto.id >= 0) {
      result.push(dto);
    }
  }
  return result;
}
