# Handoff: REDL App — UI Screens & Brand Banner

## Overview
REDL is a motorsport-heritage ride-tracking companion app. This package covers the app's core screen mockups (for a Flutter build) plus the brand product-lineup banner. Sober, premium, motorsport-heritage tone — not playful, not bright.

## About the Design Files
The files in this bundle (`REDL App Screens.dc.html`, `REDL Banner.dc.html`) are **design references built in HTML/CSS** — prototypes showing intended look, layout and content, not production code to copy directly. The task is to **recreate these designs in Flutter** (widgets, theming, navigation) using idiomatic Flutter patterns — not to embed HTML/WebViews.

## Fidelity
**High-fidelity.** Colors, typography, spacing and content shown are final — recreate pixel-close using Flutter's layout system (Row/Column/Stack, Container, custom paint for the logo mark).

## Screens / Views
All screens share: background `#1A1A1A`, iPhone-style safe-area top padding ~60-64px, horizontal content padding 20-22px.

### 01 — Onboarding
- Purpose: first-run screen, sign up / log in entry point.
- Layout: full-height column, centered, content padding-top 120px.
- Components:
  - REDL logomark (abstract apex-curve, monoline, `#8E2430` stroke, 2.5px width, ~56×56px) centered
  - Wordmark "REDL" — Inter 800, 22px, letter-spacing 4px, color `#F2EFEA`
  - Tagline "Track every apex." — Inter 400, 15px, color `#B3ABA2`
  - Spacer, then two full-width buttons stacked (gap 12px):
    - Primary "Create Account": bg `#8E2430`, radius 4px, padding 16px, text Inter 700 14px `#F2EFEA`
    - Secondary "Log In": 1px border `#3A3733`, radius 4px, same text style

### 02 — Home / Feed
- Purpose: weekly stats + recent activity feed.
- Layout: column, gap 20px, top padding 64px.
- Components:
  - Header row: avatar circle (32px, `#3A3733`) + "Hey, Marco" (Inter 700, 14px, `#F2EFEA`), settings icon circle right-aligned
  - Weekly stat card: bg `#8E2430`, radius 6px, padding 18×20px — label "THIS WEEK" (Inter 700, 10px, uppercase, letter-spacing 1.6px), value "482 km" (Inter 800, 30px, `#F2EFEA`), subtext "12 rides · 6,340 m elevation" (11px, `#E6C9CC`)
  - Section label "RECENT ACTIVITY" (Inter 700, 11px, uppercase, letter-spacing 1.2px, `#5C5750`)
  - Activity rows ×3: 52px square thumbnail placeholder (`#2A2825`, radius 4px) + title (Inter 700, 13px, `#F2EFEA`) + meta (10.5px, `#5C5750`)
  - Bottom tab bar: 4 icon slots (22px squares, radius 4px), first active in `#8E2430`, rest `#3A3733`

### 03 — Live Recording
- Purpose: active ride GPS/stat tracking screen.
- Layout: full-bleed map placeholder background (checker pattern stand-in for a real map tile), bottom stat sheet.
- Components:
  - "RECORDING" pill top-left: bg `#0E0D0C`, dot `#8E2430` (6-7px), text Inter 700 10px uppercase letter-spacing 1.5px `#F2EFEA`
  - Bottom sheet: bg `#161514`, padding 40×20×28px, 3-column stat row (speed/distance/time — Inter 800, 22px values, `#F2EFEA`; 9px uppercase labels `#5C5750`)
  - Stop/record button: 64px circle, bg `#8E2430`, centered 20px square icon `#F2EFEA`

### 04 — Profile
- Purpose: rider stats, badges, garage.
- Layout: scroll column, no top safe padding gap — banner starts at top:60px.
- Components:
  - Cover banner: 120px height, flat `#8E2430`
  - Avatar: 84px circle `#3A3733`, 4px border `#1A1A1A`, overlapping banner by -44px
  - Name "Marco Renard" (Inter 700, 16px, `#F2EFEA`), subtitle "Track club member since 2021" (11px, `#5C5750`)
  - Stat row (rides / km / elevation): bordered top+bottom `#2A2825`, values Inter 800 17px, labels 9px uppercase `#5C5750`
  - "BADGES" section: 4× 38px circles, first has `#8E2430` inset ring (earned), rest `#3A3733` (locked)
  - "VEHICLES" section: 36×26px placeholder chip + label (12px, `#B3ABA2`)

