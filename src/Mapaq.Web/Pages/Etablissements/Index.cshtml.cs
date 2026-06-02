using System.Diagnostics;
using Mapaq.Web.Telemetry;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Mapaq.Web.Pages.Etablissements;

public sealed class IndexModel : PageModel
{
    private readonly IHttpClientFactory _httpClientFactory;

    public IndexModel(IHttpClientFactory httpClientFactory)
    {
        _httpClientFactory = httpClientFactory;
    }

    [BindProperty(SupportsGet = true)]
    public string? City { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? Region { get; set; }

    public IReadOnlyList<EstablishmentRow> Results { get; private set; } = Array.Empty<EstablishmentRow>();

    public IReadOnlyList<string> AvailableRegions { get; } = new[]
    {
        "01-BAS-SAINT-LAURENT",
        "02-SAGUENAY-LAC-SAINT-JEAN",
        "03-CAPITALE-NATIONALE",
        "04-MAURICIE",
        "05-ESTRIE",
        "06-MONTREAL",
        "07-OUTAOUAIS",
        "08-ABITIBI-TEMISCAMINGUE",
        "09-COTE-NORD",
        "10-NORD-DU-QUEBEC",
        "11-GASPESIE-ILES-DE-LA-MADELEINE",
        "12-CHAUDIERE-APPALACHES",
        "13-LAVAL",
        "14-LANAUDIERE",
        "15-LAURENTIDES",
        "16-MONTEREGIE",
        "17-CENTRE-DU-QUEBEC"
    };

    public async Task OnGetAsync(CancellationToken ct)
    {
        const string page = "/Etablissements/Index";
        using var activity = WebTelemetry.Source.StartActivity("Page.Etablissements.Index");
        activity?.SetTag("mapaq.page", page);
        activity?.SetTag("mapaq.filter.city", City);
        activity?.SetTag("mapaq.filter.region", Region);
        WebTelemetry.PageViews.Add(1, new KeyValuePair<string, object?>("page", page));

        if (string.IsNullOrWhiteSpace(City) && string.IsNullOrWhiteSpace(Region))
        {
            activity?.SetTag("mapaq.search.issued", false);
            return;
        }

        WebTelemetry.Searches.Add(1, new KeyValuePair<string, object?>("page", page));
        activity?.SetTag("mapaq.search.issued", true);

        var client = _httpClientFactory.CreateClient("MapaqApi");
        var url = $"api/establishments?city={Uri.EscapeDataString(City ?? string.Empty)}"
                  + $"&region={Uri.EscapeDataString(Region ?? string.Empty)}";
        var sw = Stopwatch.StartNew();
        try
        {
            var rows = await client.GetFromJsonAsync<List<EstablishmentRow>>(url, ct);
            Results = rows ?? new List<EstablishmentRow>();
            activity?.SetTag("mapaq.result.count", Results.Count);
        }
        catch (Exception ex)
        {
            WebTelemetry.RecordApiError(activity, page, ex);
            Results = Array.Empty<EstablishmentRow>();
        }
        finally
        {
            WebTelemetry.ApiCallDurationMs.Record(sw.Elapsed.TotalMilliseconds,
                new KeyValuePair<string, object?>("page", page));
        }
    }

    public sealed record EstablishmentRow(
        long EstablishmentId,
        string Name,
        string Address,
        string City,
        string Region);
}
