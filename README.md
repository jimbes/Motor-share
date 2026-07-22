# REDL — Motor-Share

"Track every apex." A Strava-style ride tracker for motorbikes (built with
room to grow into other motorsport later): GPS ride recording, routes drawn
on OpenStreetMap, a social feed (likes, comments, photos), and a garage for
your bikes.

**No Google Maps SDK and no paid map service anywhere in this project** —
maps are OpenStreetMap tiles rendered via `flutter_map`.

## Structure

```
backend/    Laravel API (Sanctum auth, MySQL in prod / SQLite in dev)
app/        Flutter app (Android first, iOS kept possible)
PLAN.md     Original POC plan and current status
DESIGN.md   REDL brand tokens (colors, type, spacing) reference
```

## Quick start

```bash
# Backend - local Docker stack (PHP-FPM + Nginx + MySQL)
cd backend
docker compose up -d --build
# API now at http://localhost:8000/api

# App
cd ../app
flutter pub get
flutter run   # defaults to http://10.0.2.2:8000/api (Android emulator)
```

For deploying the backend to a real (non-Docker) server, see
`backend/DEPLOY.md`.

## Status

See `PLAN.md` for the full breakdown of what's implemented. In short: the
API (auth, bikes, rides, photos, likes, comments) is built and tested
(`php artisan test`), and the Flutter app implements all five core screens
end-to-end against that API. Not yet done: on-device GPS/background-tracking
testing, a real app launcher icon, and deployment to the actual distant
server (needs your server's access details).
