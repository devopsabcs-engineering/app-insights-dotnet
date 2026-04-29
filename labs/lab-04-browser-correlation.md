---
layout: default
title: "Lab 04: Browser ↔ server correlation"
parent: "Labs"
nav_order: 4
permalink: /labs/lab-04-browser-correlation
description: "Verify that a single operation_Id stitches together browser PageView, AJAX dependency, server request and SQL dependency."
---

# Lab 04: Browser ↔ server correlation

> **Timebox: 15 min** — Confirm one `operation_Id` end-to-end.

This lab is the payoff for Labs 02 and 03. It is a structured walkthrough of how to confirm end-to-end correlation in Application Insights, plus a debugging workflow for when correlation breaks.

## Learning Objectives

By the end of this lab you will be able to:

* Trigger a deterministic, easily-findable transaction from the browser.
* Locate the resulting four spans (PageView, AJAX dependency, API request, SQL dependency) in Transaction Search.
* Run a KQL `union` query that returns all four rows for a given `operation_Id`.
* Diagnose the three most common correlation breakages: missing JS SDK, missing CORS exposure, and a misconfigured `distributedTracingMode`.

## Exercises

### Exercise 4.1: Generate a known transaction

In the browser, perform a search for `postalCode=G1V`. The search box automatically appends a unique `q` query-string parameter so this transaction is easy to find later.

### Exercise 4.2: Find the operation_Id from PageView

In Application Insights → Logs:

```kusto
pageViews
| where timestamp > ago(10m)
| where url contains "postalCode=G1V"
| project timestamp, name, url, operation_Id
| top 1 by timestamp desc
```

Copy the returned `operation_Id` into your scratch buffer.

### Exercise 4.3: Confirm all four spans correlate

```kusto
let opId = "<paste-operation_Id-here>";
union
    (pageViews | where operation_Id == opId | extend kind = "pageView"),
    (dependencies | where operation_Id == opId | extend kind = "dependency"),
    (requests | where operation_Id == opId | extend kind = "request")
| project timestamp, kind, name, target, duration, success
| order by timestamp asc
```

Expected output (in order):

1. `pageView`  — the search page render.
2. `dependency` (`Ajax`) — `GET $API_URI/establishments`.
3. `request` — the API endpoint that handled the call.
4. `dependency` (`SQL`) — the EF Core query against `dbo.Establishments`.

### Exercise 4.4: Break it deliberately, then fix it

Comment out `WithExposedHeaders` in the API CORS policy from Lab 03, redeploy, and re-run Exercise 4.3. The AJAX dependency now appears under a *different* `operation_Id` from the API request — confirming the failure mode and reinforcing why exposing the W3C headers is non-negotiable.

Restore the line and confirm correlation returns.

## Verification Checkpoint

* [ ] You can name and recognize all four span types in the union query above.
* [ ] You ran the deliberate breakage and saw the orphaned AJAX dependency.
* [ ] You restored the CORS exposure and confirmed correlation returns.
* [ ] You can articulate the difference between `operation_Id` (per trace) and `operation_ParentId` (per span).

## Next Steps

End-to-end correlation is now demonstrably working. Continue with [Lab 05: Dashboards, KQL, alerts](lab-05-dashboards) to turn this telemetry into a Workbook, three KQL queries and one alert rule.
