---
layout: default
title: "Lab 00: Setup"
parent: "Labs"
nav_order: 0
permalink: /labs/lab-00-setup
description: "Install the toolchain and prepare the Azure subscription used by every subsequent lab."
---

# Lab 00: Setup

> **Timebox: 15 min** — Prerequisites and one-time environment preparation.

This lab installs everything the remaining six labs depend on. If you have run a recent `azd`-style workshop on this laptop you can skim it; otherwise, work through every checkpoint before moving on.

## Learning Objectives

By the end of this lab you will be able to:

* Confirm that an Azure subscription with `Owner` (or `Contributor` + `User Access Administrator`) on a target resource group is reachable from your shell.
* Install and verify the .NET 10 SDK, Azure CLI, Azure Developer CLI (`azd`) and the GitHub CLI (`gh`).
* Sign in to Azure and GitHub and select the correct subscription, tenant and repo.
* Clone this repository and confirm the `dev` Codespace / dev container builds without errors.

These four checkpoints together unblock every later lab. Most of the trouble we have seen in past deliveries traces back to a missing tool or a mis-scoped subscription role rather than an instrumentation bug, so be deliberate here.

## Exercises

### Exercise 0.1: Install the toolchain

Install the four CLIs below. Versions are minimums; newer is fine.

```bash
# Verify (or install) each tool
dotnet --version       # >= 10.0.100
az version             # >= 2.65
azd version            # >= 1.10
gh --version           # >= 2.55
```

If any command is missing, install it from:

* `.NET 10 SDK` — <https://dot.net/download>
* `Azure CLI` — <https://learn.microsoft.com/cli/azure/install-azure-cli>
* `Azure Developer CLI` — <https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd>
* `GitHub CLI` — <https://cli.github.com/>

### Exercise 0.2: Sign in and select your subscription

```bash
az login
az account set --subscription "<your-subscription-id>"
azd auth login
gh auth login
```

Capture the subscription ID and tenant ID — you will reuse both in Lab 01.

### Exercise 0.3: Clone the repo and open it

```bash
gh repo clone devopsabcs-engineering/app-insights-dotnet
cd app-insights-dotnet
code .
```

If you have Docker Desktop or a Codespace, accept the prompt to reopen in the dev container. Otherwise, the local `.NET 10` SDK is sufficient for every lab.

## Verification Checkpoint

Before leaving Lab 00, confirm all four checkboxes:

* [ ] `dotnet --version` reports `10.x` and `dotnet --info` lists `microsoft.netcore.app 10.0.x` runtime.
* [ ] `az account show` returns the subscription you intend to use.
* [ ] `azd auth login` succeeded (open `~/.azd/auth.json` if you need to confirm).
* [ ] `gh auth status` shows you are logged in to `github.com` with `repo` scope.

## Next Steps

You now have a primed shell with everything Lab 01 needs. Continue with [Lab 01: Provision Azure infra](lab-01-provision) to deploy the reference application.
