namespace Mapaq.Domain;

/// <summary>
/// Audit row written by <c>POST /api/sync</c> after each Données Québec sync.
/// <see cref="OperationId"/> stores the App Insights / W3C trace id so an operator
/// can correlate the row with the distributed trace in the portal.
/// </summary>
public sealed class SyncJob
{
    public long SyncJobId { get; set; }

    public DateTime StartedUtc { get; set; }

    public DateTime? CompletedUtc { get; set; }

    public string Status { get; set; } = "Running";

    public int RowsRead { get; set; }

    public int RowsUpserted { get; set; }

    public string? OperationId { get; set; }
}
