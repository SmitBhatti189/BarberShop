# Architecture — Barber Salon Management System

> **Status:** DRAFT v0.3 (Phase 1 — owner answers Q1–Q8 and R-Q1–R-Q3 applied, see §9; pending final approval). No application code has been written yet.
> Companion document: [DATABASE_DESIGN.md](DATABASE_DESIGN.md).

---

## 1. Architecture overview

```
┌──────────────────────────────────────────┐
│ Flutter app (Android / iOS / Win / macOS)│
│  Presentation → State (Riverpod)         │
│  → Domain (entities, use-cases)          │
│  → Data (repositories, DTOs, API client) │
└───────────────┬──────────────────────────┘
                │ HTTPS · JSON · REST /api/v1
                │ Bearer access token (JWT, 15 min)
┌───────────────▼──────────────────────────┐
│ Node.js + TypeScript (Fastify)           │
│  routes → middleware (auth, permission,  │
│  validation) → controllers → services    │
│  → repositories → Kysely                 │
└───────────────┬──────────────────────────┘
                │ pg connection pool, explicit transactions
┌───────────────▼──────────────────────────┐
│ PostgreSQL 16                            │
│  constraints · exclusion constraints ·   │
│  row locks · migrations                  │
└──────────────────────────────────────────┘
```

**Principle:** the backend is the single source of truth for every business rule (pricing,
discount allocation, commission, stock, payment limits, permissions). The Flutter app only
collects input, displays results, and hides UI the user is not permitted to use (convenience
only — never security).

### 1.1 Technology choices (and why)

| Concern | Choice | Reason |
|---|---|---|
| Flutter state management | **Riverpod** (`flutter_riverpod`, no code-gen) | Compile-safe DI + state in one small package; providers auto-dispose (prevents leaks); easy to unit-test without widgets; fine-grained rebuilds via `select`. |
| Navigation | **go_router** | Required; supports `redirect` for auth guard and `ShellRoute` for responsive shell. |
| HTTP client | **dio** | Interceptors (attach token, single-flight refresh on 401), cancel tokens for disposed screens, timeouts. |
| Token storage | **flutter_secure_storage** | Keychain (iOS/macOS), Keystore (Android), DPAPI (Windows). |
| Money/format | `intl` | Currency/date formatting. |
| Backend framework | **Fastify** | Lighter and faster than Express; built-in structured logging (pino); plugin-based DI; first-class TypeScript. |
| Validation | **Zod** (+ `fastify-type-provider-zod`) | One schema gives runtime validation and static types; reused by OpenAPI generation. |
| DB access | **Kysely** + `pg` | Type-safe SQL query builder — no ORM magic, explicit `SELECT … FOR UPDATE`, explicit transactions, parameterised queries (SQL-injection safe), built-in migrator. |
| Password hashing | **argon2id** (`argon2`) | Current OWASP recommendation. |
| Tokens | JWT access (15 min) + opaque rotating refresh token (stored **hashed** in DB) | Short-lived stateless access; refresh tokens revocable (logout, deactivation). |
| Money arithmetic | Integer **paise** in TypeScript, `NUMERIC(12,2)` in PostgreSQL | No floating-point errors. A tiny `Money` utility; no extra dependency. |
| Backend tests | **Vitest** + real PostgreSQL test database | Concurrency tests must run against real Postgres locking, not mocks. |
| Flutter tests | `flutter_test` + `mocktail` | Widget, navigation, provider and form tests. |

Total runtime dependencies stay small on purpose; any new package must be justified in CHANGELOG.md.

---

## 2. Repository layout

```
Barbershop/
├── app/                    Flutter client
├── server/                 Node.js + TypeScript API
├── docs/                   ARCHITECTURE, DATABASE_DESIGN, API_DOCUMENTATION,
│                           FEATURE_FLOWS, DEVELOPMENT_GUIDELINES
├── docker-compose.yml      Local PostgreSQL (dev + test databases)
├── README.md
└── CHANGELOG.md
```

### 2.1 Flutter folder structure (feature-first, layered inside each feature)

