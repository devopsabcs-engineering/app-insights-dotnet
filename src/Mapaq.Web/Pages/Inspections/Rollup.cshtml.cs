using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Mapaq.Web.Pages.Inspections;

public sealed class RollupModel : PageModel
{
    private readonly IHttpClientFactory _httpClientFactory;

    public RollupModel(IHttpClientFactory httpClientFactory)
    {
        _httpClientFactory = httpClientFactory;
    }

    [BindProperty(SupportsGet = true)]
    public string Region { get; set; } = "03-CAPITALE-NATIONALE";

    [BindProperty(SupportsGet = true)]
    public int Year { get; set; } = DateTime.UtcNow.Year - 1;

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

    public IReadOnlyList<int> AvailableYears { get; } = Enumerable
        .Range(DateTime.UtcNow.Year - 5, 6)
        .ToArray();

    public IReadOnlyList<RollupRow> Rows { get; private set; } = Array.Empty<RollupRow>();

    public async Task OnGetAsync(CancellationToken ct)
    {
        var client = _httpClientFactory.CreateClient("MapaqApi");
        var url = $"api/inspections/rollup?region={Uri.EscapeDataString(Region)}&year={Year}";
        try
        {
            var rows = await client.GetFromJsonAsync<List<RollupRow>>(url, ct);
            Rows = rows ?? new List<RollupRow>();
        }
        catch (HttpRequestException)
        {
            Rows = Array.Empty<RollupRow>();
        }
    }

    public sealed record RollupRow(
        string Region,
        int Year,
        int Month,
        string IndicatorCode,
        decimal Value);
}
