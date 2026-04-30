---
layout: default
lang: fr
nav_exclude: true
parent: "Ateliers"
title: "Atelier 03 : Instrumentation API + SQL"
nav_order: 3
permalink: /fr/labs/lab-03-instrumentation-api-sql
description: "Ajouter la distribution Application Insights à la couche API minimale, capturer les segments SQL EF Core et exposer les en-têtes de corrélation CORS."
---

# Atelier 03 : Instrumentation API + SQL

> **Durée : 20 min** — Distribution côté serveur sur l'API, capture des dépendances EF Core, en-têtes CORS exposés pour la corrélation navigateur.

La couche web de l'Atelier 02 appelle une API minimale qui lit les données du MAPAQ depuis Azure SQL. Cet atelier instrumente l'API et garantit que les segments SQL sont capturés automatiquement par l'instrumentation OpenTelemetry incluse dans la distribution.

## Objectifs d'apprentissage

À la fin de cet atelier, vous serez en mesure de :

* Enregistrer la distribution Application Insights dans le projet API minimale.
* Confirmer que les segments EF Core / `Microsoft.Data.SqlClient` apparaissent comme dépendances sous la requête API.
* Exposer les en-têtes W3C `traceparent` et `tracestate` via CORS afin que le SDK navigateur puisse coudre la dépendance AJAX à la requête API.
* Distinguer une instrumentation manquante d'une exposition CORS manquante lorsque qu'un segment apparaît dans une couche mais pas dans l'autre.

Un mode de défaillance fréquent est « tout semble correct dans l'API, mais le navigateur ne s'y rattache pas ». Le correctif consiste presque toujours en l'exposition CORS manquante des en-têtes de contexte de trace W3C — l'Exercice 3.3 prémunit contre cela.

## Exercices

### Exercice 3.1 : Ajouter la distribution au projet API

```bash
dotnet add src/api package Azure.Monitor.OpenTelemetry.AspNetCore
```

`Program.cs` pour l'API :

```csharp
using Azure.Monitor.OpenTelemetry.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenTelemetry().UseAzureMonitor(o =>
{
    o.ConnectionString =
        builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
});

builder.Services.AddDbContext<MapaqDbContext>(opts =>
    opts.UseSqlServer(builder.Configuration["SQL_CONNECTION_STRING"]));
```

### Exercice 3.2 : Confirmer la capture des dépendances SQL

La distribution enregistre les instrumentations `Microsoft.EntityFrameworkCore` et `OpenTelemetry.Instrumentation.SqlClient`. Aucun code supplémentaire n'est requis — confirmez en frappant le point de terminaison de recherche :

```bash
curl "$API_URI/establishments?postalCode=G1V"
```

Dans Application Insights → Application Map vous devriez voir `web → api → sqlserver` en environ 30 secondes.

### Exercice 3.3 : Exposer les en-têtes de corrélation W3C via CORS

Dans `Program.cs` de l'API :

```csharp
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p
    .WithOrigins(builder.Configuration["WEB_URI"]!)
    .AllowAnyHeader()
    .AllowAnyMethod()
    .WithExposedHeaders("traceparent", "tracestate", "request-id")));
```

Sans `WithExposedHeaders`, le SDK navigateur ne peut pas lire le contexte de trace de la réponse et le segment de dépendance AJAX se retrouve orphelin.

### Exercice 3.4 : Redéployer et vérifier la topologie

```bash
azd deploy api
```

Rafraîchissez la page de recherche dans le navigateur, puis inspectez l'Application Map.

## Point de vérification

* [ ] Application Map affiche trois nœuds : `web`, `api`, `sqlserver`.
* [ ] Dans Transaction Search, l'ouverture d'un PageView du navigateur révèle l'imbrication : dépendance AJAX → requête API → dépendance SQL.
* [ ] Les quatre segments partagent le même `operation_Id`.
* [ ] Aucune exception dans `traces` provenant d'une chaîne de connexion manquante ou d'une clé de configuration non liée.

## Étapes suivantes

Vous disposez maintenant d'une application à deux couches entièrement instrumentée. Continuez avec [Atelier 04 : Corrélation navigateur ↔ serveur](lab-04-correlation-navigateur) pour valider formellement la corrélation de bout en bout sous charge.
