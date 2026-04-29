using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Mapaq.Infrastructure;

/// <summary>
/// Composition-root extensions for the Infrastructure project.
/// </summary>
public static class MapaqInfrastructureExtensions
{
    /// <summary>
    /// Registers <see cref="MapaqDbContext"/> against Azure SQL using the
    /// <c>MapaqSql</c> connection string. SqlClient spans are captured
    /// automatically by the vendored instrumentation inside
    /// <c>Azure.Monitor.OpenTelemetry.AspNetCore</c> — no extra OTel call is
    /// needed.
    /// </summary>
    public static IServiceCollection AddMapaqInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddDbContext<MapaqDbContext>(opt =>
            opt.UseSqlServer(configuration.GetConnectionString("MapaqSql")));
        return services;
    }
}
