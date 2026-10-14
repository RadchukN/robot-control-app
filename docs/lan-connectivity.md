# Local robot connectivity

The existing Ethernet profile retains `192.168.123.164:8765`. This is the legacy
configuration. The approved Jetson LAN endpoint is `ws://192.168.188.50:8765/`.
Select Settings > Connectivity > LAN / Wi-Fi, verify the IP and port, enter the
bearer token, then Connect. The LAN profile now starts with the approved IP.
Connect saves a nonempty token before connecting; blank keeps the saved token.
Connect uses the existing dashboard
WebSocket and unchanged JSON telemetry, catalog, and motion command handlers.
Profiles select endpoints; they do not select a device network interface.
Endpoint settings apply to the app session only. Tokens persist in endpoint-scoped
OS-backed secure storage. Save token a nd Remove saved token manage credentials
without putting credentials in preferences. Disconnect cancels retries.

Only a successful HTTP upgrade (101) confirms authentication; commands still
require recognized fresh telemetry. After five seconds
without telemetry, the connection is degraded and commands are disabled; after
15 seconds the socket is closed and retried. Retry delay doubles from two seconds
to a maximum of 32 seconds, resetting only on telemetry. Command replies and
malformed frames do not refresh telemetry. No motion or walking command is queued
or replayed. Pending command outcomes become unknown on connection loss. App
suspension closes the socket; resume reconnects only if not explicitly disconnected.

Only private IPv4, link-local IPv4, and loopback endpoints are accepted. No discovery,
public endpoints, router changes, port forwarding, or physical robot commands are
performed. Use a trusted dedicated router with client isolation disabled between
the operator device and Jetson. Cleartext WebSocket traffic is not encrypted.

## Backend coordination (no backend changes made)

In `unitree_g1_max`, verify aiohttp listens on the Jetson LAN interface at port 8765
and the host firewall permits only the dedicated LAN. Confirm actual telemetry
cadence against freshness thresholds. Do not change motion handlers or Unitree SDK.
The server must not redirect clients to public addresses or expose its port through
the router's WAN interface.

`robotAuthenticationProvider` now uses the approved `Authorization: Bearer <token>`
HTTP upgrade contract. No JSON authentication, query token, or subprotocol is added.
HTTP 401 latches an authentication-required state and stops reconnects for that
endpoint, including explicit Connect and app resume. Only a changed stored token
clears the latch; saving the same rejected token does not. Other endpoints can
connect independently. LAN requires a token before networking; Ethernet remains
compatible with legacy unauthenticated servers and sends a saved token if present.
Tokens are loaded again for each reconnect. Neither exception text, remote close
reasons nor HTTP response bodies are included in connection logs or status errors.

`flutter_secure_storage` 10.3.4 uses Windows OS-backed DPAPI encryption in its
resolved Windows 4.2.2 implementation, Apple Keychain, and Android Keystore-backed
encryption. It does not persist tokens in plaintext preferences. Credential fields
are obscured, never prefilled, and cleared after successful saves. Store failures
fail closed with a generic message. Tests inject in-memory or failing stores; an
actual OS credential persistence smoke test remains required on deployment devices.

The installed `web_socket_channel` 3.0.3 supports custom headers on Windows through
`IOWebSocketChannel.connect`. The installed Dart 3.12.2 exposes structured
`WebSocketException.httpStatusCode`, preserved inside `WebSocketChannelException`.
Older Dart SDKs without that metadata cannot reliably distinguish 401; their
unclassified failures use normal backoff, never error-text parsing.

Flutter Web cannot set a custom Authorization upgrade header or reliably inspect
HTTP handshake status. Authenticated LAN connections and token persistence are
therefore disabled on Web with a clear status message. No browser authentication
alternative is invented; one requires a separately approved backend contract.

## Platform verification

Android release manifests now declare INTERNET and allow cleartext transport for
the configurable ws endpoint. Android manifest rules cannot scope a dynamic
private subnet; endpoint validation limits this WebSocket path. Other existing
HTTP clients retain their own configuration. The project inherits targetSdk from
Flutter (installed SDK currently defaults to targetSdk 36): if moving to SDK 37+, implement ACCESS_LOCAL_NETWORK runtime permission
before connecting, as required by Android's local-network permission rules.

iOS declares its local-network purpose and a local ATS exception; no global ATS
exception or Bonjour discovery is added. Dart socket behavior and permission
prompts must be verified on a real iOS device. A denied local-network permission
is surfaced as connection failure; enable it in system Settings. An HTTPS-hosted
Flutter web build may block ws as mixed content; use an agreed wss deployment for
that scenario. No alternate wss/auth protocol is invented here.

Apple runner entitlements include the secure-storage Keychain capability, and
Android auto-backup is disabled to prevent restoring unusable encrypted credentials.
Windows plugin setup requires Developer Mode/symlink support. `flutter pub get`
resolved dependencies here but reported that symlink prerequisite; enable Windows
Developer Mode before a native desktop build. No system setting was changed.

Tests use a loopback mock WebSocket server and never contact the robot. Android/iOS
device permission and release-build smoke checks are manual and remain required.

Platform references: [Android local-network permissions](https://developer.android.com/privacy-and-security/local-network-permission),
[Android cleartext configuration](https://developer.android.com/privacy-and-security/security-config),
[Apple local-network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy),
and [Apple local ATS exceptions](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking).

Authentication references: [IOWebSocketChannel headers](https://pub.dev/documentation/web_socket_channel/latest/io/IOWebSocketChannel/IOWebSocketChannel.connect.html),
[Dart structured upgrade status](https://api.dart.dev/dart-io/WebSocketException/WebSocketException.html),
[secure storage](https://pub.dev/packages/flutter_secure_storage/versions/10.3.4),
and [browser WebSocket API](https://websockets.spec.whatwg.org/#the-websocket-interface).
