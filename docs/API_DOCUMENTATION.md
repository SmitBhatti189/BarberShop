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

## Staff (employees)

All responses use the employee shape below — the password hash is never returned.

```json
{ "id": 7, "fullName": "Rahul Sharma", "mobile": "9876543210", "email": "rahul@example.com",
  "roleId": 2, "roleName": "Staff", "isActive": true, "performsServices": true,
  "joinedOn": "2026-01-15", "username": "rahul", "version": 3, "createdAt": "2026-11-24T10:00:00.000Z" }
```
`username: null` means the employee cannot sign in. `version` must be sent back when editing.

| Endpoint | Permission | Notes |
|---|---|---|
| `GET /staff?search=&status=active\|inactive\|all&limit=&offset=` | `staff.view` | Search matches name, username, or mobile digits (3+). `meta { limit, offset, total }`. Active first, then by name. |
| `GET /staff/:id` | `staff.view` | 404 if missing. |
| `POST /staff` | `staff.manage` | Body: `fullName`, `roleId`, optional `mobile`, `email`, `performsServices` (default true), `joinedOn` (YYYY-MM-DD, not future), optional `login: { username, password }`. → `201`. |
| `PATCH /staff/:id` | `staff.manage` | Body: `version` + any of the create fields except `login`; `null` clears an optional field. `409 STALE` if someone saved first. |
| `POST /staff/:id/deactivate` | `staff.manage` | Signs the employee out everywhere. `422 CANNOT_DEACTIVATE_SELF`, `422 LAST_MANAGER`. |
| `POST /staff/:id/activate` | `staff.manage` | |
| `PUT /staff/:id/login` | `staff.manage` | Body `{ username, password }`. Creates the login or changes it; ends the employee's other sessions (your own current one is kept if you change your own). |
| `DELETE /staff/:id/login` | `staff.manage` | Removes the login and signs them out. `422 CANNOT_REMOVE_OWN_LOGIN`, `422 LAST_MANAGER`. |
| `GET /roles` | `staff.manage` or `roles.manage` | `[{ id, name, description, isSystem }]` — system roles first. |

Input rules: mobile is an Indian 10-digit number (`+91`, spaces, dashes and a leading 0 are accepted and stripped); email is lower-cased; username 3–32 of `A–Z a–z 0–9 . _ -` (unique ignoring case); password 8–128 characters.
Duplicates return `409 DUPLICATE` with `details: [{ field: "mobile" | "email" | "username", message }]`.
**Last manager rule:** the salon always keeps at least one active employee with the Manager role who can sign in. Deactivating, removing the login of, or changing the role of the last one returns `422 LAST_MANAGER` (checked under a row lock, so two simultaneous changes cannot both pass).

---

## Services

Shape: `{ "id", "name", "category", "description", "price": "250.00", "durationMinutes": 45, "isActive", "version" }`.

| Endpoint | Permission | Notes |
|---|---|---|
| `GET /services?search=&category=&status=active\|inactive\|all&limit=&offset=` | `services.view` | Search matches name or category. Ordered by category, then name. |
| `GET /services/categories` | `services.view` | Categories used by active services, one per name ignoring case. |
| `GET /services/:id` | `services.view` | |
| `POST /services` | `services.manage` | `name`, `price` (≥ 0, 2 decimals), `durationMinutes` (1–600), optional `category`, `description`. → `201`. |
| `PATCH /services/:id` | `services.manage` | `version` + any field; `null` clears category/description; `409 STALE`. |
| `POST /services/:id/activate` · `/deactivate` | `services.manage` | |

Duplicate active name (ignoring case) → `409 DUPLICATE` on field `name`. The built-in Staff role can view services but not change them.

---

## Inventory (products and stock)

