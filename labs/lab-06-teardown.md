---
layout: default
title: "Lab 06: Teardown"
parent: "Labs"
nav_order: 6
permalink: /labs/lab-06-teardown
description: "Delete every Azure resource created by `azd up` and confirm the resource group is empty."
---

# Lab 06: Teardown

> **Timebox: 15 min** — Reverse the deployment with `azd down --purge --force` and confirm zero residual cost.

The reference application uses an App Service plan and an Azure SQL database, both of which incur cost while running. This lab removes everything and verifies that nothing is lingering — including soft-deleted Key Vaults, which is the usual gotcha.

## Learning Objectives

By the end of this lab you will be able to:

* Run `azd down` with the right flags to actually delete (not soft-delete) the resource group's contents.
* Verify in the Azure portal that the resource group is empty.
* Recognize and purge soft-deleted Key Vault and Application Insights resources, which otherwise block redeployment to the same name.
* Confirm your local `azd` environment is clean for the next workshop run.

## Exercises

### Exercise 6.1: Run azd down

```bash
azd down --purge --force
```

* `--purge` purges soft-deleted Key Vaults, Cognitive Services and Application Insights resources so the names can be reused immediately.
* `--force` skips the interactive confirmation. Use it only after you have confirmed the resource group via `azd env get-values`.

Expect 5–10 minutes for the App Service deletion to complete.

### Exercise 6.2: Confirm the resource group is gone

```bash
az group exists --name "$(azd env get-value AZURE_RESOURCE_GROUP)"
# false
```

If the command returns `true`, run `az group delete -n <name> --yes --no-wait` and re-check.

### Exercise 6.3: Confirm there are no soft-deleted Key Vaults

```bash
az keyvault list-deleted --query "[?contains(name, 'mapaq')].name" -o tsv
```

If anything comes back, purge it:

```bash
az keyvault purge --name <vault-name>
```

### Exercise 6.4: Clean the local azd environment

```bash
azd env list
azd env delete mapaq-aiworkshop
```

## Verification Checkpoint

* [ ] `az group exists` returns `false` for the workshop resource group.
* [ ] `az keyvault list-deleted` returns no MAPAQ-prefixed entries.
* [ ] `azd env list` no longer shows the workshop environment.
* [ ] Cost analysis in the Azure portal shows the resource group at $0 since teardown.

## Next Steps

You have completed the workshop. Suggested follow-ups:

* Re-run `azd up` against a different region (`westeurope` is a useful contrast for SQL latency).
* Explore the [sister Accessibility workshop](https://github.com/devopsabcs-engineering/accessibility-scan-workshop) for a parallel experience on a different observability angle.
* File issues or PRs against this repo with improvements — French and English are both first-class.
