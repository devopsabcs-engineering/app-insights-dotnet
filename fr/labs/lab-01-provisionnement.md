---
layout: default
lang: fr
nav_exclude: true
parent: "Ateliers"
title: "Atelier 01 : Provisionnement Azure"
nav_order: 1
permalink: /fr/labs/lab-01-provisionnement
description: "Déployer l'application de référence et sa ressource Application Insights avec une seule commande `azd up`."
---

# Atelier 01 : Provisionnement Azure

> **Durée : 15 min** — D'un groupe de ressources vide à une application instrumentée et en cours d'exécution via `azd up`.

Cet atelier déploie tout ce que la Phase 2 construit : une couche web Razor Pages, une couche API minimale, une base de données Azure SQL, une ressource Application Insights liée à un espace de travail Log Analytics, et un Key Vault contenant la chaîne de connexion. Vous n'écrirez encore aucun code — l'objectif est de confirmer que l'infrastructure est saine avant de commencer l'instrumentation.

## Objectifs d'apprentissage

À la fin de cet atelier, vous serez en mesure de :

* Initialiser l'environnement `azd` pour ce dépôt et choisir une région.
* Exécuter `azd up` et lire sa sortie pour identifier les ressources créées.
* Ouvrir l'URL web déployée et confirmer une sonde d'activité verte.
* Localiser la ressource Application Insights dans le portail Azure et confirmer qu'elle n'a encore reçu aucune télémétrie (nous instrumenterons l'application aux Ateliers 02 et 03).

Le modèle mental à retenir est que `azd up` est *idempotent* : le réexécuter plus tard dans l'atelier ne réapplique que ce qui a changé, ce qui est essentiel pour les redéploiements que vous ferez aux Ateliers 02 à 05.

## Exercices

### Exercice 1.1 : Initialiser l'environnement azd

```bash
azd env new mapaq-aiworkshop
azd env set AZURE_LOCATION eastus2
azd env set AZURE_SUBSCRIPTION_ID <votre-id-d-abonnement>
```

`mapaq-aiworkshop` n'est qu'une étiquette ; choisissez le nom court qui vous convient. La région dépend des SKU disponibles pour les composants Application Insights basés sur un espace de travail dans votre locataire — consultez le tableau des régions du fichier README si `eastus2` n'est pas activé chez vous.

### Exercice 1.2 : Provisionner et déployer

```bash
azd up
```

Cette commande :

1. Résout les modèles Bicep sous `infra/`.
2. Provisionne le groupe de ressources, l'espace de travail Log Analytics, Application Insights, Azure SQL, le plan App Service, l'application web et l'application API, ainsi que le Key Vault.
3. Construit et déploie les applications web et API vers App Service.

Comptez environ 8 à 10 minutes la première fois. La sortie se termine par deux URL (`WEB_URI` et `API_URI`) — copiez les deux dans un tampon de travail.

### Exercice 1.3 : Tester rapidement le déploiement

```bash
curl -fsS "$WEB_URI/health/live"
curl -fsS "$API_URI/health/live"
```

Les deux points de terminaison retournent `{"status":"Healthy"}`. Ouvrez `WEB_URI` dans un navigateur et confirmez que la page de recherche s'affiche. Ne lancez pas encore de recherche — aucune télémétrie n'est branchée.

## Point de vérification

* [ ] `azd env get-values` liste `AZURE_RESOURCE_GROUP`, `WEB_URI`, `API_URI`, `APPLICATIONINSIGHTS_CONNECTION_STRING`.
* [ ] Le portail Azure affiche la ressource Application Insights dans le même groupe de ressources, liée à l'espace de travail Log Analytics.
* [ ] Le panneau « Live Metrics » d'Application Insights affiche un trafic nul (confirmant qu'aucun SDK n'est encore branché).
* [ ] Les points de terminaison `/health/live` de `WEB_URI` et `API_URI` retournent tous deux HTTP 200.

## Étapes suivantes

L'infrastructure attend maintenant la télémétrie. Continuez avec [Atelier 02 : Instrumentation de la couche web](lab-02-instrumentation-web) pour brancher la distribution Application Insights basée sur OpenTelemetry dans l'application Razor Pages.
