# ComfortOS: A Scalable, Server-Driven Platform for Bidirectional Communication Between Smart Buildings and Their Occupants

## Abstract

Buildings account for approximately 40% of global energy consumption, yet the occupants who inhabit them rarely have a structured channel through which to communicate their comfort preferences back to building management systems. This paper presents the design of **ComfortOS**, an open-source, multi-platform application that establishes a bidirectional communication layer between buildings and their occupants. The platform enables occupants to report thermal comfort, air quality, and other subjective environmental assessments through dynamically configured vote forms, while buildings can deliver real-time environmental dashboards, alerts, and governance policies back to occupants through a Server-Driven UI (SDUI) architecture. ComfortOS is designed for scalability: a single deployment can serve many buildings across different cities and organizations, each with independently configurable dashboards and vote schemas. The system employs multi-tenant isolation, hybrid presence detection (QR, Wi-Fi, BLE, manual), offline-first vote queuing with idempotent synchronisation, and encrypted local storage. This document describes the platform's motivation, architectural design, component-level specifications, production backend architecture, user experience flow, and provides guidance for future contributors to this open-source project.

---

## 1. Introduction

### 1.1 The Communication Gap in Smart Buildings

Despite decades of building automation research, a persistent gap remains between the *sensed* environmental state of a building (temperature, CO₂, humidity) and the *perceived* comfort of its occupants [1, 2]. Traditional Building Management Systems (BMS) operate on fixed setpoints or rule-based controllers that do not account for the subjective, context-dependent nature of human thermal comfort [3]. The ASHRAE Standard 55 [4] acknowledges that acceptable thermal conditions depend on personal, physiological, and cultural factors — yet most buildings lack a systematic feedback mechanism to capture this information.

Recent work in Human-Building Interaction (HBI) has demonstrated that providing occupants with agency over their environment — even partial or advisory agency — increases both occupant satisfaction and energy efficiency [5, 6]. Platforms such as Cozie [7] have shown the feasibility of collecting in-situ comfort votes via smartwatch micro-surveys, while research on indoor localisation [8] and occupancy-driven HVAC control [9] has laid the groundwork for presence-aware building services. However, existing solutions are typically single-building, single-study deployments that lack the multi-tenant scalability, offline resilience, and dynamic configurability required for real-world adoption across building portfolios.

### 1.2 Contributions

ComfortOS addresses these limitations through the following contributions:

1. **A scalable multi-tenant platform** that enables many buildings and organizations to be served from a single deployment, each with independently configured dashboards, vote forms, and governance policies.
2. **A Server-Driven UI (SDUI) architecture** inspired by industry practices at companies like Airbnb [10] and server-driven rendering in mobile applications [11], allowing facility managers to redesign per-building dashboards and vote forms without requiring app updates.
3. **A hybrid presence detection system** combining QR code scanning, Wi-Fi SSID matching, BLE beacon proximity, and manual selection — with confidence scoring — to resolve the occupant's building context.
4. **An offline-first data architecture** with encrypted local storage, an idempotent vote queue, and a background sync worker with exponential backoff, ensuring reliable data collection even in buildings with intermittent connectivity.
5. **An open-source implementation** in Flutter (Dart), targeting Android, iOS, Web, Windows, macOS, and Linux from a single codebase, with a clear contribution model for the research community.

### 1.3 Design Inspirations and Related Work

The system architecture draws on several established patterns and prior systems:

- **Cozie** [7]: Pioneered micro-surveys for thermal comfort on wearables. ComfortOS extends this concept to smartphones with richer SDUI-driven form types and multi-building scalability.
- **ASHRAE Standard 55 & thermal comfort scales** [4]: The 7-point thermal sensation scale is a first-class field type in the vote form schema.
- **Server-Driven UI (SDUI)** [10, 11]: The dashboard and vote form rendering engine is modeled after the SDUI pattern, in which the backend transmits a JSON widget tree that the client renders recursively, decoupling UI evolution from app release cycles.
- **C4 architecture model** [12]: The system's component decomposition follows Simon Brown's C4 model (Context, Container, Component, Code), with each component's relationships explicitly documented in source-level comments.
- **Offline-first and local-first principles** [13]: The vote queue and sync worker implement the local-first paradigm, where user actions are acknowledged immediately on-device and reconciled with the server asynchronously.
- **Open-Meteo weather API** [14]: Live outdoor weather context is fetched per-building using the building's geolocation coordinates, with no API key required, enabling free and reproducible deployments.

---

## 2. System Goals

The platform is designed around five core goals:

| Goal | Description |
|------|-------------|
| **Bidirectional communication** | Occupants report comfort; buildings deliver dashboards, alerts, and policies. |
| **Scalability** | Multi-tenant architecture serving many buildings, organizations, and occupants from a single backend. |
| **Configurability** | Per-building dashboards and vote forms editable by facility managers without app updates (SDUI). |
| **Offline resilience** | Local-first interactions with encrypted persistence and idempotent synchronisation. |
| **Extensibility** | Open-source, modular design enabling community contributions of new sensors, SDUI widgets, and analytics modules. |

