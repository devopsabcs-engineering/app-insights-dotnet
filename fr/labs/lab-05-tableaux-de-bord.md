---
layout: default
lang: fr
nav_exclude: true
title: "Atelier 05 : Tableaux de bord, KQL, alertes"
nav_order: 5
permalink: /fr/labs/lab-05-tableaux-de-bord
description: "Écrire trois requêtes KQL, parcourir l'Application Map, configurer une règle d'alerte et épingler le tout dans un classeur."
---

# Atelier 05 : Tableaux de bord, KQL, alertes

> **Durée : 20 min** — De la télémétrie brute à un tableau de bord utilisable.

Cet atelier transforme la télémétrie que vous générez depuis le début en quelque chose qu'une ingénieure ou un ingénieur de garde peut réellement utiliser : un classeur (Workbook) avec trois tuiles KQL, une Application Map parcourue, et une règle d'alerte sur le taux de défaillance de l'API.

## Objectifs d'apprentissage

À la fin de cet atelier, vous serez en mesure de :

* Écrire des requêtes KQL contre `requests`, `dependencies` et `customMetrics`.
* Utiliser l'Application Map pour identifier la dépendance la plus lente dans la topologie.
* Créer une alerte de métrique sur le taux d'erreurs HTTP 5xx de l'API à l'aide de `requests | summarize`.
* Épingler le résultat d'une requête dans un classeur et le partager via une URL du portail.

## Exercices

### Exercice 5.1 : Top 5 des points de terminaison API les plus lents

```kusto
requests
| where timestamp > ago(1h)
| where cloud_RoleName == "api"
| summarize p95 = percentile(duration, 95), count() by name
| order by p95 desc
| take 5
```

Épinglez ceci dans un nouveau classeur appelé `MAPAQ — Tableau de bord d'atelier`.

### Exercice 5.2 : Décomposition de la durée des dépendances

```kusto
dependencies
| where timestamp > ago(1h)
| summarize p50 = percentile(duration, 50),
            p95 = percentile(duration, 95),
            count()
            by type, target
| order by p95 desc
```

Cette seule requête révèle si la traîne de latence se trouve dans SQL, dans des appels HTTP en aval, ou ailleurs.

### Exercice 5.3 : Compteur de corrélation AJAX navigateur → API

```kusto
let last_hour = ago(1h);
let browserAjax = dependencies
    | where timestamp > last_hour and type == "Ajax";
let apiRequests = requests
    | where timestamp > last_hour and cloud_RoleName == "api";
browserAjax
| join kind=leftouter apiRequests on operation_Id
| summarize correles = countif(isnotempty(operation_Id1)),
            orphelins = countif(isempty(operation_Id1))
```

Si `orphelins > 0`, c'est une régression de corrélation — retournez à l'Atelier 04 Exercice 4.4 pour déboguer.

### Exercice 5.4 : Parcourir l'Application Map

Dans le portail, ouvrez Application Insights → Application Map. Confirmez la topologie `web → api → sqlserver`, cliquez sur le nœud SQL, et notez la durée moyenne d'appel. C'est le même chiffre que vous verrez dans la table `dependencies` ; la carte n'est qu'une couche de visualisation au-dessus des mêmes données.

### Exercice 5.5 : Créer une alerte 5xx

Dans Application Insights → Alertes → Nouvelle règle d'alerte :

* Signal : `Failed requests`.
* Condition : `Count moyen > 5 sur 5 minutes` pour `cloud_RoleName == "api"`.
* Groupe d'actions : choisissez `Email` et votre adresse.

## Point de vérification

* [ ] Le classeur contient les trois requêtes ci-dessus comme tuiles épinglées.
* [ ] Vous pouvez articuler pourquoi le p95 des dépendances est plus utile que la moyenne.
* [ ] La règle d'alerte se déclenche lorsque vous appelez `curl` sur un point de terminaison délibérément cassé 6 fois en 5 minutes.
* [ ] L'Application Map rend la topologie à trois nœuds.

## Étapes suivantes

Vous disposez maintenant d'une surface d'observabilité fonctionnelle. Continuez avec [Atelier 06 : Démantèlement](lab-06-demantelement) pour supprimer chaque ressource et confirmer un coût résiduel nul.
