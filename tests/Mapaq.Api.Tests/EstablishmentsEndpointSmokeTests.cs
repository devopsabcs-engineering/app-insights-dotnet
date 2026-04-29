using System.Net;
using System.Net.Http.Headers;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Mapaq.Api.Tests;

public sealed class EstablishmentsEndpointSmokeTests : IClassFixture<MapaqApiFactory>
{
    private readonly MapaqApiFactory _factory;

    public EstablishmentsEndpointSmokeTests(MapaqApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Establishments_returns_200_json()
    {
        var client = _factory.CreateClient();

        using var response = await client.GetAsync("/api/establishments");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);
    }
}
