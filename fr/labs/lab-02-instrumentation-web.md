---
layout: default
lang: fr
nav_exclude: true
title: "Atelier 02 : Instrumentation de la couche web"
nav_order: 2
permalink: /fr/labs/lab-02-instrumentation-web
description: "Brancher la distribution Application Insights .NET dans l'application Razor Pages et ajouter le SDK JavaScript dans _Layout.cshtml."
---

# Atelier 02 : Instrumentation de la couche web

> **Durée : 20 min** — Distribution côté serveur dans `Program.cs`, SDK navigateur dans `_Layout.cshtml`.

À la fin de cet atelier, la couche Razor Pages produira de la télémétrie de requêtes, dépendances et traces côté serveur, ainsi que de la télémétrie de PageView et de dépendances AJAX depuis le navigateur, le tout estampillé du même `operation_Id` afin que l'Atelier 04 puisse coudre la trace de bout en bout.

## Objectifs d'apprentissage

À la fin de cet atelier, vous serez en mesure de :

* Ajouter la distribution `Azure.Monitor.OpenTelemetry.AspNetCore` au projet web et l'enregistrer dans `Program.cs`.
* Lier la chaîne de connexion depuis Key Vault via `IConfiguration` plutôt que de la valider dans le code source.
* Injecter le SDK JavaScript Application Insights dans `_Layout.cshtml` afin que les sessions du navigateur soient corrélées aux requêtes serveur.
* Vérifier dans Live Metrics que les requêtes apparaissent en quelques secondes après le redéploiement.

La distribution .NET d'Application Insights est désormais bâtie sur OpenTelemetry ; vous n'avez pas besoin du paquet hérité `Microsoft.ApplicationInsights.AspNetCore`. La distribution enregistre les exportateurs de traçage, métriques et journalisation en un seul appel.

## Exercices

### Exercice 2.1 : Ajouter le paquet de distribution

```bash
dotnet add src/web package Azure.Monitor.OpenTelemetry.AspNetCore
```

### Exercice 2.2 : Enregistrer la distribution dans `Program.cs`

```csharp
using Azure.Monitor.OpenTelemetry.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// Liée depuis Key Vault → IConfiguration via le déploiement Bicep.
builder.Services.AddOpenTelemetry().UseAzureMonitor(o =>
{
    o.ConnectionString =
        builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
});

// ... enregistrements Razor Pages existants ...
```

### Exercice 2.3 : Injecter le SDK JS dans `_Layout.cshtml`

Ajoutez l'extrait suivant à l'intérieur de la balise `<head>` dans `Pages/Shared/_Layout.cshtml`. La chaîne de connexion est rendue côté serveur depuis `IConfiguration` afin que la même valeur Key Vault alimente les deux couches.

```html
@inject Microsoft.Extensions.Configuration.IConfiguration Cfg
<script type="text/javascript">
!(function (cfg) {
  var s = document.createElement("script");
  s.src = "https://js.monitor.azure.com/scripts/b/ai.3.gbl.min.js";
  s.crossOrigin = "anonymous"; s.async = true;
  s.onload = function () {
    var ai = new window.Microsoft.ApplicationInsights.ApplicationInsights({ config: cfg });
    ai.loadAppInsights();
    ai.trackPageView();
  };
  document.head.appendChild(s);
})({
  connectionString: "@Cfg["APPLICATIONINSIGHTS_CONNECTION_STRING"]",
  enableAutoRouteTracking: true,
  enableCorsCorrelation: true,
  enableRequestHeaderTracking: true,
  enableResponseHeaderTracking: true,
  distributedTracingMode: 2 /* W3C */
});
</script>
```

### Exercice 2.4 : Redéployer et observer

```bash
azd deploy web
```

Ouvrez `WEB_URI` et cliquez sur la page de recherche. Dans le portail, ouvrez la ressource App Insights → Live Metrics. Vous devriez voir les requêtes entrantes en environ 10 secondes.

## Point de vérification

* [ ] Live Metrics affiche un RPS non nul pendant que vous cliquez dans l'application web.
* [ ] Dans Transaction Search, un `PageView` et une `Request` côté serveur partagent le même `operation_Id`.
* [ ] Les journaux Razor Pages (Application Insights → Logs → `traces`) incluent vos lignes de journalisation structurées.
* [ ] Aucune chaîne de connexion littérale n'apparaît dans `Program.cs` ni dans aucun fichier validé.

## Étapes suivantes

La couche web est entièrement instrumentée. Continuez avec [Atelier 03 : Instrumentation API + SQL](lab-03-instrumentation-api-sql) pour ajouter les segments de l'API minimale et d'EF Core que la couche web appelle.
