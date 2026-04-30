using Mapaq.Web.Telemetry;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Mapaq.Web.Pages;

public sealed class IndexModel : PageModel
{
    public void OnGet()
    {
        using var activity = WebTelemetry.Source.StartActivity("Page.Home.OnGet");
        WebTelemetry.PageViews.Add(1, new KeyValuePair<string, object?>("page", "/Index"));
    }
}
