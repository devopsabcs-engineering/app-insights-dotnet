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
        if (string.IsNullOrWhiteSpace(City) && string.IsNullOrWhiteSpace(Region))
        {
            return;
        }

        var client = _httpClientFactory.CreateClient("MapaqApi");
        var url = $"api/establishments?city={Uri.EscapeDataString(City ?? string.Empty)}"
                  + $"&region={Uri.EscapeDataString(Region ?? string.Empty)}";
        try
        {
            var rows = await client.GetFromJsonAsync<List<EstablishmentRow>>(url, ct);
            Results = rows ?? new List<EstablishmentRow>();
        }
        catch (HttpRequestException)
        {
            Results = Array.Empty<EstablishmentRow>();
        }
    }

    public sealed record EstablishmentRow(
        long EstablishmentId,
        string Name,
        string Address,
        string City,
        string Region);
}
