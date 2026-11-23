# Changelog

All notable changes. Each entry records what changed, why, files, flow, database/API changes,
dependencies and testing.

## [Unreleased]

### Added — Dashboard layout (UI only) (2026-11-20)
**What & why:** the dashboard from the design canvas, ready for its data. No module behind its numbers exists yet (Billing, Appointments, Inventory, Staff & pay), so following DEVELOPMENT_GUIDELINES nothing is made up: every number tile shows "—" with "Shows once <module> is built", and every panel says what will appear and which module brings it. Quick-action buttons already work — they open their sections.
- **Who sees what** — one pure function, `dashboardLayoutFor(user)` (`features/dashboard/domain/dashboard_layout.dart`), decided only by permissions:
  - *Manager view*: Sales today (`billing.view` or `reports.financial.view`), Appointments today + **Chairs today** panel (`appointments.view_all`), Low stock tile + panel (`inventory.view`), You owe staff + **Staff balances** panel (`compensation.view`).
  - *Staff view* (`appointments.view` without `view_all`): My clients today + **My day** panel; with `earnings.view_own`: My commission today, My balance + **My earnings** panel. No salon-wide money (ARCHITECTURE §5.4).
  - *Quick actions*: New bill (`billing.create`), New booking (`appointments.manage`), Add customer (`customers.manage`), Receive stock (`inventory.manage`).
- **Layout** (`features/dashboard/presentation/dashboard_screen.dart`): greeting + date; number tiles up to four per row (fewer when narrow); then a main column (day panels) and a side column (quick actions, stock, pay) side by side from 860 px content width, stacked below that. Key figure on a dark tile (Sales today / My balance).
- **New widgets:** `StatTile` (`widgets/stat_tile.dart`), `DashboardCard` + `ComingWithModule` (`widgets/dashboard_card.dart`). New `AppSizes` dashboard sizes, `AppIcons.forward`.
- **Next:** when each module's API lands, give its tile a value and replace its panel's `ComingWithModule` with the real list — the layout and permission rules stay.
- **Database / API / dependencies:** none.
- **Testing:** `flutter test` 44 passing. New `test/features/dashboard_test.dart`: layout per role (manager, barber, all-bookings overrides own, no permissions → empty), manager screen shows only placeholders and two columns on wide screens, barber screen hides salon money and stacks on a phone, greeting by first name.

### Changed — server address screen switched off (2026-11-19)
**What & why:** owner request — for now the app should not ask which server to connect to. Switched off, not deleted, so it can come back with one line.
- New switch `AppEnv.serverSetupEnabled = false` (`app/lib/config/env/app_env.dart`). While off: `allowServerOverride` is false (no saved-address override, no **Change server** button on login), and with no `--dart-define=API_BASE_URL` the app uses `AppEnv.builtInApiBaseUrl()` — `http://localhost:8080/api/v1`, or on web the host that served the page, port 8080. The app therefore never reaches the "Connect to the salon" screen (`ServerSetupScreen` and its route stay in the code).
- **Flow:** start → restore session against the built-in address → Login or Dashboard.
- **Docs:** README "Running locally" and FEATURE_FLOWS §1 note the switch and how to build for another PC.
- **Database / API / dependencies:** none.
- **Testing:** new test that the switch is off, no server override is allowed and the default address is set.