```
app/lib/
├── main.dart                         Bootstraps env, ProviderScope, router
├── config/                           ★ CENTRALISED CONFIGURATION
│   ├── env/app_env.dart              API base URL, environment (dev/staging/prod) via --dart-define
│   ├── theme/
│   │   ├── app_colors.dart           Palette: primary, secondary, text, background, status colours
│   │   ├── app_typography.dart       Text styles
│   │   ├── app_spacing.dart          Spacing scale (4/8/12/16/24/32)
│   │   ├── app_radius.dart           Border radii
│   │   ├── app_sizes.dart            Button heights, icon sizes, breakpoints
│   │   ├── app_button_styles.dart    Primary / secondary / danger / text button styles
│   │   └── app_theme.dart            Builds ThemeData (light/dark) from the files above
│   ├── assets/app_icons.dart         Icon constants
│   ├── assets/app_images.dart        Image + logo paths
│   └── app_strings.dart              App name, common labels
├── core/
│   ├── network/                      dio client, auth interceptor, ApiException, response envelope parsing
│   ├── auth/                         session state, token storage, permission set
│   ├── router/                       app_router.dart, route names, guards, responsive shell
│   ├── utils/                        money formatting, date helpers, debouncer
│   └── responsive/                   breakpoint helpers (compact / medium / expanded)
├── shared/widgets/                   AppButton, AppTextField, AppDropdown, AppDialog,
│                                     ConfirmDialog, AppDataTable (paginated), AppCard,
│                                     LoadingView, ErrorView, EmptyView, PermissionGate
└── features/
    ├── auth/        { data/ domain/ application/ presentation/ }
    ├── dashboard/
    ├── customers/
    ├── services/
    ├── staff/                        staff accounts, roles
    ├── compensation/                 salary, commission rules, earnings, payouts
    ├── inventory/
    ├── appointments/
    └── billing/

Inside each feature:
    data/          *_dto.dart (JSON ↔ DTO), *_api.dart (endpoints), *_repository_impl.dart
    domain/        entities (immutable), repository interface
    application/   Riverpod Notifiers/providers (state + actions)
    presentation/  screens/ and widgets/ (no business rules, no hardcoded styles)
```

Rule: screens read colours/sizes **only** from `Theme.of(context)` / `config/theme/*`. A lint check
(custom `analysis_options.yaml` + review checklist) flags `Color(0x…)` literals outside `config/`.

### 2.2 Node.js backend folder structure

```
server/
├── src/
│   ├── app.ts                        Builds Fastify instance (used by server.ts and tests)
│   ├── server.ts                     Starts HTTP listener, graceful shutdown (closes pool)
│   ├── config/env.ts                 Zod-validated environment (DB URL, JWT secrets, CORS, log level)
│   ├── db/
│   │   ├── database.ts               Kysely instance + pg pool
│   │   ├── types.ts                  Generated table types (kysely-codegen)
│   │   ├── transaction.ts            withTransaction() helper + serialization-retry wrapper
│   │   └── migrations/               0001_init.ts, 0002_… (forward-only, reviewed)
│   ├── plugins/                      auth (JWT verify), errorHandler, requestId, rateLimit (login)
│   ├── shared/
│   │   ├── errors.ts                 AppError hierarchy → HTTP status mapping
│   │   ├── money.ts                  paise arithmetic, rounding, pro-rata allocation
│   │   ├── pagination.ts             limit/offset + cursor helpers
│   │   ├── permissions.ts            Permission key constants (single source)
│   │   └── response.ts               { data, meta } envelope
│   └── modules/
│       ├── auth/        auth.routes.ts · auth.controller.ts · auth.service.ts · auth.repository.ts · auth.schemas.ts
│       ├── staff/
│       ├── roles/
│       ├── customers/
│       ├── services/
│       ├── products/                 products + stock movements
│       ├── appointments/
│       ├── billing/                  bills, bill items, finalisation
│       ├── payments/
│       ├── compensation/             compensation plans, commission rules, earnings, payouts
│       │   └── commission.calculator.ts   ★ the ONLY place commission is computed (pure function)
│       ├── dashboard/
│       └── settings/
└── test/
    ├── unit/                         calculators, money, allocation (pure, fast)
    ├── integration/                  repositories/services against test DB
    ├── api/                          HTTP-level tests incl. authz matrix
    └── concurrency/                  parallel payments, stock races, booking races
```

