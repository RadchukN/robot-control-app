# Audio devices (Settings → Connectivity)

The **Audio devices** card chooses the microphone and speaker that the
Jetson voice runtime uses. It talks to the Jetson **`medza.audio` v1**
protocol, as defined in the Jetson repository (`~/unitree_g1_max`,
`docs/audio_devices.md` §1–§7).

## Contract summary (what Flutter relies on)

- **Transport:** the existing robot WebSocket (`ws://<host>:8765/`) with the
  existing Bearer token on the upgrade. One JSON object per text frame.
  There is no second connection. Telemetry and motion are unchanged.
- **Capability probe:** `audio_get_capabilities` → `audio_capabilities`.
  - No reply within **3 s** means audio settings are unavailable.
  - Flutter requires `protocol == "medza.audio"` and
    `protocol_version == 1`.
  - Tests are allowed only when `tests_enabled` is true (the server's
    `--audio-tests` flag).
- **Requests (only the documented fields, plus `request_id`):**
  - `audio_get_devices` → `audio_devices`
  - `audio_device_status` → `audio_device_status`
  - `audio_get_settings` → `audio_settings`
  - `audio_set_settings {input_device_id?, output_device_id?}` → a pushed
    `audio_settings`, then
    `audio_result {action:"set_settings", status:"completed"}`
  - `audio_test_input {confirm:true, device_id, duration_sec 1–5}` and
    `audio_test_output {confirm:true, device_id}` → `audio_result`
    `accepted`, then a final `completed` or `rejected`
- **Correlation:** every direct reply echoes `request_id`. Pushes never
  carry one. A test's final result may arrive after later replies.
- **Pushes:** `audio_device_status` (with `devices_changed`),
  `audio_settings` and `audio_error`. A connection is subscribed from its
  first `audio_*` request. Unknown fields and pushed types are ignored.
- **Device IDs** are opaque and server-generated (`robot:mic`,
  `robot:speaker`, `system:default`,
  `usb:<vid>:<pid>[:<serial>][:dev<N>][@<usb-port>]`, `hdmi:<n>`). Flutter
  stores and sends them unchanged.
- **Saved vs active:** `audio_settings.input`/`output` is the saved
  selection (with `source`: `settings`, `env`, or `env_fallback`). Changes
  apply at `voice_runtime_start` and are **never applied live**. A device is
  "in use" only while `session.active`, according to
  `session.input_device_id` and `session.output_device_id`.
- **Busy:** `audio_result` `busy` with `audio_session_active` or
  `audio_test_running`, plus `owner`. The robot's lock is authoritative.
- **Tests cannot be cancelled.** There is no cancel message, and a test
  runs to its end even if the client disconnects.

## Flutter architecture

```
DashboardController (existing socket)
  ├─ _handleTelemetry: frames with type "audio_*" → audioFrames stream
  │                   (checked before the motion and telemetry branches)
  └─ sendAudioFrame(): only "audio_*" frames, only while authenticated
        ▲
DashboardAudioTransport  ← audioFrameTransportProvider
        ▲
LiveAudioDeviceBackend   request ids "fl-<n>", pending map, 3 s probe,
        ▲                pushes → events, accepted → wait for final result
audioDeviceBackendProvider
  Demo Mode → MockAudioDeviceBackend (simulated, never sends)
  link open → LiveAudioDeviceBackend (new instance per connection)
  otherwise → UnavailableAudioDeviceBackend ("Robot is not connected.")
        ▲
AudioDevicesController   capabilities → devices → status; selection;
        ▲                pushes; busy gating; bounded tests
_AudioDevicesCard        unchanged layout; status text per state
```

Files:

- `lib/features/settings/data/medza_audio_protocol.dart`: the exact codec.
- `lib/features/settings/data/live_audio_device_backend.dart`: the
  transport and correlation.
- `lib/features/settings/data/audio_device_backend.dart`: the models, plus
  the mock and unavailable backends.
- `lib/features/settings/application/audio_devices_controller.dart`: the
  state and the providers.
- `lib/features/settings/presentation/audio_devices_card.dart`: the UI.
- `lib/features/dashboard/application/dashboard_controller.dart`: audio
  routing and sending (additive).

## States shown per direction

| State | Shown when |
|---|---|
| Local choice, "Not saved" | The user picked a device the robot hasn't saved (rejected, busy or timed out) |
| "Saving on the robot…" | `audio_set_settings` is pending |
| "Saved on the robot · applies when the voice runtime next starts" | `audio_settings` confirms it (`source: settings`) |
| "Robot default from .env" | `source: env` (no settings file yet) |
| Configuration error, offer to re-save | `settings_file.status: invalid` / `source: env_fallback` |
| "In use by the current voice session" | `session.active` and the session device id matches |
| "Disconnected, the robot does not switch" | The saved device is unplugged (`status: disconnected`) |
| "· unverified" | `verified: false` |

Changes and tests are disabled while Flutter's own voice or TTS session is
active, while the robot reports `session.active` or `test_running`, while
disconnected, and when the capability is missing.

## Safe manual verification on the robot

Do these with the robot standing still or seated, no motion commands sent,
and no Realtime Speaking session running. Stop `gustav.service` first: the
Jetson audio lock does not cover it.

1. On the Jetson, start the WebSocket server as usual, **without**
   `--audio-tests`.
2. Connect from the app over Ethernet (`192.168.123.164:8765`, existing
   token). Turn **Demo Mode off** in AI Voice Studio.
3. Open Settings → Connectivity. Expect real devices only (for example
   "DJI Wireless Mic Rx", "Unitree G1 built-in speaker"), with no
   "(simulated)" labels and both test buttons disabled ("test is disabled
   on the robot").
4. Pick a different microphone. Expect "Saving…", then "Saved on the robot ·
   applies when the voice runtime next starts". Confirm on the Jetson that
   `~/.config/medza/audio_devices.json` changed and that nothing else did
   (volume, mixer, `.env`).
5. Unplug and replug the USB receiver. Within about 2 s expect "Audio
   device disconnected", with the saved device still shown as disconnected
   (never replaced), and then recovery.
6. Only if hardware tests are wanted: restart the server with
   `--audio-tests` in a quiet setting. "Test microphone" asks for
   confirmation and shows RMS and peak dBFS from the robot. "Test speaker"
   asks for confirmation and plays a 1 s, 440 Hz tone at the current
   volume. Neither can be cancelled.

## Known limitations

- A microphone loss shorter than the 2 s poll can go unreported (backend).
- Tests cannot be cancelled. "Stop waiting" only stops the UI from waiting.
- The robot's audio lock does not cover `gustav.service`, Unitree's own
  audio, or background music (backend §7).
- The local choice lives in `SettingsState`, which is in memory until
  `SettingsPersistence` is bound. The robot's saved file is the durable
  record.