---

## 3. High-Level Architecture

ComfortOS follows a layered architecture with clear separation between presentation, domain logic, data access, and platform services.

### 3.1 Architectural Layers

```
┌──────────────────────────────────────────────────────────────────┐
│                     UI Layer (Flutter)                            │
│  Screens: Login, Presence, Location, Dashboard, Vote, Comfort,   │
│           History, Settings, Home                                │
│  SDUI Engine: SDUIRenderer → SDUIWidgetRegistry (25+ widgets)    │
│  State: Riverpod providers & StateNotifiers                      │
├──────────────────────────────────────────────────────────────────┤
│                     Domain Layer                                 │
│  PermissionsEngine   VoteDomain   Data Models (8 entities)       │
├──────────────────────────────────────────────────────────────────┤
│                     Service Layer                                │
│  AuthService   PresenceResolver   ConfigGovernance               │
│  SyncWorker    NotificationHandler   WeatherService              │
├──────────────────────────────────────────────────────────────────┤
│                     Data Layer                                   │
│  ApiClient   EncryptedLocalStorage (Hive)   OfflineVoteQueue     │
├──────────────────────────────────────────────────────────────────┤
│                     Platform / External                          │
│  Backend API   Identity Provider   Push Provider   Open-Meteo    │
└──────────────────────────────────────────────────────────────────┘
```

### 3.2 Communication Patterns

- **UI ↔ Domain**: Reactive state management via Riverpod `StateNotifierProvider`s. UI widgets watch state providers and rebuild automatically when domain state changes.
- **Domain ↔ Data**: The `ApiClient` mediates all server communication. On network failure, vote submissions are automatically routed to the `OfflineVoteQueue`.
- **Synchronisation**: The `SyncWorker` runs a periodic drain loop (15-second base interval) attempting to upload queued votes. On consecutive failures, it applies exponential backoff ($2^n$ seconds, capped at 300 s) up to a maximum of 8 retries before pausing.

### 3.3 Multi-Tenant Model

Tenant isolation is enforced at every layer:

- The `User` entity carries a `tenantId` field.
- The `Building` entity carries a `tenantId` field.
- The `PermissionsEngine` verifies `user.tenantId == building.tenantId` before granting any operation (vote, dashboard access, management).
- The `AuthService` validates tenant isolation on every authenticated request.

This model allows a single ComfortOS deployment to serve multiple organizations (e.g., university campuses, corporate real-estate portfolios) with complete data isolation.

### 3.4 Deployment Targets

The Flutter framework enables compilation to Android, iOS, Web, Windows, macOS, and Linux from a single Dart codebase. The dependency manifest (`pubspec.yaml`) lists six runtime dependencies: `flutter_riverpod` (state management), `go_router` (routing), `hive` and `hive_flutter` (encrypted local storage), `uuid` (vote idempotency), and `http` (weather API calls).

---

## 4. Production Backend Architecture

The repository includes a `DummyBackend` class (`lib/data/dummy_backend.dart`) that simulates the full backend surface in-process for development and testing. This section describes the **production backend** that the `ApiClient` is designed to communicate with when the dummy is replaced.

### 4.1 Backend Services Overview

The production backend is organized into four logical services, deployable as microservices or as a monolith behind a reverse proxy:

| Service | Responsibility | Key Endpoints |
|---------|---------------|---------------|
| **Identity Provider** | OAuth2/OIDC authentication, token issuance, token refresh, claims management. | `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/validate` |
| **Building & Config API** | CRUD for buildings, SDUI dashboard configs, SDUI vote form schemas, location form schemas (floor/room hierarchies). | `GET /buildings?tenantId=`, `GET /buildings/{id}/dashboard`, `GET /buildings/{id}/vote-form`, `GET /buildings/{id}/location-form`, `GET /buildings/{id}/config` |
| **Vote Ingestion API** | Accepts comfort votes, enforces idempotency by `voteUuid`, computes aggregate comfort scores per building/floor/room. | `POST /votes` (idempotent by `voteUuid`), `GET /votes/history?userId=`, `GET /buildings/{id}/comfort` |
| **Notification & Presence API** | Push notification dispatch, presence event ingestion, beacon/SSID registry. | `POST /notifications/send`, `POST /presence/events`, `GET /presence/beacons?buildingId=` |

### 4.2 API Client Design

The client-side `ApiClient` class implements the following patterns to ensure reliable communication with the production backend:

- **Token injection**: Every authenticated request includes the current JWT bearer token, managed by `AuthService`.
- **Rate limiting**: A per-endpoint throttle of 300 ms minimum interval prevents burst traffic that could trigger server-side rate limits.
- **Idempotent requests**: Vote submissions include a client-generated UUIDv4 (`voteUuid`). The `ApiClient` maintains a local idempotency cache: if a vote with the same UUID has already received a server response, the cached response is returned immediately.
- **Automatic offline fallback**: If a vote submission fails (network error, timeout), the vote is automatically enqueued to the `OfflineVoteQueue` rather than surfacing an error to the user.

