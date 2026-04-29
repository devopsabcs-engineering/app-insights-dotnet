namespace Mapaq.Domain;

/// <summary>
/// A licensed food establishment in Quebec.
/// Source: Données Québec — Suspensions de permis dataset (column dictionary).
/// </summary>
public sealed class Establishment
{
    public long EstablishmentId { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Address { get; set; } = string.Empty;

    public string City { get; set; } = string.Empty;

    public string PostalCode { get; set; } = string.Empty;

    public string Region { get; set; } = string.Empty;

    public string PermitType { get; set; } = string.Empty;

    public ICollection<Conviction> Convictions { get; set; } = new List<Conviction>();

    public ICollection<Suspension> Suspensions { get; set; } = new List<Suspension>();
}
