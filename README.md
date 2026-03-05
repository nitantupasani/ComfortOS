
# ComfortOS — Smart Building Comfort Platform (Flutter)

A demo Flutter mobile client implementing the C4 component diagram for a Smart Building platform.
This repository includes a Flutter app (frontend) wired to a dummy in-process backend for rapid development and testing.

---

**Quick status**
- App built and wired to a dummy backend located at `lib/data/dummy_backend.dart`.
- SDUI (Server-Driven UI) renderer included; app falls back to an internal default dashboard when server config is missing.
- Offline vote queue, encrypted local storage (Hive), sync worker, and token-based auth simulated.

---

## Demo accounts
- `alice@comfort.io` / `password` — occupant
- `bob@comfort.io` / `password` — manager
- `admin@comfort.io` / `password` — admin

---

## Run (development)

1. Ensure Flutter SDK is installed and available on PATH.
2. From the project root run:

```bash
flutter pub get
flutter run
```

3. To run tests:

```bash
flutter test
```

4. To run static analysis:

```bash
flutter analyze
```

You can open the Dart VM service / DevTools when running in debug mode; the run logs will print the DevTools URL.

---

## Performance & profiling notes
- If you see UI jank ("Skipped frames", "Davey!"), open DevTools Timeline and CPU profiler.
- Defer heavy startup tasks using `WidgetsBinding.instance.addPostFrameCallback` and offload CPU-heavy JSON parsing to a background isolate via `compute()`.

---

## Where in-app logs come from
- The app contains an in-memory structured logger: `lib/platform/logger.dart` (`AppLogger.buffer`).
- `Settings` screen reads `AppLogger.buffer` and displays recent entries.
- System logs (logcat) are separate; long-frame messages come from Android HWUI and indicate a UI-thread stall.

---

## Primary files & folders (high level)

- `lib/`
	- `main.dart` — app entrypoint and bootstrap (initial restore + Provider overrides)
	- `app.dart` — root `ComfortOSApp` widget
	- `router/app_router.dart` — `GoRouter` with auth & building-context guards
	- `domain/` — pure domain models and logic
		- `models/` — `user.dart`, `building.dart`, `vote.dart`, etc.
		- `vote_domain.dart` — vote creation & idempotency logic
		- `permissions_engine.dart` — role & tenant checks
	- `data/` — data layer and local persistence
		- `dummy_backend.dart` — in-memory simulated Platform API + Identity Provider
		- `api_client.dart` — token injection, rate-limiting, idempotent requests
		- `encrypted_local_storage.dart` — Hive storage wrapper
		- `offline_vote_queue.dart` — encrypted offline queue
	- `services/` — service components
		- `auth_service.dart`, `presence_resolver.dart`, `config_governance.dart`, `sync_worker.dart`, `notification_handler.dart`
	- `state/` — Riverpod providers and state notifiers
		- `providers.dart` — provider graph mirroring the C4 diagram
		- `auth_state.dart`, `presence_state.dart`, `vote_state.dart`, `notification_state.dart`
	- `ui/`
		- `screens/` — `login_screen.dart`, `home_screen.dart`, `dashboard_screen.dart`, `vote_screen.dart`, `presence_screen.dart`, `settings_screen.dart`
		- `widgets/` — `vote_form_widget.dart`, `presence_indicator.dart`, `error_boundary.dart`
		- `sdui/` — `sdui_renderer.dart`, `sdui_widget_registry.dart`, `default_dashboard.dart`
	- `platform/` — `logger.dart` (structured in-memory logger + crash facade)

- `test/` — unit tests (e.g. `widget_test.dart` contains domain tests for `VoteDomain` and `PermissionsEngine`)
- `pubspec.yaml` — project dependencies (includes `flutter_riverpod`, `go_router`, `hive`, `uuid`)

---

## Selected file references
- App entry: [lib/main.dart](lib/main.dart)
- Root widget: [lib/app.dart](lib/app.dart)
- Router: [lib/router/app_router.dart](lib/router/app_router.dart)
- Dummy backend: [lib/data/dummy_backend.dart](lib/data/dummy_backend.dart)
- SDUI renderer: [lib/ui/sdui/sdui_renderer.dart](lib/ui/sdui/sdui_renderer.dart)
- Default dashboard: [lib/ui/sdui/default_dashboard.dart](lib/ui/sdui/default_dashboard.dart)
- Offline queue: [lib/data/offline_vote_queue.dart](lib/data/offline_vote_queue.dart)
- Logger: [lib/platform/logger.dart](lib/platform/logger.dart)

---

## How SDUI works (brief)
- The backend (here, `DummyBackend`) returns a JSON tree for the dashboard and vote form.
- `SDUIRenderer` (in `lib/ui/sdui`) recursively builds widgets using `SDUIWidgetRegistry`.
- If the server returns `null` for a building's dashboard, the app uses `DefaultDashboard.config` as the fallback.

---

## Extending / swapping the backend
- Replace `lib/data/dummy_backend.dart` with a real network-backed implementation and update the provider in `lib/state/providers.dart` where `dummyBackendProvider` is used.
- `ApiClient` already encapsulates token injection and idempotency handling so swapping to real HTTP calls is straightforward.

---

## Developer notes & tips
- Use the demo accounts above for quick testing.
- For performance issues: open the DevTools URL printed by `flutter run`, record a Timeline, and look for long tasks on the UI thread; migrating heavy parse work to `compute()` is typically the fastest win.
- To persist more complex types in Hive consider registering TypeAdapters.

---

If you want, I can:
- Add `README` sections with code pointers for migrating the dummy backend to a network client.
- Patch startup to move heavy JSON decoding to `compute()` and defer restores until after first frame to reduce jank.
