using System.Diagnostics;
using OpenTelemetry;

namespace Mapaq.Api.Telemetry;

/// <summary>
/// Stamps every exported <see cref="Activity"/> (incoming requests, SQL and
/// HTTP dependencies, and custom <see cref="ApiTelemetry"/> spans alike) with
/// common dimensions so they are filterable in Application Insights
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
        activity.SetTag("mapaq.tier", "api");
    }
}
