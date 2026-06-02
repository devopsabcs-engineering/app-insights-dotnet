# syntax=docker/dockerfile:1
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Semantic version supplied by CI/CD (GitVersion). Defaults to 1.0.0 for plain
# `docker build` so local image builds still succeed without the build arg.
ARG VERSION=1.0.0

# Central Package Management + shared build props must be present before restore.
COPY Directory.Build.props Directory.Packages.props global.json ./
COPY src/Mapaq.Api/Mapaq.Api.csproj                 src/Mapaq.Api/
COPY src/Mapaq.Domain/Mapaq.Domain.csproj           src/Mapaq.Domain/
COPY src/Mapaq.Infrastructure/Mapaq.Infrastructure.csproj src/Mapaq.Infrastructure/
RUN dotnet restore src/Mapaq.Api/Mapaq.Api.csproj

COPY src/ src/
RUN dotnet publish src/Mapaq.Api/Mapaq.Api.csproj \
    -c Release -o /app --no-restore \
    -p:Version="${VERSION}" -p:InformationalVersion="${VERSION}"

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
ARG VERSION=1.0.0
# Standard OCI label so the running image is traceable back to its SemVer.
LABEL org.opencontainers.image.version="${VERSION}"
# Also expose it to the process (handy for /healthz, logs, banners).
ENV APP_VERSION="${VERSION}"
WORKDIR /app
# aspnet:8.0+ already runs as non-root 'app' and defaults ASPNETCORE_HTTP_PORTS=8080.
EXPOSE 8080
COPY --from=build /app .
ENTRYPOINT ["dotnet", "Mapaq.Api.dll"]
