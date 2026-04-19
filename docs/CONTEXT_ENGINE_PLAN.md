# Context Engine Implementation Plan

> **Goal:** Implement context-aware AI chat that knows exactly where the user is in the audiobook, responds in-character, and never spoils future content.
>
> **Voice-First:** Both text AND voice input/output with conversational latency (<2 seconds to first audio).

---

## Design Principles

1. **Voice-First, Text-Supported** - Voice is the primary interaction while listening
2. **Streaming Everything** - Never wait for complete responses; stream STT→LLM→TTS
3. **Modular Pipelines** - Swap STT/TTS providers without changing core logic
4. **Edge-Aware** - Design for mobile with intermittent connectivity
5. **Persona Voices** - Each character should sound distinct

---

## User Flow (Dual Mode)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ USER JOURNEY │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ 1. LISTENING 2. CURIOUS │
│ ┌─────────────────────┐ ┌─────────────────────┐ │
│ │ The Great Gatsby │ │ "Wait, who is this │ │
│ │ Chapter 3 • 14:32 │ ──► │ Jordan Baker │ │
│ │ ▶ Playing... │ │ person?" │ │
│ └─────────────────────┘ └──────────┬──────────┘ │
│ │ │
│ ▼ │
│ 3. ASK AI 4. SELECT PERSONA │
│ ┌─────────────────────┐ ┌─────────────────────┐ │
│ │ [Ask AI Button] │ ──► │ ○ Nick Carraway │ │
│ │ │ │ ● Jay Gatsby │ │
│ │ Opens chat modal │ │ ○ English Teacher │ │
│ └─────────────────────┘ └──────────┬──────────┘ │
│ │ │
│ ▼ │
│ 5. TYPE QUESTION 6. CONTEXT-AWARE RESPONSE │
│ ┌─────────────────────┐ ┌─────────────────────────────────────┐ │
│ │ "Who is Jordan │ │ Jay Gatsby: │ │
│ │ Baker?" │ ──► │ "Ah, Miss Baker! A most striking │ │
│ │ │ │ young woman, old sport. She's a │ │
│ │ [Send] │ │ professional golfer-quite famous. │ │
│ └─────────────────────┘ │ I noticed you speaking with her │ │
│ │ at my little gathering..." │ │
│ └─────────────────────────────────────┘ │
│ │
│ 7. CONTINUE OR ASK MORE │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ [Continue Listening] [Ask Follow-up] [Change Persona] │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Voice vs Text Flow Comparison

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ TEXT MODE vs VOICE MODE │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ TEXT MODE (Simple, ~3-5s total) │
│ ════════════════════════════════ │
│ │
│ User types ──► API receives ──► LLM generates ──► Text displayed │
│ │ │ │ │ │
│ 200ms 50ms 2-4 sec instant │
│ │
│ ───────────────────────────────────────────────────────────────────── │
│ │
│ VOICE MODE (Streaming, <2s to first audio) │
│ ══════════════════════════════════════════ │
│ │
│ User speaks ──► STT ──► LLM streams ──► TTS streams ──► Audio plays │
│ │ │ │ │ │ │
│ ~1-3 sec 200ms streaming streaming immediate │
│ (talking) (fast) (tokens flow) (chunks flow) (as received) │
│ │
│ ┌─────────────────────────────────────┐ │
│ │ KEY INSIGHT: Start TTS on first │ │
│ │ sentence, don't wait for full │ │
│ │ LLM response! │ │
│ └─────────────────────────────────────┘ │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Voice Pipeline Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ VOICE STREAMING PIPELINE │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ MOBILE APP / WEB BROWSER │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ │ │
│ │ ┌──────────────┐ ┌──────────────────────────────┐ │ │
│ │ │ Microphone │ │ Audio Output │ │ │
│ │ │ ────────── │ │ ──────────── │ │ │
│ │ │ Records │ │ Plays TTS chunks as they │ │ │
│ │ │ user voice │ │ arrive (AudioWorklet/ │ │ │
│ │ │ │ │ AVAudioEngine) │ │ │
│ │ └──────┬───────┘ └──────────────▲───────────────┘ │ │
│ │ │ │ │ │
│ │ │ Audio stream │ Audio chunks │ │
│ │ │ (WebSocket) │ (WebSocket) │ │
│ │ │ │ │ │
│ └─────────┼─────────────────────────────────────┼─────────────────────┘ │
│ │ │ │
│ ▼ │ │
│ ══════════════════════════════════════════════════════════════════════ │
│ WEBSOCKET CONNECTION │
│ wss://api.echowright.com/ai/voice-chat │
│ ══════════════════════════════════════════════════════════════════════ │
│ │ ▲ │
│ │ │ │
│ ▼ │ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ API GATEWAY (Voice Handler) │ │
│ │ │ │
│ │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │ │
│ │ │ STT │ │ CONTEXT │ │ LLM │ │ │
│ │ │ (Speech │───►│ ENGINE │───►│ (Streaming │ │ │
│ │ │ to Text) │ │ + Persona │ │ Response) │ │ │
│ │ └─────────────┘ └─────────────┘ └──────┬──────┘ │ │
│ │ │ │ │
│ │ │ Token stream │ │
│ │ ▼ │ │
│ │ ┌─────────────┐ │ │
│ │ │ SENTENCE │ │ │
│ │ │ BUFFER │ │ │
│ │ │ ───────── │ │ │
│ │ │ Accumulate │ │ │
│ │ │ until "." │ │ │
│ │ │ "?" or "!" │ │ │
│ │ └──────┬──────┘ │ │
│ │ │ │ │
│ │ │ Complete sentences │ │
│ │ ▼ │ │
│ │ ┌─────────────┐ │ │
│ │ │ TTS │──────────────┼──┘
│ │ │ (Text to │ Audio chunks│
│ │ │ Speech) │ │
│ │ └─────────────┘ │
│ │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Latency Budget (Voice Mode Target: <2s to First Audio)

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ LATENCY BREAKDOWN │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ USER SPEAKS: "Who is Jordan Baker?" (~1.5 seconds of speech) │
│ │
│ ┌──────────────────────────────────────────────────────────────────────┐ │
│ │ │ │
│ │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │ │
│ │ 0ms 2000ms │ │
│ │ │ │
│ │ ├─ STT Processing ─┤├─ Context ─┤├─ LLM First Token ─┤├─ TTS ─┤ │ │
│ │ 200-400ms 50ms 300-800ms 200ms │ │
│ │ │ │
│ │ Total to first audio: 750ms - 1450ms │ │
│ │ │ │
│ └──────────────────────────────────────────────────────────────────────┘ │
│ │
│ BREAKDOWN: │
│ ┌────────────────────────┬─────────────┬──────────────────────────────┐ │
│ │ Component │ Target │ Strategy │ │
│ ├────────────────────────┼─────────────┼──────────────────────────────┤ │
│ │ STT (Speech-to-Text) │ 200-400ms │ Streaming STT (Deepgram/ │ │
│ │ │ │ Azure) - transcribe as user │ │
│ │ │ │ speaks, not after │ │
│ ├────────────────────────┼─────────────┼──────────────────────────────┤ │
│ │ Context Retrieval │ 50ms │ Pre-fetch context when │ │
│ │ │ │ user opens chat, cache hot │ │
│ ├────────────────────────┼─────────────┼──────────────────────────────┤ │
│ │ LLM First Token │ 300-800ms │ Use fast model (gpt-4o-mini) │ │
│ │ │ │ with streaming enabled │ │
│ ├────────────────────────┼─────────────┼──────────────────────────────┤ │
│ │ TTS First Audio │ 200-300ms │ Stream TTS on first complete │ │
│ │ │ │ sentence, not full response │ │
│ ├────────────────────────┼─────────────┼──────────────────────────────┤ │
│ │ Network Round Trip │ 50-100ms │ Regional edge deployment, │ │
│ │ │ │ persistent WebSocket │ │
│ └────────────────────────┴─────────────┴──────────────────────────────┘ │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Streaming Protocol (WebSocket Messages)

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ WEBSOCKET MESSAGE PROTOCOL │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ CONNECTION SETUP │
│ ════════════════ │
│ │
│ Client → Server: Connect to wss://api/ai/voice-chat │
│ Headers: { Authorization: Bearer <jwt> } │
│ │
│ Server → Client: { "type": "connected", "session_id": "abc123" } │
│ │
│ ───────────────────────────────────────────────────────────────────── │
│ │
│ START VOICE SESSION │
│ ═══════════════════ │
│ │
│ Client → Server: │
│ { │
│ "type": "start_session", │
│ "book_id": "uuid", │
│ "chapter": 3, │
│ "timestamp_seconds": 872.5, │
│ "persona_id": "uuid", │
│ "input_mode": "voice", // or "text" │
│ "output_mode": "voice" // or "text" │
│ } │
│ │
│ Server → Client: │
│ { "type": "session_ready", "context_loaded": true } │
│ │
│ ───────────────────────────────────────────────────────────────────── │
│ │
│ VOICE INPUT (Streaming Audio) │
│ ═════════════════════════════ │
│ │
│ Client → Server: [Binary audio chunks - PCM 16kHz mono] │
│ Client → Server: [Binary audio chunks...] │
│ Client → Server: { "type": "audio_end" } // User stopped speaking │
│ │
│ Server → Client: (During STT) │
│ { "type": "transcript_partial", "text": "Who is Jor" } │
│ { "type": "transcript_partial", "text": "Who is Jordan" } │
│ { "type": "transcript_final", "text": "Who is Jordan Baker?" } │
│ │
│ ───────────────────────────────────────────────────────────────────── │
│ │
│ TEXT INPUT (Alternative) │
│ ════════════════════════ │
│ │
│ Client → Server: │
│ { "type": "text_message", "text": "Who is Jordan Baker?" } │
│ │
│ ───────────────────────────────────────────────────────────────────── │
│ │
│ LLM RESPONSE (Streaming) │
│ ════════════════════════ │
│ │
│ Server → Client: │
│ { "type": "llm_start", "persona": "Jay Gatsby" } │
│ { "type": "llm_delta", "text": "Ah, " } │
│ { "type": "llm_delta", "text": "Miss Baker! " } │
│ { "type": "llm_delta", "text": "A most " } │
│ ... │
│ { "type": "llm_end", "full_text": "Ah, Miss Baker! A most..." } │
│ │
│ ───────────────────────────────────────────────────────────────────── │
│ │
│ TTS AUDIO (Streaming - sentence by sentence) │
│ ════════════════════════════════════════════ │
│ │
│ Server → Client: │
│ { "type": "audio_start", "format": "pcm_16k" } │
│ [Binary: First sentence audio chunk] │
│ [Binary: More audio...] │
│ { "type": "sentence_boundary", "text": "Ah, Miss Baker!" } │
│ [Binary: Second sentence audio chunk] │
│ ... │
│ { "type": "audio_end" } │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## STT/TTS Provider Options

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ STT PROVIDER COMPARISON │
├───────────────────┬─────────────┬─────────────┬─────────────┬──────────────┤
│ Provider │ Latency │ Streaming │ Cost │ Notes │
├───────────────────┼─────────────┼─────────────┼─────────────┼──────────────┤
│ Deepgram │ ~200ms │ Yes │ $0.0043/min │ Best latency │
│ Azure Speech │ ~300ms │ Yes │ $0.016/min │ Good quality │
│ Whisper (OpenAI) │ ~500ms │ No │ $0.006/min │ Batch only │
│ Whisper (local) │ ~1-2s │ No │ Free │ CPU/GPU req │
│ AssemblyAI │ ~300ms │ Yes │ $0.015/min │ Good quality │
└───────────────────┴─────────────┴─────────────┴─────────────┴──────────────┘

