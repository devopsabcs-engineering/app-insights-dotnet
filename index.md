---
layout: default
title: "Workshop Home"
nav_order: 1
permalink: /
---

# App Insights .NET 10 — MAPAQ Workshop

> Bilingual hands-on workshop for instrumenting a .NET 10 reference application with Azure Application Insights, built around the Quebec MAPAQ open-data establishments inspection dataset.
>
> 🇫🇷 **[Version française](fr/)** · 🇬🇧 **English (current)**

This workshop walks Software Engineering and DevOps practitioners through end-to-end observability on a realistic Razor Pages + Minimal API + EF Core / Azure SQL stack. Six modules add up to roughly two hours of guided lab time and produce a fully instrumented application with browser-to-database trace correlation, KQL dashboards and alerts.

## Audience and prerequisites

* Comfortable with C# and ASP.NET Core fundamentals (controllers vs Razor Pages, middleware pipeline).
* Basic Azure familiarity (resource groups, deployments, the portal).
* See [Lab 00: Setup](labs/lab-00-setup) for the full prerequisite checklist (Azure subscription, .NET 10 SDK, `az`, `azd`, `gh`).

## Module map

| # | Module | Lab | Timebox |
|---|---|---|---|
| 0 | Setup | [Lab 00: Setup](labs/lab-00-setup) | 15 min |
| 1 | Provision Azure infra | [Lab 01: Provision](labs/lab-01-provision) | 15 min |
| 2 | Instrument Razor Pages web | [Lab 02: Web instrumentation](labs/lab-02-instrument-web) | 20 min |
| 3 | Instrument Minimal API + SQL | [Lab 03: API + SQL instrumentation](labs/lab-03-instrument-api-sql) | 20 min |
| 4 | Browser ↔ server correlation | [Lab 04: Browser correlation](labs/lab-04-browser-correlation) | 15 min |
| 5 | Dashboards, KQL, alerts | [Lab 05: Dashboards](labs/lab-05-dashboards) | 20 min |
| 6 | Teardown | [Lab 06: Teardown](labs/lab-06-teardown) | 15 min |

## Reference application

The reference app is a search UI for MAPAQ-published establishment inspections, conviction notices and permit suspensions. Data is loaded from the public open-data feed; no PII is involved. A separate research note in this repo documents the licensing and the bilingual glossary used throughout the labs.

## What you will leave with

* A working Application Insights resource correlating browser, web, API and SQL spans under a single `operation_Id`.
* A Workbook and three KQL queries you authored yourself.
* A reproducible `azd` deployment you can tear down with one command.

> **Next:** [Start Lab 00 — Setup](labs/lab-00-setup)