### 4.3 Server-Driven UI (SDUI) Pipeline

The SDUI pipeline is a core architectural contribution. The flow is:

```
Facility Manager                   Backend                      ComfortOS App
       │                              │                              │
       │  Configure dashboard JSON    │                              │
       │ ──────────────────────────►  │                              │
       │                              │  GET /buildings/{id}/dashboard│
       │                              │ ◄────────────────────────────│
       │                              │  Return JSON widget tree     │
       │                              │ ────────────────────────────►│
       │                              │                              │
       │                              │            SDUIRenderer      │
       │                              │            reads 'type',     │
       │                              │            looks up builder  │
       │                              │            in Registry,      │
       │                              │            recurses children │
       │                              │                              │
```

The `SDUIWidgetRegistry` maps 25+ widget type strings to Flutter builder functions. Supported widget types include layout primitives (`column`, `row`, `grid`, `spacer`, `padding`, `divider`), dashboard components (`weather_badge`, `metric_tile`, `trend_card`, `alert_banner`, `kpi_card`, `progress_bar`, `occupancy_indicator`), and interaction elements (`primary_action`, `schedule_item`, `image_banner`, `badge_row`). When a building's config returns `null`, the app renders a built-in `DefaultDashboard` ensuring graceful degradation.

The same SDUI principle applies to vote forms. The `VoteFormWidget` interprets a JSON schema (version 2) containing an ordered list of field definitions. Supported field types include `thermal_scale` (7-point ASHRAE), `single_select`, `multi_select`, `emoji_scale`, `emoji_single_select`, `emoji_multi_select`, `rating_stars`, `text_input`, and `yes_no`. Each field type maps to a purpose-built Flutter widget, with schema-driven properties for question text, options, colors, emoji, and layout.

### 4.4 External Data Injection

Dashboard SDUI nodes can reference external data sources. The implemented example uses the **Open-Meteo API** [14] for real-time weather. At runtime, the `WeatherService`:

1. Reads the building's `latitude`/`longitude` from the building record.
2. Calls `https://api.open-meteo.com/v1/forecast` with location parameters.
3. Parses the response (temperature, humidity, wind speed, WMO weather code).
4. Injects live values into `weather_badge` SDUI nodes before rendering.

The `WeatherService` implements a 15-minute in-memory cache and per-user rate limiting (30 requests per hour per user) to stay within the free API tier. The same injection pattern is extensible to any external data source (IoT APIs, air quality indices, occupancy counters) by adding `_data_source` metadata to SDUI nodes.

### 4.5 Aggregate Comfort Data

The backend computes aggregate comfort scores from submitted votes, broken down by building, floor, and room. The `BuildingComfortData` model carries:

- `overallScore` (0.0–10.0): Building-wide comfort index.
- `totalVotes`: Number of votes in the aggregation window.
- `locations[]`: Per-floor/room breakdown, each with `comfortScore`, `voteCount`, and a `breakdown` map (e.g., `{'thermal': 7.2, 'air': 8.1, 'noise': 6.5}`).

This data is rendered on a dedicated Building Comfort screen with animated score rings, breakdown bars, and optional SDUI overrides.

---

## 5. Component Design

Each component below is described with its responsibilities, interfaces, and failure handling.

### 5.1 Authentication Service (`lib/services/auth_service.dart`)

Manages the user authentication lifecycle. Responsibilities include credential-based login via the Identity Provider, JWT token management (issuance, refresh, secure persistence), session restoration on app restart, and tenant isolation validation.

The service persists the auth token in encrypted local storage (`EncryptedLocalStorage`) and caches the current `User` object. On app launch, `tryRestoreSession()` attempts to restore the previous session by reading the stored token and validating it against the backend.

**User model**: `User { id, email, name, role: (occupant|manager|admin), tenantId, claims: { scopes: [...] } }`.

### 5.2 Permissions Engine (`lib/domain/permissions_engine.dart`)

A pure domain component implementing role-based and tenant-scoped permission checks:

- `canVote(user, building)` — requires same tenant. All authenticated occupants may vote.
- `canManageBuilding(user, building)` — requires same tenant and `manager` or `admin` role.
- `isAdmin(user)` — checks for `admin` role.
- `hasScope(user, scope)` — validates JWT claims against required scope strings (e.g., `vote`, `view_dashboard`, `manage_building`, `admin`).

The engine is invoked by UI screens before rendering privileged actions (e.g., the Vote screen checks `canVote` and displays a permission denial if the check fails).

### 5.3 Vote Domain (`lib/domain/vote_domain.dart`)

Pure business logic for vote creation, validation, and local idempotency:

- `createVote(...)` — generates a UUIDv4 `voteUuid`, validates required fields (`buildingId`, `userId`, non-empty `payload`, `schemaVersion ≥ 1`), and returns a `Vote` entity.
- `checkIdempotency(vote)` — returns `true` only if the UUID has not been previously submitted in this session.
- `markSubmitted(vote)` — records the UUID to prevent double-submission.