Layer rules:
- **routes** declare URL, Zod schemas and the required permission (`preHandler: requirePermission('billing.create')`).
- **controllers** map HTTP ↔ service calls. No SQL, no business rules.
- **services** hold business rules and open transactions.
- **repositories** hold all SQL; accept a `Transaction | Kysely` executor so services compose them inside one transaction.
- Dependencies are injected via a small container registered on the Fastify instance (no DI framework).

---

## 3. API architecture

- Base path: `/api/v1`. Resource nouns, plural, kebab-case.
- Success envelope: `{ "data": …, "meta": { "page": …, "limit": …, "total"|"nextCursor": … } }`
- Error envelope: `{ "error": { "code": "STOCK_INSUFFICIENT", "message": "…", "details": [...] } }`
- Status codes: 200, 201, 204, 400 (validation), 401, 403, 404, 409 (conflict: booking clash, duplicate, stale), 422 (business rule), 500.
- Pagination: `?limit=&offset=` for admin lists; **cursor** (`?cursor=`) for growing history (bills, stock movements, customer history).
- Filtering/sorting: whitelisted query params only (`?status=&from=&to=&sort=-createdAt`).
- Idempotency: `Idempotency-Key` header **required** on `POST /bills` and `POST /bills/:id/payments`.
- Optimistic concurrency on edits: `version` field; `PATCH` with stale version → 409.
- No internal IDs of other tables, hashes, or SQL errors are ever returned.

### 3.1 Module breakdown

| Module | Endpoints (initial) | Permission keys |
|---|---|---|
| Auth | `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /auth/me` | — (me returns own permissions) |
| Staff | `GET/POST /staff`, `GET/PATCH /staff/:id`, `POST /staff/:id/activate`, `/deactivate`, `POST /staff/:id/reset-password` | `staff.view`, `staff.manage` |
| Roles | `GET/POST /roles`, `PATCH/DELETE /roles/:id`, `GET /permissions` | `roles.manage` |
| Customers | `GET /customers?search=`, `POST`, `GET/PATCH /customers/:id`, `GET /customers/:id/history`, `GET /customers/:id/summary` | `customers.view`, `customers.manage`, `customers.history.view` |
| Services | `GET /services`, `POST`, `PATCH /services/:id` (deactivate via `isActive`) | `services.view`, `services.manage` |
| Products | `GET /products?lowStock=true`, `POST`, `PATCH /products/:id`, `GET /products/:id/stock-movements`, `POST /products/:id/stock-movements` (purchase / adjustment) | `inventory.view`, `inventory.manage` |
| Appointments | `GET /appointments?from=&to=&staffId=&status=&search=`, `POST`, `PATCH /appointments/:id`, `POST /appointments/:id/status` | `appointments.view`, `appointments.view_all`, `appointments.manage` |
| Billing | `POST /bills` (atomic create + finalise), `GET /bills`, `GET /bills/:id`, `POST /bills/:id/adjustments` (extra discount), `POST /bills/:id/void` | `billing.create`, `billing.view`, `billing.discount`, `billing.void` |
| Payments | `POST /bills/:id/payments`, `GET /payments?receivedBy=&from=&to=` (cash collected report), `GET /payment-methods`, `POST/PATCH /payment-methods` | `payments.record`, `payments.view`, `settings.manage` |
| Compensation | `GET/PUT /staff/:id/compensation` (monthly salary), `GET/PUT /staff/:id/commission-rules`, `GET /staff/:id/work?from=&to=` (lines done/sold + commission), `GET /staff/:id/balance`, `GET /staff/:id/ledger`, `POST /staff/:id/salary-credits` (post month), `POST /staff/:id/withdrawals`, `POST /ledger/:entryId/confirm` · `/reject`. `me` aliases: `/me/work`, `/me/balance`, `/me/withdrawals` | `compensation.view`, `compensation.manage`, `earnings.view_own`, `withdrawals.request_own`, `withdrawals.confirm` |
| Branches | `GET/PATCH /branches` (single branch for now; create added at expansion) | `settings.manage` |
| Dashboard | `GET /dashboard` (sections included only if permitted) | per section |
| Settings | `GET/PATCH /settings` | `settings.manage` |