RECOMMENDATION: Deepgram for production (fastest streaming)
 Azure Speech as fallback (already in our stack)

┌─────────────────────────────────────────────────────────────────────────────┐
│ TTS PROVIDER COMPARISON │
├───────────────────┬─────────────┬─────────────┬─────────────┬──────────────┤
│ Provider │ Latency │ Streaming │ Cost │ Notes │
├───────────────────┼─────────────┼─────────────┼─────────────┼──────────────┤
│ Azure Speech │ ~200ms │ Yes │ $0.016/min │ Many voices │
│ ElevenLabs │ ~300ms │ Yes │ $0.30/1k ch │ Best quality │
│ OpenAI TTS │ ~400ms │ Yes │ $0.015/1k ch│ Good quality │
│ PlayHT │ ~250ms │ Yes │ $0.05/1k ch │ Voice cloning│
│ Cartesia │ ~100ms │ Yes │ $0.07/1k ch │ Ultra-fast │
└───────────────────┴─────────────┴─────────────┴─────────────┴──────────────┘

RECOMMENDATION: Azure Speech for MVP (cost-effective, good quality)
 ElevenLabs for premium personas (custom voices)
 Cartesia for ultra-low-latency mode
```

---

## Persona Voice Configuration

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ PERSONA VOICE SETTINGS │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ Each persona needs voice configuration for TTS: │
│ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ PersonaVoiceConfig │ │
│ │ ══════════════════ │ │
│ │ │ │
│ │ { │ │
│ │ "persona_id": "jay_gatsby", │ │
│ │ "tts_provider": "azure", // or "elevenlabs", "openai" │ │
│ │ "voice_id": "en-US-DavisNeural", // Provider-specific voice │ │
│ │ "voice_style": "cheerful", // Azure-specific styling │ │
│ │ "speaking_rate": 1.1, // Gatsby speaks confidently │ │
│ │ "pitch": "+5%", // Slightly higher pitch │ │
│ │ "custom_voice_id": null // For ElevenLabs cloned voice │ │
│ │ } │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│ │
│ EXAMPLE VOICE MAPPINGS: │
│ ┌────────────────────┬────────────────┬────────────────────────────────┐ │
│ │ Persona │ Provider │ Voice │ │
│ ├────────────────────┼────────────────┼────────────────────────────────┤ │
│ │ Jay Gatsby │ Azure │ en-US-DavisNeural (confident) │ │
│ │ Nick Carraway │ Azure │ en-US-GuyNeural (thoughtful) │ │
│ │ Daisy Buchanan │ Azure │ en-US-JennyNeural (soft) │ │
│ │ English Teacher │ Azure │ en-US-AriaNeural (clear) │ │
│ │ Premium: Custom │ ElevenLabs │ Cloned author voice │ │
│ └────────────────────┴────────────────┴────────────────────────────────┘ │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Cloud ↔ Mobile Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ PRODUCTION DEPLOYMENT TOPOLOGY │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ ┌───────────────────┐ │
│ │ MOBILE APP │ │
│ │ (iOS/Android) │ │
│ │ │ │
│ │ • Audio capture │ │
│ │ • Audio playback │ │
│ │ • WebSocket mgmt │ │
│ │ • Offline queue │ │
│ └─────────┬─────────┘ │
│ │ │
│ │ WebSocket (persistent) │
│ │ │
│ ┌────────────────────────────────────┴────────────────────────────────┐ │
│ │ EDGE / CDN LAYER │ │
│ │ (Cloudflare Workers / AWS Lambda@Edge) │ │
│ │ │ │
│ │ • WebSocket termination (reduced latency) │ │
│ │ • JWT validation at edge │ │
│ │ • Request routing to nearest region │ │
│ │ • Response caching for common queries │ │
│ └──────────────────────────────┬──────────────────────────────────────┘ │
│ │ │
│ ┌─────────────────────┼─────────────────────┐ │
│ │ │ │ │
│ ▼ ▼ ▼ │
│ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
│ │ US-WEST │ │ US-EAST │ │ EU-WEST │ │
│ │ ────────── │ │ ────────── │ │ ────────── │ │
│ │ │ │ │ │ │ │
│ │ API Gateway │ │ API Gateway │ │ API Gateway │ │
│ │ LLM Gateway │ │ LLM Gateway │ │ LLM Gateway │ │
│ │ Redis Cache │ │ Redis Cache │ │ Redis Cache │ │
│ │ │ │ │ │ │ │
│ └────────┬────────┘ └────────┬────────┘ └────────┬────────┘ │
│ │ │ │ │
│ └─────────────────────┼─────────────────────┘ │
│ │ │
│ ▼ │
│ ┌──────────────────────────────────────────────────────────────────────┐ │
│ │ SHARED SERVICES │ │
│ │ │ │
│ │ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ │ │
│ │ │ PostgreSQL │ │ STT Service │ │ TTS Service │ │ │
│ │ │ (Primary + │ │ (Deepgram/ │ │ (Azure/ │ │ │
│ │ │ Replicas) │ │ Azure) │ │ ElevenLabs) │ │ │
│ │ └───────────────┘ └───────────────┘ └───────────────┘ │ │
│ │ │ │
│ │ ┌───────────────┐ ┌───────────────┐ │ │
│ │ │ LLM Provider │ │ Blob Storage │ │ │
│ │ │ (Azure/ │ │ (Audio files,│ │ │
│ │ │ OpenAI) │ │ Transcripts)│ │ │
│ │ └───────────────┘ └───────────────┘ │ │
│ │ │ │
│ └──────────────────────────────────────────────────────────────────────┘ │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Mobile-Specific Considerations

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ MOBILE OPTIMIZATION STRATEGIES │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ 1. AUDIO CAPTURE │
│ ════════════════ │
│ iOS: AVAudioEngine with installTap() for low-latency capture │
│ Web: AudioWorklet for processing without main thread blocking │
│ Format: PCM 16kHz mono (smallest size, STT-compatible) │
│ │
│ 2. AUDIO PLAYBACK │
│ ═════════════════ │
│ iOS: AVAudioEngine with scheduled buffers for gapless streaming │
│ Web: AudioContext with AudioWorklet for smooth chunk stitching │
│ Buffer: Keep 200ms buffer to absorb network jitter │
│ │
│ 3. CONNECTION MANAGEMENT │
│ ════════════════════════ │
│ • Persistent WebSocket with automatic reconnection │
│ • Exponential backoff on failures │
│ • Queue messages during brief disconnections │
│ • Graceful degradation to text-only mode │
│ │
│ 4. OFFLINE HANDLING │
│ ═══════════════════ │
│ • Cache last persona + context locally │
│ • Queue voice questions for when connection returns │
│ • Show "offline" indicator, allow text input to queue │
│ │
│ 5. BATTERY OPTIMIZATION │
│ ═══════════════════════ │
│ • Release microphone immediately after capture │
│ • Use efficient audio codecs (Opus for streaming) │
│ • Batch small network requests │
│ │
│ 6. PUSH-TO-TALK vs VOICE ACTIVATION │
│ ═══════════════════════════════════ │
│ MVP: Push-to-talk button (simpler, more reliable) │
│ V2: Voice activation with wake word ("Hey Gatsby") │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## System Architecture (Updated with Voice)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ CONTEXT ENGINE ARCHITECTURE │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ WEB FRONTEND │ │
│ │ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │ │
│ │ │ Audio Player│ │ Chat Modal │ │ Persona Selector │ │ │
│ │ │ (tracks │ │ (question │ │ (Nick, Gatsby, │ │ │
│ │ │ position) │ │ + response│ │ Teacher, etc.) │ │ │
│ │ └──────┬──────┘ └──────┬──────┘ └───────────┬─────────────┘ │ │
│ │ │ │ │ │ │
│ │ └────────────────┴──────────────────────┘ │ │
│ │ │ │ │
│ └───────────────────────────┼─────────────────────────────────────────┘ │
│ │ │
│ ▼ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ API GATEWAY (Port 8000) │ │
│ │ │ │
│ │ POST /ai/chat │ │
│ │ { │ │
│ │ "book_id": "gatsby", │ │
│ │ "chapter": 3, │ │
│ │ "timestamp_seconds": 872, │ │
│ │ "persona_id": "jay_gatsby", │ │
│ │ "question": "Who is Jordan Baker?" │ │
│ │ } │ │
│ │ │ │
│ └───────────────────────────┬─────────────────────────────────────────┘ │
│ │ │
│ ┌───────────────────┼───────────────────┐ │
│ │ │ │ │
│ ▼ ▼ ▼ │
│ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ │
│ │ CONTEXT │ │ PERSONA │ │ PROMPT │ │
│ │ RETRIEVER │ │ MANAGER │ │ BUILDER │ │
│ │ (Interface) │ │ (Interface) │ │ │ │
│ └───────┬───────┘ └───────┬───────┘ └───────┬───────┘ │
│ │ │ │ │
│ │ ┌─────────────┴─────────────┐ │ │
│ │ │ │ │ │
│ ▼ ▼ ▼ ▼ │
│ ┌─────────────────┐ ┌─────────────────┐ │
│ │ PostgreSQL │ │ LLM GATEWAY │ │
│ │ ─────────── │ │ (Port 8002) │ │
│ │ • transcripts │ │ │ │
│ │ • personas │ │ Azure OpenAI │ │
│ │ • books │ │ or Ollama │ │
│ └─────────────────┘ └─────────────────┘ │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Modular Interface Design

The key to future-proofing is defining clean interfaces that can be swapped out.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ INTERFACE ABSTRACTION LAYERS │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ ═══════════════════════════════════════════════════════════════════════ │
│ CONTEXT & PERSONA INTERFACES (Core Engine) │
│ ═══════════════════════════════════════════════════════════════════════ │
│ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ IContextRetriever (Interface) │ │
│ │ │ │
│ │ get_context(book_id, chapter, timestamp) -> ContextResult │ │
│ │ │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│ ▲ │
│ ┌───────────────────┼───────────────────┐ │
│ ┌───────┴───────┐ ┌───────┴───────┐ ┌───────┴───────┐ │
│ │ Timestamped │ │ RAG │ │ Hybrid │ │
│ │ Retriever │ │ Retriever │ │ Retriever │ │
│ │ (Phase 1) ◄──│ │ (Future) │ │ (Future) │ │
│ └───────────────┘ └───────────────┘ └───────────────┘ │
│ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ IPersonaManager (Interface) │ │
│ │ │ │
│ │ get_persona(persona_id, book_id) -> PersonaConfig │ │
│ │ get_personas_for_book(book_id) -> List[PersonaConfig] │ │
│ │ get_voice_config(persona_id) -> VoiceConfig │ │
│ │ │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│ │
│ ═══════════════════════════════════════════════════════════════════════ │
│ VOICE INTERFACES (STT/TTS - Swappable Providers) │
│ ═══════════════════════════════════════════════════════════════════════ │
│ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ ISTTProvider (Interface) │ │
│ │ │ │
│ │ transcribe_stream(audio_chunks) -> AsyncIterator[TranscriptEvent] │ │
│ │ transcribe_batch(audio_bytes) -> TranscriptResult │ │
│ │ │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│ ▲ │
│ ┌───────────────────┼───────────────────┐ │
│ ┌───────┴───────┐ ┌───────┴───────┐ ┌───────┴───────┐ │
│ │ Deepgram │ │ Azure Speech │ │ Whisper │ │
│ │ Provider │ │ Provider │ │ Provider │ │
│ │ (Primary) ◄──│ │ (Fallback) │ │ (Offline) │ │
│ └───────────────┘ └───────────────┘ └───────────────┘ │
│ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ ITTSProvider (Interface) │ │
│ │ │ │
│ │ synthesize_stream(text, voice_config) -> AsyncIterator[AudioChunk]│ │
│ │ synthesize_batch(text, voice_config) -> AudioBytes │ │
│ │ get_available_voices() -> List[VoiceInfo] │ │
│ │ │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│ ▲ │
│ ┌───────────────────┼───────────────────┐ │
│ ┌───────┴───────┐ ┌───────┴───────┐ ┌───────┴───────┐ │
│ │ Azure Speech │ │ ElevenLabs │ │ Cartesia │ │
│ │ Provider │ │ Provider │ │ Provider │ │
│ │ (Default) ◄──│ │ (Premium) │ │ (Ultra-fast) │ │
│ └───────────────┘ └───────────────┘ └───────────────┘ │
│ │
│ ═══════════════════════════════════════════════════════════════════════ │
│ ORCHESTRATION INTERFACES (Coordinates the pipeline) │
│ ═══════════════════════════════════════════════════════════════════════ │
│ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ IChatOrchestrator (Interface) │ │
│ │ │ │
│ │ handle_text_chat(request: ChatRequest) -> ChatResponse │ │
│ │ handle_voice_chat(session: VoiceSession) -> AsyncIterator[Event] │ │
│ │ │ │
│ │ Coordinates: Context → Persona → Prompt → LLM → [TTS] │ │
│ │ │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ ISentenceBuffer (Interface) │ │
│ │ │ │
│ │ add_tokens(tokens: str) -> List[CompleteSentence] │ │
│ │ flush() -> Optional[CompleteSentence] │ │
│ │ │ │
│ │ Accumulates LLM tokens, emits complete sentences for TTS │ │
│ │ │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Python Interface Definitions

```python
# ═══════════════════════════════════════════════════════════════════════════
# CORE INTERFACES
# ═══════════════════════════════════════════════════════════════════════════

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import AsyncIterator, List, Optional
from uuid import UUID