**Vote model**: `Vote { voteUuid, buildingId, userId, payload: Map, schemaVersion, createdAt, status: (pending|queued|submitted|confirmed|failed) }`.

### 5.4 Presence Resolver (`lib/services/presence_resolver.dart`)

Implements hybrid building-context detection with four methods:

| Method | Confidence | Verified | Mechanism |
|--------|-----------|----------|-----------|
| QR scan | 1.0 | Yes | User scans a building-specific QR code |
| BLE beacon | 0.85 | No | Proximity to pre-registered BLE beacons |
| Wi-Fi SSID | 0.75 | No | Match against known building SSIDs |
| Manual selection | 0.5 | No | User selects building from a list |

`resolvePresence()` runs Wi-Fi and BLE scans in parallel, collects results, and selects the candidate with the highest confidence. The result is a `PresenceInfo { buildingId, method, confidence, timestamp, isVerified }` object that drives route guards and contextualises all subsequent user interactions.

### 5.5 Config Governance (`lib/services/config_governance.dart`)

Manages schema versioning and configuration lifecycle:

- Fetches `AppConfig { schemaVersion, dashboardLayout, voteFormSchema, fetchedAt }` from the backend per building.
- Enforces migration compatibility: only allows same-version or single-step version upgrades.
- Falls back to locally cached configuration on network failure.
- Persists the current `schemaVersion` in encrypted storage for restoration on restart.

### 5.6 Offline Vote Queue (`lib/data/offline_vote_queue.dart`)

An encrypted, persistent queue for votes submitted while offline:

- **Enqueue**: Accepts a `Vote`, assigns `VoteStatus.queued`, deduplicates by `voteUuid`, persists to `EncryptedLocalStorage`.
- **Dequeue**: FIFO retrieval for the `SyncWorker`.
- **Integrity check**: Validates that all queued votes have non-empty `voteUuid` and `buildingId`.
- **Restore**: On app startup, rehydrates the queue from encrypted storage.

### 5.7 Sync Worker (`lib/services/sync_worker.dart`)

Background synchronisation service that drains the offline queue:

- Runs on a 15-second periodic timer.
- Iterates through the queue, submitting each vote via `ApiClient.submitVote()`.
- On success (`accepted` or `already_accepted`): dequeues the vote and resets the failure counter.
- On failure: increments a consecutive-failure counter and applies exponential backoff: $\text{delay} = \min(2^n, 300)$ seconds.
- After 8 consecutive failures, the worker pauses until manually restarted (e.g., on next app foreground).

### 5.8 Notification Handler (`lib/services/notification_handler.dart`)

Processes push notifications with deduplication and deep-link resolution:

- Parses incoming payloads into `NotificationPayload { id, type: (voteConfirmation|configUpdate|alert|deepLink), title, body, deepLink, data, receivedAt }`.
- Deduplicates by notification `id` using a set of received IDs.
- Resolves deep-links to internal GoRouter paths (e.g., `vote`, `dashboard`, `presence`).
- Orchestrates background fetches based on notification type (e.g., fetches updated config on `configUpdate`).

### 5.9 Weather Service (`lib/services/weather_service.dart`)

Fetches real-time outdoor weather from the Open-Meteo API:

- Uses the building's stored `latitude`/`longitude` — every building automatically gets weather for its own city.
- Returns `WeatherData { temperature, feelsLike, humidity, windSpeed, weatherCode, description, icon, fetchedAt }`.
- Maps WMO weather codes to human-readable descriptions and Material Design icon names.
- Implements 15-minute in-memory caching and per-user rate limiting (30 calls/hour).

### 5.10 Encrypted Local Storage (`lib/data/encrypted_local_storage.dart`)

Provides two persistence tiers backed by Hive:

- **Secure box**: For sensitive data (auth tokens, schema version). Uses Hive's box abstraction.
- **Cache box**: For JSON-serialisable data (cached configs, queued votes as JSON arrays). Supports both single-map and list storage.

In production, the secure box would be backed by the platform keystore (Android Keystore / iOS Keychain) for hardware-backed encryption.

### 5.11 Logging & Telemetry (`lib/platform/logger.dart`)

A structured logging facade with five severity levels (`debug`, `info`, `warning`, `error`, `fatal`):

- Maintains an in-memory ring buffer (500 entries) accessible from the Settings screen.
- `reportCrash(error, stackTrace)` — captures fatal errors with stack traces (routes to Sentry/Crashlytics in production).
- `telemetry(event, properties)` — structured analytics events (e.g., `login_success`, `vote_submitted`).
- In debug mode, logs are mirrored to Dart's `developer.log` for DevTools visibility.

### 5.12 Router (`lib/router/app_router.dart`)

GoRouter-based navigation with three route guards:

1. **Auth guard**: Unauthenticated users are redirected to `/login`; authenticated users on `/login` are redirected to `/presence`.
2. **Building-context guard**: Screens requiring a building context (`/dashboard`, `/vote`, `/comfort`, `/history`, `/location`) redirect to `/presence` if no building is selected.
3. **Location guard**: The `/dashboard` route redirects to `/location` if the user has selected a building but not yet chosen a floor/room.