---

## 4. Navigation flow

```
/login ──(success)──► /dashboard
                         │
  Responsive shell (ShellRoute):
   • compact  (<600dp):  BottomNavigationBar — Dashboard · Appointments · Billing · Customers · More
   • medium   (600–1199): NavigationRail (collapsed labels)
   • expanded (≥1200):   Side NavigationDrawer + list/detail split panes
                         │
  ├── /dashboard
  ├── /appointments            (day | week toggle)   → /appointments/new, /appointments/:id
  ├── /billing/new[?appointmentId=]   → /bills/:id (receipt, add payment)
  ├── /bills                    (history, filters)
  ├── /customers               → /customers/new, /customers/:id (profile + visit history)
  ├── /services                → editor dialog
  ├── /inventory               → /inventory/:id (stock movements, add purchase/adjustment)
  ├── /staff                   → /staff/:id → /staff/:id/compensation (rules, earnings, payouts)
  ├── /roles
  └── /settings                (payment methods, salon info, tax, invoice prefix)
```

- `redirect` guard: unauthenticated → `/login`; route lacking permission → `/dashboard` with message.
  Nav items are built from the user's permission set, so staff never see manager menus.
- The appointment → billing hand-off pre-fills customer, staff and services from the appointment.

---

## 5. Commission calculation design

### 5.1 Configuration

- `staff_compensation` (effective-dated): optional **monthly salary** (0 = commission-only).
- `commission_rules` (effective-dated): rate % per `(staff, service)` or `(staff, product)`, plus an
  optional default rate per item type. **No rule ⇒ no commission** — so a fixed-salary employee
  earns commission only on what the manager explicitly configures (e.g. 10% on products sold).
- Salary and commission are independent and can be combined (Q4).

### 5.2 Calculation (backend only — `commission.calculator.ts`, pure function)

Per **line** (service performed or product sold) at billing, and again whenever an extra discount
is applied to the bill:

```
line_gross     = unit_price × quantity
line_discount  = item discount + pro-rata share of bill-level & extra discounts   (largest-remainder, exact to the paisa)
line_net       = line_gross − line_discount
basis          = line_net                                   (after discount, before tax — Q2)
rate           = specific rule(staff, item) ?? staff default for item type ?? none   (snapshot at billing)
commission     = round_half_up(basis × rate / 100, 2)
```

Example: Haircut ₹200 (A, 40%) + Beard ₹100 (A, 30%) + Shampoo ₹220 (B, 10%) = ₹520.
- No discount → A ₹80 + ₹30 = ₹110, B ₹22.
- Customer later gets ₹52 extra discount (10%) → each line loses 10% → A ₹72 + ₹27 = ₹99, B ₹19.80.

### 5.3 Snapshot and history

The bill line stores `commission_rate`, `commission_basis`, `commission_amount` and the `staff_id`
**at billing**. An extra discount re-uses the stored rate (never the current rule). Changing rules
or prices later never alters history.

### 5.4 Staff balance and withdrawals (Q3)

```
available balance = Σ commission on my finalised bill lines
                  + Σ confirmed salary credits / adjustments
                  − Σ confirmed withdrawals
```

- **Staff login** shows only their own data: work done (services, products, per-line commission),
  balance, and withdrawal history/status (`earnings.view_own`). No salon-wide financials.
- **Withdrawals any time:** either the staff member or the manager enters the withdrawal (amount,
  cash/UPI, note). It stays **PENDING** until the *other* party confirms it — so both sides agree
  on every entry and the same withdrawal cannot be counted twice. Only CONFIRMED entries change
  the balance. (Confirming locks the staff's balance rows to prevent two concurrent confirmations
  overdrawing.)