@dataclass
class ContextResult:
 text: str
 token_estimate: int
 chapters_included: List[int]
 truncated: bool
 retrieval_method: str # "timestamped", "rag", "hybrid"

@dataclass
class VoiceConfig:
 provider: str # "azure", "elevenlabs", "cartesia"
 voice_id: str # Provider-specific voice ID
 speaking_rate: float # 0.5 - 2.0
 pitch: str # e.g., "+5%", "-10Hz"
 style: Optional[str] # Azure-specific: "cheerful", "sad", etc.

@dataclass
class PersonaConfig:
 id: UUID
 name: str
 system_prompt: str
 voice_config: VoiceConfig
 temperature: float
 is_character: bool

class IContextRetriever(ABC):
 """Retrieves book context up to a given timestamp."""

 @abstractmethod
 async def get_context(
 self,
 book_id: UUID,
 chapter: int,
 timestamp_seconds: float,
 max_tokens: int = 16000
 ) -> ContextResult:
 pass

class IPersonaManager(ABC):
 """Manages persona configurations and voice settings."""

 @abstractmethod
 async def get_persona(self, persona_id: UUID, book_id: UUID) -> PersonaConfig:
 pass

 @abstractmethod
 async def get_personas_for_book(self, book_id: UUID) -> List[PersonaConfig]:
 pass

