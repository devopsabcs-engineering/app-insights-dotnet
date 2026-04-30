"""
Locust load test for the Mapaq workshop apps (Mapaq.Api + Mapaq.Web).

Targets the four API endpoints exposed by `src/Mapaq.Api/Program.cs`:
    GET  /healthz
    GET  /api/establishments?city=&region=
    GET  /api/establishments/{id}
    GET  /api/inspections/rollup?region=&year=
    POST /api/sync                       (rare; exercised at low weight)

…and the Razor Pages on `Mapaq.Web` so end-to-end traces (browser → web → api → SQL)
show up in Application Insights:
    GET  /
    GET  /Etablissements?city=&region=
    GET  /Inspections/Rollup?region=&year=

Two locust user classes are defined so a single run can drive load against either
the API directly or the Web tier (which itself fans out to the API). The default
when running locust without `--class-picker` is to spawn both proportionally.

Usage (headless, from repo root):

    locust -f tests/load/locustfile.py \
        --host https://localhost:7020 \
        --users 25 --spawn-rate 5 --run-time 2m --headless

Or use the bundled PowerShell wrappers in `scripts/`:

    pwsh ./scripts/load-test.ps1                 # one-liner, sensible defaults
    pwsh ./scripts/run-load-test.ps1 -Users 50   # full set of knobs
"""
from __future__ import annotations

import os
import random
import urllib3
from datetime import datetime, timezone

from locust import HttpUser, between, events, task

# ---------------------------------------------------------------------------
# Demo dataset — must mirror MapaqDemoSeeder so the load actually returns data
# ---------------------------------------------------------------------------
REGIONS: list[str] = [
    "01-BAS-SAINT-LAURENT",
    "02-SAGUENAY-LAC-SAINT-JEAN",
    "03-CAPITALE-NATIONALE",
    "04-MAURICIE",
    "05-ESTRIE",
    "06-MONTREAL",
    "07-OUTAOUAIS",
    "08-ABITIBI-TEMISCAMINGUE",
    "09-COTE-NORD",
    "10-NORD-DU-QUEBEC",
    "11-GASPESIE-ILES-DE-LA-MADELEINE",
    "12-CHAUDIERE-APPALACHES",
    "13-LAVAL",
    "14-LANAUDIERE",
    "15-LAURENTIDES",
    "16-MONTEREGIE",
    "17-CENTRE-DU-QUEBEC",
]

CITIES: list[str] = [
    "Montreal", "Quebec", "Laval", "Gatineau", "Sherbrooke",
    "Trois-Rivieres", "Longueuil", "Saguenay", "Drummondville",
    "Saint-Jerome", "Granby", "Levis", "Rimouski",
]


def _years() -> list[int]:
    """Years served by the rollup endpoint (current and previous)."""
    now = datetime.now(timezone.utc).year
    return [now, now - 1]


# ---------------------------------------------------------------------------
# Self-signed dev cert: the local apps use the ASP.NET Core dev certificate.
# Disable verification + the noisy warning so the load test works against
# https://localhost:7020 / https://localhost:7010 out of the box. Pass
# LOCUST_VERIFY_SSL=1 in the environment to re-enable verification when
# pointing at a real Azure environment.
# ---------------------------------------------------------------------------
_VERIFY = os.environ.get("LOCUST_VERIFY_SSL", "0") == "1"
if not _VERIFY:
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ---------------------------------------------------------------------------
# Per-tier host overrides. The Mapaq.Api endpoints (/api/...) live on a
# different port than the Mapaq.Web Razor pages (/, /Etablissements, ...),
# so a single `--host` cannot satisfy both. The wrapper script sets these
# env vars; when unset, each user class falls back to `environment.host`.
# ---------------------------------------------------------------------------
_API_HOST = os.environ.get("MAPAQ_API_HOST") or None
_WEB_HOST = os.environ.get("MAPAQ_WEB_HOST") or None


@events.init.add_listener
def _on_locust_init(environment, **_kwargs) -> None:
    """Print resolved targets so it is obvious which tiers are under load."""
    print(
        f"[mapaq-load] api_host={_API_HOST or environment.host} "
        f"web_host={_WEB_HOST or environment.host} "
        f"verify_ssl={_VERIFY}"
    )


