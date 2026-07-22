# REDL — Motor-Share (app)

"Track every apex." A Strava-style ride tracker for motorbikes (built with
room to grow into other motorsport later): GPS ride recording, routes drawn
on OpenStreetMap, a social feed (likes, comments, photos), and a garage for
your bikes.

**No Google Maps SDK and no paid map service anywhere in this project** —
maps are OpenStreetMap tiles rendered via `flutter_map`.

This repo holds the **Flutter app**. The API backend lives in a separate
repo: [jimbes/motor-share-back](https://github.com/jimbes/motor-share-back).

## Structure

```
app/        Flutter app (Android first, iOS kept possible)
design/     Original design handoff (mockups, logo exports)
PLAN.md     Original POC plan and current status
DESIGN.md   REDL brand tokens (colors, type, spacing) reference
```

## Quick start

```bash
# 1. Backend - see jimbes/motor-share-back's DEPLOY.md, or for local Docker:
#    git clone https://github.com/jimbes/motor-share-back backend
#    cd backend && docker compose up -d --build
#    API now at http://localhost:8000/api

# 2. App
cd app
flutter pub get
flutter run   # defaults to http://10.0.2.2:8000/api (Android emulator)
```

## Releasing an APK

Push a version tag to trigger `.github/workflows/release-apk.yml`, which
builds a release APK and attaches it to a GitHub Release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

It can also be run manually from the Actions tab (uploads the APK as a
build artifact instead of a release, for quick testing).

## Status

See `PLAN.md` for the full breakdown of what's implemented. In short: the
API (auth, bikes, rides, photos, likes, comments) is built and tested, and
the Flutter app implements all five core screens end-to-end against that
API. Not yet done: on-device GPS/background-tracking testing, a real app
launcher icon, and deploying the backend to the actual distant server
(needs your server's access details).