# ═══════════════════════════════════════════════════════════════════════════
# VOICE INTERFACES (Swappable Providers)
# ═══════════════════════════════════════════════════════════════════════════

@dataclass
class TranscriptEvent:
 type: str # "partial" or "final"
 text: str
 confidence: float
 is_final: bool

@dataclass
class AudioChunk:
 data: bytes
 format: str # "pcm_16k", "mp3", "opus"
 duration_ms: int

class ISTTProvider(ABC):
 """Speech-to-Text provider interface."""

 @abstractmethod
 async def transcribe_stream(
 self,
 audio_chunks: AsyncIterator[bytes]
 ) -> AsyncIterator[TranscriptEvent]:
 """Stream audio in, get transcript events out."""
 pass

 @abstractmethod
 async def transcribe_batch(self, audio_bytes: bytes) -> str:
 """Transcribe complete audio file."""
 pass

class ITTSProvider(ABC):
 """Text-to-Speech provider interface."""

 @abstractmethod
 async def synthesize_stream(
 self,
 text: str,
 voice_config: VoiceConfig
 ) -> AsyncIterator[AudioChunk]:
 """Stream text in, get audio chunks out."""
 pass

 @abstractmethod
 async def synthesize_batch(
 self,
 text: str,
 voice_config: VoiceConfig
 ) -> bytes:
 """Synthesize complete text to audio."""
 pass

# ═══════════════════════════════════════════════════════════════════════════
# ORCHESTRATION INTERFACES
# ═══════════════════════════════════════════════════════════════════════════

@dataclass
class ChatRequest:
 book_id: UUID
 chapter: int
 timestamp_seconds: float
 persona_id: UUID
 question: str
 input_mode: str # "text" or "voice"
 output_mode: str # "text" or "voice"

@dataclass
class ChatEvent:
 type: str # "transcript", "llm_delta", "llm_end", "audio_chunk", "error"
 data: any

class IChatOrchestrator(ABC):
 """Coordinates the full chat pipeline."""

 @abstractmethod
 async def handle_text_chat(self, request: ChatRequest) -> str:
 """Simple text-in, text-out chat."""
 pass

 @abstractmethod
 async def handle_voice_chat(
 self,
 request: ChatRequest,
 audio_input: AsyncIterator[bytes]
 ) -> AsyncIterator[ChatEvent]:
 """Full streaming voice pipeline."""
 pass

class ISentenceBuffer(ABC):
 """Buffers LLM tokens and emits complete sentences."""

 @abstractmethod
 def add_tokens(self, tokens: str) -> List[str]:
 """Add tokens, return any complete sentences."""
 pass

 @abstractmethod
 def flush(self) -> Optional[str]:
 """Flush remaining content as final sentence."""
 pass
