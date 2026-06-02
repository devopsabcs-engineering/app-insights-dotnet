using System.Diagnostics;
using OpenTelemetry;

namespace Mapaq.Web.Telemetry;

/// <summary>
/// Stamps every exported <see cref="Activity"/> (incoming requests, the
/// outbound Mapaq.Api dependency, and custom <see cref="WebTelemetry"/> spans)
/// with common dimensions so they are filterable in Application Insights
/// Transaction Search / Logs without relying solely on resource attributes.
/// </summary>
internal sealed class TelemetryEnrichmentProcessor : BaseProcessor<Activity>
{
    private readonly string _environment;
    private readonly string _version;

    public TelemetryEnrichmentProcessor(string environment, string version)
    {
        _environment = environment;
        _version = version;
    }

    public override void OnEnd(Activity activity)
    {
        activity.SetTag("deployment.environment", _environment);
        activity.SetTag("service.version", _version);
        activity.SetTag("mapaq.tier", "web");
    }
}
