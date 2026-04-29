namespace Mapaq.Domain;

/// <summary>
/// Pre-aggregated inspection counts powering the regional dashboard
/// (« Tableau de bord régional »).
/// Source: Données Québec — Rapport cumulatif inspections dataset.
/// </summary>
public sealed class InspectionRollup
{
    public long RollupId { get; set; }

    public string Region { get; set; } = string.Empty;

    public int Year { get; set; }

    public int Month { get; set; }

    public string IndicatorCode { get; set; } = string.Empty;

    public decimal Value { get; set; }
}
