// Test suite registry — imports and runs all test modules.
// Old service-layer tests (MessagesController, PreferencesService, etc.) removed —
// those modules no longer exist in the current architecture.

import messagesReducerTest from './MessagesReducer.test';
import messageDtoParserTest from './MessageDtoParser.test';
import stateCloneTest from './StateClone.test';
import chatTimelineVOTest from './ChatTimelineVO.test';
import textEngineTest from './TextEngine.test';
import appStateModelsTest from './AppStateModels.test';
import appErrorTest from './AppError.test';
import loadCallsTest from './LoadCalls.test';
import chatCommandsTest from './ChatCommands.test';
import userDtoTest from './UserDto.test';
import filePipelineTest from './FilePipeline.test';
import tdGatewayTest from './TdGateway.test';
import eventNormalizerTest from './EventNormalizer.test';

export default function testsuite() {
  // Core state management
  messagesReducerTest();
  stateCloneTest();
  appStateModelsTest();
  appErrorTest();
  chatCommandsTest();
  filePipelineTest();

  // Infrastructure
  tdGatewayTest();
  eventNormalizerTest();

  // Feature use cases
  loadCallsTest();

  // DTO / parsing layer
  messageDtoParserTest();
  userDtoTest();

  // UI view models
  chatTimelineVOTest();

  // Text engine
  textEngineTest();
}
