using System.Diagnostics;
using Mapaq.Web.Telemetry;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Mapaq.Web.Pages.Etablissements;

public sealed class DetailModel : PageModel
{
    private readonly IHttpClientFactory _httpClientFactory;

    public DetailModel(IHttpClientFactory httpClientFactory)
    {
        _httpClientFactory = httpClientFactory;
    }

    public EstablishmentDetail? Establishment { get; private set; }

    public async Task OnGetAsync(long id, CancellationToken ct)
    {
        const string page = "/Etablissements/Detail";
        using var activity = WebTelemetry.Source.StartActivity("Page.Etablissements.Detail");
        activity?.SetTag("mapaq.page", page);
        activity?.SetTag("mapaq.establishment.id", id);
        WebTelemetry.PageViews.Add(1, new KeyValuePair<string, object?>("page", page));

        var client = _httpClientFactory.CreateClient("MapaqApi");
        var sw = Stopwatch.StartNew();
        try
        {
            Establishment = await client.GetFromJsonAsync<EstablishmentDetail>(
                $"api/establishments/{id}", ct);
            activity?.SetTag("mapaq.result.found", Establishment is not null);
        }
        catch (HttpRequestException ex)
        {
            WebTelemetry.RecordApiError(activity, page, ex);
            Establishment = null;
        }
        catch (Exception ex)
        {
            WebTelemetry.RecordApiError(activity, page, ex);
            Establishment = null;
        }
        finally
        {
            WebTelemetry.ApiCallDurationMs.Record(sw.Elapsed.TotalMilliseconds,
                new KeyValuePair<string, object?>("page", page));
        }
    }

    public sealed record EstablishmentDetail(
        long EstablishmentId,
        string Name,
        string Address,
        string City,
        string Region,
        IReadOnlyList<ConvictionRow> Convictions);

    public sealed record ConvictionRow(
        DateOnly ConvictionDate,
        decimal AmountCad,
        string ArticleCode,
        string ArticleTitleFr,
        string ArticleTitleEn);
}