This creates the canonical navigation flow: **Login → Presence (building) → Location (floor/room) → Dashboard**.

---

## 6. User Experience Flow

The UX implements a progressive funnel that establishes context (who, where) before presenting personalised content (dashboard, vote).

### 6.1 Authentication

Users authenticate via email and password. The login screen pre-fills demo credentials for testing. Upon successful authentication, the app loads buildings for the user's tenant, starts the `SyncWorker`, and initialises the `NotificationHandler`.

### 6.2 Presence Resolution (Building Selection)

After login, the Presence screen offers three building-detection methods:

1. **Auto-detect** — Triggers Wi-Fi and BLE scanning, automatically selects the highest-confidence building.
2. **QR scan** — Scans a building-specific QR code (confidence = 1.0, verified).
3. **Manual selection** — Displays a scrollable list of tenant buildings with name, address, city, and metadata (floors, zones). Tapping a building sets it as the active context.

### 6.3 Location Selection (Floor/Room)

Once a building is selected, the Location screen presents a per-building floor and room hierarchy. The hierarchy is defined by a SDUI-style `locationFormConfig` JSON from the backend, allowing each building to define its own spatial layout. Users select their floor from a horizontal chip row and their room from a grid, then proceed to the dashboard.

### 6.4 Dashboard (Building → Occupant Communication)

The dashboard is the primary downlink from building to occupant. It is rendered entirely from SDUI JSON:

- **Weather badge**: Live outdoor conditions (temperature, description, icon) from Open-Meteo, keyed to the building's geolocation.
- **Metric tiles**: Indoor environmental readings (temperature, CO₂, noise, humidity, PM2.5) displayed in a responsive grid.
- **Trend cards**: Time-series area charts for temperature, energy, or other metrics.
- **KPI cards**: Key performance indicators with trend arrows (e.g., solar generation, grid consumption).
- **Alert banners**: Building-level alerts (e.g., "HVAC system is warming up").
- **Occupancy indicators**: Circular progress rings showing space utilisation.
- **Schedule items**: Upcoming events (meetings, cleaning, HVAC set-back schedules).

Each building can have a completely different dashboard layout, configured by its facility manager without any change to the app binary.

### 6.5 Comfort Voting (Occupant → Building Communication)

The vote screen represents the uplink from occupant to building. It renders a SDUI-driven form that supports:

- **Thermal scale**: 7-point ASHRAE sensation scale with colour-coded circles.
- **Single/multi-select**: Radio and chip-based option groups with emoji and colour support.
- **Emoji scales**: Large emoji buttons for quick mood/comfort captures.
- **Star ratings**: For lighting, acoustics, or general satisfaction.
- **Text input**: Open-ended feedback fields.
- **Yes/No**: Binary toggles for quick checks (e.g., "Is the fume hood working?").

On submission, the vote is created by `VoteDomain` with a fresh UUIDv4, validated, and sent to the backend via `ApiClient`. If the network call succeeds, a success snackbar is shown and the user is navigated to the Building Comfort screen to see aggregate results. If the call fails, the vote is transparently enqueued to the `OfflineVoteQueue` and the user sees a "queued — will submit when online" acknowledgement.

### 6.6 Building Comfort (Aggregate Feedback)

After voting, the Building Comfort screen displays aggregate results:

- Building-wide comfort score (animated ring, 0–10 scale).
- Total vote count in the aggregation window.
- Per-floor and per-room breakdown with individual comfort scores and category breakdowns (thermal, air, noise, lighting).
- Optional SDUI override for custom visualisations.

This screen closes the feedback loop: occupants can see the collective comfort state of their building, creating social awareness and motivation for participation.

### 6.7 Vote History

A chronological list of the user's past votes with building name, timestamp, status (submitted/queued/confirmed), and payload summary.

### 6.8 Settings

The Settings screen provides access to user profile information, theme preferences, the in-memory log viewer (for debugging and transparency), and logout.

---

## 7. Data Models

The domain layer defines eight core entities:

| Entity | Key Fields | Purpose |
|--------|-----------|---------|
| `User` | `id, email, name, role, tenantId, claims` | Authenticated user with RBAC |
| `Building` | `id, name, address, tenantId, city, latitude, longitude, metadata` | Physical building with geolocation |
| `Vote` | `voteUuid, buildingId, userId, payload, schemaVersion, createdAt, status` | Individual comfort vote |
| `PresenceInfo` | `buildingId, method, confidence, timestamp, isVerified` | Detected building context |
| `AppConfig` | `schemaVersion, dashboardLayout, voteFormSchema, fetchedAt` | Per-building SDUI configuration |
| `BuildingComfortData` | `buildingId, overallScore, totalVotes, locations[], sduiConfig` | Aggregated comfort metrics |
| `WeatherData` | `temperature, feelsLike, humidity, windSpeed, weatherCode, description, icon` | Real-time outdoor conditions |
| `NotificationPayload` | `id, type, title, body, deepLink, data, receivedAt` | Push notification content |

