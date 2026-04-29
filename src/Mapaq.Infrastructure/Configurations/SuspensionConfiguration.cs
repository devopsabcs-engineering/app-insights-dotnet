using Mapaq.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Mapaq.Infrastructure.Configurations;

internal sealed class SuspensionConfiguration : IEntityTypeConfiguration<Suspension>
{
    public void Configure(EntityTypeBuilder<Suspension> builder)
    {
        builder.ToTable("Suspensions");
        builder.HasKey(s => s.SuspensionId);

        builder.Property(s => s.Reason).HasMaxLength(500).IsRequired();

        builder.HasOne(s => s.Establishment)
            .WithMany(e => e.Suspensions)
            .HasForeignKey(s => s.EstablishmentId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(s => s.EstablishmentId);
        builder.HasIndex(s => s.StartDate);
    }
}
