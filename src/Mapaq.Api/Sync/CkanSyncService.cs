using System.Diagnostics;
using System.Text.Json;
using Mapaq.Api.Telemetry;
using Mapaq.Domain;
using Mapaq.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace Mapaq.Api.Sync;

/// <summary>
/// Pulls a page of data from the Données Québec CKAN API and merges it into
/// the local SQL store. Each call writes a <see cref="SyncJob"/> row tagged
/// with the current <c>Activity.Current?.RootId</c> — the App Insights /
/// W3C trace id — so an operator can find the corresponding distributed
/// trace in the portal by joining on <c>operation_Id</c>.
/// </summary>
/// <remarks>
/// CKAN endpoint pattern:
/// <c>https://www.donneesquebec.ca/recherche/api/3/action/datastore_search?resource_id=…&amp;limit=1000&amp;offset=…</c>
/// </remarks>
public sealed class CkanSyncService
{
    // Condamnations dataset (verified live 2026-04-29).
    private const string ConvictionsResourceId = "40105615-3abf-414b-bcba-182e8f2c5eb2";

    private readonly HttpClient _http;
    private readonly MapaqDbContext _db;
    private readonly ILogger<CkanSyncService> _log;

    public CkanSyncService(HttpClient http, MapaqDbContext db, ILogger<CkanSyncService> log)
    {
        _http = http;
        _db = db;
        _log = log;
    }

    public async Task<SyncJobResult> RunAsync(CancellationToken ct)
    {
        var job = new SyncJob
        {
            StartedUtc = DateTime.UtcNow,
            Status = "Running",
            OperationId = Activity.Current?.RootId
        };
        _db.SyncJobs.Add(job);
        await _db.SaveChangesAsync(ct);

        try
        {
            var url = $"datastore_search?resource_id={ConvictionsResourceId}&limit=1000&offset=0";
            using var response = await _http.GetAsync(url, ct);
            response.EnsureSuccessStatusCode();

            await using var stream = await response.Content.ReadAsStreamAsync(ct);
            using var doc = await JsonDocument.ParseAsync(stream, cancellationToken: ct);

            var rowsRead = 0;
            var rowsUpserted = 0;
            if (doc.RootElement.TryGetProperty("result", out var result)
                && result.TryGetProperty("records", out var records)
                && records.ValueKind == JsonValueKind.Array)
            {
                rowsRead = records.GetArrayLength();
                // For the workshop the merge is intentionally a no-op against
                // EF Core (the seed CSV already populated the rows). The HTTP
                // dependency span is the point of this method — the App
                // Insights waterfall shows browser → API → CKAN + SQL.
                rowsUpserted = rowsRead;
            }

            job.RowsRead = rowsRead;
            job.RowsUpserted = rowsUpserted;
            job.Status = "Succeeded";
            job.CompletedUtc = DateTime.UtcNow;
            await _db.SaveChangesAsync(ct);

            return new SyncJobResult(job.SyncJobId, job.Status, job.RowsRead, job.RowsUpserted, job.OperationId);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "CKAN sync failed (OperationId={OperationId}).", job.OperationId);
            job.Status = "Failed";
            job.CompletedUtc = DateTime.UtcNow;
            await _db.SaveChangesAsync(CancellationToken.None);
            throw;
        }
    }

    public sealed record SyncJobResult(
        long SyncJobId,
        string Status,
        int RowsRead,
        int RowsUpserted,
        string? OperationId);
}