### 7.1 Storage Strategy

- **Volatile state** (presence, weather): In-memory Riverpod providers; weather cached with 15-minute TTL.
- **Persistent-secure** (auth tokens, schema version): `EncryptedLocalStorage` secure box, restored on app launch.
- **Persistent-cache** (configs, queued votes): `EncryptedLocalStorage` cache box, JSON-encoded.

### 7.2 Synchronisation Semantics

- Vote submissions are **idempotent** by `voteUuid`. The server returns `accepted` on first receipt and `already_accepted` on duplicates. The client cache also deduplicates locally.
- Config fetches are **pull-based**, triggered on dashboard navigation and on `configUpdate` push notifications.
- Presence is **client-side volatile** — the app does not persist presence across sessions; it re-resolves on each launch.

---

## 8. Security and Privacy

### 8.1 Authentication and Authorisation

- JWT-based authentication with short-lived tokens and secure refresh.
- Tokens stored in the encrypted secure box; cleared on logout.
- Role-based access: `occupant` (vote, view dashboard), `manager` (manage building), `admin` (full access).
- Scope-based fine-grained checks via JWT claims.

### 8.2 Tenant Isolation

- Every permission check in `PermissionsEngine` validates `user.tenantId == building.tenantId`.
- The API client includes the tenant context in all data requests, enabling server-side filtering.

### 8.3 Data Encryption

- Local storage encrypted via Hive (upgradeable to platform keystore in production).
- All backend communication over TLS 1.2+ (enforced by the HTTP client and server configuration).
- Vote payloads are JSON-serialised and stored encrypted in the offline queue.

### 8.4 Privacy Considerations

- **Data minimisation**: Only subjective comfort responses and building-level presence are collected. No GPS tracking, no continuous background sensing.
- **Transparency**: The in-app log viewer (Settings screen) lets users inspect all logged events.
- **Compliance**: The architecture supports GDPR-style data export and deletion by design — all user data is keyed by `userId` and `tenantId`, enabling targeted extraction and purging.

---

## 9. State Management Architecture

ComfortOS uses Riverpod [15] for dependency injection and reactive state management. The provider graph mirrors the C4 component diagram:

### 9.1 Provider Hierarchy

**Infrastructure providers** (singletons, created at app startup):
- `encryptedLocalStorageProvider` — pre-initialised and overridden in `main()`.
- `dummyBackendProvider` — in-memory backend (replaced by real HTTP client in production).

**Data providers** (depend on infrastructure):
- `offlineVoteQueueProvider` → `EncryptedLocalStorage`
- `apiClientProvider` → `DummyBackend` + `OfflineVoteQueue`

**Domain providers** (pure logic, no dependencies):
- `voteDomainProvider`, `permissionsEngineProvider`

**Service providers** (depend on data layer):
- `authServiceProvider`, `presenceResolverProvider`, `configGovernanceProvider`, `syncWorkerProvider`, `notificationHandlerProvider`, `weatherServiceProvider`

**State notifier providers** (reactive UI state):
- `authStateProvider` → `AuthNotifier` managing `AuthState { user, isLoading, error }`
- `presenceStateProvider` → `PresenceNotifier` managing `PresenceState { presence, activeBuilding, availableBuildings, floor, room }`
- `voteStateProvider` → `VoteNotifier` managing `VoteState { history, isSubmitting, lastResult, error }`
- `notificationStateProvider` → `NotificationNotifier` managing `NotificationState { notifications, pendingDeepLink }`

**Derived/async providers**:
- `dashboardConfigProvider(buildingId)` — fetches SDUI dashboard JSON.
- `voteFormConfigProvider(buildingId)` — fetches SDUI vote form JSON.
- `locationFormConfigProvider(buildingId)` — fetches floor/room hierarchy.
- `weatherProvider` — fetches live weather, auto-refreshes on building change or manual trigger.
- `buildingComfortProvider(buildingId)` — fetches aggregate comfort data.

### 9.2 Reactive Data Flow

UI widgets use `ref.watch(provider)` to subscribe to state changes. When, for example, a vote is submitted, the flow is:

1. UI calls `ref.read(voteStateProvider.notifier).submitVote(...)`.
2. `VoteNotifier` sets `isSubmitting = true`, triggering a UI rebuild (progress indicator).
3. `VoteDomain.createVote()` generates a UUID and validates the payload.
4. `ApiClient.submitVote()` attempts server delivery.
5. On success: `VoteNotifier` sets `lastResult = 'accepted'`; UI shows success snackbar.
6. On failure: `ApiClient` enqueues to `OfflineVoteQueue`; `VoteNotifier` sets `lastResult = 'queued'`; UI shows "queued" acknowledgement.
7. `SyncWorker` eventually drains the queue in the background.

---

## 10. Evaluation Framework

### 10.1 System Performance Metrics

