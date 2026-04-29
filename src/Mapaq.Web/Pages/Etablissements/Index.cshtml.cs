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
