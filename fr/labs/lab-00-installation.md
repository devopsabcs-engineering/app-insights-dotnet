---
layout: default
lang: fr
nav_exclude: true
parent: "Ateliers"
title: "Atelier 00 : Installation"
nav_order: 0
permalink: /fr/labs/lab-00-installation
description: "Installer la trousse d'outils et préparer l'abonnement Azure utilisé par tous les ateliers suivants."
---

# Atelier 00 : Installation

> **Durée : 15 min** — Prérequis et préparation ponctuelle de l'environnement.

Cet atelier installe tout ce dont les six ateliers suivants dépendent. Si vous avez récemment exécuté un atelier de type `azd` sur ce poste, vous pouvez le parcourir rapidement ; sinon, complétez chaque point de vérification avant de poursuivre.

## Objectifs d'apprentissage

À la fin de cet atelier, vous serez en mesure de :

* Confirmer qu'un abonnement Azure avec le rôle `Owner` (ou `Contributor` + `User Access Administrator`) sur un groupe de ressources cible est joignable depuis votre interpréteur de commandes.
* Installer et vérifier le SDK .NET 10, Azure CLI, Azure Developer CLI (`azd`) et le GitHub CLI (`gh`).
* Vous connecter à Azure et à GitHub et sélectionner le bon abonnement, locataire et dépôt.
* Cloner ce dépôt et confirmer que le conteneur de développement / Codespace `dev` se construit sans erreur.

Ces quatre points de vérification débloquent ensemble tous les ateliers suivants. La plupart des problèmes que nous avons observés en livraison se ramènent à un outil manquant ou à un rôle d'abonnement mal cadré, plutôt qu'à un bogue d'instrumentation — soyez donc rigoureux ici.

## Exercices

### Exercice 0.1 : Installer la trousse d'outils

Installez les quatre interpréteurs de ligne de commande ci-dessous. Les versions sont des minimums ; plus récent est correct.

```bash
# Vérifier (ou installer) chaque outil
dotnet --version       # >= 10.0.100
az version             # >= 2.65
azd version            # >= 1.10
gh --version           # >= 2.55
```

Si une commande est manquante, installez-la depuis :

* `SDK .NET 10` — <https://dot.net/download>
* `Azure CLI` — <https://learn.microsoft.com/cli/azure/install-azure-cli>
* `Azure Developer CLI` — <https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd>
* `GitHub CLI` — <https://cli.github.com/>

### Exercice 0.2 : Se connecter et sélectionner l'abonnement

```bash
az login
az account set --subscription "<votre-id-d-abonnement>"
azd auth login
gh auth login
```

Notez l'identifiant d'abonnement et l'identifiant de locataire — vous les réutiliserez à l'Atelier 01.

### Exercice 0.3 : Cloner le dépôt et l'ouvrir

```bash
gh repo clone devopsabcs-engineering/app-insights-dotnet
cd app-insights-dotnet
code .
```

Si vous avez Docker Desktop ou un Codespace, acceptez l'invitation à rouvrir dans le conteneur de développement. Sinon, le SDK .NET 10 local suffit pour tous les ateliers.

## Point de vérification

Avant de quitter l'Atelier 00, confirmez les quatre cases :

* [ ] `dotnet --version` retourne `10.x` et `dotnet --info` liste l'environnement d'exécution `microsoft.netcore.app 10.0.x`.
* [ ] `az account show` retourne l'abonnement que vous comptez utiliser.
* [ ] `azd auth login` a réussi (ouvrez `~/.azd/auth.json` au besoin pour confirmer).
* [ ] `gh auth status` indique que vous êtes connecté à `github.com` avec la portée `repo`.

## Étapes suivantes

Vous disposez maintenant d'un interpréteur préparé avec tout ce dont l'Atelier 01 a besoin. Continuez avec [Atelier 01 : Provisionnement Azure](lab-01-provisionnement) pour déployer l'application de référence.