- **Salary:** the manager posts "Salary for <month>" once per employee (UNIQUE per month — cannot
  be posted twice), which credits the balance.
- **Advance:** a withdrawal larger than the balance is allowed (the manager is always one of the two
  parties). The balance goes negative and is recovered from future commission, or by a
  `REPAYMENT` entry when the staff pays it back.
- **Daily settlement (commission staff):** manager taps "Settle today" → payout = balance rounded
  **up** to the nearest ₹10 (setting) → `ROUND_OFF` credit + `WITHDRAWAL` entry created together
  → balance becomes 0. E.g. ₹113 → pay ₹120 (₹7 round-off).
- Staff without a login: manager-entered entries are auto-confirmed.
- **Voided bill / extra discount** after money was withdrawn simply lowers the balance (it may go
  negative and is recovered from future earnings). No blocking, full audit trail.

### 5.5 Customer bill round-off

After discounts and tax, the payable total is rounded to the nearest ₹10 (setting: 0 / 1 / 5 / 10)
using the owner's rule — **last digit 1–5 rounds down, 6–9 rounds up**:

```
r = total mod unit
round_off = (r ≤ unit/2) ? −r : unit − r          // ties (exactly 5) round DOWN
```
E.g. ₹521 → ₹520 (−1), ₹525 → ₹520 (−5), ₹526 → ₹530 (+4), ₹529 → ₹530 (+1), ₹525.50 → ₹530 (+4.50).

The signed amount is stored as `bills.round_off_amount`, shown on the receipt ("Round off −₹5" /
"+₹4"), and **not** spread across lines — staff commission is unchanged either way.

---

## 6. Inventory and billing transaction flow

### 6.1 Create & finalise bill — `POST /bills` (one DB transaction)

Client sends: customer, optional appointment, lines (service+staff / product+qty), discounts,
optional initial payments, `Idempotency-Key`.

```
BEGIN
 1. Idempotency: INSERT key into bills.idempotency_key (UNIQUE). If it already exists → return
    the existing bill (no double billing on retry / double tap).
 2. Load current service & product prices from DB (client prices are ignored).
 3. Lock stock rows:  SELECT … FROM product_stock WHERE branch_id=$b AND product_id = ANY($ids)
    ORDER BY product_id FOR UPDATE   (fixed ordering prevents deadlocks between concurrent bills).
 4. Validate stock (unless settings.allow_negative_stock) → else 422 STOCK_INSUFFICIENT.
 5. Compute line totals, allocate bill discount, tax (0 until configured), commission snapshots.
 6. Allocate invoice number:  UPDATE branches SET next_invoice_no = next_invoice_no + 1 RETURNING …
    (row lock ⇒ gapless, sequential under concurrency).
 7. INSERT bill, bill_items.
 8. UPDATE product_stock SET quantity = quantity − qty; INSERT stock_movements (type SALE, bill_item_id).
 9. INSERT initial payments (amount ≤ outstanding), update bill.paid_total.
10. If appointmentId: UPDATE appointment status → COMPLETED (only from allowed states).
COMMIT   — any failure ⇒ ROLLBACK ⇒ nothing changes.
```

Customer visit history, service sales, product sales, commission and payments are all
**derived from this one committed bill** — there is no second copy of the data to fall out of sync.

### 6.2 Record payment — `POST /bills/:id/payments`

```
BEGIN
 SELECT … FROM bills WHERE id = $1 FOR UPDATE      ← serialises concurrent payments on one bill
 reject if bill voided; reject if amount > grand_total − paid_total (409 OVERPAYMENT)
 INSERT payment (UNIQUE idempotency_key ⇒ retry returns the original payment)
 UPDATE bills SET paid_total = paid_total + amount
COMMIT
```

### 6.3 Stock purchase / adjustment

Same pattern: lock the `product_stock` row → insert `stock_movements` → update `quantity`
(rejected below zero unless negative stock is allowed). `quantity` is a maintained balance;
`stock_movements` is the immutable ledger and can rebuild/verify it.

### 6.4 Appointment conflicts and rest gap

