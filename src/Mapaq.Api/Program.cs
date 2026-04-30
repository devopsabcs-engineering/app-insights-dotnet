using System.Diagnostics;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using Mapaq.Api.Sync;
using Mapaq.Api.Telemetry;
using Mapaq.Domain;
using Mapaq.Infrastructure;
using Microsoft.EntityFrameworkCore;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;

var builder = WebApplication.CreateBuilder(args);

var resourceAttributes = new Dictionary<string, object>
{
    ["service.name"]        = "Mapaq.Api",
    ["service.namespace"]   = "Mapaq",
    ["service.instance.id"] = Environment.MachineName
};

// Azure Monitor OpenTelemetry Distro.
// SamplingRatio = 1.0F + TracesPerSecond = null are required (forward-compat
// with the 1.5.0-beta.1 default-sampler change to RateLimitedSampler 5/sec).
builder.Services.AddOpenTelemetry()
    .UseAzureMonitor(options =>
    {
        options.ConnectionString =
            builder.Configuration["ApplicationInsights:ConnectionString"]
            ?? builder.Configuration["AzureMonitor:ConnectionString"];
        options.SamplingRatio               = 1.0F;
        options.TracesPerSecond             = null;
        options.EnableLiveMetrics           = true;
    })
    .ConfigureResource(rb => rb.AddAttributes(resourceAttributes));

builder.Services.ConfigureOpenTelemetryTracerProvider((sp, b) => b.AddSource("Mapaq.Api"));
builder.Services.ConfigureOpenTelemetryMeterProvider((sp, b) => b.AddMeter("Mapaq.Api"));

// EF Core; SQL spans flow automatically via the Distro-vendored
// SqlClient instrumentation (see Mapaq.Infrastructure / DD-02).
if (!string.IsNullOrWhiteSpace(builder.Configuration.GetConnectionString("MapaqSql")))
{
    builder.Services.AddMapaqInfrastructure(builder.Configuration);
}
else
{
    // Fallback for the workshop "smoke run" before SQL is provisioned:
    // an in-memory store keeps the API bootable so attendees can hit the
    // endpoints from Mapaq.Web without first wiring up a connection string.
    builder.Services.AddDbContext<MapaqDbContext>(opt => opt.UseInMemoryDatabase("MapaqInMemory"));
}

// CORS — DD-03: the browser SDK must be allowed to read traceparent /
// tracestate / Request-Context off the response, otherwise the
// browser → API edge breaks in the Application Map.
builder.Services.AddCors(o => o.AddPolicy("default", p => p
    .WithOrigins(builder.Configuration["WebOrigin"] ?? "https://localhost:7010")
    .AllowAnyHeader()
    .AllowAnyMethod()
    .WithExposedHeaders("traceparent", "tracestate", "Request-Context")));

builder.Services.AddOpenApi();

builder.Services.AddHttpClient<CkanSyncService>(client =>
{
    client.BaseAddress = new Uri(
        builder.Configuration["Ckan:BaseAddress"]
        ?? "https://www.donneesquebec.ca/recherche/api/3/action/");
});

var app = builder.Build();

// Seed the demo dataset on startup. For in-memory, seed synchronously.
// For SQL, seed via a background task so the app responds to health probes
// while waiting for the DB connection (private endpoint may need a moment).
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<MapaqDbContext>();
    if (db.Database.IsInMemory())
    {
        db.Database.EnsureCreated();
        MapaqDemoSeeder.SeedIfEmpty(db);
    }
}

