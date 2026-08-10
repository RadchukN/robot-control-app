# Robot Control App

Production-ready Flutter foundation for the Robot Control client. The application is
currently UI and infrastructure only: it does not invoke robot motion, audio, vision,
DDS, ROS2, or runtime business logic.

## Technology

- Flutter stable and Dart with Material 3
- Riverpod for dependency injection and state management
- go_router with state-preserving shell navigation
- Dio for HTTP transport
- web_socket_channel for future real-time transport
- Freezed and json_serializable with build_runner for future generated models

## Architecture

The codebase follows a feature-first structure around reusable core infrastructure:

```text
lib/
├── core/
│   ├── api/          # Dio client, API and connection providers
│   ├── config/       # Environment-backed application configuration
│   ├── constants/    # Shared technical constants
│   ├── routing/      # go_router routes and navigation shell
│   ├── theme/        # Material 3 colors, type, spacing, themes and state
│   └── utils/        # Cross-cutting utility types
├── models/           # Immutable application models
├── services/         # Robot API and WebSocket transport boundaries
├── shared/widgets/   # Reusable presentation components
├── features/
│   ├── dashboard/
│   ├── motion/
│   ├── audio/
│   ├── vision/
│   └── settings/
├── app.dart          # MaterialApp composition
└── main.dart         # ProviderScope entry point
```

Feature screens depend on providers and services, not directly on Dio. `ApiClient`
owns HTTP configuration and response validation. `RobotService` defines the initial
API boundary with `health`, `runtime`, `project`, `services`, and `motions` methods.
No network request runs automatically at application startup.

## State management

Riverpod provides request-independent dependency injection and observable state:

- `appConfigProvider` resolves compile-time configuration.
- `apiClientProvider` owns and disposes the configured Dio instance.
- `robotServiceProvider` exposes the Robot Control API boundary.
- `connectionProvider` tracks disconnected, connecting, connected, and failed states.
- `themeProvider` manages system, light, and dark theme modes.

Providers are named for diagnostics and can be overridden in tests.

## Navigation

`StatefulShellRoute.indexedStack` preserves each tab's navigation stack. The Material
3 bottom navigation contains Dashboard, Motion, Audio, Vision, and Settings.

| Route | Screen |
| --- | --- |
| `/` | Dashboard |
| `/dashboard` | Redirect to Dashboard |
| `/motion` | Motion |
| `/audio` | Audio |
| `/vision` | Vision |
| `/settings` | Settings |

## Theme

Light and dark themes share one seeded color palette, typography scale, spacing tokens,
and border radii. Theme mode defaults to the operating-system preference and can be
changed on the Settings screen.

## Configuration

Defaults are suitable for local development:

```text
API_URL=http://127.0.0.1:8000
DEBUG_MODE=<Flutter debug mode>
APP_NAME=Robot Control
APP_VERSION=0.1.0
```

Override values through Dart defines:

```bash
flutter run --dart-define=API_URL=http://192.168.1.10:8000
```

## Setup and run

Install the latest Flutter stable SDK, confirm it is available in `PATH`, then run:

```bash
flutter channel stable
flutter upgrade
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run
```

A minimal web runner is included, so the application can also be launched with:

```bash
flutter run -d chrome
```

Generated Freezed/JSON files are not required by the foundation yet; build_runner is
configured for models introduced in later feature stages.
