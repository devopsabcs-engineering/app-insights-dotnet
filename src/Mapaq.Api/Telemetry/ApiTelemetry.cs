using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace Mapaq.Api.Telemetry;

/// <summary>
/// Shared <see cref="ActivitySource"/> and <see cref="Meter"/> for the Mapaq.Api tier.
/// The names match the ones registered with the TracerProvider/MeterProvider
/// in <c>Program.cs</c> (<c>AddSource("Mapaq.Api")</c> + <c>AddMeter("Mapaq.Api")</c>).
/// </summary>
internal static class ApiTelemetry
{
    public const string SourceName = "Mapaq.Api";

    public static readonly ActivitySource Source = new(SourceName);
    public static readonly Meter Meter = new(SourceName);

    public static readonly Counter<long> Queries =
        Meter.CreateCounter<long>("mapaq.api.queries", description: "API endpoint invocations.");

    public static readonly Counter<long> Errors =
        Meter.CreateCounter<long>("mapaq.api.errors", description: "API endpoint failures.");

    public static readonly Counter<long> ResultRows =
        Meter.CreateCounter<long>("mapaq.api.result_rows", description: "Rows returned by API endpoints.");

    public static readonly Histogram<double> EndpointDurationMs =
        Meter.CreateHistogram<double>("mapaq.api.endpoint_duration_ms", unit: "ms",
            description: "Server-side duration of API endpoint handlers.");

    /// <summary>
    /// Records the exception on the current activity and increments the
    /// <see cref="Errors"/> counter tagged with the endpoint name.
    /// </summary>
    public static void RecordError(Activity? activity, string endpoint, Exception ex)
    {
        activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
        activity?.AddException(ex);
        Errors.Add(1,
            new KeyValuePair<string, object?>("endpoint", endpoint),
            new KeyValuePair<string, object?>("exception.type", ex.GetType().FullName));
    }
}
