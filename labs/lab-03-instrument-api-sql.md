---
layout: default
title: "Lab 03: Instrument the API + SQL tier"
parent: "Labs"
nav_order: 3
permalink: /labs/lab-03-instrument-api-sql
description: "Add the Application Insights distro to the Minimal API tier, capture EF Core SQL spans, and expose CORS correlation headers."
---

# Lab 03: Instrument the API + SQL tier

> **Timebox: 20 min** — Server-side distro on the API, EF Core dependency capture, CORS exposed headers for browser correlation.

The web tier from Lab 02 calls a Minimal API that reads the MAPAQ data from Azure SQL. This lab instruments the API and ensures the SQL spans are captured automatically by the OpenTelemetry instrumentation that the distro brings in.

## Learning Objectives

By the end of this lab you will be able to:

* Register the Application Insights distro in the Minimal API project.
* Confirm that EF Core / `Microsoft.Data.SqlClient` spans show up as dependencies under the API request.
* Expose the W3C `traceparent` and `tracestate` headers via CORS so the browser SDK can stitch the AJAX dependency to the API request.
* Tell the difference between a missing instrumentation and a missing CORS exposure when a span is present in one tier but not the other.

A common failure mode is "everything looks fine in the API, but the browser doesn't link to it." The fix is almost always missing CORS exposure of the W3C trace context headers — Exercise 3.3 hardens against that.

## Exercises

### Exercise 3.1: Add the distro to the API project

```bash
dotnet add src/api package Azure.Monitor.OpenTelemetry.AspNetCore
```

`Program.cs` for the API:

```csharp
using Azure.Monitor.OpenTelemetry.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenTelemetry().UseAzureMonitor(o =>
{
    o.ConnectionString =
        builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
});

builder.Services.AddDbContext<MapaqDbContext>(opts =>
    opts.UseSqlServer(builder.Configuration["SQL_CONNECTION_STRING"]));
```

### Exercise 3.2: Confirm SQL dependency capture

The distro registers the `Microsoft.EntityFrameworkCore` and `OpenTelemetry.Instrumentation.SqlClient` instrumentations. No additional code is needed — but confirm by hitting the search endpoint:

```bash
curl "$API_URI/establishments?postalCode=G1V"
```

In Application Insights → Application Map you should see `web → api → sqlserver` within ~30 seconds.

### Exercise 3.3: Expose W3C correlation headers via CORS

In the API `Program.cs`:

```csharp
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p
    .WithOrigins(builder.Configuration["WEB_URI"]!)
    .AllowAnyHeader()
    .AllowAnyMethod()
    .WithExposedHeaders("traceparent", "tracestate", "request-id")));
```

Without `WithExposedHeaders`, the browser SDK cannot read the response trace context and the AJAX dependency span ends up orphaned.

### Exercise 3.4: Redeploy and verify the topology

```bash
azd deploy api
```

Refresh the search page in the browser, then inspect the Application Map.

## Verification Checkpoint

* [ ] Application Map shows three nodes: `web`, `api`, `sqlserver`.
* [ ] In Transaction Search, opening any browser PageView reveals nested AJAX dependency → API request → SQL dependency.
* [ ] All four spans share the same `operation_Id`.
* [ ] No exceptions in `traces` from a missing connection string or unbound config key.

## Next Steps

You now have a fully instrumented two-tier app. Continue with [Lab 04: Browser ↔ server correlation](lab-04-browser-correlation) to formally validate the end-to-end correlation under load.
