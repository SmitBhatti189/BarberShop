# Development Guidelines

Rules every change must follow. They implement the project's mandatory standards.

## General
- Business rules live in the **backend services**. The Flutter app never calculates prices, discounts, commission, stock or permissions itself — it displays what the API returns.
- Do not modify unrelated modules. Do not rewrite working code without a stated reason.
- A feature is "done" only when its frontend → API → database flow is verified by tests. Unfinished modules show `PlaceholderPage`, never fake data.
- Every change updates the relevant docs and adds a CHANGELOG entry (what, why, files, flow, DB/API changes, dependencies, tests).
- New dependencies must be justified in CHANGELOG.md.

## Backend (server/)
- Layering: `*.routes.ts` (URL, schema, permission) → service (rules, transactions) → `*.repository.ts` (all SQL). No SQL in routes/controllers.
- Validate every input with Zod in the route schema. Never trust client-sent prices or totals; reload them from the DB.
- Protect routes with `requirePermission(app, PERMISSIONS.X)`. Add new keys only in `src/shared/permissions.ts` (and mirror them in `app/lib/core/permissions.dart`).
- Multi-row changes run in `withTransaction`. Lock rows that are read-then-written (`forUpdate()`), always in ascending id order to avoid deadlocks.
- Money: integer paise via `shared/money.ts`; `NUMERIC(12,2)` in the DB. Never use JS floats for money.
- Throw `AppError` subclasses for expected failures; never return raw DB errors.
- Historical rows (bills, ledgers, stock movements) are never updated in place except by the defined adjustment flows, and never deleted.
- Select only needed columns. Paginate every list that can grow.

### Database
- Schema changes only through a new migration in `src/db/migrations/` registered in `migrations/index.ts`. Never edit an applied migration.
- Each migration has a working `down()`; the test suite runs down → up on every run.
- Update `src/db/types.ts` and DATABASE_DESIGN.md in the same change.
- Constraints first: CHECK, UNIQUE, FK (`RESTRICT` for history), exclusion constraints for overlaps.

## Flutter (app/)
- No colour, size, radius, spacing or text-style literals in screens — use `config/theme/*` and `Theme.of(context)`.
- Colours: every token exists in both `AppColors.light` and `AppColors.dark`; read them with `AppColors.of(context)` (or `Theme.of(context).colorScheme`). Check every new screen in both themes.
- Icons only via `AppIcons`; images only via `AppImages`; shared copy in `AppStrings`.
- Use the shared widgets (`AppButton`, `AppTextField`, `AppDropdown`, `AppDialog`/`showConfirmDialog`, `AppCard`, `LoadingView`/`ErrorView`/`EmptyView`, `PageScaffold`, `PermissionGate`).
- Feature folders: `data/` (DTOs, API), `domain/` (entities), `application/` (Riverpod notifiers), `presentation/` (widgets).
- Dispose every controller, focus node, stream subscription and timer. Prefer `ref.watch(provider.select(...))` to limit rebuilds; use `ListView.builder` for lists.
- Disable submit buttons while a request is in flight (`AppButton(loading: …)`) to prevent duplicate submissions.
- New sections: add an `AppDestination` with its permissions and a route (`inMenu: false` if it is reached from somewhere other than the sidebar).
- Hover tooltips on navigation elements go through `HoverLabel` with a switch from `config/app_hover_labels.dart` — never a bare `Tooltip`.

## Testing
- Backend: `npm test` (unit + integration + API + concurrency) against `TEST_DATABASE_URL`. Every business rule gets unit tests; every endpoint gets API tests incl. 401/403 cases; every race-prone operation gets a concurrency test.
- Flutter: `flutter test` — widget, navigation, state and form-validation tests.

## Commands
| Task | Command (from `server/`) |
|---|---|
| First-time DB setup | `npm run db:setup` |
| Migrate | `npm run db:migrate` · rollback one: `npm run db:rollback` |
| Create/reset a manager login | `npm run staff:create-manager` (uses `MANAGER_*` env vars) |
| Run API (watch) | `npm run dev` |
| Tests / type-check | `npm test` · `npm run typecheck` |
