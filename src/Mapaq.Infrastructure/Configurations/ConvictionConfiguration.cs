using Mapaq.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Mapaq.Infrastructure.Configurations;

internal sealed class ConvictionConfiguration : IEntityTypeConfiguration<Conviction>
{
    public void Configure(EntityTypeBuilder<Conviction> builder)
    {
        builder.ToTable("Convictions");
        builder.HasKey(c => c.ConvictionId);

        builder.Property(c => c.AmountCad).HasColumnType("decimal(10,2)");
        builder.Property(c => c.ArticleCode).HasMaxLength(32).IsRequired();
        builder.Property(c => c.ArticleTitleFr).HasMaxLength(200).IsRequired();
        builder.Property(c => c.ArticleTitleEn).HasMaxLength(200).IsRequired();

        builder.HasOne(c => c.Establishment)
            .WithMany(e => e.Convictions)
            .HasForeignKey(c => c.EstablishmentId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(c => c.EstablishmentId);
        builder.HasIndex(c => c.ConvictionDate);

        var rows = SeedLoader.Load("condamnations.csv");
        var seed = new List<Conviction>();
        long syntheticId = 1;
        foreach (var row in rows)
        {
            if (!long.TryParse(row.GetValueOrDefault("EstablishmentId"), out var estId))
            {
                continue;
            }
            seed.Add(new Conviction
            {
                ConvictionId = syntheticId++,
                EstablishmentId = estId,
                ConvictionDate = SeedLoader.ParseDate(row.GetValueOrDefault("ConvictionDate")),
                AmountCad = SeedLoader.ParseDecimal(row.GetValueOrDefault("AmountCad")),
                ArticleCode = row.GetValueOrDefault("ArticleCode") ?? string.Empty,
                ArticleTitleFr = row.GetValueOrDefault("ArticleTitleFr") ?? string.Empty,
                ArticleTitleEn = row.GetValueOrDefault("ArticleTitleEn") ?? string.Empty
            });
        }
        if (seed.Count > 0)
        {
            builder.HasData(seed);
        }
    }
}
