---
layout: default
title: "Lab 05: Dashboards, KQL, alerts"
parent: "Labs"
nav_order: 5
permalink: /labs/lab-05-dashboards
description: "Author three KQL queries, walk the Application Map, configure one alert rule, and pin everything to a Workbook."
---

# Lab 05: Dashboards, KQL, alerts

> **Timebox: 20 min** — From raw telemetry to a usable dashboard.

This lab turns the telemetry you have been generating into something an on-call engineer can actually use: a Workbook with three KQL tiles, a walked Application Map, and one alert rule on the API failure rate.

## Learning Objectives

By the end of this lab you will be able to:

* Write KQL queries against `requests`, `dependencies` and `customMetrics`.
* Use the Application Map to identify the slowest dependency in the topology.
* Create a metric alert on API HTTP 5xx rate using `requests | summarize`.
* Pin a query result to a Workbook and share it via a portal URL.

## Exercises

### Exercise 5.1: Top-5 slowest API endpoints

```kusto
requests
| where timestamp > ago(1h)
| where cloud_RoleName == "api"
| summarize p95 = percentile(duration, 95), count() by name
| order by p95 desc
| take 5
```

Pin this to a new Workbook called `MAPAQ — Workshop dashboard`.

### Exercise 5.2: Dependency duration breakdown

```kusto
dependencies
| where timestamp > ago(1h)
| summarize p50 = percentile(duration, 50),
            p95 = percentile(duration, 95),
            count()
            by type, target
| order by p95 desc
```

This single query reveals whether your latency tail is in SQL, in HTTP downstream calls, or in something else entirely.

### Exercise 5.3: Browser AJAX → API correlation count

```kusto
let last_hour = ago(1h);
let browserAjax = dependencies
    | where timestamp > last_hour and type == "Ajax";
let apiRequests = requests
    | where timestamp > last_hour and cloud_RoleName == "api";
browserAjax
| join kind=leftouter apiRequests on operation_Id
| summarize correlated = countif(isnotempty(operation_Id1)),
            orphaned   = countif(isempty(operation_Id1))
```

If `orphaned > 0`, that is a correlation regression — go back to Lab 04 Exercise 4.4 to debug.

### Exercise 5.4: Walk the Application Map

In the portal, open Application Insights → Application Map. Confirm the `web → api → sqlserver` topology, click on the SQL node, and note the average call duration. This is the same number you will see in the `dependencies` table; the map is just a visualization layer over the same data.

### Exercise 5.5: Create a 5xx alert

In Application Insights → Alerts → New alert rule:

* Signal: `Failed requests`.
* Condition: `Average count > 5 over 5 minutes` for `cloud_RoleName == "api"`.
* Action group: pick `Email` and your address.

## Verification Checkpoint

* [ ] The Workbook contains all three queries above as pinned tiles.
* [ ] You can articulate why dependency p95 is more useful than dependency average.
* [ ] The alert rule fires when you `curl` a deliberately broken endpoint 6 times in 5 minutes.
* [ ] Application Map renders the three-node topology.

## Next Steps

You now have a working observability surface. Continue with [Lab 06: Teardown](lab-06-teardown) to delete every resource and confirm zero residual cost.
