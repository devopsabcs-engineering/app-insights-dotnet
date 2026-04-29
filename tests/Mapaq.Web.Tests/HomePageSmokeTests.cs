using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Mapaq.Web.Tests;

public sealed class HomePageSmokeTests : IClassFixture<MapaqWebFactory>
{
    private readonly MapaqWebFactory _factory;

    public HomePageSmokeTests(MapaqWebFactory factory)
    {
        _factory = factory;
    }

    [Theory]
    [InlineData("fr-CA")]
    [InlineData("en-CA")]
    public async Task Home_returns_200(string culture)
    {
        var client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });
        client.DefaultRequestHeaders.AcceptLanguage.ParseAdd(culture);

        using var response = await client.GetAsync("/");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