Enforced by PostgreSQL itself with an **exclusion constraint** on
`tstzrange(starts_at, blocked_until)` per staff, where `blocked_until = ends_at + rest buffer`
(setting, default **10 min**, snapshotted per booking). Back-to-back bookings therefore always
leave the staff a break. Two receptionists booking the same slot at the same instant → one
succeeds, the other gets 409 with the next free time. Walk-ins are billed directly without an
appointment (Q6).

### 6.5 Cash received directly + extra discount (Q6)

- Any staff with `billing.create` + `payments.record` can create the bill and take cash on the
  spot; `payments.received_by` records who physically holds the money (report: cash collected per
  staff per day, for handing over to the manager). Commission is calculated in the same transaction.
- **Extra discount** given later (e.g. while collecting the balance): `POST /bills/:id/adjustments`
  (permission `billing.discount`, reason required, ≤ outstanding amount). In one transaction:
  lock bill → record adjustment → re-allocate discount across lines → recompute each line's
  commission with its snapshot rate → update totals. Commission is re-balanced automatically.

### 6.6 Void (corrections)

Finalised bills are immutable. `POST /bills/:id/void` (permission `billing.void`, reason required)
in one transaction: mark voided, reverse stock movements; its lines stop counting toward staff
commission, so balances adjust automatically (see §5.4).

### 6.7 Withdrawal confirmation

```
POST /staff/:id/withdrawals   → INSERT staff_ledger (WITHDRAWAL, PENDING, entered_by=me, idempotency_key)
POST /ledger/:entryId/confirm → BEGIN; lock entry FOR UPDATE; require status PENDING and
                                confirmer ≠ entered_by (staff ↔ manager); set CONFIRMED; COMMIT
```

---

## 7. Development roadmap

| Phase | Deliverable | Exit criteria |
|---|---|---|
| **1. Planning** (this doc) | Architecture, DB design, API, navigation, risks | Owner approval + answers to open questions |
| **2. Initialisation** | Monorepo, docker-compose Postgres, Fastify skeleton, env config, migrations runner, error handling, logging; Flutter app with theme/config system, router, shell, shared widgets | `GET /health` passes; migrations up/down; Flutter builds for Android + Windows (iOS/macOS on a Mac — see R1) |
| **3a. Auth & users** | Login/refresh/logout, roles, permissions, staff CRUD, activation | Authz test matrix green |
| **3b. Customers** | CRUD, search (name/mobile) | API + widget tests |
| **3c. Services & pricing** | CRUD, deactivate | |
| **3d. Staff & compensation** | Compensation plans, commission rules UI | Calculator unit tests (all cases) |
| **3e. Inventory** | Products, purchases, adjustments, low-stock | Concurrent stock tests |
| **3f. Appointments** | Day/week views, create/edit/cancel, conflicts | Concurrent booking test |
| **3g. Billing & payments** | Atomic bill, split/partial payments, receipt, void | Duplicate-payment & rollback tests |
| **3h. Customer history** | Profile visit history, lifetime totals | |
| **3i. Dashboard** | Permission-aware sections | |
| **4. Integration** | End-to-end: register → book → bill → pay → stock → commission → history | Scripted E2E API test + manual run-through |
| **5. Hardening** | Perf (query plans, indexes), memory (DevTools), responsive checks, all platform builds | |
| **6. Docs** | All docs current; implementation summary | |

Each step ships with its tests and doc updates; no module is reported "done" without a verified
frontend → API → database flow.

---

## 8. Technical risks and mitigations

