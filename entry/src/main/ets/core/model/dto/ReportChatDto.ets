// Chat report flow — Report entry in chat actions (C10 remainder / S12d).
// TDLib: reportChat (td_api.tl:14338) → ReportChatResult (:8352-8369): options → text/messages → ok.
// Both option_id and the result are bytes; the JSON bridge represents them as base64 strings.

import { TdObject as TdObjectType } from '../../../models/TdTypes';

export class ReportChatOptionDto {
  id: string = '';
  text: string = '';
}

export type ReportChatStepKind = 'ok' | 'options' | 'text' | 'messages' | 'unknown';

export class ReportChatStepDto {
  kind: ReportChatStepKind = 'unknown';
  title: string = '';
  options: ReportChatOptionDto[] = [];
  optionId: string = '';
  isTextOptional: boolean = false;
}

export function createReportChatStepFromTd(td: TdObjectType): ReportChatStepDto {
  const step = new ReportChatStepDto();
  const type = td.getTopLevelStringStrict('@type') ?? '';
  if (type === 'reportChatResultOk') {
    step.kind = 'ok';
    return step;
  }
  if (type === 'reportChatResultOptionRequired') {
    step.kind = 'options';
    step.title = td.getTopLevelStringStrict('title') ?? '';
    const rawOptions = td.getTopLevelRawItemArrayStrict('options');
    if (rawOptions !== undefined) {
      for (const raw of rawOptions) {
        if (raw === null) {
          continue;
        }
        const option = TdObjectType.fromJSON(raw);
        const id = option.getTopLevelStringStrict('id') ?? '';
        const text = option.getTopLevelStringStrict('text') ?? '';
        if (id.length > 0) {
          const dto = new ReportChatOptionDto();
          dto.id = id;
          dto.text = text;
          step.options.push(dto);
        }
      }
    }
    return step;
  }
  if (type === 'reportChatResultTextRequired') {
    step.kind = 'text';
    step.optionId = td.getTopLevelStringStrict('option_id') ?? '';
    step.isTextOptional = td.getTopLevelBooleanStrict('is_optional') ?? false;
    return step;
  }
  if (type === 'reportChatResultMessagesRequired') {
    step.kind = 'messages';
    return step;
  }
  return step;
}
