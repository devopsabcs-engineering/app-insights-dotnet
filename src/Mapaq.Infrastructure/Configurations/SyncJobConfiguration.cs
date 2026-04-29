using Mapaq.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Mapaq.Infrastructure.Configurations;

internal sealed class SyncJobConfiguration : IEntityTypeConfiguration<SyncJob>
{
    public void Configure(EntityTypeBuilder<SyncJob> builder)
    {
        builder.ToTable("SyncJobs");
        builder.HasKey(j => j.SyncJobId);

        builder.Property(j => j.Status).HasMaxLength(32).IsRequired();
        builder.Property(j => j.OperationId).HasMaxLength(64);

        builder.HasIndex(j => j.StartedUtc);
    }
}
