# PPTX template placeholder

This file documents the template-handling contract for `slides/build/build-pptx-deck.py`.

## Behaviour

* If `slides/theme/deck.pptx-template.pptx` exists, the build script opens it via
  `Presentation(str(template_path))` so the deck inherits any custom slide masters,
  brand fonts, or layout placeholders configured in the template.
* If the template file does NOT exist, the build script falls back to the
  python-pptx default `Presentation()` constructor, which yields the built-in
  blank widescreen 16:9 master. Slides are laid out with explicit shape calls so
  the output remains visually correct without a template.

## Why this placeholder exists

A valid `.pptx` file is a ZIP archive with a strict internal structure. We do not
hand-author one in this repo because:

1. Generating a valid template requires running python-pptx in CI.
2. The build script is designed to work without a template (see fallback above),
   so committing an empty `.pptx` would be misleading.
3. Brand teams who want to inject a custom template can drop their own
   `deck.pptx-template.pptx` next to this file and the build will pick it up
   automatically — no script edits required.

## To inject a custom template

1. Open PowerPoint (or LibreOffice Impress).
2. Build a 16:9 widescreen deck with one blank-layout slide (slide_layouts[6]
   in python-pptx terms — `MSO_LAYOUT.BLANK`).
3. Save as `slides/theme/deck.pptx-template.pptx`.
4. Re-run `python slides/build/build-pptx-deck.py`.

## Font note (DD-05)

The build script pins all text to **Segoe UI** for Windows-safe rendering. If you
inject a template that uses a different theme font, the `add_textbox`/`add_shape`
calls will still override per-shape fonts to Segoe UI — this is intentional for
parity with the workshop dress code.
