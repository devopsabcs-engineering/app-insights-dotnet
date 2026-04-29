using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Mapaq.Web.Tests;

/// <summary>
/// Test-only factory that injects a placeholder Application Insights
/// connection string so the Azure Monitor Distro can build its exporter
/// pipeline without failing on a missing <c>APPLICATIONINSIGHTS_CONNECTION_STRING</c>
/// environment variable.
/// </summary>
public sealed class MapaqWebFactory : WebApplicationFactory<Program>
{
    private const string FakeConnectionString =
        "InstrumentationKey=00000000-0000-0000-0000-000000000000;"
        + "IngestionEndpoint=https://example.in.applicationinsights.azure.com/;"
        + "LiveEndpoint=https://example.livediagnostics.monitor.azure.com/";

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("ApplicationInsights:ConnectionString", FakeConnectionString);
        builder.UseSetting("AzureMonitor:ConnectionString", FakeConnectionString);
    }
}