// Background DB initializer for SQL — non-blocking so the container passes
// the App Service warmup probe within the 230-second timeout.
if (!string.IsNullOrWhiteSpace(builder.Configuration.GetConnectionString("MapaqSql")))
{
    _ = Task.Run(async () =>
    {
        using var scope = app.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<MapaqDbContext>();
        var logger = scope.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger("DbInit");
        for (var attempt = 1; attempt <= 5; attempt++)
        {
            try
            {
                logger.LogInformation("DB init attempt {Attempt}: EnsureCreated + seed", attempt);
                await db.Database.EnsureCreatedAsync();
                MapaqDemoSeeder.SeedIfEmpty(db);
                logger.LogInformation("DB init succeeded on attempt {Attempt}", attempt);
                return;
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "DB init attempt {Attempt} failed, retrying in 10s", attempt);
                await Task.Delay(TimeSpan.FromSeconds(10));
            }
        }
        logger.LogError("DB init failed after 5 attempts — data will be empty until next restart");
    });
}

app.UseCors("default");

// Health check endpoint — responds instantly for App Service warmup/health probes.
app.MapGet("/healthz", () => Results.Ok("ok")).ExcludeFromDescription();

app.MapOpenApi();

// Swagger UI served at /swagger, consuming the .NET 10 OpenApi document at
// /openapi/v1.json that MapOpenApi() produces above. Browsable demo of all
// 4 endpoints + a "Try it out" button suitable for the workshop.
app.UseSwaggerUI(o =>
{
    o.SwaggerEndpoint("/openapi/v1.json", "Mapaq.Api v1");
    o.RoutePrefix = "swagger";
    o.DocumentTitle = "Mapaq.Api — Swagger UI";
});

// All endpoints below use ApiTelemetry.Source/Meter so spans, custom metrics,
// and exceptions are captured uniformly and surfaced in Application Insights
// via the Azure Monitor OpenTelemetry Distro registered above.

app.MapGet("/api/establishments", async (
    string? city,
    string? region,
    MapaqDbContext db,
    CancellationToken ct) =>
{
    const string endpoint = "/api/establishments";
    using var activity = ApiTelemetry.Source.StartActivity("SearchEstablishments", ActivityKind.Server);
    activity?.SetTag("mapaq.endpoint", endpoint);
    activity?.SetTag("mapaq.filter.city", city);
    activity?.SetTag("mapaq.filter.region", region);
    ApiTelemetry.Queries.Add(1, new KeyValuePair<string, object?>("endpoint", endpoint));
    var sw = Stopwatch.StartNew();
    try
    {
        var query = db.Establishments.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(city))
        {
            query = query.Where(e => e.City == city);
        }
        if (!string.IsNullOrWhiteSpace(region))
        {
            query = query.Where(e => e.Region == region);
        }
        var rows = await query
            .OrderBy(e => e.Name)
            .Take(50)
            .Select(e => new
            {
                e.EstablishmentId,
                e.Name,
                e.Address,
                e.City,
                e.Region
            })
            .ToListAsync(ct);
        activity?.SetTag("mapaq.result.count", rows.Count);
        ApiTelemetry.ResultRows.Add(rows.Count, new KeyValuePair<string, object?>("endpoint", endpoint));
        return Results.Ok(rows);
    }
    catch (Exception ex)
    {
        ApiTelemetry.RecordError(activity, endpoint, ex);
        throw;
    }
    finally
    {
        ApiTelemetry.EndpointDurationMs.Record(sw.Elapsed.TotalMilliseconds,
            new KeyValuePair<string, object?>("endpoint", endpoint));
    }
});

