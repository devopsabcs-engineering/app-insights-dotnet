using Mapaq.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Mapaq.Infrastructure.Configurations;

internal sealed class InspectionRollupConfiguration : IEntityTypeConfiguration<InspectionRollup>
{
    public void Configure(EntityTypeBuilder<InspectionRollup> builder)
    {
        builder.ToTable("InspectionRollups");
        builder.HasKey(r => r.RollupId);

        builder.Property(r => r.Region).HasMaxLength(100).IsRequired();
        builder.Property(r => r.IndicatorCode).HasMaxLength(120).IsRequired();
        builder.Property(r => r.Value).HasColumnType("decimal(18,2)");

        builder.HasIndex(r => new { r.Region, r.Year, r.Month });

        var rows = SeedLoader.Load("inspections-cumulatif.csv");
        var seed = new List<InspectionRollup>();
        long syntheticId = 1;
        foreach (var row in rows)
        {
            seed.Add(new InspectionRollup
            {
                RollupId = syntheticId++,
                Region = row.GetValueOrDefault("Region") ?? string.Empty,
                Year = int.TryParse(row.GetValueOrDefault("Year"), out var y) ? y : 0,
                Month = int.TryParse(row.GetValueOrDefault("Month"), out var m) ? m : 0,
                IndicatorCode = row.GetValueOrDefault("IndicatorCode") ?? string.Empty,
                Value = SeedLoader.ParseDecimal(row.GetValueOrDefault("Value"))
            });
        }
        if (seed.Count > 0)
        {
            builder.HasData(seed);
        }
    }
}