```

---

## Data Storage Strategy

### Hybrid Approach: PostgreSQL + JSON Files

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ SIMPLIFIED DATA ARCHITECTURE │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ POSTGRESQL (existing tables) JSON FILES (no migrations!) │
│ ════════════════════════════ ════════════════════════════ │
│ │
│ ┌─────────────────────────┐ ┌─────────────────────────┐ │
│ │ users │ │ /book_files/ │ │
│ │ ├── id, email, etc. │ │ └── gatsby/ │ │
│ │ └── (auth, identity) │ │ ├── transcript.json│ │
│ ├─────────────────────────┤ │ ├── personas.json │ │
│ │ purchases │ │ └── chapters/ │ │
│ │ ├── user_id, book_id │ │ ├── 1.mp3 │ │
│ │ └── (money, ownership) │ │ └── 2.mp3 │ │
│ ├─────────────────────────┤ ├─────────────────────────┤ │
│ │ books │ │ /config/ │ │
│ │ ├── id, title, etc. │ │ └── personas/ │ │
│ │ └── (catalog metadata) │ │ ├── global.json │ │
│ └─────────────────────────┘ │ └── voices.json │ │
│ └─────────────────────────┘ │
│ WHY DB: WHY FILES: │
│ • ACID for purchases • No migrations needed │
│ • User auth needs integrity • Easy to edit manually │
│ • Already exists • Version control friendly │
│ • Load once, cache in memory │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Transcript File Format

```text
/book_files/gatsby/transcript.json
```

```json
{
 "book_id": "the-great-gatsby",
 "total_chapters": 9,
 "chapters": [
 {
 "chapter": 1,
 "title": "Chapter 1",
 "duration_seconds": 1847,
 "chunks": [
 {
 "start": 0.0,
 "end": 28.5,
 "text": "In my younger and more vulnerable years my father gave me some advice that I've been turning over in my mind ever since."
 },
 {
 "start": 28.5,
 "end": 45.2,
 "text": "Whenever you feel like criticizing anyone, he told me, just remember that all the people in this world haven't had the advantages that you've had."
 }
 ]
 },
 {
 "chapter": 2,
 "title": "Chapter 2",
 "duration_seconds": 1523,
 "chunks": [
 {"start": 0.0, "end": 32.1, "text": "About half way between West Egg and New York..."}
 ]
 }
 ]
}
```

### Persona Config File Format

```text
/book_files/gatsby/personas.json
```

```json
{
 "book_id": "the-great-gatsby",
 "personas": [
 {
 "id": "jay-gatsby",
 "name": "Jay Gatsby",
 "type": "character",
 "avatar": "gatsby-avatar.png",
 "system_prompt": "You are Jay Gatsby from The Great Gatsby. You speak with confidence and charm, frequently using 'old sport'. You are mysterious about your past but eager to discuss your parties and your dreams. You are deeply romantic and optimistic despite everything.",
 "voice": {
 "provider": "azure",
 "voice_id": "en-US-DavisNeural",
 "style": "cheerful",
 "rate": 1.1
 },
 "temperature": 0.8
 },
 {
 "id": "nick-carraway",
 "name": "Nick Carraway",
 "type": "character",
 "avatar": "nick-avatar.png",
 "system_prompt": "You are Nick Carraway, the narrator of The Great Gatsby. You are observational, thoughtful, and somewhat reserved. You try to withhold judgment but have strong opinions. You speak in a measured, literary way.",
 "voice": {
 "provider": "azure",
 "voice_id": "en-US-GuyNeural",
 "style": "calm",
 "rate": 0.95
 },
 "temperature": 0.7
 }
 ]
}
```

### Global Personas Config

```text
/config/personas/global.json
```

```json
{
 "global_personas": [
 {
 "id": "english-teacher",
 "name": "English Teacher",
 "type": "guide",
 "avatar": "teacher-avatar.png",
 "system_prompt": "You are a thoughtful English teacher helping a student understand the book they're reading. You analyze themes, symbolism, character development, and literary devices. You ask Socratic questions to guide understanding rather than just giving answers. You are encouraging but intellectually rigorous.",
 "voice": {
 "provider": "azure",
 "voice_id": "en-US-AriaNeural",
 "style": "friendly",
 "rate": 1.0
 },
 "temperature": 0.7
 },
 {
 "id": "language-tutor",
 "name": "Language Tutor",
 "type": "guide",
 "system_prompt": "You help language learners understand vocabulary, grammar, idioms, and pronunciation in the book they're reading. You explain things clearly and give examples. You're patient and encouraging.",
 "voice": {
 "provider": "azure",
 "voice_id": "en-US-JennyNeural",
 "style": "friendly",
 "rate": 0.9
 },
 "temperature": 0.6
 }
 ]
}
```

### Minimal Database Migration (Optional)

Only add this if you want to persist conversation history:

```sql
-- Optional: Only if you want to save chat history
-- Otherwise, conversations are session-only (simpler)

CREATE TABLE IF NOT EXISTS ai_conversations (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id UUID NOT NULL REFERENCES users(id),
 book_id VARCHAR(100) NOT NULL, -- matches book folder name
 persona_id VARCHAR(100) NOT NULL, -- matches persona id in JSON
 chapter_number INTEGER NOT NULL,
 timestamp_seconds FLOAT NOT NULL,
 question TEXT NOT NULL,
 response TEXT NOT NULL,
 created_at TIMESTAMP DEFAULT NOW()
);