| # | Risk | Mitigation |
|---|---|---|
| R1 | **iOS/macOS builds require a Mac with Xcode**; this machine is Windows | Develop/verify Android + Windows here; iOS/macOS builds need a Mac or a CI macOS runner (e.g. GitHub Actions). Code stays platform-agnostic. |
| R2 | Flutter SDK and PostgreSQL are not installed on this machine (Node 22 is) | Phase 2 setup: install Flutter SDK; run Postgres via Docker Desktop or native installer. |
| R3 | Floating-point money errors | Integer paise in TS; `NUMERIC` in DB; single `money.ts` utility; allocation tests sum exactly. |
| R4 | Double payment / double bill on network retry or double tap | `Idempotency-Key` (UNIQUE), bill row lock, overpayment check, disabled button while submitting. |
| R5 | Stock races / deadlocks | Row locks in deterministic order; `CHECK` constraint as last line of defence; concurrency tests. |
| R6 | Booking races | DB exclusion constraint (not app checks). |
| R7 | History corruption when prices/rates change | Snapshot price, name, rate, amounts on bill lines; reports never join to current price. |
| R8 | Timezones (server UTC vs salon local time; "today" boundaries) | Store `timestamptz`; salon timezone in settings; day boundaries computed server-side in salon TZ. |
| R9 | LAN server PC off / IP changes; Wi-Fi drop | Server address configurable in-app (not only compile-time); DHCP reservation for the server PC; clear "server unreachable" state. No offline sync in v1. |
| R13 | Plain HTTP on the salon LAN during testing | Acceptable only for local testing; Android cleartext allowed in the **dev** build flavour only; HTTPS (reverse proxy + certificate) mandatory when hosted. |
| R10 | Token theft on shared salon PCs | Short access-token life, refresh rotation with reuse detection, logout revokes, deactivation revokes all sessions. |
| R11 | Permission drift between UI and API | Permission keys defined once in backend; `/auth/me` returns the list; Flutter only consumes it. |
| R12 | Large history lists slow on low-end phones | Cursor pagination, `ListView.builder`, select only needed columns, indexed queries. |

---

## 9. Business rules decided (owner answers, 2026-11-03)

| # | Topic | Decision |
|---|---|---|
| Q1 | Branches | One salon now; schema is branch-ready (`branches`, per-branch stock & invoice numbers). |
| Q2 | Commission basis | After discount, before tax. Staff earn commission on **products they sell** too. |
| Q3 | Earning & withdrawal | Staff see their own work + commission status. Withdraw any time; staff or manager enters it, the other confirms. Voids/extra discounts lower the balance. |
| Q4 | Salary | Monthly. Fixed-salary staff may also earn commission (e.g. on products) when configured. |
| Q5 | Tax / invoices | No tax initially (configurable later); gapless invoice numbers per branch. |
| Q6 | Walk-ins & gaps | Walk-ins allowed. Rest buffer between consecutive appointments (setting, default 10 min). Staff can bill & take cash directly; extra discounts re-balance commission. |
| Q7 | Logins | Staff login optional now (daily pay from app data later). Manager performing services optional. |
| Q8 | Hosting | Local/LAN for testing; cloud hosting later. Online-only (no offline sync). |
| R-Q1 | Advances | Allowed with manager approval; negative balance recovered from future earnings or staff repayment. |
| R-Q2 | Daily pay / cash | Commission staff are settled daily (payout rounded up to ₹10). Cash collected per staff shown as a report. |
| R-Q3 | Extra discounts | Only roles granted `billing.discount`. |
| — | Commission per service | Each staff can have a different rate per service/product (e.g. beard x%, haircut y%). |
| — | Bill round-off | Customer total to nearest ₹10: last digit 1–5 down, 6–9 up. Commission unaffected. |
| — | Default commission (2026-11-24) | Each employee has a monthly salary and/or commission %s per service/product. A **salon-wide default %** (set at the top of the commission page) applies when an employee has **no monthly salary and no specific % for that item**. Salaried employees earn commission only where a specific % is set. Commission page is laid out per employee, covering services and products. |

## 10. Deployment (testing phase — salon LAN)

```
[Phones / tablets / Windows PCs on salon Wi-Fi]
            │  http://<server-LAN-IP>:8080/api/v1   (dev flavour)
[Salon PC]  Node API (binds 0.0.0.0:8080)  ──► PostgreSQL (localhost only, not exposed)
```
- First app launch (dev builds) asks for the server address; stored locally, editable in Settings.
- Windows firewall rule opens only the API port. PostgreSQL never listens on the LAN.
- Moving to cloud later = change server URL + enable HTTPS; no code restructuring.

## 11. Remaining open questions

None blocking Phase 2. Rounding units are settings and can be changed without code changes.
