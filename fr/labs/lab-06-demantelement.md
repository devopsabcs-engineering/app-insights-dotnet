---
layout: default
lang: fr
nav_exclude: true
title: "Atelier 06 : Démantèlement"
nav_order: 6
permalink: /fr/labs/lab-06-demantelement
description: "Supprimer chaque ressource Azure créée par `azd up` et confirmer que le groupe de ressources est vide."
---

# Atelier 06 : Démantèlement

> **Durée : 15 min** — Inverser le déploiement avec `azd down --purge --force` et confirmer un coût résiduel nul.

L'application de référence utilise un plan App Service et une base Azure SQL, qui engendrent tous deux des coûts pendant leur exécution. Cet atelier supprime tout et vérifie qu'aucun élément ne traîne — y compris les Key Vaults supprimés de façon réversible, qui sont le piège habituel.

## Objectifs d'apprentissage

À la fin de cet atelier, vous serez en mesure de :

* Exécuter `azd down` avec les bons indicateurs pour réellement supprimer (et non supprimer de façon réversible) le contenu du groupe de ressources.
* Vérifier dans le portail Azure que le groupe de ressources est vide.
* Reconnaître et purger les ressources Key Vault et Application Insights supprimées de façon réversible, qui bloqueraient sinon un redéploiement avec le même nom.
* Confirmer que votre environnement `azd` local est propre pour la prochaine exécution de l'atelier.

## Exercices

### Exercice 6.1 : Exécuter azd down

```bash
azd down --purge --force
```

* `--purge` purge les Key Vaults, Cognitive Services et ressources Application Insights supprimés de façon réversible afin que les noms puissent être réutilisés immédiatement.
* `--force` saute la confirmation interactive. Ne l'utilisez qu'après avoir confirmé le groupe de ressources via `azd env get-values`.

Comptez 5 à 10 minutes pour que la suppression de l'App Service se termine.

### Exercice 6.2 : Confirmer que le groupe de ressources a disparu

```bash
az group exists --name "$(azd env get-value AZURE_RESOURCE_GROUP)"
# false
```

Si la commande retourne `true`, exécutez `az group delete -n <nom> --yes --no-wait` et revérifiez.

### Exercice 6.3 : Confirmer qu'il n'y a aucun Key Vault supprimé de façon réversible

```bash
az keyvault list-deleted --query "[?contains(name, 'mapaq')].name" -o tsv
```

Si quelque chose revient, purgez-le :

```bash
az keyvault purge --name <nom-vault>
```

### Exercice 6.4 : Nettoyer l'environnement azd local

```bash
azd env list
azd env delete mapaq-aiworkshop
```

## Point de vérification

* [ ] `az group exists` retourne `false` pour le groupe de ressources de l'atelier.
* [ ] `az keyvault list-deleted` ne retourne aucune entrée préfixée MAPAQ.
* [ ] `azd env list` n'affiche plus l'environnement de l'atelier.
* [ ] L'analyse des coûts dans le portail Azure affiche le groupe de ressources à 0 $ depuis le démantèlement.

## Étapes suivantes

Vous avez complété l'atelier. Suites suggérées :

* Réexécutez `azd up` contre une autre région (`westeurope` est un contraste utile pour la latence SQL).
* Explorez l'[atelier sœur sur l'accessibilité](https://github.com/devopsabcs-engineering/accessibility-scan-workshop) pour une expérience parallèle sur un autre angle d'observabilité.
* Soumettez des issues ou des PR contre ce dépôt avec des améliorations — le français et l'anglais sont tous deux de premier ordre.