### 05 — Ride Summary
- Purpose: post-ride recap screen.
- Layout: scroll column, map/route placeholder image (200px) at top, stat grid below.
- Components:
  - Route image placeholder: `#2A2825`, full width, 200px
  - Title "Ride Complete" (Inter 700, 18px, `#F2EFEA`), timestamp subtitle (11px, `#5C5750`)
  - 2×2 stat grid cards: bg `#221F1C`, radius 4px, padding 14px — label 9px uppercase `#5C5750`, value Inter 800 19px `#F2EFEA` (Distance, Duration, Avg speed, Elevation)
  - "Save Ride" button: full width, bg `#8E2430`, radius 4px, padding 16px, Inter 700 13px `#F2EFEA`

## Interactions & Behavior (to be implemented in Flutter)
- Onboarding → Create Account / Log In → auth flow → Home
- Home bottom tab bar → navigate to Record / Profile / (other) tabs
- Home stat card or activity row tap → open Ride Summary (historical) detail
- Live Recording: record button starts/stops a session; live stats update from GPS in real time; on stop, navigate to Ride Summary
- Profile: badges and vehicles are read-only display for now; tapping a vehicle could open a garage/edit view (not designed yet — confirm with design before building)
- No hover states specified (mobile-only, touch targets); ensure all tappable elements meet 44px minimum hit target regardless of visual size shown

## State Management
- User profile (name, member since, stats, badges, vehicles) — likely fetched from backend/auth
- Weekly rollup stats (distance, ride count, elevation) — aggregated from ride history
- Active recording session state: elapsed time, distance, current speed, GPS track — live-updating during a ride
- Ride history list + individual ride summary records

## Design Tokens
**Colors**
- Base (dark): `#1A1A1A`
- Base (alt, light/off-white): `#F2EFEA`
- Accent (single, bordeaux): `#8E2430` — never brighten to pure red; used sparingly for CTAs, key stat highlight, active states
- Neutral dark gray: `#5C5750` (secondary text, labels)
- Neutral light gray: `#B3ABA2` (muted text on dark, secondary copy)
- Surface elevations on dark base: `#221F1C`, `#2A2825`, `#3A3733`, `#161514`, `#0E0D0C` (card/sheet/placeholder backgrounds, darkest to lightest)
- Accent tint (on-accent secondary text): `#E6C9CC`

**Typography** — Inter throughout
- Wordmark/headline: weight 800, large positive letter-spacing (~+130, i.e. ~4-6px at 22-38px sizes)
- Section labels/eyebrows: weight 700, 9-11px, uppercase, letter-spacing 1.2-1.6px
- Body/stat values: weight 800 for large numerals, weight 700 for titles/buttons, weight 400 for body copy
- No italics, no light weights

**Spacing / shape**
- Border radius: small and consistent — 4px for cards/buttons, 6px for the hero stat card, full circle for avatars/badges
- No decorative rounded-corner cards with left accent borders
- Flat design only — no gradients, no glossy highlights, no drop-shadow glow effects (only plain soft elevation shadows on the phone bezel itself, not on in-app cards)

## Logo
- Abstract monoline curve suggesting a racing line / apex — never a literal wheel, helmet, or vehicle illustration
- Stroke color `#8E2430`, stroke width 2.5px, round caps, no fill
- Paired with wordmark "REDL", Inter 800, wide tracking

## Assets
No photographic or stock assets used. All imagery in the mockups (map, route, activity thumbnails, vehicle chip) is a flat placeholder — replace with real map tiles / photos / icons during implementation.

## Files
- `REDL App Screens.dc.html` — the 5 screen mockups (Onboarding, Home/Feed, Live Recording, Profile, Ride Summary) in iPhone frames, plus a color swatch reference strip
- `REDL Banner.dc.html` — 1600×800 marketing/pitch-deck banner showing the product line-up (not an app screen — for reference/context only)

Open either file directly in a browser to view/inspect exact spacing and colors (use browser dev tools to inspect computed styles if needed).
