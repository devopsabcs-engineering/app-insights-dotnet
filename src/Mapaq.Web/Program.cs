using System.Globalization;
using System.Reflection;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using Mapaq.Web.Telemetry;
using Microsoft.AspNetCore.Localization;
using Microsoft.Extensions.Options;
using OpenTelemetry.Instrumentation.AspNetCore;
using OpenTelemetry.Instrumentation.Http;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;

var builder = WebApplication.CreateBuilder(args);

// ---- Resource attributes drive cloud_RoleName / cloud_RoleInstance ----
// service.version surfaces as application_Version in Application Insights;
// deployment.environment lets attendees split Dev/Prod telemetry.
// Prefer the full SemVer stamped by GitVersion into AssemblyInformationalVersion
// (e.g. 1.0.3); fall back to the assembly version, then a hard-coded default.
var serviceVersion  =
    typeof(Program).Assembly
        .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
        .InformationalVersion?.Split('+')[0]
    ?? typeof(Program).Assembly.GetName().Version?.ToString()
    ?? "1.0.0";
var environmentName = builder.Environment.EnvironmentName;

var resourceAttributes = new Dictionary<string, object>
{
    ["service.name"]           = "Mapaq.Web",
    ["service.namespace"]      = "Mapaq",
    ["service.version"]        = serviceVersion,
    ["service.instance.id"]    = Environment.MachineName,
    ["deployment.environment"] = environmentName
};

// ---- Azure Monitor OpenTelemetry Distro ----
// SamplingRatio = 1.0F and TracesPerSecond = null are intentional and
// REQUIRED for the workshop — Azure.Monitor.OpenTelemetry.AspNetCore
// 1.5.0-beta.1 changes the default sampler to RateLimitedSampler 5/sec,
// which would silently drop most of the traces attendees generate.
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

// ---- Enrich the vendored ASP.NET Core (incoming request) instrumentation ----
// Drop health-probe noise and decorate request spans with client detail.
builder.Services.Configure<AspNetCoreTraceInstrumentationOptions>(options =>
{
    options.RecordException = true;
    options.Filter = httpContext =>
        !httpContext.Request.Path.StartsWithSegments("/healthz");
    options.EnrichWithHttpRequest = (activity, request) =>
    {
        activity.SetTag("http.request.host", request.Host.Value);
        activity.SetTag("mapaq.client.ip", request.HttpContext.Connection.RemoteIpAddress?.ToString());
        activity.SetTag("mapaq.culture", CultureInfo.CurrentUICulture.Name);
    };
    options.EnrichWithHttpResponse = (activity, response) =>
        activity.SetTag("http.response.status_code", response.StatusCode);
    options.EnrichWithException = (activity, exception) =>
        activity.SetTag("exception.type", exception.GetType().FullName);
});

// ---- Enrich the vendored HttpClient (outbound dependency) instrumentation ----
// Makes the Web -> Mapaq.Api edge richer in the Application Map.
builder.Services.Configure<HttpClientTraceInstrumentationOptions>(options =>
{
    options.RecordException = true;
    options.EnrichWithHttpRequestMessage = (activity, request) =>
    {
        if (request.RequestUri is not null)
        {
            activity.SetTag("peer.service", request.RequestUri.Host);
            activity.SetTag("http.request.uri", request.RequestUri.AbsoluteUri);
        }
    };
    options.EnrichWithHttpResponseMessage = (activity, response) =>
        activity.SetTag("http.response.status_code", (int)response.StatusCode);
});

// Custom ActivitySource and Meter for the Web tier.
builder.Services.ConfigureOpenTelemetryTracerProvider((sp, b) => b
    .AddSource("Mapaq.Web")
    .AddProcessor(new TelemetryEnrichmentProcessor(environmentName, serviceVersion)));

// Explicit histogram buckets make the Web -> API latency distribution readable
// in Metrics Explorer instead of defaulting to a single bucket.
builder.Services.ConfigureOpenTelemetryMeterProvider((sp, b) => b
    .AddMeter("Mapaq.Web")
    .AddView("mapaq.web.api_call_duration_ms", new ExplicitBucketHistogramConfiguration
    {
        Boundaries = new double[] { 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000 }
    }));

