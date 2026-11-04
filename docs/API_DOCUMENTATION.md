# API Documentation

Base URL: `http://<server>:8080/api/v1` (LAN testing) · JSON only.

## Conventions

| Topic | Rule |
|---|---|
| Auth | `Authorization: Bearer <accessToken>` on every protected endpoint. Access tokens live 15 min; renew with `/auth/refresh`. |
| Success | `{ "data": … , "meta"?: … }` |
| Error | `{ "error": { "code": "…", "message": "…", "details"?: [ { "field", "message" } ] } }` |
| Status codes | 200 OK · 201 Created · 204 No Content · 400 `VALIDATION_ERROR` · 401 `UNAUTHORIZED` / `INVALID_CREDENTIALS` · 403 `FORBIDDEN` · 404 `NOT_FOUND` · 409 `DUPLICATE` / `CONFLICT` · 422 business rule · 429 `TOO_MANY_ATTEMPTS` · 500 `INTERNAL_ERROR` |
| Pagination | Offset lists: `?limit=&offset=` → `meta { limit, offset, total }`. History lists: `?limit=&cursor=` → `meta { limit, nextCursor }`. Max limit 100. |
| Idempotency | `Idempotency-Key: <uuid>` required on bill creation and payments (when those modules land). |
| Money | Decimal strings with 2 places, e.g. `"520.00"`. |

Every protected endpoint re-checks on each request that the session is active, the staff member is active, and the role holds the required permission — changes take effect immediately.

---

## Health

### `GET /health` — public
`200` `{ "data": { "status": "ok", "database": "up", "time": "2026-11-04T10:00:00.000Z" } }`
`503` same shape with `status: "degraded", database: "down"`.

## Auth

### `POST /auth/login` — public
Body: `{ "username": "owner", "password": "…", "deviceLabel"?: "android" }`
`200`:
```json
{ "data": {
    "accessToken": "eyJ…", "refreshToken": "q3J…", "expiresIn": 900,
    "user": { "id": 1, "fullName": "Salon Owner", "branchId": 1, "roleId": 1, "permissions": ["billing.create", "…"] } } }
```
Errors: `401 INVALID_CREDENTIALS` (same response for unknown user, wrong password or deactivated account), `429 TOO_MANY_ATTEMPTS` after 5 failures per username+IP in 15 min, `400 VALIDATION_ERROR`.

### `POST /auth/refresh` — public
Body: `{ "refreshToken": "…" }` → `200` same shape as login (new access **and** refresh token).
The old refresh token is revoked. Re-using a revoked token revokes the whole session family (theft protection) → `401`.
Clients must never send two refreshes with the same token concurrently.

### `POST /auth/logout` — authenticated
Revokes the current session. `204`.

### `GET /auth/me` — authenticated
`200` `{ "data": { "id", "fullName", "branchId", "roleId", "permissions": [] } }`

---

## Permission keys

Defined in `server/src/shared/permissions.ts` (mirrored for UI hints in `app/lib/core/permissions.dart`).

| Key | Meaning |
|---|---|
| `staff.view` / `staff.manage` | View / manage staff |
| `roles.manage` | Manage roles and their permissions |
| `customers.view` / `customers.manage` / `customers.history.view` | Customers |
| `services.view` / `services.manage` | Services & prices |
| `inventory.view` / `inventory.manage` | Products & stock |
| `appointments.view` / `appointments.view_all` / `appointments.manage` | Appointments |
| `billing.create` / `billing.view` / `billing.discount` / `billing.void` | Bills |
| `payments.record` / `payments.view` | Payments |
| `compensation.view` / `compensation.manage` | Salary, commission rules, ledgers |
| `earnings.view_own` / `withdrawals.request_own` / `withdrawals.confirm` | Staff self-service & withdrawals |
| `reports.financial.view` | Salon-wide financial figures |
| `settings.manage` | Settings, branches, payment methods |

Planned endpoints per module are listed in [ARCHITECTURE.md §3.1](ARCHITECTURE.md); each is documented here when implemented.
