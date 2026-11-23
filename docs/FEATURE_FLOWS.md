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

## 6. App start with a saved session

Saved tokens → `GET /auth/me` (refreshing if needed) → Dashboard. If the server is unreachable the tokens are kept and Login shows the network message, so the next attempt can resume the session.