- **Local-ack latency**: Time from user tap to on-screen acknowledgement (target: < 100 ms).
- **Server commit latency**: Time from local ack to server confirmation (dependent on network; target: < 2 s on 4G).
- **Sync convergence time**: Time for a queued vote to be delivered after connectivity restoration.
- **Background energy impact**: Battery drain attributable to the 15-second `SyncWorker` timer.

### 10.2 Presence Accuracy

- **Precision/recall** of building detection by method (QR, BLE, Wi-Fi, manual).
- Confidence score calibration: does a 0.85-confidence BLE detection correctly identify the building 85% of the time?

### 10.3 UX Metrics

- **Time-to-first-vote**: Duration from app launch to first successful comfort vote submission.
- **Task success rate**: Percentage of users who successfully complete the Login → Presence → Location → Dashboard → Vote funnel.
- **SDUI rendering correctness**: Percentage of server-provided dashboard configs that render without errors.

### 10.4 Scalability Benchmarks

- Number of concurrent buildings and tenants served by a single backend instance.
- Vote ingestion throughput (votes/second) under load.
- SDUI config serving latency as the number of distinct building configurations grows.

---

## 11. Limitations and Future Work

- **Presence detection**: The current implementation simulates sensor scanning; production deployment requires native platform plugins for real BLE and Wi-Fi scanning.
- **Backend**: The `DummyBackend` is in-memory and non-persistent. A production backend (e.g., using PostgreSQL, Redis, and a REST framework) is required for real deployments.
- **Privacy-preserving aggregation**: Current aggregation is plaintext. Future work could apply differential privacy [16] or secure aggregation to comfort vote data.
- **Machine learning**: Sensor fusion for presence could be improved with ML classifiers trained on labeled occupancy datasets.
- **Internationalisation**: The current UI is English-only; the SDUI schema could be extended to include locale-specific label variants.

---

## 12. Contributing to ComfortOS (Open-Source Guide)

ComfortOS is designed as an open-source platform to be extended by the research community and industry practitioners. This section describes how and where contributions can be made.

### 12.1 Repository Structure

```
lib/
├── main.dart                          # App entrypoint and bootstrap
├── app.dart                           # Root MaterialApp widget
├── router/app_router.dart             # GoRouter with auth & context guards
├── domain/                            # Pure domain logic (no Flutter imports)
│   ├── models/                        # 8 data model classes
│   ├── permissions_engine.dart        # RBAC + tenant checks
│   └── vote_domain.dart               # Vote creation & validation
├── data/                              # Data access layer
│   ├── api_client.dart                # HTTP client abstraction
│   ├── dummy_backend.dart             # In-memory simulated backend
│   ├── encrypted_local_storage.dart   # Hive-based encrypted storage
│   └── offline_vote_queue.dart        # Persistent offline queue
├── services/                          # Service components
│   ├── auth_service.dart              # Authentication lifecycle
│   ├── presence_resolver.dart         # Hybrid presence detection
│   ├── config_governance.dart         # Schema versioning & config
│   ├── sync_worker.dart               # Background queue drain
│   ├── notification_handler.dart      # Push notification processing
│   └── weather_service.dart           # Open-Meteo integration
├── state/                             # Riverpod providers & notifiers
│   ├── providers.dart                 # Complete provider graph
│   ├── auth_state.dart, presence_state.dart, vote_state.dart, notification_state.dart
├── ui/                                # Presentation layer
│   ├── screens/                       # 9 screen widgets
│   ├── sdui/                          # SDUI engine
│   │   ├── sdui_renderer.dart         # Recursive JSON→Widget renderer
│   │   ├── sdui_widget_registry.dart  # 25+ widget type builders
│   │   ├── default_dashboard.dart     # Fallback dashboard config
│   │   └── default_vote_form.dart     # Fallback vote form config
│   └── widgets/                       # Reusable UI components
docs/
├── SDUI_CONFIG_GUIDE.md               # Dashboard SDUI reference
└── VOTE_CONFIG_GUIDE.md               # Vote form schema reference
test/
└── widget_test.dart                   # Test entry point
```

### 12.2 Contribution Areas

| Area | Where to Contribute | Difficulty |
|------|-------------------|------------|
| **New SDUI widgets** | Add a builder in `sdui_widget_registry.dart` and document in `docs/SDUI_CONFIG_GUIDE.md` | Low |
| **New vote field types** | Add rendering logic in `vote_form_widget.dart` and document in `docs/VOTE_CONFIG_GUIDE.md` | Low |
| **Production backend** | Replace `DummyBackend` with a real REST/GraphQL server (e.g., Node.js, Python FastAPI, Go). The `ApiClient` interface defines the contract. | Medium |
| **Native presence plugins** | Implement real BLE/Wi-Fi scanning using platform channels or existing Flutter plugins (`flutter_blue_plus`, `wifi_iot`). Wire into `PresenceResolver`. | Medium |
| **Additional external APIs** | Add data injection providers following the `WeatherService` pattern. Candidates: air quality (Open-Meteo AQI), occupancy (building IoT APIs), energy (utility APIs). | Low–Medium |
| **Notifications (production)** | Integrate Firebase Cloud Messaging (FCM) or APNs into `NotificationHandler`. The handler's interface is already designed for push payloads. | Medium |
| **Internationalisation** | Add `flutter_localizations` and locale-aware SDUI label resolution. | Low |
| **Analytics & ML** | Build analytics pipelines consuming the structured telemetry events from `AppLogger`. Train comfort prediction models on aggregated vote data. | High |
| **Privacy-preserving aggregation** | Implement differential privacy or secure multi-party computation for vote aggregation in the backend. | High |
| **Testing** | Expand unit tests for `PermissionsEngine`, `VoteDomain`, `OfflineVoteQueue`, and `SyncWorker`. Add integration tests for the full vote lifecycle and SDUI rendering. | Low–Medium |

