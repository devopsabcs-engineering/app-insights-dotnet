namespace Mapaq.Domain;

/// <summary>
/// A conviction issued against a food establishment.
/// Source: Données Québec — Condamnations dataset.
/// </summary>
public sealed class Conviction
{
    public long ConvictionId { get; set; }

    public long EstablishmentId { get; set; }

    public DateOnly ConvictionDate { get; set; }

    public decimal AmountCad { get; set; }

    public string ArticleCode { get; set; } = string.Empty;

    public string ArticleTitleFr { get; set; } = string.Empty;

    public string ArticleTitleEn { get; set; } = string.Empty;

    public Establishment? Establishment { get; set; }
}