### Changed — UI redesign, step 1: look and app shell (2026-11-18)
**What & why:** first step of the redesign agreed on the design canvas ("Barbershop UI Redesign"). Only the shared look and the frame around every page change here; module screens follow as their modules are built. No fake data is shown — the dashboard still says which summaries are coming.
- **Dark side menu** in both themes, sections listed under group labels *Front desk · Business · Me · Admin* (`AppNavGroup` on each `AppDestination`; menu order changed so groups stay together). Collapsed menu shows a divider instead of the label. Footer shows the server the app talks to (`core/router/app_sidebar.dart`, `app_destinations.dart`).
- **Logo** is now a gold square with the scissors, salon name in a serif (`BrandMark`, `AppBrand(onDark:)` in `core/router/app_brand.dart`).
- **Top bar**: gold **New bill** shortcut on tablet/desktop for people with `billing.create` (opens Billing); avatar restyled; height 60 → 64 (`app_navbar.dart`, `app_sizes.dart`).
- **Login and server setup**: dark brand panel on the left on wide screens, logo above the form on narrow ones; serif "Welcome back" title; the server line under Sign in shows the current server with a *Change server* button (`features/auth/presentation/auth_form_frame.dart`, `login_screen.dart`, `server_setup_screen.dart`).
- **Page titles** are larger, in the serif display face, with an optional small line above (`PageScaffold.subtitle`). The dashboard greets by time of day with today's date (`dashboard_screen.dart`).
- **Colours:** new side-menu tokens (`sidebar*`) in `AppColors.light`/`dark`. **Gold button changed from `#A47D43` + white text to `#C9A465` + charcoal text** — white on the old gold was ~3.6:1 contrast, below the 4.5:1 minimum. The owner's `#A47D43` stays as the focus border.
- **Type:** headings, page titles and the salon name use **Fraunces**, bundled in `app/assets/fonts/Fraunces.ttf` (360 KB variable font, from github.com/google/fonts `ofl/fraunces`) with its licence `Fraunces-OFL.txt` (SIL Open Font License 1.1 — free to bundle and ship; the licence must travel with it). Bundled rather than using a system serif because Flutter **web** cannot use installed system fonts, so headings fell back to the sans font there. Weight and optical size are set per style through `AppTypography.display()` (a variable font's weight axis does not follow `fontWeight` alone). Georgia / Noto Serif remain only as a fallback. The licence is registered on Flutter's licences page in `main.dart`. Body text stays on the platform font. Files: `app_typography.dart` (new `display()`, `brandName`, `overline`), `app_brand.dart`, `pubspec.yaml` (`fonts:` + licence asset).
- New helper `displayServerAddress()` (`core/server/server_address.dart`); new icon `AppIcons.add`; new strings `AppStrings.tagline*`.
- **Database / API:** none. **Dependencies:** no packages; one bundled font asset (above).
- **Testing:** `flutter analyze` clean; `flutter test` 36 passing. New `test/core/redesign_test.dart` covers headings using the bundled font with an explicit weight axis, the server-address display, greeting by time, menu groups staying together, the dark side menu with group labels, and the New bill button per permission and screen size. Existing shell and login tests pass unchanged.

### Fixed
- Login returned 500 when a new PostgreSQL connection took longer than 5 s (seen right after an unclean Windows restart). Pool `connectionTimeoutMillis` raised to 15 s (`server/src/db/database.ts`). Found during the live app tour; verified by logging in through the app.

### Added
- Flutter **web** platform folder (`app/web/`) — used only to preview the app in a browser while desktop/mobile build tools are missing; not a production target.
- `.claude/launch.json` with `api`, `app-web` and `app-web-static` run configurations.

- **New colour system with light and dark themes** from the owner's colour spec (buttons, gold/secondary buttons, hover/pressed overlays, disabled states, text fields, focus border, selected/unselected nav items, dividers, status colours). Tokens live in one `ThemeExtension`, `AppColors.light` / `AppColors.dark` (`app/lib/config/theme/app_colors.dart`); `AppTheme` maps them onto Material (`app_theme.dart`). Page background, card surface, body text colours and on-status text were not in the spec and are marked "assumed".
- New button variant `gold`; `secondary` is now the soft beige filled button (`app_button_styles.dart`, `shared/widgets/app_button.dart`).
- **Top navbar** on every signed-in page: sidebar toggle, salon name (click → Dashboard), and a **profile box** on the right opening Profile · Settings (only with `settings.manage`) · Dark mode switch · Log out (`core/router/app_navbar.dart`).
- **Collapsible sidebar** for tablet/desktop: toggle button in the navbar; collapsed shows icons only, with the section name as a hover tooltip; clicking still navigates. Starts collapsed on tablets, expanded on desktops; the user's choice is remembered (`core/router/app_sidebar.dart`, `core/router/app_shell.dart`).
- **Light/dark preference and sidebar state** stored per device (`core/ui/ui_preferences.dart`; keys in `core/storage/secure_store.dart`). Defaults to the system theme until the user toggles.
- **Profile page** (`/profile`) showing the signed-in user and their permissions (`features/profile/presentation/profile_screen.dart`).
- `PageScaffold` no longer has its own AppBar (the navbar replaces it); pages show a title row instead.
- Logout moved from the sidebar / "More" sheet into the profile box.

- **Navigation refinements (owner request):**
  - Settings removed from the sidebar and phone "More" sheet — it is opened from the profile box only (`AppDestination.inMenu`, `AppDestinations.menuFor`). The `/settings` route and its permission check are unchanged.
  - Central hover-label switches in `app/lib/config/app_hover_labels.dart` (`sidebarItems` on; `sidebarToggle`, `appName`, `profileButton` off), applied through `shared/widgets/hover_label.dart`.
  - The logo + salon name moved into the **sidebar header** (open: scissors + full name; collapsed: scissors only; click → Dashboard). The **collapse button sits to the right of the logo**. The sidebar is now full height, with the navbar beside it. On phones the brand stays in the navbar (`core/router/app_brand.dart`, `app_sidebar.dart`, `app_shell.dart`, `app_navbar.dart`).
  - Collapsed sidebar width 72 → 80 px so logo and button fit side by side.

### Fixed (from the tour)
- Dark-theme error text was low-contrast — now `#F08C86` per the colour spec.
- Phone bottom bar: "Appointments" wrapped onto two lines — the bottom bar now uses the short label "Bookings" (`AppDestination.shortLabel`).

### Testing
- `flutter test`: 27 passing (incl. sidebar header layout, Settings kept out of menus but reachable, hover labels off for toggle/app name). New `test/core/shell_test.dart` covers phone/tablet/desktop shells, sidebar collapse/expand + tooltip + persistence, profile menu contents per permission, logout, dark-mode toggle + persistence, restoring saved preferences, salon name → dashboard, and collapsed icons navigating. Shared fakes in `test/helpers/fakes.dart`.

## [0.1.0] — 2026-11-04 — Phase 2: project foundation

### What & why
Phase 1 design (docs v0.3) was approved. This release lays the foundation every module will
build on: configuration, database migrations, error handling, logging, authentication, the
permission system, the Flutter theme/config system and responsive navigation. No business
module (customers, services, billing, …) is implemented yet; their menu entries open an
explicit "not built yet" page.

### Backend (`server/`)
- Fastify app factory (`src/app.ts`) + server with graceful shutdown (`src/server.ts`).
- Zod-validated environment config (`src/config/env.ts`, `.env.example`).
- Central error handler → `{ error: { code, message, details } }`; DB constraint errors mapped to 409/422 without leaking internals (`src/plugins/error-handler.ts`, `src/shared/errors.ts`).
- Structured request logging with request ids; secrets redacted from logs.
- Kysely + pg database layer, `withTransaction` with retry on serialization failure/deadlock (`src/db/*`).
- Migration runner with explicit registry (`src/db/migrate.ts`, `src/db/migrations/index.ts`).
- Permission keys defined once in code and synced to the DB after every migration; Manager role always holds all keys (`src/shared/permissions.ts`, `src/db/sync-permissions.ts`).
- Auth: argon2id password hashing, login with brute-force throttle and timing-safe unknown-user handling, rotating refresh tokens (stored hashed) with reuse detection, logout, `/auth/me`. Every request re-validates session, staff status and permissions (`src/modules/auth/*`, `src/plugins/auth.ts`).
- Money utilities in integer paise: parsing/formatting, half-up percent, largest-remainder pro-rata allocation, owner's bill round-off rule (1–5 down / 6–9 up) and payout round-up (`src/shared/money.ts`).
- Pagination helpers (offset + cursor) (`src/shared/pagination.ts`).
- Scripts: `db:setup` (creates role + dev/test DBs, migrates), `staff:create-manager`.

### Database
Migration `0001_foundation`: `branches`, `settings` (single row), `permissions`, `roles`,
`role_permissions`, `staff`, `auth_sessions`; extensions `btree_gist`, `pg_trgm`; `updated_at`
trigger. Seeds the settings row and "Main Branch" (`MAIN` invoice prefix); system roles Manager and Staff.

### API
Added `GET /health`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/me`
— see [docs/API_DOCUMENTATION.md](docs/API_DOCUMENTATION.md).

### Flutter (`app/`)
- Platforms generated: Android, iOS, Windows, macOS.
- Centralised config: colours, typography, spacing, radii, sizes/breakpoints, button styles, theme (light/dark), icons, images, strings, environment (`lib/config/**`).
- Core: dio `ApiClient` with token attach, single-flight refresh + retry, envelope/error decoding; secure token storage; `AuthController` (server setup → restore → login/logout); go_router with auth/permission redirects; responsive shell (bottom bar / rail / drawer) built from permission-aware destinations (`lib/core/**`).
- Shared widgets: `AppButton`, `AppTextField`, `AppDropdown`, `AppDialog`/`showConfirmDialog`/`showAppMessage`, `AppCard`, `LoadingView`/`ErrorView`/`EmptyView`, `PageScaffold`, `PermissionGate`, `PlaceholderPage`.
- Screens: splash, server setup (verifies address via `/health`), login, dashboard (welcome only).

### Dependencies (justification)
- Server: `fastify`, `fastify-plugin`, `@fastify/cors`, `@fastify/jwt` (HTTP + auth), `zod` + `fastify-type-provider-zod` (validation & types), `kysely` + `pg` (type-safe SQL), `argon2` (password hashing). Dev: `typescript`, `tsx`, `vitest`, `@types/*`, `pino-pretty`.
- App: `flutter_riverpod` (state/DI), `go_router` (required), `dio` (interceptors for token refresh), `flutter_secure_storage` (OS-encrypted token storage), `intl` (currency/date formatting). Dev: `flutter_lints`.

### Testing
- Backend `npm test`: **51 tests passing** — money/rounding unit tests; migration up/down, seeds, constraints, permission sync; health, error envelope, validation; auth guard (401/403, deactivation, revoked session, live permission changes); login, throttle, refresh rotation, replay detection, concurrent refresh race, logout.
- Flutter `flutter test`: **19 tests passing** — routing/redirect rules, destination visibility, server-address parsing, ApiClient single-flight refresh and error decoding, login form validation, responsive shell (phone vs desktop). The desktop-shell test caught a 9 px label overflow; the side drawer width was raised from 248 to 280 (`AppSizes.navDrawerWidth`).
- `flutter analyze`: no issues. `npm run typecheck`: no errors.
- Manual API smoke test against the running server: health on localhost and on the LAN IP, manager login, `/auth/me`, 401 without token.

### Not yet verified (environment prerequisites missing on the dev PC)
- **Windows build** — needs Windows *Developer Mode* (plugin symlinks) and the Visual Studio *Desktop development with C++* workload.
- **Android build** — needs Android Studio / Android SDK.
- **iOS / macOS builds** — need a Mac with Xcode.
- Access from other LAN devices — needs the firewall rule in README.
