using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace Mapaq.Web.Telemetry;

/// <summary>
/// Shared <see cref="ActivitySource"/> and <see cref="Meter"/> for the Mapaq.Web tier.
/// The source/meter names match the ones registered with the OpenTelemetry
/// TracerProvider/MeterProvider in <c>Program.cs</c> (<c>AddSource("Mapaq.Web")</c>
/// and <c>AddMeter("Mapaq.Web")</c>), so all activities and metrics flow to
/// Application Insights via the Azure Monitor Distro.
/// </summary>
internal static class WebTelemetry
{
    public const string SourceName = "Mapaq.Web";

    public static readonly ActivitySource Source = new(SourceName);
    public static readonly Meter Meter = new(SourceName);

    public static readonly Counter<long> PageViews =
        Meter.CreateCounter<long>("mapaq.web.page_views", description: "Razor Page handler invocations.");

    public static readonly Counter<long> Searches =
        Meter.CreateCounter<long>("mapaq.web.searches", description: "Establishment/rollup searches issued.");

    public static readonly Counter<long> ApiErrors =
        Meter.CreateCounter<long>("mapaq.web.api_errors", description: "Failures calling the Mapaq.Api backend.");

    public static readonly Histogram<double> ApiCallDurationMs =
        Meter.CreateHistogram<double>("mapaq.web.api_call_duration_ms", unit: "ms",
            description: "Duration of HTTP calls from Mapaq.Web to Mapaq.Api.");

    /// <summary>
    /// Records the exception on the current activity and increments the
    /// <see cref="ApiErrors"/> counter with the given page tag.
    /// </summary>
    public static void RecordApiError(Activity? activity, string page, Exception ex)
    {
        activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
        activity?.AddException(ex);
        ApiErrors.Add(1,
            new KeyValuePair<string, object?>("page", page),
            new KeyValuePair<string, object?>("exception.type", ex.GetType().FullName));
    }
}