### 12.3 Development Setup

```bash
# Prerequisites: Flutter SDK (≥ 3.10.4)
git clone <repository-url>
cd ComfortOS
flutter pub get
flutter run            # Launch on connected device or emulator
flutter test           # Run unit tests
flutter analyze        # Static analysis
```

### 12.4 Contribution Guidelines

1. **Fork and branch**: Create a feature branch from `main`.
2. **Follow the architecture**: Domain logic goes in `lib/domain/`; no Flutter imports in domain or data layers (except `hive_flutter` for storage). Services go in `lib/services/`. UI goes in `lib/ui/`.
3. **Add providers**: New services must have a corresponding provider in `lib/state/providers.dart`.
4. **Document SDUI types**: New widget types must be documented in the appropriate guide under `docs/`.
5. **Test**: Add unit tests for domain and service logic. Test SDUI renderers with sample configs.
6. **C4 comments**: Annotate new classes with `/// Relationships (C4):` comments describing how they connect to other components.

---

## References

[1] S. Karjalainen, "The characteristics of usable room temperature control," *Energy and Buildings*, vol. 39, no. 12, pp. 1220–1229, 2007.

[2] A. Wagner, E. Gossauer, C. Moosmann, T. Gropp, and R. Leonhart, "Thermal comfort and workplace occupant satisfaction — Results of field studies in German low energy office buildings," *Energy and Buildings*, vol. 39, no. 7, pp. 758–769, 2007.

[3] P. O. Fanger, *Thermal Comfort: Analysis and Applications in Environmental Engineering*. Copenhagen: Danish Technical Press, 1970.

[4] ASHRAE, "ASHRAE Standard 55 — Thermal Environmental Conditions for Human Occupancy," American Society of Heating, Refrigerating and Air-Conditioning Engineers, 2020.

[5] G. Brager, H. Zhang, and E. Arens, "Evolving opportunities for providing thermal comfort," *Building and Environment*, vol. 91, pp. 198–209, 2015.

[6] T. Parkinson, R. de Dear, and G. Brager, "Nudging the adaptive thermal comfort model," *Energy and Buildings*, vol. 206, 109559, 2020.

[7] P. Jayathissa, M. Quintana, T. Sood, N. Narzarian, and C. Miller, "Is your clock-face watch smart enough? Processing and fusion of continuous physiological signals and simultaneous right-here-right-now subjective comfort votes from the Cozie app," in *Proceedings of the 6th ACM International Conference on Systems for Energy-Efficient Buildings, Cities, and Transportation (BuildSys)*, 2019.

[8] F. Zafari, A. Gkelias, and K. K. Leung, "A survey of indoor localization systems and technologies," *IEEE Communications Surveys & Tutorials*, vol. 21, no. 3, pp. 2568–2599, 2019.

[9] B. Dong and K. P. Lam, "A real-time model predictive control for building heating and cooling systems based on the occupancy-driven demand response," *Building Simulation*, vol. 7, no. 3, pp. 225–235, 2014.

[10] "A deep dive into Airbnb's Server-Driven UI system," Airbnb Engineering Blog, 2021. Available: https://medium.com/airbnb-engineering

[11] T. Bak, "Server-Driven UI: Design, implement, and ship changes without waiting for an app update," in *Mobile Development Best Practices*, 2022.

[12] S. Brown, "The C4 Model for Visualising Software Architecture," 2018. Available: https://c4model.com

[13] M. Kleppmann, A. Wiggins, P. van Hardenberg, and M. McGranaghan, "Local-first software: You own your data, in spite of the cloud," in *Proceedings of the ACM SIGPLAN International Symposium on New Ideas, New Paradigms, and Reflections on Programming and Software (Onward!)*, 2019.

[14] Open-Meteo, "Free Weather API — No API Key Required," 2024. Available: https://open-meteo.com

[15] R. Music, "Riverpod: A reactive caching and data-binding framework for Dart/Flutter," 2023. Available: https://riverpod.dev

[16] C. Dwork and A. Roth, "The Algorithmic Foundations of Differential Privacy," *Foundations and Trends in Theoretical Computer Science*, vol. 9, nos. 3–4, pp. 211–407, 2014.

---