app.MapGet("/api/establishments/{id:long}", async (
    long id,
    MapaqDbContext db,
    CancellationToken ct) =>
{
    const string endpoint = "/api/establishments/{id}";
    using var activity = ApiTelemetry.Source.StartActivity("GetEstablishment", ActivityKind.Server);
    activity?.SetTag("mapaq.endpoint", endpoint);
    activity?.SetTag("mapaq.establishment.id", id);
    ApiTelemetry.Queries.Add(1, new KeyValuePair<string, object?>("endpoint", endpoint));
    var sw = Stopwatch.StartNew();
    try
    {
        var e = await db.Establishments
            .AsNoTracking()
            .Include(x => x.Convictions)
            .FirstOrDefaultAsync(x => x.EstablishmentId == id, ct);
        if (e is null)
        {
            activity?.SetTag("mapaq.result.found", false);
            return Results.NotFound();
        }
        activity?.SetTag("mapaq.result.found", true);
        activity?.SetTag("mapaq.result.convictions", e.Convictions.Count);
        return Results.Ok(new
        {
            e.EstablishmentId,
            e.Name,
            e.Address,
            e.City,
            e.Region,
            Convictions = e.Convictions
                .OrderByDescending(c => c.ConvictionDate)
                .Select(c => new
                {
                    c.ConvictionDate,
                    c.AmountCad,
                    c.ArticleCode,
                    c.ArticleTitleFr,
                    c.ArticleTitleEn
                })
        });
    }
    catch (Exception ex)
    {
        ApiTelemetry.RecordError(activity, endpoint, ex);
        throw;
    }
    finally
    {
        ApiTelemetry.EndpointDurationMs.Record(sw.Elapsed.TotalMilliseconds,
            new KeyValuePair<string, object?>("endpoint", endpoint));
    }
});

app.MapGet("/api/inspections/rollup", async (
    string region,
    int year,
    MapaqDbContext db,
    CancellationToken ct) =>
{
    const string endpoint = "/api/inspections/rollup";
    using var activity = ApiTelemetry.Source.StartActivity("InspectionRollup", ActivityKind.Server);
    activity?.SetTag("mapaq.endpoint", endpoint);
    activity?.SetTag("mapaq.filter.region", region);
    activity?.SetTag("mapaq.filter.year", year);
    ApiTelemetry.Queries.Add(1, new KeyValuePair<string, object?>("endpoint", endpoint));
    var sw = Stopwatch.StartNew();
    try
    {
        var rows = await db.InspectionRollups
            .AsNoTracking()
            .Where(r => r.Region == region && r.Year == year)
            .OrderBy(r => r.Month).ThenBy(r => r.IndicatorCode)
            .Select(r => new
            {
                r.Region,
                r.Year,
                r.Month,
                r.IndicatorCode,
                r.Value
            })
            .ToListAsync(ct);
        activity?.SetTag("mapaq.result.count", rows.Count);
        ApiTelemetry.ResultRows.Add(rows.Count, new KeyValuePair<string, object?>("endpoint", endpoint));
        return Results.Ok(rows);
    }
    catch (Exception ex)
    {
        ApiTelemetry.RecordError(activity, endpoint, ex);
        throw;
    }
    finally
    {
        ApiTelemetry.EndpointDurationMs.Record(sw.Elapsed.TotalMilliseconds,
            new KeyValuePair<string, object?>("endpoint", endpoint));
    }
});

app.MapPost("/api/sync", async (CkanSyncService sync, CancellationToken ct) =>
{
    const string endpoint = "/api/sync";
    using var activity = ApiTelemetry.Source.StartActivity("SyncFromDonneesQuebec", ActivityKind.Server);
    activity?.SetTag("mapaq.endpoint", endpoint);
    ApiTelemetry.Queries.Add(1, new KeyValuePair<string, object?>("endpoint", endpoint));
    var sw = Stopwatch.StartNew();
    try
    {
        var result = await sync.RunAsync(ct);
        activity?.SetTag("mapaq.sync.status", result.Status);
        activity?.SetTag("mapaq.sync.rows_read", result.RowsRead);
        activity?.SetTag("mapaq.sync.rows_upserted", result.RowsUpserted);
        return Results.Ok(result);
    }
    catch (Exception ex)
    {
        ApiTelemetry.RecordError(activity, endpoint, ex);
        throw;
    }
    finally
    {
        ApiTelemetry.EndpointDurationMs.Record(sw.Elapsed.TotalMilliseconds,
            new KeyValuePair<string, object?>("endpoint", endpoint));
    }
});

app.Run();

/// <summary>
/// Exposed for <c>WebApplicationFactory&lt;Program&gt;</c> in tests.
/// </summary>
public partial class Program;
