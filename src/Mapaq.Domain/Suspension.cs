namespace Mapaq.Domain;

/// <summary>
/// A permit suspension applied to a food establishment.
/// Source: Données Québec — Suspensions de permis dataset.
/// </summary>
public sealed class Suspension
{
    public long SuspensionId { get; set; }

    public long EstablishmentId { get; set; }

    public DateOnly StartDate { get; set; }

    public DateOnly? EndDate { get; set; }

    public string Reason { get; set; } = string.Empty;

    public Establishment? Establishment { get; set; }
}
