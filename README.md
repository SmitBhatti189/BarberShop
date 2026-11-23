# Barbershop Manager

Lightweight, cross-platform barber salon management system: appointments, customers,
services & pricing, staff commission and salary, inventory, billing and payments.

| Part | Tech | Folder |
|---|---|---|
| Client (Android, iOS, Windows, macOS) | Flutter · Riverpod · go_router · dio | [`app/`](app) |
| API | Node.js 22 · TypeScript · Fastify · Zod · Kysely | [`server/`](server) |
| Database | PostgreSQL 17 | migrations in `server/src/db/migrations` |

## Status

**Phase 2 — project foundation.** Working today: database foundation (branches, settings,
roles/permissions, staff, sessions), login / refresh / logout / me, permission-guarded API
plumbing, the Flutter theme/config system, responsive navigation shell, server-address setup
and login screens. All business modules (customers, services, billing, …) are **not built yet**
and show a placeholder page. See [CHANGELOG.md](CHANGELOG.md) and the roadmap in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#7-development-roadmap).

## Running locally (salon LAN testing)

### 1. Database + API

```bash
cd server
npm install
cp .env.example .env        # then fill in passwords/secrets
npm run db:setup            # creates role + barbershop and barbershop_test databases, migrates both
npm run staff:create-manager   # needs MANAGER_USERNAME / MANAGER_PASSWORD / MANAGER_NAME in .env
npm run dev                 # API on http://0.0.0.0:8080/api/v1
```

Allow the API port through Windows Firewall so phones on the same Wi-Fi can reach it
(PowerShell as administrator):

```bash
New-NetFirewallRule -DisplayName "Barbershop API" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow -Profile Private
```

PostgreSQL itself stays local to the server PC.

### 2. App

```bash
cd app
flutter pub get
flutter run -d windows      # or an Android device/emulator
```

The app does **not** ask for the server address at the moment (switched off in
`app/lib/config/env/app_env.dart`, `serverSetupEnabled`). It connects to
`http://localhost:8080` — fine on the server PC itself. On another device, build it with the
server PC's LAN address:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://192.168.1.10:8080/api/v1
```

Find the address with `ipconfig` (IPv4 address of the Wi-Fi adapter). A DHCP reservation on the
router keeps it stable.

Build prerequisites per platform:

| Platform | Needs |
|---|---|
| Windows | Windows **Developer Mode** on (Settings → System → For developers) and Visual Studio with the **Desktop development with C++** workload |
| Android | Android Studio (Android SDK + an emulator or a USB-debugging phone) |
| iOS / macOS | A Mac with Xcode (`flutter build ios` / `flutter build macos`) |

Run `flutter doctor` to see what is still missing.

## Tests

```bash
cd server && npm test        # unit, integration, API, concurrency (uses TEST_DATABASE_URL)
cd app && flutter test       # widget, navigation, state, form tests
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — layers, folder structure, API design, flows, roadmap, risks, decided business rules
- [Database design](docs/DATABASE_DESIGN.md) — ER diagram, tables, constraints, snapshots
- [API documentation](docs/API_DOCUMENTATION.md)
- [Feature flows](docs/FEATURE_FLOWS.md)
- [Development guidelines](docs/DEVELOPMENT_GUIDELINES.md)
- [Changelog](CHANGELOG.md)
