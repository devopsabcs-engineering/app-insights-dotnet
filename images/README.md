# Workshop screenshots

Placeholder folder for screenshots referenced from the lab markdown files.

Screenshots are **regenerated from a live demo and committed manually** after the workshop is rehearsed end-to-end at least once. Do not check in stale or pre-rehearsal captures.

## Expected files

| File | Referenced from | Capture target |
| --- | --- | --- |
| `lab-04-application-map.png` | Lab 04 | Azure Portal → Application Insights → Application map, showing the demo service and its dependencies. |
| `lab-05-end-to-end-trace.png` | Lab 05 | Azure Portal → Application Insights → Transaction search → end-to-end transaction view of one request. |
| `lab-05-kql-results.png` | Lab 05 | Azure Portal → Application Insights → Logs (KQL), showing results of the lab's sample query. |

## Capture conventions

- 16:9 aspect ratio, 1920 x 1080 source resolution, exported as PNG (lossless).
- Crop to the relevant pane only; avoid capturing the full browser chrome.
- Redact tenant / subscription / resource group names that are not part of the demo persona.
- File names use the pattern `lab-NN-<short-slug>.png` and are referenced with relative paths from the lab markdown.

## Jekyll exclusion

The Jekyll site (`_config.yml`, Phase 4 deliverable) excludes this folder from the navigation collection so it ships only as static assets. Do not move the folder or change its name without updating `_config.yml`.
