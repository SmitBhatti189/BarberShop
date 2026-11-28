# Feature Flows

How each implemented feature works end to end. Planned flows (billing, commission, withdrawals …) are designed in [ARCHITECTURE.md §5–6](ARCHITECTURE.md) and move here as they are built.

## 1. First launch → server address (dev builds)

> **Currently switched off** (`AppEnv.serverSetupEnabled = false`, owner request 2026-11-19). The app never shows the server screen or a "Change server" button. It uses `--dart-define=API_BASE_URL` if given, otherwise `http://localhost:8080/api/v1` (on web: the PC that served the page, port 8080). The flow below applies again when the switch is set back to `true`.

1. App starts → `AuthController` checks for a saved server address.
2. None saved and no `--dart-define=API_BASE_URL` → **Server setup** screen.
3. User types e.g. `192.168.1.10:8080` → normalised to `http://192.168.1.10:8080/api/v1`.
4. App calls `GET /health` on it. Only a valid response saves the address (secure storage).
5. → **Login** screen. "Change server" on the login screen reopens step 2.

Production builds use the compiled-in address only.

## 2. Login

1. User enters username + password (form validates empty fields locally).
2. `POST /auth/login` → backend looks the user up case-insensitively and verifies the argon2id hash (a dummy verification runs for unknown users so timing does not reveal valid usernames).
3. 5 failures per username + device IP within 15 min → `429` for the rest of the window.
4. Success → a session row is stored with the **hash** of a new random refresh token; the app receives access + refresh tokens and the user's permissions.
5. Tokens go to the OS secure storage; the router moves to **Dashboard**, and the menu shows only sections the permissions allow.

## 3. Every authenticated request

1. App attaches the access token.
2. Backend verifies the JWT signature/expiry, then loads (one query) the session + staff + permissions, requiring session not revoked/expired and staff active.
3. Route guard checks the required permission → `403` if missing.
4. Hence deactivating a staff member, logging out or changing a role applies on the **next request**, not after the token expires.

## 4. Token refresh

1. A request gets `401` → `ApiClient` starts **one** refresh (`POST /auth/refresh`); other failing requests wait for the same refresh.
2. Backend locks the session row (`SELECT … FOR UPDATE`), revokes it and issues a new one in the same family.
3. Original requests are retried with the new token.
4. If the refresh is rejected (expired, revoked, or token replayed — which revokes the whole family) → tokens are cleared and the user is returned to Login with "session expired".

## 5. Logout

`POST /auth/logout` revokes the session; the app clears tokens even if the server is unreachable.

## 7. Navigation frame (navbar, sidebar, profile box)

- **Sidebar** (tablet/desktop, full height): header shows the scissors logo + salon name (only the logo when collapsed); clicking it opens the Dashboard. The collapse button sits to the right of the logo. Collapsed = icons only; hovering an icon shows its name; clicking navigates. Default: collapsed on tablets, expanded on desktops; after the first toggle the choice is remembered on that device. Settings is not listed here.
- **Navbar:** profile box on the right (avatar + name; avatar only on phones). On phones it also shows the logo + salon name on the left.
- **Profile box menu:** Profile → `/profile`; Settings → `/settings` (only with `settings.manage`); Dark mode switch (keeps the menu open, flips light ↔ dark immediately); Log out.
- **Phones:** no sidebar; bottom bar with up to 4 sections + "More".
- **Hover labels** are switched per element in `app/lib/config/app_hover_labels.dart`.
- Theme and sidebar choices are stored on the device only (OS secure storage), never on the server.

## 8. Employee management (Staff & pay → Employees)