-- That's it. One optional table.
```

### TypeScript/Python Interfaces

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ DATA STRUCTURES │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ ContextRequest ContextResult │
│ ┌─────────────────────────┐ ┌─────────────────────────────────┐ │
│ │ book_id: UUID │ │ text: str │ │
│ │ chapter: int │ ──► │ token_estimate: int │ │
│ │ timestamp_seconds: float│ │ chapters_included: List[int] │ │
│ └─────────────────────────┘ │ truncated: bool │ │
│ │ retrieval_method: str │ │
│ └─────────────────────────────────┘ │
│ │
│ PersonaConfig ChatRequest │
│ ┌─────────────────────────────┐ ┌─────────────────────────────────┐ │
│ │ id: UUID │ │ book_id: UUID │ │
│ │ name: str │ │ chapter: int │ │
│ │ display_name: str │ │ timestamp_seconds: float │ │
│ │ system_prompt: str │ │ persona_id: UUID │ │
│ │ voice_style: str │ │ question: str │ │
│ │ avatar_url: str │ │ conversation_history: List[...] │ │
│ │ temperature: float │ └─────────────────────────────────┘ │
│ │ is_character: bool │ │
│ │ knowledge_boundary: str │ ChatResponse │
│ └─────────────────────────────┘ ┌─────────────────────────────────┐ │
│ │ response: str │ │
│ │ persona_name: str │ │
│ │ tokens_used: int │ │
│ │ context_chapters: List[int] │ │
│ └─────────────────────────────────┘ │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## API Specification

### POST /ai/chat

Primary endpoint for context-aware AI chat.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ POST /ai/chat │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ REQUEST │
│ Headers: │
│ Authorization: Bearer <jwt_token> │
│ Content-Type: application/json │
│ │
│ Body: │
│ { │
│ "book_id": "550e8400-e29b-41d4-a716-446655440000", │
│ "chapter": 3, │
│ "timestamp_seconds": 872.5, │
│ "persona_id": "660e8400-e29b-41d4-a716-446655440001", │
│ "question": "Who is Jordan Baker?", │
│ "include_history": true // Optional: include recent Q&A │
│ } │
│ │
│ ───────────────────────────────────────────────────────────────────── │
│ │
│ RESPONSE (200 OK) │
│ { │
│ "response": "Ah, Miss Baker! A most striking young woman, old sport...",│
│ "persona": { │
│ "id": "660e8400-e29b-41d4-a716-446655440001", │
│ "name": "Jay Gatsby", │
│ "avatar_url": "/personas/gatsby-avatar.png" │
│ }, │
│ "context_info": { │
│ "chapters_included": [1, 2, 3], │
│ "tokens_used": 4521, │
│ "retrieval_method": "timestamped_chunks" │
│ }, │
│ "conversation_id": "770e8400-e29b-41d4-a716-446655440002" │
│ } │
│ │
│ ───────────────────────────────────────────────────────────────────── │
│ │
│ ERROR RESPONSES │
│ 401: Unauthorized (invalid/missing token) │
│ 403: Book not in user's library │
│ 404: Book or persona not found │
│ 422: Invalid request (missing fields, invalid timestamp) │
│ 503: LLM service unavailable │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### GET /books/{book_id}/personas

Get available personas for a book.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ GET /books/{book_id}/personas │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ RESPONSE (200 OK) │
│ { │
│ "book_personas": [ │
│ { │
│ "id": "...", │
│ "name": "Jay Gatsby", │
│ "description": "The mysterious millionaire himself", │
│ "avatar_url": "/personas/gatsby.png", │
│ "is_character": true │
│ }, │
│ { │
│ "id": "...", │
│ "name": "Nick Carraway", │
│ "description": "The narrator, your neighbor in West Egg", │
│ "avatar_url": "/personas/nick.png", │
│ "is_character": true │
│ } │
│ ], │
│ "global_personas": [ │
│ { │
│ "id": "...", │
│ "name": "English Teacher", │
│ "description": "Analyze themes, symbolism, and literary devices", │
│ "avatar_url": "/personas/teacher.png", │
│ "is_character": false │
│ } │
│ ] │
│ } │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Request Flow (Detailed)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ DETAILED REQUEST FLOW │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ 1. USER CLICKS "ASK AI" AT CHAPTER 3, 14:32 │
│ │ │
│ ▼ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ Frontend captures: │ │
│ │ • current_chapter = 3 │ │
│ │ • current_time = audioElement.currentTime (872.5 seconds) │ │
│ │ • book_id from current context │ │
│ └──────────────────────────────────┬──────────────────────────────────┘ │
│ │ │
│ 2. USER SELECTS PERSONA + TYPES QUESTION │
│ │ │
│ ▼ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ POST /ai/chat │ │
│ │ {book_id, chapter: 3, timestamp: 872.5, persona_id, question} │ │
│ └──────────────────────────────────┬──────────────────────────────────┘ │
│ │ │
│ 3. API GATEWAY RECEIVES REQUEST │
│ │ │
│ ├──► Validate JWT token │
│ ├──► Verify user owns this book │
│ ├──► Validate persona exists and is available for book │
│ │ │
│ ▼ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ 4. CONTEXT RETRIEVER │ │
│ │ │ │
│ │ context = context_retriever.get_context( │ │
│ │ book_id=book_id, │ │
│ │ chapter=3, │ │
│ │ timestamp_seconds=872.5 │ │
│ │ ) │ │
│ │ │ │
│ │ SQL Query: │ │
│ │ SELECT text_content FROM book_transcripts │ │
│ │ WHERE book_id = $1 │ │
│ │ AND (chapter_number < $2 │ │
│ │ OR (chapter_number = $2 AND start_seconds <= $3)) │ │
│ │ ORDER BY chapter_number, chunk_index │ │
│ │ │ │
│ │ Returns: ~15,000 tokens of text (Chapters 1-3 up to 14:32) │ │
│ └──────────────────────────────────┬──────────────────────────────────┘ │
│ │ │
│ ▼ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ 5. PERSONA MANAGER │ │
│ │ │ │
│ │ persona = persona_manager.get_persona(persona_id, book_id) │ │
│ │ │ │
│ │ Returns: │ │
│ │ { │ │
│ │ name: "Jay Gatsby", │ │
│ │ system_prompt: "You are Jay Gatsby from The Great Gatsby...", │ │
│ │ voice_style: "Formal 1920s speech, uses 'old sport'...", │ │
│ │ temperature: 0.8 │ │
│ │ } │ │
│ └──────────────────────────────────┬──────────────────────────────────┘ │
│ │ │
│ ▼ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ 6. PROMPT BUILDER │ │
│ │ │ │
│ │ prompt = prompt_builder.build( │ │
│ │ persona=persona, │ │
│ │ context=context, │ │
│ │ question=question, │ │
│ │ history=conversation_history │ │
│ │ ) │ │
│ │ │ │
│ │ ┌─────────────────────────────────────────────────────────────┐ │ │
│ │ │ SYSTEM: You are Jay Gatsby from The Great Gatsby. │ │ │
│ │ │ You speak in formal 1920s style, often using "old sport". │ │ │
│ │ │ │ │ │
│ │ │ IMPORTANT: The reader is at Chapter 3, 14:32. You may ONLY │ │ │
│ │ │ reference events from the book context below. Do NOT │ │ │
│ │ │ mention, hint at, or spoil ANY events beyond this point. │ │ │
│ │ │ │ │ │
│ │ │ BOOK CONTEXT (everything the reader has experienced): │ │ │
│ │ │ [Chapter 1 text...] │ │ │
│ │ │ [Chapter 2 text...] │ │ │
│ │ │ [Chapter 3 text up to 14:32...] │ │ │
│ │ │ │ │ │
│ │ │ === END OF READER'S KNOWLEDGE - SPOILER BOUNDARY === │ │ │
│ │ │ │ │ │
│ │ │ USER: Who is Jordan Baker? │ │ │
│ │ └─────────────────────────────────────────────────────────────┘ │ │
│ └──────────────────────────────────┬──────────────────────────────────┘ │
│ │ │
│ ▼ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ 7. LLM GATEWAY CALL │ │
│ │ │ │
│ │ response = await llm_gateway.complete( │ │
│ │ messages=[{"role": "system", "content": system_prompt}, │ │
│ │ {"role": "user", "content": user_message}], │ │
│ │ temperature=persona.temperature, │ │
│ │ max_tokens=500 │ │
│ │ ) │ │
│ └──────────────────────────────────┬──────────────────────────────────┘ │
│ │ │
│ ▼ │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ 8. SAVE & RESPOND │ │
│ │ │ │
│ │ • Save conversation to ai_conversations table │ │
│ │ • Return formatted response to frontend │ │
│ │ • Frontend displays with persona avatar and name │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## File Structure

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ PROJECT STRUCTURE │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ book_files/ ◄── CONTENT (JSON + Audio) │
│ ├── gatsby/ │
│ │ ├── transcript.json # Timestamped text chunks │
│ │ ├── personas.json # Book-specific personas │
│ │ ├── cover.jpg │
│ │ └── chapters/ │
│ │ ├── 1.mp3 │
│ │ └── 2.mp3 │
│ └── moby-dick/ │
│ ├── transcript.json │
│ ├── personas.json │
│ └── chapters/... │
│ │
│ config/ ◄── CONFIGURATION (JSON) │
│ ├── personas/ │
│ │ ├── global.json # English Teacher, Language Tutor │
│ │ └── voices.json # Default voice mappings │
│ └── prompts/ │
│ └── spoiler_boundary.txt # Reusable prompt fragments │
│ │
│ platform/backend/services/api_gateway/ ◄── BACKEND │
│ ├── main.py # Add routes + WebSocket │
│ ├── routers/ │
│ │ ├── ai_chat.py # NEW: POST /ai/chat │
│ │ └── voice_chat.py # NEW: WebSocket /ai/voice-chat │
│ ├── context/ │
│ │ ├── interfaces.py # NEW: IContextRetriever │
│ │ ├── json_retriever.py # NEW: Load from transcript.json │
│ │ └── prompt_builder.py # NEW: Build LLM prompts │
│ ├── personas/ │
│ │ ├── interfaces.py # NEW: IPersonaManager │
│ │ └── json_persona_manager.py # NEW: Load from personas.json │
│ └── voice/ │
│ ├── interfaces.py # NEW: ISTTProvider, ITTSProvider │
│ ├── stt/ │
│ │ ├── azure_stt.py # NEW: Azure Speech STT │
│ │ └── deepgram_stt.py # NEW: Deepgram STT │
│ ├── tts/ │
│ │ ├── azure_tts.py # NEW: Azure Speech TTS │
│ │ └── elevenlabs_tts.py # NEW: ElevenLabs TTS │
│ ├── sentence_buffer.py # NEW: Tokens → sentences │
│ └── orchestrator.py # NEW: STT→LLM→TTS pipeline │
│ │
│ platform/frontend/simple_web/ ◄── FRONTEND │
│ ├── index.html # Add chat UI │
│ ├── js/ │
│ │ ├── app.js # Chat integration │
│ │ ├── chat.js # NEW: Text chat modal │
│ │ ├── voice-chat.js # NEW: Voice + WebSocket │
│ │ └── audio-worklet.js # NEW: Low-latency audio │
│ └── css/ │
│ └── chat.css # NEW: Chat styling │
│ │
└─────────────────────────────────────────────────────────────────────────────┘

NO NEW DATABASE MIGRATIONS REQUIRED!
Just JSON files you can edit with any text editor.
```

