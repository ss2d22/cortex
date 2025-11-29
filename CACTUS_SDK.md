# Cactus SDK Integration

How we use the Cactus SDK to power Cortex's on-device AI.

## Why These Models

We picked the smallest models that still do the job well. The goal was accessibility - Cortex should run on any decent phone, not just flagship devices.

| Model         | Why We Chose It                                                                                           |
| ------------- | --------------------------------------------------------------------------------------------------------- |
| Qwen 3 0.6B   | Only 394MB but supports tool calling. Essential for our memory system - the AI decides when to save facts |
| Nomic Embed   | Fast vector search locally. No cloud embeddings API needed                                                |
| LFM Vision    | Analyzes photos without shipping images to a server                                                       |
| Whisper Small | Reliable speech-to-text that fits in mobile memory                                                        |

These models load in 2-3 seconds and respond instantly. Bigger models would mean longer load times and potential crashes on mid-range devices.

## Core Components

### Chat with Tool Calling

```dart
_primaryLM = CactusLM(enableToolFiltering: true);
await _primaryLM.initializeModel(
  params: CactusInitParams(
    model: 'qwen3-0.6',
    contextSize: 2048,
  ),
);
```

Streaming for responsive UI:

```dart
final stream = await _cactus.generateCompletionStream(
  messages: messages,
  params: CactusCompletionParams(maxTokens: 300),
);

await for (final chunk in stream.stream) {
  response += chunk;
}
```

### RAG for Memory

CactusRAG stores and retrieves memories using vector similarity:

```dart
_rag = CactusRAG();
await _rag.initialize();

_rag.setEmbeddingGenerator((text) async {
  final result = await _embeddingLM.generateEmbedding(text: text);
  return result.embeddings;
});

await _rag.addDocuments(documents: [memory], metadata: [meta]);
final results = await _rag.search(text: query, limit: 5);
```

### Voice Input

Whisper transcription with streaming:

```dart
final streamedResult = await stt.transcribeStream(audioFilePath: path);
streamedResult.stream.listen((token) => transcription += token);
final result = await streamedResult.result;
```

### Vision

Photo analysis:

```dart
final result = await _visionLM.generateCompletion(
  messages: [ChatMessage(content: prompt, role: 'user', images: [path])],
);
```

## Memory Swapping

Mobile RAM is limited. We can't keep all models loaded, so we swap:

1. **Chat mode** - Primary LM + Embedding model loaded
2. **Voice mode** - Unload both, load Whisper, transcribe, restore
3. **Photo mode** - Unload primary, load vision, analyze, restore

```dart
await _cactus.getSTT();     // Unloads primary, loads Whisper
await _cactus.unloadSTT();  // Restores primary + embedding

await _cactus.getVisionLM();      // Unloads primary, loads vision
await _cactus.restorePrimaryLM(); // Swaps back
```

This means no feature is blocked by memory constraints. The tradeoff is a brief load time when switching modes.

## Tool Calling for Memory

The LLM can call functions to store facts. We define tools:

```dart
CactusTool(
  name: 'store_fact',
  description: 'Save important info about the user',
  parameters: {...},
)
```

And handle calls:

```dart
if (result.toolCalls.isNotEmpty) {
  for (final call in result.toolCalls) {
    await handleToolCall(call);
  }
}
```

## Error Recovery

Context can fill up. We detect and recover:

```dart
try {
  await generateResponse();
} catch (e) {
  if (e.toString().contains('context')) {
    await reinitializePrimaryLM();
    await generateResponse();
  }
}
```

## What the SDK Handles

- Model downloading with progress callbacks
- GGUF model loading and inference
- Streaming token generation
- Vector embeddings and similarity search
- Audio transcription with Whisper
- Image analysis with vision models
- Tool/function call parsing
