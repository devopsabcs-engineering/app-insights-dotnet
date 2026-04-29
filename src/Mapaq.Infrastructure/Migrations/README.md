# EF Core Migrations

The `Initial` migration is **not pre-generated** in this workshop scaffold —
attendees create it themselves as the first lab exercise. To generate it
locally:

```pwsh
dotnet tool install --global dotnet-ef --version 10.*
dotnet ef migrations add Initial `
    --project src/Mapaq.Infrastructure `
    --startup-project src/Mapaq.Api `
    --output-dir Migrations
```

Then verify SQL output without applying:

```pwsh
dotnet ef migrations script `
    --project src/Mapaq.Infrastructure `
    --startup-project src/Mapaq.Api
```

`HasData(...)` rows seeded by the `Configurations/*.cs` files are read from
`data/seed/*.csv` at design time via `SeedLoader`. The CSVs are intentionally
small (~10 rows each) so the workshop can be run offline without having to
download the live Données Québec snapshots.

> **Note.** Until the migration is added the Migrations folder contains only
> this README. The `Mapaq.Api` project still boots — it just cannot run
> `Database.Migrate()` until the migration exists.
