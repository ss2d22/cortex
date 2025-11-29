import 'package:cactus/cactus.dart';

final List<CactusTool> memoryTools = [
  CactusTool(
    name: 'remember',
    description: 'Store important information to remember. Use when user says "remember", "don\'t forget", or shares personal info.',
    parameters: ToolParametersSchema(
      properties: {
        'content': ToolParameter(
          type: 'string',
          description: 'Information to remember',
          required: true,
        ),
        'importance': ToolParameter(
          type: 'string',
          description: 'low, medium, high, or critical',
          required: false,
        ),
      },
    ),
  ),
  CactusTool(
    name: 'recall',
    description: 'Search memories for relevant information.',
    parameters: ToolParametersSchema(
      properties: {
        'query': ToolParameter(
          type: 'string',
          description: 'What to search for',
          required: true,
        ),
      },
    ),
  ),
  CactusTool(
    name: 'list_facts',
    description: 'List all known facts about the user.',
    parameters: ToolParametersSchema(properties: {}),
  ),
];
