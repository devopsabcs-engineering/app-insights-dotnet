---
layout: default
title: "Lab 01: Provision Azure infra"
parent: "Labs"
nav_order: 1
permalink: /labs/lab-01-provision
description: "Deploy the reference application and its Application Insights resource with a single `azd up` command."
---

# Lab 01: Provision Azure infra

> **Timebox: 15 min** — From an empty resource group to a running, instrumented app via `azd up`.

This lab deploys everything Phase 2 builds: a Razor Pages web tier, a Minimal API tier, an Azure SQL database, an Application Insights resource bound to a Log Analytics workspace, and a Key Vault holding the connection string. You will not write any code yet — the goal is to confirm the infra is healthy before you start instrumenting.

## Learning Objectives

By the end of this lab you will be able to:

* Initialize the `azd` environment for this repo and pick a region.
* Run `azd up` and read its output to identify which resources were created.
* Open the deployed web URL and confirm a green liveness probe.
* Locate the Application Insights resource in the Azure portal and confirm it has not yet received any telemetry (we will instrument the app in Lab 02 and Lab 03).

The mental model to lock in is that `azd up` is *idempotent*: running it again later in the workshop only re-applies what changed, which is critical for the redeploys you will do in Labs 02–05.

## Exercises

### Exercise 1.1: Initialize the azd environment

```bash
azd env new mapaq-aiworkshop
azd env set AZURE_LOCATION eastus2
azd env set AZURE_SUBSCRIPTION_ID <your-subscription-id>
```

`mapaq-aiworkshop` is just a label; pick whatever short name you want. The location is mandated by the available SKUs of Application Insights workspace-based components in your tenant — see the regions table in the README if `eastus2` is not enabled for you.

### Exercise 1.2: Provision and deploy

```bash
azd up
```

This command:

1. Resolves the Bicep templates under `infra/`.
2. Provisions the resource group, Log Analytics workspace, Application Insights, Azure SQL, App Service plan, Web App and API App, and Key Vault.
3. Builds and pushes the web and API apps to App Service.

Expect ~8–10 minutes the first time. The output ends with two URLs (`WEB_URI` and `API_URI`) — copy both into a scratch buffer.

### Exercise 1.3: Smoke-test the deployment

```bash
curl -fsS "$WEB_URI/health/live"
curl -fsS "$API_URI/health/live"
```

Both endpoints return `{"status":"Healthy"}`. Open `WEB_URI` in a browser and confirm the search page renders. Do not search yet — there is no telemetry plumbed in.

## Verification Checkpoint

* [ ] `azd env get-values` lists `AZURE_RESOURCE_GROUP`, `WEB_URI`, `API_URI`, `APPLICATIONINSIGHTS_CONNECTION_STRING`.
* [ ] The Azure portal shows the Application Insights resource in the same resource group, bound to the Log Analytics workspace.
* [ ] The Application Insights "Live Metrics" blade shows zero traffic (confirming no SDK is wired in yet).
* [ ] Both `WEB_URI` and `API_URI` `/health/live` endpoints return HTTP 200.

## Next Steps

The infrastructure is now waiting for telemetry. Continue with [Lab 02: Instrument the web tier](lab-02-instrument-web) to wire the OpenTelemetry-based Application Insights distro into the Razor Pages app.