// ---- Razor Pages + localization (FR primary, EN secondary) ----
// NOTE: ResourcesPath is intentionally NOT set. The SDK embeds
// `Resources/SharedResource.resx` as the manifest resource
// `Mapaq.Web.SharedResource.resources` (the SDK collapses the folder),
// so combined with marker type `Mapaq.Web.SharedResource` the
// ResourceManager finds the resources without an extra "Resources." prefix.
builder.Services.AddLocalization();
builder.Services.AddRazorPages()
    .AddViewLocalization()
    .AddDataAnnotationsLocalization();

builder.Services.Configure<RequestLocalizationOptions>(o =>
{
    var supported = new[] { new CultureInfo("fr-CA"), new CultureInfo("en-CA") };
    o.DefaultRequestCulture = new RequestCulture("fr-CA");
    o.SupportedCultures = supported;
    o.SupportedUICultures = supported;
});

// ---- Typed HttpClient that calls the API ----
builder.Services.AddHttpClient("MapaqApi", client =>
{
    client.BaseAddress = new Uri(
        builder.Configuration["MapaqApi:BaseAddress"] ?? "https://localhost:7020/");
});

// JS SDK Loader Script injection helper for _Layout.cshtml.
// We reference Microsoft.ApplicationInsights.AspNetCore solely for this
// helper class — AddApplicationInsightsTelemetry() is NOT called, so the
// classic SDK pipeline does not start. JavaScriptSnippet does, however,
// require an ApplicationInsightsServiceOptions, a TelemetryConfiguration,
// and an IHttpContextAccessor in DI to render the loader; we register the
// bare minimum below.
builder.Services.AddHttpContextAccessor();
builder.Services.Configure<Microsoft.ApplicationInsights.AspNetCore.Extensions.ApplicationInsightsServiceOptions>(o =>
{
    o.ConnectionString = builder.Configuration["ApplicationInsights:ConnectionString"]
                         ?? builder.Configuration["AzureMonitor:ConnectionString"];
});
builder.Services.AddSingleton(sp =>
{
    var tc = Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration.CreateDefault();
    var cs = builder.Configuration["ApplicationInsights:ConnectionString"]
             ?? builder.Configuration["AzureMonitor:ConnectionString"];
    if (!string.IsNullOrWhiteSpace(cs))
    {
        tc.ConnectionString = cs;
    }
    return tc;
});
builder.Services.AddSingleton<Microsoft.ApplicationInsights.AspNetCore.JavaScriptSnippet>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRequestLocalization(app.Services.GetRequiredService<IOptions<RequestLocalizationOptions>>().Value);
app.UseRouting();
app.UseAuthorization();

// Health check endpoint — responds instantly for App Service warmup/health probes.
app.MapGet("/healthz", () => Results.Ok("ok"));

// Language switcher endpoint: writes the AspNetCore.Culture cookie so
// CookieRequestCultureProvider picks it up on subsequent requests.
app.MapGet("/setlang", (string culture, string? returnUrl, HttpContext ctx) =>
{
    var supported = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "fr-CA", "en-CA" };
    if (!supported.Contains(culture))
    {
        culture = "fr-CA";
    }
    ctx.Response.Cookies.Append(
        Microsoft.AspNetCore.Localization.CookieRequestCultureProvider.DefaultCookieName,
        Microsoft.AspNetCore.Localization.CookieRequestCultureProvider.MakeCookieValue(
            new Microsoft.AspNetCore.Localization.RequestCulture(culture)),
        new CookieOptions
        {
            Expires = DateTimeOffset.UtcNow.AddYears(1),
            IsEssential = true,
            HttpOnly = false,
            SameSite = SameSiteMode.Lax
        });
    return Results.LocalRedirect(string.IsNullOrWhiteSpace(returnUrl) ? "~/" : returnUrl);
});

app.MapRazorPages();

app.Run();

/// <summary>
/// Exposed for <c>WebApplicationFactory&lt;Program&gt;</c> in tests.
/// </summary>
public partial class Program;
