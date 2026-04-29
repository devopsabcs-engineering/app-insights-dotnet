---
layout: default
lang: fr
nav_exclude: true
title: "Atelier 04 : Corrélation navigateur ↔ serveur"
nav_order: 4
permalink: /fr/labs/lab-04-correlation-navigateur
description: "Vérifier qu'un seul operation_Id coud le PageView du navigateur, la dépendance AJAX, la requête serveur et la dépendance SQL."
---

# Atelier 04 : Corrélation navigateur ↔ serveur

> **Durée : 15 min** — Confirmer un seul `operation_Id` de bout en bout.

Cet atelier est le dénouement des Ateliers 02 et 03. Il s'agit d'une procédure structurée pour confirmer la corrélation de bout en bout dans Application Insights, plus un atelier de débogage pour quand la corrélation se brise.

## Objectifs d'apprentissage

À la fin de cet atelier, vous serez en mesure de :

* Déclencher une transaction déterministe et facile à retrouver depuis le navigateur.
* Localiser les quatre segments résultants (PageView, dépendance AJAX, requête API, dépendance SQL) dans Transaction Search.
* Exécuter une requête KQL `union` qui retourne les quatre lignes pour un `operation_Id` donné.
* Diagnostiquer les trois ruptures de corrélation les plus fréquentes : SDK JS manquant, exposition CORS manquante, et `distributedTracingMode` mal configuré.

## Exercices

### Exercice 4.1 : Générer une transaction connue

Dans le navigateur, lancez une recherche sur `postalCode=G1V`. La boîte de recherche ajoute automatiquement un paramètre de chaîne de requête `q` unique afin que cette transaction soit facile à retrouver plus tard.

### Exercice 4.2 : Trouver l'operation_Id depuis le PageView

Dans Application Insights → Logs :

```kusto
pageViews
| where timestamp > ago(10m)
| where url contains "postalCode=G1V"
| project timestamp, name, url, operation_Id
| top 1 by timestamp desc
```

Copiez l'`operation_Id` retourné dans votre tampon de travail.

### Exercice 4.3 : Confirmer que les quatre segments sont corrélés

```kusto
let opId = "<collez-l-operation_Id-ici>";
union
    (pageViews | where operation_Id == opId | extend kind = "pageView"),
    (dependencies | where operation_Id == opId | extend kind = "dependency"),
    (requests | where operation_Id == opId | extend kind = "request")
| project timestamp, kind, name, target, duration, success
| order by timestamp asc
```

Sortie attendue (dans l'ordre) :

1. `pageView`  — le rendu de la page de recherche.
2. `dependency` (`Ajax`) — `GET $API_URI/establishments`.
3. `request` — le point de terminaison API qui a traité l'appel.
4. `dependency` (`SQL`) — la requête EF Core sur `dbo.Establishments`.

### Exercice 4.4 : Le briser délibérément, puis le réparer

Commentez `WithExposedHeaders` dans la politique CORS de l'API issue de l'Atelier 03, redéployez, et réexécutez l'Exercice 4.3. La dépendance AJAX apparaît maintenant sous un `operation_Id` *différent* de la requête API — confirmant le mode de défaillance et renforçant pourquoi exposer les en-têtes W3C n'est pas négociable.

Restaurez la ligne et confirmez que la corrélation revient.

## Point de vérification

* [ ] Vous pouvez nommer et reconnaître les quatre types de segments dans la requête `union` ci-dessus.
* [ ] Vous avez exécuté la rupture délibérée et vu la dépendance AJAX orpheline.
* [ ] Vous avez restauré l'exposition CORS et confirmé que la corrélation revient.
* [ ] Vous pouvez articuler la différence entre `operation_Id` (par trace) et `operation_ParentId` (par segment).

## Étapes suivantes

La corrélation de bout en bout fonctionne maintenant de façon démontrable. Continuez avec [Atelier 05 : Tableaux de bord, KQL, alertes](lab-05-tableaux-de-bord) pour transformer cette télémétrie en un classeur, trois requêtes KQL et une règle d'alerte.