Product shape (money as 2-decimal strings, stock for the caller's branch):
```json
{ "id": 4, "name": "Anti-dandruff Shampoo", "brand": "Beardo", "category": "Shampoo",
  "mrp": "2000.00", "defaultDiscountPct": "10.00", "sellingPrice": "1800.00",
  "lastPurchasePrice": "1600.00", "stockQuantity": 12, "lowStockThreshold": 3,
  "isLowStock": false, "isActive": true, "version": 1 }
```
`sellingPrice` = MRP less the default discount, rounded to the paisa — computed by the server only. `isLowStock` = stock ≤ threshold (so out-of-stock is also low).

| Endpoint | Permission | Notes |
|---|---|---|
| `GET /products?search=&category=&status=active\|inactive\|all&lowStock=true&limit=&offset=` | `inventory.view` | Search matches name or brand; category is case-insensitive. |
| `GET /products/suggestions` | `inventory.view` | `{ categories: [], brands: [] }` already used by active products. |
| `GET /products/:id` | `inventory.view` | |
| `POST /products` | `inventory.manage` | `name`, `mrp`, optional `brand`, `category`, `defaultDiscountPct` (0–100), `lowStockThreshold`, `openingStock { quantity, unitCost, supplierName?, invoiceNo?, note? }` (recorded as the first delivery). → `201`. |
| `PATCH /products/:id` | `inventory.manage` | `version` + any product field; `409 STALE` if changed meanwhile. |
| `POST /products/:id/activate` · `/deactivate` | `inventory.manage` | Reactivating can return `409 DUPLICATE` if an active product with the same name + brand exists. |
| `POST /products/:id/purchases` | `inventory.manage` | A delivery: `{ quantity ≥ 1, unitCost, supplierName?, invoiceNo?, note? }`. → `201 { product, movement }`. |
| `POST /products/:id/adjustments` | `inventory.manage` | `{ direction: IN\|OUT, quantity ≥ 1, reason, note? }` — `note` required for `OTHER`. `422 STOCK_INSUFFICIENT` (with `details.inStock`) if it would go below zero and negative stock is off. → `201 { product, movement }`. |
| `GET /products/:id/movements?limit=&cursor=` | `inventory.view` | Stock history, newest first; `meta.nextCursor`. |

Stock changes on an inactive product return `422 PRODUCT_INACTIVE`. Duplicate active name + brand returns `409 DUPLICATE` on field `name`. Every stock change locks that product's stock row, so simultaneous changes queue instead of losing or inventing units.

---

## Compensation (salary and commission rates)

Rule (server only): an employee's own rate for the item → else, if they have no monthly salary, the salon default → else no commission.

| Endpoint | Permission | Notes |
|---|---|---|
| `GET /compensation/default` | `compensation.view` | `{ defaultCommissionPct: "10.00" }` |
| `PUT /compensation/default` | `compensation.manage` | `{ defaultCommissionPct }` (0–100). |
| `GET /compensation/staff` | `compensation.view` | Active employees: `[{ staffId, fullName, roleName, performsServices, monthlySalary \| null, specificRates }]`. |
| `GET /compensation/staff/:id` | `compensation.view` | `{ staff, monthlySalary, salonDefaultPct, services: [PayItem], products: [PayItem] }` — every active service and product. |
| `PUT /compensation/staff/:id` | `compensation.manage` | `{ monthlySalary: "15000" \| null, rates: [{ itemType: SERVICE\|PRODUCT, itemId, ratePct: "40" \| null }] }`. `null` salary = commission-based; `null` rate removes the own rate. Only listed items change; each item once. Returns the same shape as GET. |

`PayItem`: `{ itemId, name, detail, price, ratePct (own rate or null), effectiveRatePct (what applies now, or null), source: SPECIFIC | DEFAULT | NONE }`.
Errors: `404` unknown employee, `422 STAFF_INACTIVE`, `422 ITEM_NOT_AVAILABLE` (inactive or missing item, `details.itemIds`). Unchanged values write nothing; changes close the old row and add a new one (history kept).

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
