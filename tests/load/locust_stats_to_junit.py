"""
Convert Locust headless CSV output (`<prefix>_stats.csv` and `<prefix>_failures.csv`)
into a JUnit XML report so Azure DevOps' Test tab can render per-endpoint results.

One <testcase> is emitted per endpoint row in `_stats.csv` (the `Aggregated` row is
emitted as the suite-wide totals, not a testcase). A testcase is marked failed when
either of these is true:

* the endpoint had at least one HTTP failure (`Failure Count > 0`), or
* the endpoint's p95 latency exceeded ``--p95-threshold-ms`` (default 1500 ms).

Usage:

    python locust_stats_to_junit.py \
        --stats-prefix tests/load/reports/20260430-122427/stats \
        --output      tests/load/reports/20260430-122427/junit.xml \
        --suite-name  "Mapaq Load Test" \
        --p95-threshold-ms 1500

The script intentionally has no third-party dependencies so it can run on a
clean Azure DevOps Microsoft-hosted agent without a `pip install` step.
"""

from __future__ import annotations

import argparse
import csv
import os
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from typing import Iterable


# ---------------------------------------------------------------------------
# CSV helpers
# ---------------------------------------------------------------------------
def _read_stats(stats_csv: str) -> tuple[list[dict[str, str]], dict[str, str] | None]:
    """Return (per-endpoint rows, aggregated row) from Locust's _stats.csv."""
    if not os.path.isfile(stats_csv):
        raise FileNotFoundError(f"Locust stats CSV not found: {stats_csv}")
    rows: list[dict[str, str]] = []
    aggregated: dict[str, str] | None = None
    with open(stats_csv, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            if (row.get("Name") or "").strip() == "Aggregated":
                aggregated = row
            else:
                rows.append(row)
    return rows, aggregated


def _read_failures(failures_csv: str) -> dict[tuple[str, str], list[tuple[str, int]]]:
    """Return {(method, name): [(error, occurrences), ...]} from _failures.csv."""
    grouped: dict[tuple[str, str], list[tuple[str, int]]] = defaultdict(list)
    if not os.path.isfile(failures_csv):
        return grouped
    with open(failures_csv, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            method = (row.get("Method") or "").strip()
            name = (row.get("Name") or "").strip()
            error = (row.get("Error") or "").strip()
            try:
                occurrences = int(row.get("Occurrences") or "0")
            except ValueError:
                occurrences = 0
            grouped[(method, name)].append((error, occurrences))
    return grouped


# ---------------------------------------------------------------------------
# Type coercion
# ---------------------------------------------------------------------------
def _to_int(value: str | None, default: int = 0) -> int:
    try:
        return int(float((value or "").strip()))
    except (ValueError, TypeError):
        return default


def _to_float(value: str | None, default: float = 0.0) -> float:
    try:
        return float((value or "").strip())
    except (ValueError, TypeError):
        return default


# ---------------------------------------------------------------------------
# JUnit emission
# ---------------------------------------------------------------------------
def _build_junit(
    rows: Iterable[dict[str, str]],
    aggregated: dict[str, str] | None,
    failures_by_endpoint: dict[tuple[str, str], list[tuple[str, int]]],
    suite_name: str,
    p95_threshold_ms: float,
) -> ET.ElementTree:
    """Return a JUnit XML tree describing one testcase per endpoint."""
    testsuite = ET.Element("testsuite", attrib={"name": suite_name})
    suite_failures = 0
    suite_total = 0
    suite_time_seconds = 0.0

    for row in rows:
        method = (row.get("Type") or "").strip()
        name = (row.get("Name") or "").strip()
        if not name:
            continue

        request_count = _to_int(row.get("Request Count"))
        failure_count = _to_int(row.get("Failure Count"))
        avg_ms = _to_float(row.get("Average Response Time"))
        p95_ms = _to_float(row.get("95%"))
        p99_ms = _to_float(row.get("99%"))
        max_ms = _to_float(row.get("Max Response Time"))
        rps = _to_float(row.get("Requests/s"))

        # JUnit's `time` is per-testcase total seconds — use the cumulative latency
        # in seconds so the Test tab still totals to a meaningful "time" column.
        elapsed_seconds = (avg_ms * request_count) / 1000.0
        suite_time_seconds += elapsed_seconds
        suite_total += 1

        case_name = f"{method} {name}".strip()
        case = ET.SubElement(
            testsuite,
            "testcase",
            attrib={
                "classname": suite_name,
                "name": case_name,
                "time": f"{elapsed_seconds:.3f}",
            },
        )

        # ---- properties (visible as attachments in the Test tab) ----
        props = ET.SubElement(case, "properties")
        for key, value in (
            ("requests", str(request_count)),
            ("failures", str(failure_count)),
            ("requests_per_second", f"{rps:.3f}"),
            ("avg_ms", f"{avg_ms:.1f}"),
            ("p95_ms", f"{p95_ms:.1f}"),
            ("p99_ms", f"{p99_ms:.1f}"),
            ("max_ms", f"{max_ms:.1f}"),
        ):
            ET.SubElement(props, "property", attrib={"name": key, "value": value})

        # ---- failure conditions ----
        failure_messages: list[str] = []
        if failure_count > 0:
            details = failures_by_endpoint.get((method, name), [])
            if details:
                summary = "; ".join(
                    f"{occ}x {err}" for err, occ in details
                )
            else:
                summary = f"{failure_count} request(s) failed"
            failure_messages.append(
                f"{failure_count}/{request_count} requests failed: {summary}"
            )
        if p95_threshold_ms > 0 and p95_ms > p95_threshold_ms:
            failure_messages.append(
                f"p95 latency {p95_ms:.0f}ms exceeded threshold {p95_threshold_ms:.0f}ms"
            )

        if failure_messages:
            suite_failures += 1
            failure_element = ET.SubElement(
                case,
                "failure",
                attrib={
                    "type": "LoadTestFailure",
                    "message": failure_messages[0],
                },
            )
            failure_element.text = "\n".join(failure_messages)

    # Suite-level summary attributes (ADO uses these for the run dashboard).
    testsuite.set("tests", str(suite_total))
    testsuite.set("failures", str(suite_failures))
    testsuite.set("errors", "0")
    testsuite.set("skipped", "0")
    testsuite.set("time", f"{suite_time_seconds:.3f}")

    if aggregated is not None:
        agg_props = ET.SubElement(testsuite, "properties")
        for key, csv_key in (
            ("aggregated_requests", "Request Count"),
            ("aggregated_failures", "Failure Count"),
            ("aggregated_avg_ms", "Average Response Time"),
            ("aggregated_p95_ms", "95%"),
            ("aggregated_p99_ms", "99%"),
            ("aggregated_rps", "Requests/s"),
        ):
            ET.SubElement(
                agg_props,
                "property",
                attrib={"name": key, "value": (aggregated.get(csv_key) or "").strip()},
            )

    testsuites = ET.Element("testsuites", attrib={"name": suite_name})
    testsuites.append(testsuite)
    return ET.ElementTree(testsuites)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument(
        "--stats-prefix",
        required=True,
        help="The --csv prefix passed to locust (e.g. reports/run-1/stats).",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Path for the generated JUnit XML file.",
    )
    parser.add_argument(
        "--suite-name",
        default="Mapaq Load Test",
        help="JUnit testsuite name displayed in the Azure DevOps Test tab.",
    )
    parser.add_argument(
        "--p95-threshold-ms",
        type=float,
        default=1500.0,
        help="Mark an endpoint as failed when its p95 latency exceeds this value (ms). "
             "Set to 0 to disable the latency gate and only fail on HTTP errors.",
    )
    args = parser.parse_args(argv)

    stats_csv = f"{args.stats_prefix}_stats.csv"
    failures_csv = f"{args.stats_prefix}_failures.csv"

    rows, aggregated = _read_stats(stats_csv)
    failures = _read_failures(failures_csv)
    tree = _build_junit(
        rows=rows,
        aggregated=aggregated,
        failures_by_endpoint=failures,
        suite_name=args.suite_name,
        p95_threshold_ms=args.p95_threshold_ms,
    )

    os.makedirs(os.path.dirname(os.path.abspath(args.output)) or ".", exist_ok=True)
    # ET.indent only exists on Python 3.9+, which Locust already requires.
    ET.indent(tree, space="  ", level=0)
    tree.write(args.output, encoding="utf-8", xml_declaration=True)

    print(f"Wrote JUnit report to {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