---

## Implementation Phases

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ IMPLEMENTATION ROADMAP │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ PHASE 1 PHASE 2 PHASE 3 PHASE 4 PHASE 5 │
│ Foundation Text Chat Voice Input Voice Output Polish │
│ ────────── ───────── ─────────── ──────────── ────── │
│ │
│ • DB Schema • /ai/chat • WebSocket • TTS • Mobile │
│ • Interfaces • Prompts • STT • Streaming • Edge │
│ • Context • Frontend • Audio • Sentence • Caching │
│ • Personas • Streaming • Push-to-talk • Buffer • Monitoring │
│ │
│ Week 1 Week 2 Week 3 Week 4 Week 5+ │
│ │
│ ████████████████████████████████████████████████████████████ │
│ │ TEXT CHAT WORKING │ VOICE CHAT WORKING │ PROD │ │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Phase 1: Foundation (Week 1)

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 1: JSON FILES + CORE INTERFACES │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ GOAL: Set up content files and core interfaces (NO database migrations) │
│ │
│ □ Create transcript.json for The Great Gatsby │
│ ├── Chapter 1-3 with timestamped text chunks │
│ ├── ~30 second chunks with start/end times │
│ └── Can use Whisper or manual transcription │
│ │
│ □ Create personas.json for The Great Gatsby │
│ ├── Jay Gatsby (system prompt + voice config) │
│ ├── Nick Carraway (system prompt + voice config) │
│ └── Daisy Buchanan (system prompt + voice config) │
│ │
│ □ Create config/personas/global.json │
│ ├── English Teacher │
│ ├── Language Tutor │
│ └── Socratic Guide │
│ │
│ □ Define Python interfaces (contracts for future swapping) │
│ ├── IContextRetriever │
│ ├── IPersonaManager │
│ ├── ISTTProvider │
│ ├── ITTSProvider │
│ └── ISentenceBuffer │
│ │
│ □ Implement JsonContextRetriever │
│ └── Load transcript.json, return text up to timestamp │
│ │
│ □ Implement JsonPersonaManager │
│ └── Load personas.json + global.json, merge and return │
│ │
│ DELIVERABLE: Can retrieve context + persona for any book position │
│ No database changes. Just JSON files + Python code. │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Phase 2: Text Chat API + Frontend (Week 2)

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 2: TEXT CHAT END-TO-END │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ GOAL: Working text chat with context-aware, in-character responses │
│ │
│ □ Create POST /ai/chat endpoint │
│ ├── Request validation (book_id, chapter, timestamp, persona, question) │
│ ├── Authorization checks (user owns book) │
│ ├── Call context retriever + persona manager │
│ └── Build prompt + call LLM Gateway │
│ │
│ □ Implement PromptBuilder │
│ ├── System prompt template with spoiler boundary │
│ ├── Context formatting (chapter markers) │
│ └── Conversation history injection │
│ │
│ □ Add LLM streaming support │
│ └── Server-Sent Events (SSE) for progressive text display │
│ │
│ □ Craft persona system prompts │
│ ├── Jay Gatsby (confident, 1920s speech, "old sport") │
│ ├── Nick Carraway (observational, thoughtful) │
│ ├── English Teacher (analytical, Socratic) │
│ └── Language Tutor (helpful, focuses on vocabulary) │
│ │
│ □ Build frontend text chat UI │
│ ├── "Ask AI" button on audio player │
│ ├── Chat modal with persona selector │
│ ├── Text input + send button │
│ ├── Streaming response display │
│ └── Conversation history view │
│ │
│ DELIVERABLE: Full text chat working in browser │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Phase 3: Voice Input (Week 3)

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 3: VOICE INPUT (STT) │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ GOAL: User can speak questions, see text response │
│ │
│ □ Set up WebSocket endpoint /ai/voice-chat │
│ ├── Connection handling + authentication │
│ ├── Session state management │
│ └── Binary audio frame handling │
│ │
│ □ Implement AzureSTTProvider (fallback) │
│ ├── Azure Speech SDK integration │
│ ├── Streaming transcription │
│ └── Partial + final transcript events │
│ │
│ □ Implement DeepgramSTTProvider (primary) │
│ ├── Deepgram WebSocket client │
│ ├── Real-time streaming transcription │
│ └── Lower latency than Azure │
│ │
│ □ Build frontend voice input │
│ ├── Microphone access (getUserMedia) │
│ ├── Audio capture with AudioWorklet │
│ ├── Push-to-talk button │
│ ├── WebSocket connection management │
│ ├── Send audio chunks to server │
│ └── Display partial transcription │
│ │
│ □ Wire STT → existing chat pipeline │
│ └── Transcribed text feeds into PromptBuilder │
│ │
│ DELIVERABLE: Speak question → see text response │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Phase 4: Voice Output (Week 4)

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 4: VOICE OUTPUT (TTS) + STREAMING │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ GOAL: Full voice conversation with low latency │
│ │
│ □ Implement SentenceBuffer │
│ ├── Accumulate LLM tokens │
│ ├── Detect sentence boundaries (. ? ! ...) │
│ └── Emit complete sentences for TTS │
│ │
│ □ Implement AzureTTSProvider │
│ ├── Azure Speech SDK for TTS │
│ ├── Voice selection per persona │
│ ├── SSML support for expression │
│ └── Streaming audio output │
│ │
│ □ Implement ElevenLabsTTSProvider (premium) │
│ ├── ElevenLabs API integration │
│ ├── Higher quality voices │
│ └── Custom voice cloning (future) │
│ │
│ □ Build ChatOrchestrator │
│ ├── Coordinates full pipeline: STT → Context → LLM → TTS │
│ ├── Parallel sentence processing │
│ └── Error handling + fallbacks │
│ │
│ □ Build frontend audio playback │
│ ├── Receive audio chunks via WebSocket │
│ ├── AudioContext + AudioWorklet for gapless playback │
│ ├── Buffer management for smooth audio │
│ └── Visual feedback (speaking indicator) │
│ │
│ □ Optimize for latency │
│ ├── Pre-fetch context when chat opens │
│ ├── Start TTS on first sentence (don't wait for full response) │
│ └── Measure and log latency at each stage │
│ │
│ DELIVERABLE: Full voice-to-voice conversation │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Phase 5: Production Polish (Week 5+)

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 5: PRODUCTION READY │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ GOAL: Reliable, scalable, cost-effective │
│ │
│ □ Transcript tooling │
│ ├── Whisper-based audio→text alignment script │
│ ├── SRT/VTT import tool │
│ └── Bulk transcript ingestion │
│ │
│ □ Caching layer │
│ ├── Cache context retrieval results │
│ ├── Semantic cache for similar questions │
│ └── TTS audio caching for repeated phrases │
│ │
│ □ Error handling + resilience │
│ ├── STT provider failover (Deepgram → Azure) │
│ ├── TTS provider failover │
│ ├── Graceful degradation (voice → text fallback) │
│ └── Retry logic with exponential backoff │
│ │
│ □ Mobile optimizations │
│ ├── Connection handling for cellular networks │
│ ├── Offline queue for voice messages │
│ ├── Battery-efficient audio capture │
│ └── iOS/Android native audio integration │
│ │
│ □ Monitoring + observability │
│ ├── Latency metrics at each pipeline stage │
│ ├── Cost tracking (LLM tokens, STT minutes, TTS characters) │
│ ├── Error rate monitoring │
│ └── User satisfaction metrics │
│ │
│ □ Edge deployment (future) │
│ ├── WebSocket termination at edge │
│ ├── Regional API deployment │
│ └── CDN for audio file delivery │
│ │
│ DELIVERABLE: Production-ready voice chat system │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Upgrade Path to Hybrid

The modular design allows swapping implementations:

```python
# Current (Phase 1)
context_retriever = TimestampedContextRetriever(db)

# Future (Phase 2) - just change this line
context_retriever = RAGContextRetriever(db, vector_store)

# Future (Phase 3) - or this
context_retriever = HybridContextRetriever(
 timestamped=TimestampedContextRetriever(db),
 rag=RAGContextRetriever(db, vector_store),
 classifier=QueryClassifier()
)
```

The rest of the system (API, frontend, personas) remains unchanged.

---

## Success Criteria

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ SUCCESS METRICS │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ TEXT CHAT METRICS │
│ ┌────────────────────────────────┬────────────────┬─────────────────────┐ │
│ │ Metric │ Target │ Measurement │ │
│ ├────────────────────────────────┼────────────────┼─────────────────────┤ │
│ │ Response latency (text) │ < 3 seconds │ Server-side timing │ │
│ │ Spoiler incidents │ 0% │ Manual QA review │ │
│ │ In-character consistency │ > 90% │ Manual QA review │ │
│ │ Context accuracy │ 100% │ Automated tests │ │
│ └────────────────────────────────┴────────────────┴─────────────────────┘ │
│ │
│ VOICE CHAT METRICS │
│ ┌────────────────────────────────┬────────────────┬─────────────────────┐ │
│ │ Metric │ Target │ Measurement │ │
│ ├────────────────────────────────┼────────────────┼─────────────────────┤ │
│ │ Time to first audio │ < 2 seconds │ Client-side timing │ │
│ │ STT accuracy │ > 95% │ WER measurement │ │
│ │ TTS naturalness │ > 4/5 rating │ User feedback │ │
│ │ End-to-end voice latency │ < 2.5 seconds │ Client-side timing │ │
│ │ Audio quality (MOS) │ > 4.0 │ POLQA measurement │ │
│ └────────────────────────────────┴────────────────┴─────────────────────┘ │
│ │
│ RELIABILITY METRICS │
│ ┌────────────────────────────────┬────────────────┬─────────────────────┐ │
│ │ Metric │ Target │ Measurement │ │
│ ├────────────────────────────────┼────────────────┼─────────────────────┤ │
│ │ Uptime │ > 99.5% │ Monitoring │ │
│ │ Error rate │ < 1% │ Server logs │ │
│ │ Successful voice sessions │ > 95% │ Session completion │ │
│ │ Fallback activation rate │ < 5% │ Provider failovers │ │
│ └────────────────────────────────┴────────────────┴─────────────────────┘ │
│ │
│ COST METRICS (per conversation) │
│ ┌────────────────────────────────┬────────────────┬─────────────────────┐ │
│ │ Component │ Target │ Tracking │ │
│ ├────────────────────────────────┼────────────────┼─────────────────────┤ │
│ │ LLM tokens │ < 20k tokens │ API response │ │
│ │ STT cost │ < $0.01 │ Provider billing │ │
│ │ TTS cost │ < $0.02 │ Provider billing │ │
│ │ Total cost per voice chat │ < $0.05 │ Aggregated │ │
│ └────────────────────────────────┴────────────────┴─────────────────────┘ │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Open Questions

1. **Transcript source**: Generate with Whisper? Manual alignment? Existing SRT files?
2. **Token limits**: Cap context at 16k tokens? Truncate oldest chapters first?
3. **STT provider**: Start with Azure (already in stack) or Deepgram (lower latency)?
4. **TTS voices**: Pre-select Azure voices per persona, or let users customize?
5. **Mobile first**: Build web voice chat first, or target iOS native from start?
6. **Wake word**: Implement "Hey Gatsby" voice activation in V2?

---

## Summary

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ PLAN SUMMARY │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ WHAT WE'RE BUILDING │
│ ═══════════════════ │
│ A context-aware AI chat system where users can ask questions about the │
│ audiobook they're listening to, either by typing or speaking. The AI │
│ responds in-character as book personas (Gatsby, Nick, etc.) or as │
│ helpful guides (English Teacher), with full knowledge of the story up │
│ to the user's current position - and NO spoilers beyond that point. │
│ │
│ KEY FEATURES │
│ ════════════ │
│ Context-aware responses (knows where you are in the book) │
│ Spoiler prevention (hard boundary at current timestamp) │
│ Multiple personas per book (characters + teachers) │
│ Voice input (speak your question) │
│ Voice output (hear the response in persona's voice) │
│ Low latency (<2s to first audio) │
│ Streaming (don't wait for full response) │
│ │
│ ARCHITECTURE PRINCIPLES │
│ ═══════════════════════ │
│ • Modular interfaces (swap STT/TTS/LLM providers easily) │
│ • Voice-first design (text is fallback) │
│ • Stream everything (STT, LLM, TTS all streaming) │
│ • Sentence-level TTS (start speaking before LLM finishes) │
│ • Mobile-ready (WebSocket, offline handling, battery efficiency) │
│ • JSON files for content (no database migrations!) │
│ │
│ TIMELINE │
│ ════════ │
│ Week 1: JSON files + interfaces (no DB migrations) │
│ Week 2: Text chat end-to-end │
│ Week 3: Voice input (STT) │
│ Week 4: Voice output (TTS) │
│ Week 5+: Production polish │
│ │
│ DATA STORAGE │
│ ════════════ │
│ • Transcripts: JSON files in /book_files/{book}/transcript.json │
│ • Personas: JSON files in /book_files/{book}/personas.json │
│ • Global config: JSON files in /config/personas/global.json │
│ • Users/Purchases: PostgreSQL (existing tables, no changes) │
│ │
│ TECH STACK │
│ ══════════ │
│ • STT: Deepgram (primary), Azure Speech (fallback) │
│ • TTS: Azure Speech (default), ElevenLabs (premium) │
│ • LLM: Azure OpenAI (gpt-4o-mini with streaming) │
│ • Transport: WebSocket for voice, REST+SSE for text │
│ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

*Plan created: November 2025*
*Updated: Voice architecture added*
