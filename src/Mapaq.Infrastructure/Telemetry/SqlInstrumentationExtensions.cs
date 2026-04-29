using Microsoft.Extensions.DependencyInjection;

namespace Mapaq.Infrastructure.Telemetry;

/// <summary>
/// <para>
/// <b>Important — discrepancy DD-02 (do not standalone-register
/// <c>OpenTelemetry.Instrumentation.SqlClient</c>).</b>
/// </para>
/// <para>
/// The <c>Azure.Monitor.OpenTelemetry.AspNetCore</c> Distro vendors the SQL
/// Client instrumentation internally. The Distro README explicitly warns:
/// <i>"If an app references the OpenTelemetry.Instrumentation.SqlClient
/// package, it might be missing dependency telemetry. Remove the package
/// reference (or) add <c>AddSqlClientInstrumentation</c> to the
/// <c>TracerProvider</c> configuration."</i>
/// </para>
/// <para>
/// In other words: adding the standalone package <i>shadows</i> the
/// vendored copy and silently breaks SQL dependency capture unless you
/// also call <c>AddSqlClientInstrumentation()</c> yourself. We deliberately
/// do neither — the workshop relies on the vendored copy so the
/// "happy path" works with zero extra OTel calls. Any opt-in override
/// belongs in <see cref="AddOptionalSqlClientOverride"/> below and the
/// caller must understand the trade-off.
/// </para>
/// </summary>
public static class SqlInstrumentationExtensions
{
    /// <summary>
    /// <b>Documentation-only.</b> This method is intentionally a no-op.
    /// </summary>
    /// <remarks>
    /// To enable a custom SQL Client instrumentation override (for example
    /// to record <c>SqlException</c> details or set
    /// <c>SetDbStatementForStoredProcedure</c>), uncomment the body below
    /// AND add a <c>&lt;PackageReference Include="OpenTelemetry.Instrumentation.SqlClient" /&gt;</c>
    /// to <c>Mapaq.Infrastructure.csproj</c>. Doing so replaces the
    /// vendored instrumentation; you become responsible for keeping it
    /// aligned with future Distro releases.
    /// </remarks>
    public static IServiceCollection AddOptionalSqlClientOverride(this IServiceCollection services)
    {
        // Intentionally no-op. See remarks for how to enable.
        //
        // services.ConfigureOpenTelemetryTracerProvider((sp, b) => b
        //     .AddSqlClientInstrumentation(o =>
        //     {
        //         o.RecordException = true;
        //         o.SetDbStatementForStoredProcedure = true;
        //     }));
        return services;
    }
}
