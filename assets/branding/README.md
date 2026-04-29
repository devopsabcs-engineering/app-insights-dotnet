# Branding assets

Hand-authored SVG branding for the **App Insights .NET 10 Workshop / Atelier d'observabilite .NET 10**.

## Files

| File | Dimensions (viewBox) | Purpose |
| --- | --- | --- |
| [favicon.svg](favicon.svg) | 32 x 32 | Browser tab icon. Wired up via `<link rel="icon" type="image/svg+xml" href="...">` and a fallback `<link rel="shortcut icon" href="...">`. |
| [logo-128.svg](logo-128.svg) | 128 x 128 | Site header / nav mark. |
| [social-card.svg](social-card.svg) | 1200 x 630 | Open Graph / Twitter card. Title text is hand-rendered with `<text>` elements (no `<image>`) so the card stays language-agnostic and editable. |

## Palette tokens

| Token | Hex | Role |
| --- | --- | --- |
| `--graphite` | `#1F2A37` | Background, foreground tile |
| `--leaf` | `#16A34A` | Primary accent (wheat stalk, agriculture motif) |
| `--sky` | `#3B82F6` | Secondary accent (chart line, telemetry motif) |
| `--orange` | `#F97316` | Highlight / data point accent |

Typography on the social card uses a neutral system stack (`Segoe UI, -apple-system, Roboto, Open Sans, sans-serif`). No custom font file is shipped.

## Constraints (must hold)

- **No Quebec emblem.** No reproduction of the official Government of Quebec wordmark.
- **No MAPAQ trademark.** No reproduction of the MAPAQ logo or wordmark.
- **No fleurdelisé / fleur-de-lys glyph.** Anywhere. Including stylised approximations.
- **Total branding asset budget < 50 KB.** Keep SVG markup minimal; do not embed raster `<image>` payloads.
- **Hand-authored, valid XML.** Use `viewBox` (not fixed `width`/`height`) so marks stay scalable.

## Bitmap (`.png`) generation

The social card is shipped as `.svg` only so the repo does not require a binary build step.
A future GitHub Actions workflow may rasterize `social-card.svg` to `social-card.png` (1200 x 630) for platforms that do not consume SVG Open Graph cards. When that workflow is added, the generated `.png` should be written next to the source `.svg` in this folder and committed alongside it.

A multi-size `favicon.ico` (16 / 32 / 48) may also be generated from `favicon.svg` by the same workflow. Until then, the `<link rel="icon" type="image/svg+xml">` declaration is sufficient for all evergreen browsers.
