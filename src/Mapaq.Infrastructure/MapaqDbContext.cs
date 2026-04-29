using Mapaq.Domain;
using Microsoft.EntityFrameworkCore;

namespace Mapaq.Infrastructure;

/// <summary>
/// EF Core <see cref="DbContext"/> for the MAPAQ workshop demo.
/// Spans for <see cref="Microsoft.Data.SqlClient.SqlConnection"/> flow into
/// Application Insights automatically thanks to the SQL Client instrumentation
/// vendored by <c>Azure.Monitor.OpenTelemetry.AspNetCore</c>; no extra OTel
/// registration is required here.
/// </summary>
public sealed class MapaqDbContext : DbContext
{
    public MapaqDbContext(DbContextOptions<MapaqDbContext> options)
        : base(options)
    {
    }

    public DbSet<Establishment> Establishments => Set<Establishment>();

    public DbSet<Conviction> Convictions => Set<Conviction>();

    public DbSet<Suspension> Suspensions => Set<Suspension>();

    public DbSet<InspectionRollup> InspectionRollups => Set<InspectionRollup>();

    public DbSet<SyncJob> SyncJobs => Set<SyncJob>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(MapaqDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }
}
