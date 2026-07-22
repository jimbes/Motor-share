# Motor-Share POC — Strava-style Motorbike Tracking App

## Status: implemented

Everything below has been built. Backend: full API (auth, bikes, rides,
photos, likes, comments), 32 passing feature tests, Docker for local dev,
a classic-PHP-server deploy guide for the distant server. App: all six
screens wired end-to-end against the API, branded with the REDL design
system, `flutter analyze` clean, 18 passing tests. See root `README.md` for
quick start and `DESIGN.md` for the brand reference.

Not yet done: on-device GPS/background-tracking testing (needs a real
phone), a custom app launcher icon, and actually deploying to the distant
server (needs its access details from Jimmy).

One deviation from the original plan: production DB is MySQL (confirmed),
and rather than Docker on the distant server, that server runs classic
PHP-FPM + Nginx/Apache — Docker is used for local development only. See
the backend repo's `DEPLOY.md`.

**Second deviation: split into two repos.** What started as a monorepo
(`backend/` + `app/` here) is now two separate repos — this one holds just
the Flutter app, and the API moved to
[jimbes/motor-share-back](https://github.com/jimbes/motor-share-back)
(backend history was preserved via `git subtree split` before the move).
Simpler to clone/deploy each independently, at the cost of no longer being
able to land an API-change + app-change in one atomic commit. A CI workflow
(`.github/workflows/release-apk.yml`) now builds and releases a signed-ish
(debug-keystore) APK on every `vX.Y.Z` tag push.

## Context

Jimmy wants a Strava-like app focused on motorbikes (later, all motorsport). A previous Flutter attempt was painful largely because of Google Maps; the hard requirement is **no Google Maps dependency — OpenStreetMap only**. The repository is empty, so this is a greenfield build.

**Decisions made with the user:**
- **App**: Flutter + `flutter_map` (OSM-native, zero Google dependency)
- **Backend**: Laravel (PHP) + MySQL, deployed on the user's own server
- **Platform**: Android first (iOS kept possible, not tested)
- **Auth**: email + password

**POC scope (agreed):**
1. Record a ride with GPS → publish it as a Strava-style post with the route drawn on a map
2. Profile section with motorbike info ("garage")
3. Social layer on posts: **likes, comments, and photos attached to a ride**

## Repository layout

Originally planned (and initially built) as a monorepo; now split into two
repos (see "Status" above for why):

```
Motor-share/            (this repo - the Flutter app)
├── app/
├── design/
└── README.md

motor-share-back/       (github.com/jimbes/motor-share-back)
└── (the Laravel API, formerly this repo's backend/)
```

## Part 1 — Backend (Laravel API)

Laravel 11+, PHP 8.2+, **Laravel Sanctum** for token auth (idiomatic Laravel, simpler than JWT packages). MySQL in production on the user's server; SQLite for local dev/tests so no DB setup is needed.

### Data model

- **users**: name, email, password (standard Laravel) 
- **bikes**: `user_id`, brand, model, year, nickname, engine_cc — the "garage"
- **rides**: `user_id`, `bike_id` (nullable), title, description, `started_at`, `duration_seconds`, `distance_meters`, `avg_speed_kmh`, `max_speed_kmh`, `track` (JSON column: array of `{lat, lng, alt, speed, t}` points)
- **ride_photos**: `ride_id`, `path` — images uploaded as multipart, stored on Laravel's public storage disk, served as URLs
- **ride_likes**: `ride_id`, `user_id` (unique pair — one like per user per ride)
- **ride_comments**: `ride_id`, `user_id`, `body`, timestamps

GPS track stored as a JSON column — no PostGIS/spatial extension needed for the POC. The app draws the polyline itself with flutter_map, so the backend never renders maps.

### API endpoints (all under `/api`, Sanctum token auth except register/login)

- `POST /register`, `POST /login`, `POST /logout`, `GET /me`
- `GET|POST /bikes`, `PUT|DELETE /bikes/{id}`
- `POST /rides` — upload a finished session (stats + full track)
- `GET /rides` — the feed (paginated, newest first; POC = all users' rides; includes photo URLs, like count, whether I liked it, comment count)
- `GET /rides/{id}` — detail incl. full track points, photos, comments
- `POST /rides/{id}/photos` — multipart image upload (attach photos to a ride, at save time or later)
- `POST|DELETE /rides/{id}/like` — like / unlike
- `GET|POST /rides/{id}/comments`, `DELETE /comments/{id}` (own comments only)
- Feed responses omit the heavy `track` field and include a **simplified polyline** (Douglas-Peucker reduction, computed server-side on upload and stored) so the feed stays light

### Backend tests

Laravel feature tests (Pest or PHPUnit) on SQLite: auth flow, bike CRUD, ride upload + feed retrieval, photo upload (faked storage), like/unlike, comment create/delete + authorization.

## Part 2 — Flutter app

### Key packages (all open, no Google services)

- `flutter_map` + `latlong2` — OSM map rendering & polylines
- `geolocator` — GPS stream; on Android its `foregroundNotificationConfig` keeps tracking alive with the screen off (foreground service, no paid plugin)
- `image_picker` — pick photos from camera/gallery to attach to a ride (no Google services involved)
- `dio` — HTTP client (also handles multipart photo upload); `flutter_secure_storage` — auth token
- `provider` (or `riverpod`) — state management, kept simple
- OSM tiles from `tile.openstreetmap.org` with a proper User-Agent (fine for a POC; note in README that production needs a tile provider per OSM usage policy)

### Screens

1. **Login / Register** — email+password, token stored securely, auto-login on relaunch
2. **Record** (the core) — full-screen OSM map centered on the rider; Start/Pause/Stop; live polyline drawn as points arrive; live stats bar (duration, distance, current speed). GPS noise filtered: drop points with accuracy > ~25 m, distance filter ~5 m; distance computed by haversine sum
3. **Save ride** — after Stop: title, description, pick a bike from the garage, attach photos (camera or gallery) → upload to API
4. **Feed** — Strava-style cards: static (non-interactive) `flutter_map` preview showing the route polyline, photo strip, title, date, distance / duration / avg speed, **like button with count** and comment count; tapping like toggles instantly (optimistic update)
5. **Ride detail** — full interactive map with the complete track, photo gallery, all stats, and the **comment thread** (read + write, delete own comments)
6. **Profile** — user info + garage: list bikes, add/edit/delete bike

### Android specifics

- Permissions: `ACCESS_FINE_LOCATION`, `FOREGROUND_SERVICE`(+`_LOCATION`), notification permission flow for the tracking notification
- Runtime permission request flow before starting a recording

## Implementation order

1. Scaffold monorepo: `backend/` (fresh Laravel) + `app/` (fresh Flutter)
2. Backend: migrations, models, Sanctum auth, bike + ride endpoints, polyline simplification, feature tests
3. Backend: social endpoints — photos (multipart upload), likes, comments + tests
4. Flutter: auth screens + API client + token storage
5. Flutter: Record screen (map, GPS stream, live tracking, stats)
6. Flutter: Save ride (with photo attach) → upload; Feed with likes; Ride detail with comments
7. Flutter: Profile + garage
8. README with local run instructions (backend: `php artisan serve` with SQLite; app: point `API_BASE_URL` at it, `flutter run`)

## Verification

- **Backend**: `php artisan test` (auth, bikes, rides feature tests); boot `php artisan serve` and exercise register → login → create bike → upload ride → attach photo → like → comment → fetch feed with curl
- **Flutter**: `flutter analyze` + `flutter test` (widget tests for auth form, feed card, stats calculation unit tests for haversine/filtering); build a debug APK to confirm it compiles for Android
- Real-device GPS testing is on the user (needs an actual ride/walk); the Record screen will also accept mocked location streams in tests

## Getting started on the laptop

The code is already built — this is how to run it, not scaffold it.

```bash
# Prerequisites: Flutter SDK (https://docs.flutter.dev/get-started/install),
# Android Studio/SDK, and either PHP 8.3+/Composer or Docker for the backend.

# 1. Backend - separate repo, pick one:
git clone https://github.com/jimbes/motor-share-back backend
cd backend
docker compose up -d --build          # Docker (recommended, needs nothing else installed)
# API at http://localhost:8000/api

# --- or, plain PHP ---
composer install
touch database/database.sqlite
php artisan migrate
php artisan serve                     # API at http://127.0.0.1:8000/api

# 2. Flutter app (this repo)
cd app
flutter pub get
flutter run
# Physical device: flutter run --dart-define=API_BASE_URL=http://<laptop-LAN-IP>:8000/api
```

For deploying the backend to the real distant server (classic PHP hosting,
no Docker), see the backend repo's `DEPLOY.md`.

## Out of scope for this POC (later iterations)

- Following/followers, private rides, notifications
- OAuth logins, password reset emails
- iOS testing, offline ride queueing, map tile self-hosting
