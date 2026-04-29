---
layout: default
title: "Lab 02: Instrument the web tier"
parent: "Labs"
nav_order: 2
permalink: /labs/lab-02-instrument-web
description: "Wire the Application Insights .NET distro into the Razor Pages web app and add the JavaScript SDK to _Layout.cshtml."
---

# Lab 02: Instrument the web tier

> **Timebox: 20 min** — Server-side distro in `Program.cs`, browser SDK in `_Layout.cshtml`.

By the end of this lab the Razor Pages tier will produce request, dependency and trace telemetry server-side, plus page-view and AJAX-dependency telemetry from the browser, all stamped with the same `operation_Id` so Lab 04 can stitch the trace end-to-end.

## Learning Objectives

By the end of this lab you will be able to:

* Add the `Azure.Monitor.OpenTelemetry.AspNetCore` distro to the web project and register it in `Program.cs`.
* Bind the connection string from Key Vault via `IConfiguration` rather than checking it into source.
* Inject the Application Insights JavaScript SDK into `_Layout.cshtml` so browser sessions correlate to server requests.
* Verify in Live Metrics that requests appear within seconds of redeployment.

The Application Insights .NET distro is now built on OpenTelemetry; you do not need the legacy `Microsoft.ApplicationInsights.AspNetCore` package. The distro registers tracing, metrics and logging exporters in a single call.

## Exercises

### Exercise 2.1: Add the distro package

```bash
dotnet add src/web package Azure.Monitor.OpenTelemetry.AspNetCore
```

### Exercise 2.2: Register the distro in `Program.cs`

```csharp
using Azure.Monitor.OpenTelemetry.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// Bound from Key Vault → IConfiguration via Bicep deployment.
builder.Services.AddOpenTelemetry().UseAzureMonitor(o =>
{
    o.ConnectionString =
        builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
});

// ... existing Razor Pages registrations ...
```

### Exercise 2.3: Inject the JS SDK into `_Layout.cshtml`

Add the following snippet inside `<head>` in `Pages/Shared/_Layout.cshtml`. The connection string is rendered server-side from `IConfiguration` so the same Key Vault value powers both tiers.

```html
@inject Microsoft.Extensions.Configuration.IConfiguration Cfg
<script type="text/javascript">
!(function (cfg) {
  var s = document.createElement("script");
  s.src = "https://js.monitor.azure.com/scripts/b/ai.3.gbl.min.js";
  s.crossOrigin = "anonymous"; s.async = true;
  s.onload = function () {
    var ai = new window.Microsoft.ApplicationInsights.ApplicationInsights({ config: cfg });
    ai.loadAppInsights();
    ai.trackPageView();
  };
  document.head.appendChild(s);
})({
  connectionString: "@Cfg["APPLICATIONINSIGHTS_CONNECTION_STRING"]",
  enableAutoRouteTracking: true,
  enableCorsCorrelation: true,
  enableRequestHeaderTracking: true,
  enableResponseHeaderTracking: true,
  distributedTracingMode: 2 /* W3C */
});
</script>
```

### Exercise 2.4: Redeploy and observe

```bash
azd deploy web
```

Open `WEB_URI` and click around the search page. In the portal, open the App Insights resource → Live Metrics. You should see incoming requests within ~10 seconds.

## Verification Checkpoint

* [ ] Live Metrics shows non-zero RPS while you click around the web app.
* [ ] In Transaction Search, a `PageView` and a server-side `Request` share the same `operation_Id`.
* [ ] The Razor Pages logs (Application Insights → Logs → `traces`) include your structured log lines.
* [ ] No connection-string literal appears in `Program.cs` or any committed file.

## Next Steps

The web tier is fully instrumented. Continue with [Lab 03: API + SQL instrumentation](lab-03-instrument-api-sql) to add the Minimal API and EF Core spans that the web tier calls into.
