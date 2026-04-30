using System.Diagnostics;
using System.Diagnostics.Metrics;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using Mapaq.Api.Sync;
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

// Seed the demo dataset on startup. For SQL, EnsureCreated() creates tables
// if they don't exist (no migration required for the workshop scaffold).
// For in-memory, it works as before. MapaqDemoSeeder populates both paths.
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<MapaqDbContext>();
    if (db.Database.IsInMemory())
    {
        db.Database.EnsureCreated();
    }
    else
    {
        // Create tables from the model if they don't exist (idempotent).
        db.Database.EnsureCreated();
    }
    MapaqDemoSeeder.SeedIfEmpty(db);
}

app.UseCors("default");
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

var apiSource = new ActivitySource("Mapaq.Api");
var apiMeter  = new Meter("Mapaq.Api");
var queryCounter = apiMeter.CreateCounter<long>("mapaq.api.queries");

app.MapGet("/api/establishments", async (
    string? city,
    string? region,
    MapaqDbContext db,
    CancellationToken ct) =>
{
    using var activity = apiSource.StartActivity("SearchEstablishments");
    queryCounter.Add(1, new KeyValuePair<string, object?>("endpoint", "/api/establishments"));

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
    return Results.Ok(rows);
});

app.MapGet("/api/establishments/{id:long}", async (
    long id,
    MapaqDbContext db,
    CancellationToken ct) =>
{
    using var activity = apiSource.StartActivity("GetEstablishment");
    queryCounter.Add(1, new KeyValuePair<string, object?>("endpoint", "/api/establishments/{id}"));

    var e = await db.Establishments
        .AsNoTracking()
        .Include(x => x.Convictions)
        .FirstOrDefaultAsync(x => x.EstablishmentId == id, ct);
    if (e is null)
    {
        return Results.NotFound();
    }
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
});

app.MapGet("/api/inspections/rollup", async (
    string region,
    int year,
    MapaqDbContext db,
    CancellationToken ct) =>
{
    using var activity = apiSource.StartActivity("InspectionRollup");
    queryCounter.Add(1, new KeyValuePair<string, object?>("endpoint", "/api/inspections/rollup"));

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
    return Results.Ok(rows);
});

app.MapPost("/api/sync", async (CkanSyncService sync, CancellationToken ct) =>
{
    using var activity = apiSource.StartActivity("SyncFromDonneesQuebec");
    var result = await sync.RunAsync(ct);
    return Results.Ok(result);
});

app.Run();

/// <summary>
/// Exposed for <c>WebApplicationFactory&lt;Program&gt;</c> in tests.
/// </summary>
public partial class Program;
