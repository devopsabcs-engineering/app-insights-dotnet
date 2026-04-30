using System.Globalization;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using Microsoft.AspNetCore.Localization;
using Microsoft.Extensions.Options;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;

var builder = WebApplication.CreateBuilder(args);

// ---- Resource attributes drive cloud_RoleName / cloud_RoleInstance ----
var resourceAttributes = new Dictionary<string, object>
{
    ["service.name"]        = "Mapaq.Web",
    ["service.namespace"]   = "Mapaq",
    ["service.instance.id"] = Environment.MachineName
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

// Custom ActivitySource and Meter for the Web tier.
builder.Services.ConfigureOpenTelemetryTracerProvider((sp, b) => b.AddSource("Mapaq.Web"));
builder.Services.ConfigureOpenTelemetryMeterProvider((sp, b) => b.AddMeter("Mapaq.Web"));

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
