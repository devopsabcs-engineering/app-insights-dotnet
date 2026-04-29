---
layout: default
lang: fr
title: "Accueil"
nav_order: 1
nav_exclude: true
permalink: /fr/
---

# Atelier App Insights .NET 10 — MAPAQ

> Atelier bilingue pratique pour instrumenter une application de référence .NET 10 avec Azure Application Insights, à partir des données ouvertes du MAPAQ sur les inspections d'établissements alimentaires.
>
> 🇫🇷 **Français (en cours)** · 🇬🇧 **[English version](../)**

Cet atelier guide les praticiennes et praticiens du génie logiciel et du DevOps à travers une démarche d'observabilité de bout en bout sur une pile réaliste : Razor Pages + API minimale + EF Core / Azure SQL. Six modules totalisant environ deux heures de laboratoire produisent une application entièrement instrumentée, avec une corrélation de traces du navigateur jusqu'à la base de données, des tableaux de bord KQL et des alertes.

## Public et prérequis

* Aisance avec les fondamentaux C# et ASP.NET Core (différences entre contrôleurs et Razor Pages, pipeline d'intergiciels).
* Connaissance de base d'Azure (groupes de ressources, déploiements, portail).
* Voir l'[Atelier 00 : Installation](labs/lab-00-installation) pour la liste complète des prérequis (abonnement Azure, SDK .NET 10, `az`, `azd`, `gh`).

## Carte des modules

| # | Module | Atelier | Durée |
|---|---|---|---|
| 0 | Installation | [Atelier 00 : Installation](labs/lab-00-installation) | 15 min |
| 1 | Provisionnement Azure | [Atelier 01 : Provisionnement](labs/lab-01-provisionnement) | 15 min |
| 2 | Instrumentation Razor Pages | [Atelier 02 : Instrumentation web](labs/lab-02-instrumentation-web) | 20 min |
| 3 | Instrumentation API + SQL | [Atelier 03 : Instrumentation API + SQL](labs/lab-03-instrumentation-api-sql) | 20 min |
| 4 | Corrélation navigateur ↔ serveur | [Atelier 04 : Corrélation navigateur](labs/lab-04-correlation-navigateur) | 15 min |
| 5 | Tableaux de bord, KQL, alertes | [Atelier 05 : Tableaux de bord](labs/lab-05-tableaux-de-bord) | 20 min |
| 6 | Démantèlement | [Atelier 06 : Démantèlement](labs/lab-06-demantelement) | 15 min |

## Application de référence

L'application de référence est une interface de recherche pour les inspections d'établissements alimentaires, les avis de condamnation et les suspensions de permis publiés par le MAPAQ. Les données sont chargées à partir du flux de données ouvertes ; aucune donnée personnelle n'est en jeu. Une note de recherche distincte dans ce dépôt documente la licence et le glossaire bilingue utilisés tout au long des ateliers.

## Ce que vous repartirez avec

* Une ressource Application Insights qui corrèle les segments navigateur, web, API et SQL sous un seul `operation_Id`.
* Un classeur (Workbook) et trois requêtes KQL que vous aurez écrites vous-même.
* Un déploiement `azd` reproductible que vous pourrez démanteler avec une seule commande.

> **Suite :** [Démarrer l'Atelier 00 — Installation](labs/lab-00-installation)