class MapaqApiUser(HttpUser):
    """
    Drives the API directly. Use when `--host https://localhost:7020`.

    The weights below approximate a realistic read-mostly mix:
        * ~70% search by region/city
        * ~20% drill-down into a single establishment
        * ~10% rollup queries
        *  rare /api/sync (POST) so the CKAN integration also sees traffic
    """

    wait_time = between(0.5, 2.0)
    # 60% of virtual users hit the API directly, 40% go through Web.
    weight = 6
    # Pin to the API tier when MAPAQ_API_HOST is provided so a single run can
    # exercise both tiers regardless of which URL is passed to --host.
    host = _API_HOST

    # ---- discovered ids cached per virtual user so /{id} drills are valid ----
    def on_start(self) -> None:  # noqa: D401 - locust hook
        self.client.verify = _VERIFY
        self._known_ids: list[int] = []
        self._prime_ids()

    def _prime_ids(self) -> None:
        """Pre-fetch a search so subsequent /{id} calls hit a real row."""
        region = random.choice(REGIONS)
        with self.client.get(
            "/api/establishments",
            params={"region": region},
            name="/api/establishments?region=[prime]",
            catch_response=True,
        ) as resp:
            if resp.status_code != 200:
                resp.failure(f"prime returned {resp.status_code}")
                return
            try:
                rows = resp.json()
            except ValueError:
                resp.failure("prime payload was not JSON")
                return
            self._known_ids = [
                int(row["establishmentId"]) for row in rows if "establishmentId" in row
            ]

    @task(7)
    def search_by_region(self) -> None:
        region = random.choice(REGIONS)
        self.client.get(
            "/api/establishments",
            params={"region": region},
            name="/api/establishments?region=",
        )

    @task(3)
    def search_by_city(self) -> None:
        city = random.choice(CITIES)
        self.client.get(
            "/api/establishments",
            params={"city": city},
            name="/api/establishments?city=",
        )

    @task(4)
    def get_establishment_detail(self) -> None:
        if not self._known_ids:
            self._prime_ids()
            if not self._known_ids:
                return
        est_id = random.choice(self._known_ids)
        self.client.get(
            f"/api/establishments/{est_id}",
            name="/api/establishments/{id}",
        )

    @task(2)
    def inspections_rollup(self) -> None:
        region = random.choice(REGIONS)
        year = random.choice(_years())
        self.client.get(
            "/api/inspections/rollup",
            params={"region": region, "year": year},
            name="/api/inspections/rollup?region=&year=",
        )

    @task(1)
    def healthz(self) -> None:
        self.client.get("/healthz", name="/healthz")

    # POST /api/sync hits the donneesquebec.ca CKAN API — keep it very rare so
    # we don't hammer a public service from the load test.
    @task(0)  # disabled by default; bump to >0 in custom runs to exercise sync
    def trigger_sync(self) -> None:
        self.client.post("/api/sync", name="/api/sync")


class MapaqWebUser(HttpUser):
    """
    Drives the Razor pages on Mapaq.Web. Use when `--host https://localhost:7010`.

    Each page server-side calls the API, so a single virtual user generates a
    distributed trace spanning Browser → Web → API → SQL/EF Core.
    """

    wait_time = between(1.0, 3.0)
    weight = 4
    # Pin to the Web tier so /Etablissements etc. resolve even when --host
    # points at the API (Razor pages live on a different port).
    host = _WEB_HOST

    def on_start(self) -> None:  # noqa: D401 - locust hook
        self.client.verify = _VERIFY

    @task(2)
    def home(self) -> None:
        self.client.get("/", name="GET /")

    @task(5)
    def search_etablissements(self) -> None:
        region = random.choice(REGIONS)
        self.client.get(
            "/Etablissements",
            params={"region": region},
            name="GET /Etablissements?region=",
        )

    @task(3)
    def search_etablissements_by_city(self) -> None:
        city = random.choice(CITIES)
        self.client.get(
            "/Etablissements",
            params={"city": city},
            name="GET /Etablissements?city=",
        )

    @task(3)
    def inspections_rollup_page(self) -> None:
        region = random.choice(REGIONS)
        year = random.choice(_years())
        self.client.get(
            "/Inspections/Rollup",
            params={"region": region, "year": year},
            name="GET /Inspections/Rollup?region=&year=",
        )
