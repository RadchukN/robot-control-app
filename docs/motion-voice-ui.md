# AI Voice Studio — UI and backend integration

AI Voice Studio (`/voice-studio`) is a separate page from Motion. It holds
five cards: Realtime Speaking, Conversation Transcript, Speak Custom Text,
Quick Motions, and Connection & Voice State. The Motion page (`/motion`) is
unchanged.

**Current status:** the Jetson voice and TTS protocol does not exist yet. The
page works fully in **Demo Mode** (on by default) with a local mock. With Demo
Mode off, voice and TTS are shown as *Unavailable* and nothing is sent.

## Where things live

```
lib/features/voice_studio/
  domain/voice_models.dart          session/device/TTS enums, entries, capabilities
  domain/transcript_buffer.dart     bounded, ordered, de-duplicating transcript
  data/voice_backend.dart           VoiceBackend interface, events, UnavailableVoiceBackend
  data/mock_voice_backend.dart      deterministic Demo Mode backend (no I/O)
  data/voice_protocol.dart          provisional v1 tts_* codec (not wired)
  application/voice_studio_providers.dart   Demo Mode, backend selection,
                                            audio-session ownership, event log
  application/realtime_voice_controller.dart  conversation state machine
  application/tts_controller.dart   TextToSpeechController + saved phrases
  presentation/                     page and the five cards
```

The controllers are kept separate:

| Concern | Provider | Notes |
|---|---|---|
| Realtime conversation | `realtimeVoiceProvider` | Never reads or calls motion. |
| Text-to-speech | `ttsProvider` | Owns request ids and correlation. |
| Saved phrases | `savedPhrasesProvider` | In memory only, max 20. Survives Demo Mode toggles. |
| Speaker ownership | `audioSessionProvider` | Exactly one of `none`, `realtime`, `tts`. |
| Motion | existing `motionProvider` | Quick Motions is only a view over it. |

## Safety rules the UI enforces

- **Demo Mode never touches the robot.** `MockVoiceBackend` opens no socket.
  Every event it emits is flagged simulated. The page shows a *Demo Mode* badge
  and "the robot is not speaking".
- **Simulated hardware is never shown as Ready.** Microphone and speaker show
  `Demo`, `Unknown` or `Unavailable`. Only a non-simulated backend can report
  `Ready`.
- **Exclusive speaker.** TTS is refused while a conversation owns the speaker,
  and the reverse. `VoiceCapabilities.ttsHandover` exists for a future
  backend-confirmed handover, but nothing implements it yet.
- **Voice never moves the robot.** The voice and TTS controllers have no access
  to motion. The demo script includes "Can you wave your hand?" to show this.
- **Quick Motions in Demo Mode:** Wave Hand and recorded-motion play are
  disabled. **Stop stays enabled and sends a real `stop_motion`**, because it
  is a safety action.
- **Quick Motions keeps the existing motion safety.** It calls
  `MotionController` (`playGesture`, `sendRecordedMotion`, `stop`, `refresh`).
  So it keeps Bearer auth on the upgrade, the existing motion JSON, `dry_run`
  handling, result correlation, and the unknown-outcome lock. A simulated Stop
  still never clears a live uncertainty.
- **No replay on reconnect.** A link drop moves a live session to
  `Disconnected` and releases the speaker. A reconnect returns to `Idle` and
  never restarts by itself.
- **Late events are ignored.** Activity that arrives after Stop cannot reopen a
  session. TTS events for any request other than the active one are ignored.
- **No conversation persistence.** The transcript lives in memory (max 200
  entries) and is cleared on Demo Mode toggles.
- **No OpenAI calls and no API key in Flutter.**

## Realtime session states

`idle → starting → listening ⇄ thinking ⇄ speaking → stopping → idle`, plus
`error`, `disconnected` (live link down) and `busy` (speaker owned by TTS).
The waveform shows `VoiceAudioLevelEvent` levels (0..1, 48 samples) only while
a session is active.

## What the Jetson backend must provide

1. **Transport.** Use the existing authenticated WebSocket (Bearer token on the
   HTTP upgrade). Do not open a second robot connection.
2. **Synthesis and playback on the Jetson.** Flutter sends text and receives
   status. Audio never streams through the app.
3. **Capabilities.** Report supported languages (the UI shows `cs-CZ`, `en-US`,
   `uk-UA`, `de-DE` but enables only what the backend reports), voices per
   language, speeds, max text length, whether realtime conversation is
   available, and whether a TTS handover is supported.
4. **Device state.** Report microphone and speaker as ready or unavailable from
   real hardware checks.
5. **Exclusive audio.** Reject a TTS request while a conversation is active
   (`tts_error` with code `audio_busy`), unless an explicit handover was
   requested and confirmed.
6. **Correlation.** Echo `request_id` on every TTS reply. Mark simulated output
   with `"dry_run": true`.

### Provisional TTS protocol (v1)

These names are a proposal. They live only in `VoiceProtocol` so they can be
renamed in one place. Frames with another `v` are ignored.

```json
{"type":"tts_speak","v":1,"request_id":"tts-3","text":"Ahoj","language":"cs-CZ","voice":"…","speed":1.0}
{"type":"tts_stop","v":1,"request_id":"tts-3"}

{"type":"tts_status","v":1,"request_id":"tts-3","state":"speaking"}
{"type":"tts_result","v":1,"request_id":"tts-3","status":"completed","dry_run":false}
{"type":"tts_result","v":1,"request_id":"tts-3","status":"cancelled"}
{"type":"tts_error","v":1,"request_id":"tts-3","code":"audio_busy","message":"…"}
```

The realtime conversation messages (start, stop, session state, transcript
deltas with utterance id and sequence, audio levels, device state,
capabilities) still need to be specified with the backend team. The event
types in `voice_backend.dart` describe what the UI expects to receive.

### Wiring a live adapter later

1. Implement `VoiceBackend` as a `LiveVoiceBackend` that writes through the
   dashboard's channel. `DashboardController._handleTelemetry` routes
   `motion_result` today, and `tts_*` and voice frames would be routed the same
   way.
2. Decode replies with `VoiceProtocol.decode` and emit them as
   `VoiceBackendEvent`s.
3. Return it from `voiceBackendProvider` when Demo Mode is off, and only after
   the backend reports capabilities.
4. Keep `unavailableReason` non-null whenever the link is down or capabilities
   are missing.

## Not supported yet

- Live realtime conversation, live TTS, and real microphone and speaker status.
- A TTS handover from an active conversation.
- Persisted saved phrases. They reset when the app restarts.
- Raise Arms, Stand Up and similar gestures from the reference image. They are
  not backend-supported motions, so they were left out on purpose.

## Tests

`test/voice_studio/`:

- `voice_logic_test.dart`: transcript ordering, de-duplication and bounds; TTS
  text validation; protocol encoding and decoding.
- `voice_controllers_test.dart`: session transitions, Start/Stop, audio-session
  conflicts, TTS cancellation and correlation, saved phrases, Demo Mode off,
  disconnect and reconnect, late events, simulated device status, and
  voice/motion isolation.
- `voice_studio_screen_test.dart`: seven viewport sizes with no overflow, Demo
  interactions, TTS editor and phrases, Quick Motions gating, and separate
  navigation from Motion.

Existing motion regressions are covered by `test/motion_dry_run_test.dart`.
