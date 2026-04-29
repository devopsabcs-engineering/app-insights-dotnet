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
        var client = _httpClientFactory.CreateClient("MapaqApi");
        try
        {
            Establishment = await client.GetFromJsonAsync<EstablishmentDetail>(
                $"api/establishments/{id}", ct);
        }
        catch (HttpRequestException)
        {
            Establishment = null;
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
