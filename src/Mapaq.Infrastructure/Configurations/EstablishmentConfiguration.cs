using Mapaq.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Mapaq.Infrastructure.Configurations;

internal sealed class EstablishmentConfiguration : IEntityTypeConfiguration<Establishment>
{
    public void Configure(EntityTypeBuilder<Establishment> builder)
    {
        builder.ToTable("Establishments");
        builder.HasKey(e => e.EstablishmentId);

        builder.Property(e => e.Name).HasMaxLength(200).IsRequired();
        builder.Property(e => e.Address).HasMaxLength(300).IsRequired();
        builder.Property(e => e.City).HasMaxLength(100).IsRequired();
        builder.Property(e => e.PostalCode).HasMaxLength(10).IsRequired();
        builder.Property(e => e.Region).HasMaxLength(100).IsRequired();
        builder.Property(e => e.PermitType).HasMaxLength(100).IsRequired();

        // Indexes for the search endpoint (GET /api/establishments?city=&region=)
        builder.HasIndex(e => e.City);
        builder.HasIndex(e => e.Region);

        var rows = SeedLoader.Load("condamnations.csv");
        var seen = new HashSet<long>();
        var seed = new List<Establishment>();
        foreach (var row in rows)
        {
            if (!long.TryParse(row.GetValueOrDefault("EstablishmentId"), out var id) || !seen.Add(id))
            {
                continue;
            }
            seed.Add(new Establishment
            {
                EstablishmentId = id,
                Name = row.GetValueOrDefault("Name") ?? string.Empty,
                Address = row.GetValueOrDefault("Address") ?? string.Empty,
                City = row.GetValueOrDefault("City") ?? string.Empty,
                PostalCode = row.GetValueOrDefault("PostalCode") ?? "H0H0H0",
                Region = row.GetValueOrDefault("Region") ?? string.Empty,
                PermitType = row.GetValueOrDefault("PermitType") ?? "RESTAURANT"
            });
        }
        if (seed.Count > 0)
        {
            builder.HasData(seed);
        }
    }
}
