# Cortex

A private AI assistant that actually remembers you. Everything runs locally on your phone - no cloud, no data sharing, just you and your AI companion.

## The Problem

Every AI chat starts from scratch. You introduce yourself, explain your preferences, share context about your life - and then the conversation ends and it's all forgotten. Cloud assistants claim to "remember" but they're really just storing your data on someone else's servers.

## Our Solution

Cortex runs entirely on-device using the Cactus SDK. Your conversations, memories, and personal data never leave your phone. It learns who you are over time and genuinely remembers - your name, your job, your preferences, your past conversations.

## Why Small Models Work

We deliberately chose the smallest models that get the job done. This isn't a limitation - it's a feature.

- **Qwen 3 0.6B** for chat (394MB) - Tiny but supports tool calling, which is essential for our memory system
- **Nomic Embed** for vectors (533MB) - Fast semantic search without cloud APIs
- **LFM Vision** (420MB) and **Whisper Small** (464MB) - Multimodal without the bloat

The result: Cortex runs smoothly on mid-range phones, not just flagships. AI should be accessible to everyone, not just people with the latest hardware. These models load in seconds and respond instantly because they're small enough to actually fit in mobile memory.

## What Makes It Unique

**100% Offline & Private** - Works in airplane mode. No internet required after initial model download. Your data physically cannot leave the device.

**Human-Inspired Memory System** (Track 1: Memory Master)
- *Episodic* - Stores conversations and experiences
- *Semantic* - Extracts and maintains facts about you (name, job, interests, relationships)
- *Procedural* - Learns your communication preferences and rules
- *Working Memory* - Active context with 7+/-2 slots (Miller's Law)

**Memory That Decays** - Just like human memory, unused information fades while frequently accessed memories strengthen. This keeps context relevant without infinite storage bloat.

**Real Utility Beyond Chat**
- Voice memos transcribed and remembered
- Photos analyzed and stored in memory
- Automatic fact extraction from conversations
- Memory explorer UI to see what Cortex knows about you

## Edge Capabilities

| Feature | Implementation |
|---------|---------------|
| Offline | All inference runs locally via Cactus SDK |
| Zero Latency | Streaming responses, no network round-trips |
| Total Privacy | No telemetry, no cloud, no data leaves device |

## Tech Stack

Built with Flutter + Cactus SDK. Four models swap in/out of memory as needed since mobile can't keep everything loaded at once.

| Purpose | Model | Size |
|---------|-------|------|
| Chat | Qwen 3 0.6B | 394 MB |
| Embeddings | Nomic Embed V2 | 533 MB |
| Vision | LFM 2 VL 450M | 420 MB |
| Speech | Whisper Small | 464 MB |

## Project Structure

```
lib/
├── core/
│   ├── models/           # Memory data structures
│   ├── services/         # Cactus SDK wrapper, memory manager
│   └── tools/            # LLM function calling for memory
├── features/
│   ├── chat/             # Main conversation UI
│   ├── memory/           # Memory explorer views
│   └── onboarding/       # Loading & setup
└── shared/               # Theme, constants, widgets
```

## Pre-built Downloads

| Platform | File | Notes |
|----------|------|-------|
| Android | `cortex-release.apk` | Ready to install |
| iOS | `cortex-ios.xcarchive.zip` | Requires signing in Xcode |

Available in `builds/` folder and repo root.

## Building

```bash
# Android
flutter build apk --release

# iOS (requires Apple Developer account)
flutter build ipa --release
```

## Cactus SDK Integration

See [CACTUS_SDK.md](CACTUS_SDK.md) for technical details on how we use the SDK.

## License

MIT