1. **List** (`/staff`, needs `staff.view`): active employees by default; filter Active / Inactive / All; search by name, username or mobile (runs 0.3 s after typing stops). Wide screens show a table (name, role, mobile, sign-in); phones show cards.
2. **Add** (`/staff/new`, needs `staff.manage`): name, optional mobile/email, role, optional join date, "performs services" (can be booked), and optionally "can sign in" with username + password. The app checks the obvious mistakes; the server re-checks everything and its messages (e.g. duplicate mobile) appear under the matching field. On success the employee's page opens.
3. **Edit** (`/staff/:id`): the form saves with the version it loaded. If someone else saved first, the server refuses (`STALE`), the app says so and reloads the latest values.
4. **Sign-in card:** give a login, change the password (ends their other sessions), or remove the login (signs them out). Employees without a login can still be booked and paid.
5. **Deactivate / Reactivate:** asks for confirmation; deactivating signs them out everywhere and hides them from the default list. Their history stays.
6. **Guards (server-side):** you can't deactivate yourself or remove your own login, and the last active Manager who can sign in can't be deactivated, demoted or have their login removed.

## 11. Commission & salary (Staff & pay → Commission & salary)

1. **Open** `/staff/pay` (needs `compensation.view`); the "Employees | Commission & salary" switch at the top of Staff & pay shows when you can see both.
2. **Salon default %** (top card, `compensation.manage` to change): applies to commission-based employees on any item without their own rate.
3. **Pick an employee** (list on the left; a dropdown on phones). The list shows "Commission" or "Salary ₹X" and how many own rates they have.
4. **Monthly salary:** blank = commission-based. With a salary, items without an own rate earn nothing — the page says which rule applies and each row's note ("Own rate", "Default 10%", "No commission") updates as you type.
5. **Rates:** one % field per active service and product; blank uses the rule above. **Save changes** sends the salary and only the rates you changed; the server validates, locks the employee and records history (old row closed, new row added). Without `compensation.manage` the page is view-only.
6. Used next by billing: each bill line will copy the rate that applied at that moment.

## 10. Services

1. **List** (`/services`, needs `services.view` — staff have it): every service with category, duration and price, grouped by category. Search, category and Active/Inactive/All filters.
2. **Add service** (`/services/new`, needs `services.manage`): name, optional category (one-tap suggestions), price, duration in minutes (quick chips 15 / 30 / 45 / 1 h / 1 h 30), optional description. Returns to the list.
3. **Service page** (`/services/:id`): edit any field (versioned save); "Stop offering" deactivates it — hidden from booking and billing, past bills keep it.
4. Used next by: appointments (duration blocks the barber's time), billing (price copied onto the bill), and commission rates (per employee, per service).

## 9. Inventory

1. **List** (`/inventory`, needs `inventory.view`): products with stock, MRP, discount and selling price; "Low stock" / "Out of stock" labels. Filter by search (name or brand), category, Active/Inactive/All, and "Low stock only".
2. **Add product** (`/inventory/new`, needs `inventory.manage`): left — name, brand, category (one-tap suggestions from names already used), MRP, default discount %, low-stock alert level; the selling price is shown as you type (display only; the server computes the saved value with the same rule). Right — optional opening stock (quantity, buying price per unit, supplier, bill no.), saved as the first delivery.
3. **Product page** (`/inventory/:id`): edit details and prices (versioned save); Stock card with current units, selling price, MRP, discount and last buying price; **Receive stock** (a delivery: quantity + buying price per unit, optional supplier, bill no., note) and **Adjust stock** (take out / add in, with a reason; "Other" needs a note). Stock history lists every movement newest first ("Show older" pages back).
4. **Rules (server-side):** stock never goes below zero unless the negative-stock setting is on; inactive products can't take stock changes; the same name + brand can't be active twice; each stock change is locked and written to the ledger in one transaction.
5. **Prices at the till (with Billing, later):** billing will charge the selling price (MRP − default discount) and record each sale as a SALE movement.

## 6. App start with a saved session

Saved tokens → `GET /auth/me` (refreshing if needed) → Dashboard. If the server is unreachable the tokens are kept and Login shows the network message, so the next attempt can resume the session.
