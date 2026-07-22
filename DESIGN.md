# REDL Design Reference

Source of truth for the brand implemented in `app/lib/theme/`. Sober,
premium, motorsport-heritage tone — not playful, not bright.

## Logo

Abstract monoline apex-curve — never a literal wheel/helmet/vehicle
illustration. Stroke `#8E2430`, 2.5-7px depending on export size, round
caps, no fill. Source SVGs: `app/assets/images/redl-icon-*.svg`,
`redl-lockup-*.svg`.

## Colors

| Token | Hex | Use |
|---|---|---|
| Base (dark) | `#1A1A1A` | App background |
| Base (alt) | `#F2EFEA` | Primary text on dark |
| Accent (bordeaux) | `#8E2430` | CTAs, key stat highlight, active states — used sparingly, never brightened |
| Accent tint | `#E6C9CC` | Secondary text on accent surfaces |
| Neutral dark gray | `#5C5750` | Secondary text, labels |
| Neutral light gray | `#B3ABA2` | Muted text on dark |
| Surface `0E0D0C` → `3A3733` | darkest → lightest | Card/sheet/placeholder backgrounds |

Implemented in `app/lib/theme/redl_colors.dart`.

## Typography

Inter throughout (bundled locally as a variable font —
`app/assets/fonts/Inter-Variable.ttf` — no runtime Google Fonts fetch).

- Wordmark/headline: weight 800, wide positive letter-spacing
- Section labels/eyebrows: weight 700, 9-11px, uppercase, tracked
- Stat values: weight 800; titles/buttons: weight 700; body: weight 400
- No italics, no light weights

Implemented in `app/lib/theme/redl_text_styles.dart`.

## Spacing / shape

- Border radius: 4px (cards/buttons), 6px (hero stat card), full circle
  (avatars/badges)
- Flat design only — no gradients, no glossy highlights, no drop-shadow glow
- 20-22px horizontal screen padding, ~60-64px safe-area top padding

## Screens

Five core screens, all recreated as native Flutter widgets (not embedded
HTML): Onboarding, Home/Feed, Live Recording, Profile, Ride Summary. See
`app/lib/screens/`.

Map imagery (route lines, live tracking) is real OpenStreetMap tiles via
`flutter_map`, replacing the flat placeholders used in the original mockups
— per the original design handoff's own note that placeholders should be
replaced with real map tiles during implementation.

## Provenance

Original design handoff: Strava-style REDL app screens + brand banner
(HTML/CSS mockups + logo SVG exports), used as the pixel-reference for the
Flutter implementation.
