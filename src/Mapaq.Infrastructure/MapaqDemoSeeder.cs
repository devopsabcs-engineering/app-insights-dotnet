using System.Globalization;
using Mapaq.Domain;
using Microsoft.EntityFrameworkCore;

namespace Mapaq.Infrastructure;

/// <summary>
/// Generates a rich, lifelike demo dataset for the workshop's in-memory
/// EF Core store so the UI feels populated even before SQL provisioning.
///
/// Idempotent: <see cref="SeedIfEmpty"/> only seeds when the
/// <see cref="MapaqDbContext.Establishments"/> table is empty. Uses a
/// fixed PRNG seed so every <c>dotnet run</c> produces the same data,
/// which keeps the App Insights end-to-end demo reproducible.
/// </summary>
public static class MapaqDemoSeeder
{
    private const int RandomSeed = 4172026;

    /// <summary>Treat a context with this many establishments or fewer as "needs seeding".</summary>
    private const int SeededThreshold = 50;

    private static readonly (string Code, string[] Cities)[] Regions = new[]
    {
        ("01-BAS-SAINT-LAURENT",            new[] { "Rimouski", "Riviere-du-Loup", "Matane" }),
        ("02-SAGUENAY-LAC-SAINT-JEAN",      new[] { "Chicoutimi", "Jonquiere", "Alma", "Saguenay" }),
        ("03-CAPITALE-NATIONALE",           new[] { "Quebec", "Sainte-Foy", "Beauport", "Charlesbourg" }),
        ("04-MAURICIE",                     new[] { "Trois-Rivieres", "Shawinigan" }),
        ("05-ESTRIE",                       new[] { "Sherbrooke", "Magog", "Coaticook" }),
        ("06-MONTREAL",                     new[] { "Montreal", "Westmount", "Outremont", "Verdun", "LaSalle" }),
        ("07-OUTAOUAIS",                    new[] { "Gatineau", "Hull", "Aylmer" }),
        ("08-ABITIBI-TEMISCAMINGUE",        new[] { "Val-d-Or", "Rouyn-Noranda" }),
        ("09-COTE-NORD",                    new[] { "Sept-Iles", "Baie-Comeau" }),
        ("10-NORD-DU-QUEBEC",               new[] { "Chibougamau", "Chapais" }),
        ("11-GASPESIE-ILES-DE-LA-MADELEINE", new[] { "Gaspe", "Sainte-Anne-des-Monts" }),
        ("12-CHAUDIERE-APPALACHES",         new[] { "Levis", "Saint-Georges", "Thetford-Mines" }),
        ("13-LAVAL",                        new[] { "Laval" }),
        ("14-LANAUDIERE",                   new[] { "Joliette", "Repentigny", "Terrebonne" }),
        ("15-LAURENTIDES",                  new[] { "Saint-Jerome", "Mont-Tremblant", "Sainte-Therese" }),
        ("16-MONTEREGIE",                   new[] { "Longueuil", "Saint-Hyacinthe", "Granby", "Brossard" }),
        ("17-CENTRE-DU-QUEBEC",             new[] { "Drummondville", "Victoriaville" })
    };

    private static readonly string[] PermitTypes = new[]
    {
        "RESTAURANT", "CASSE-CROUTE", "EPICERIE", "BOULANGERIE",
        "POISSONNERIE", "BOUCHERIE", "CAFE-BISTRO", "TRAITEUR"
    };

    private static readonly string[] StreetNames = new[]
    {
        "rue Sainte-Catherine", "avenue Royale", "rue King Ouest", "rue des Cascades",
        "chemin du Roy", "rue Saint-Pierre", "promenade du Portage", "avenue Atwater",
        "rue Racine", "avenue du Mont-Royal", "boulevard Rene-Levesque", "rue Principale",
        "avenue des Pins", "rue Saint-Joseph", "boulevard Laurier", "avenue Cartier",
        "rue Notre-Dame", "boulevard Saint-Laurent", "rue Saint-Denis", "avenue du Parc"
    };

    private static readonly string[] EstablishmentBaseNames = new[]
    {
        "Restaurant Chez", "Bistro", "Cafe", "Boulangerie", "Casse-croute du",
        "Epicerie Fine", "Marche", "Poissonnerie", "Boucherie", "Traiteur",
        "Auberge", "Brasserie", "Comptoir", "Cantine du", "Pizzeria"
    };

    private static readonly string[] OwnerNames = new[]
    {
        "Marcel", "Sophie", "Jean-Pierre", "Marie-Claude", "Francois", "Isabelle",
        "Pascal", "Nathalie", "Eric", "Helene", "Pierre", "Lucie",
        "Stephane", "Genevieve", "Daniel", "Veronique", "Mathieu", "Caroline"
    };

    private static readonly (string Code, string Fr, string En)[] Articles = new[]
    {
        ("P-29-r.1-art.4",  "Hygiene et salubrite",         "Hygiene and sanitation"),
        ("P-29-r.1-art.5",  "Proprete des lieux",           "Cleanliness of premises"),
        ("P-29-r.1-art.7",  "Temperature de conservation",  "Storage temperature"),
        ("P-29-r.1-art.9",  "Conservation produits frais",  "Fresh-product storage"),
        ("P-29-r.1-art.12", "Etiquetage trompeur",          "Misleading labelling"),
        ("P-29-r.1-art.16", "Manipulation des aliments",    "Food handling"),
        ("P-29-r.1-art.21", "Lutte contre les rongeurs",    "Pest control"),
        ("P-29-r.1-art.27", "Permis non conforme",          "Permit non-compliance")
    };

    private static readonly string[] SuspensionReasons = new[]
    {
        "Risque sanitaire grave - infestation de rongeurs",
        "Manquement repete a la chaine du froid",
        "Defaut d'entretien et insalubrite generalisee",
        "Refus d'acces aux inspecteurs",
        "Recidive multiple - hygiene"
    };

    private static readonly string[] Indicators = new[]
    {
        "01-Inspections",
        "02-AvisNonConformite",
        "03-AmendesEmises",
        "04-PermisSuspendus"
    };

    /// <summary>
    /// Seeds a representative dataset into the supplied context. Idempotent
    /// — when the establishment count already exceeds <see cref="SeededThreshold"/>
    /// the call is a no-op. Otherwise any pre-existing rows (typically the
    /// small <c>HasData</c> set inserted by EF Core <c>EnsureCreated</c>)
    /// are removed first so the rich demo dataset is the single source of
    /// truth on the in-memory store.
    /// </summary>
    public static void SeedIfEmpty(MapaqDbContext db)
    {
        ArgumentNullException.ThrowIfNull(db);

        if (db.Establishments.Count() > SeededThreshold)
        {
            return;
        }

        // Wipe any pre-existing seed (HasData inserts ~10 rows on EnsureCreated)
        // so the rich generated dataset is authoritative on the in-memory store.
        db.SyncJobs.RemoveRange(db.SyncJobs);
        db.InspectionRollups.RemoveRange(db.InspectionRollups);
        db.Suspensions.RemoveRange(db.Suspensions);
        db.Convictions.RemoveRange(db.Convictions);
        db.Establishments.RemoveRange(db.Establishments);
        db.SaveChanges();

        var rng = new Random(RandomSeed);

        // ---- Establishments (~12 per region = ~200 total) ----
        var establishments = new List<Establishment>();
        foreach (var (region, cities) in Regions)
        {
            var count = rng.Next(8, 15);
            for (var i = 0; i < count; i++)
            {
                var city = cities[rng.Next(cities.Length)];
                var permit = PermitTypes[rng.Next(PermitTypes.Length)];
                var name = $"{EstablishmentBaseNames[rng.Next(EstablishmentBaseNames.Length)]} " +
                           $"{OwnerNames[rng.Next(OwnerNames.Length)]}";
                var streetNumber = rng.Next(10, 999);
                var street = StreetNames[rng.Next(StreetNames.Length)];

                establishments.Add(new Establishment
                {
                    Name = name,
                    Address = $"{streetNumber} {street}",
                    City = city,
                    PostalCode = GeneratePostalCode(rng),
                    Region = region,
                    PermitType = permit
                });
            }
        }
        db.Establishments.AddRange(establishments);
        db.SaveChanges(); // flush so SQL Server generates EstablishmentId values

        // ---- Convictions: 0-5 per establishment, last 3 years ----
        var convictions = new List<Conviction>();
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var earliest = today.AddYears(-3);
        foreach (var est in establishments)
        {
            var convCount = WeightedZeroBiased(rng, max: 5);
            for (var i = 0; i < convCount; i++)
            {
                var article = Articles[rng.Next(Articles.Length)];
                var dayOffset = rng.Next(0, today.DayNumber - earliest.DayNumber);
                var date = earliest.AddDays(dayOffset);
                var amount = decimal.Parse(
                    (250 + rng.Next(50) * 50).ToString(CultureInfo.InvariantCulture),
                    CultureInfo.InvariantCulture);
                convictions.Add(new Conviction
                {
                    EstablishmentId = est.EstablishmentId,
                    ConvictionDate = date,
                    AmountCad = amount,
                    ArticleCode = article.Code,
                    ArticleTitleFr = article.Fr,
                    ArticleTitleEn = article.En
                });
            }
        }
        db.Convictions.AddRange(convictions);

        // ---- Suspensions: 1-2% of establishments currently suspended ----
        var suspensions = new List<Suspension>();
        foreach (var est in establishments)
        {
            if (rng.NextDouble() > 0.02)
            {
                continue;
            }
            var start = today.AddDays(-rng.Next(1, 60));
            var endNullable = rng.NextDouble() < 0.5
                ? (DateOnly?)null
                : start.AddDays(rng.Next(7, 90));
            suspensions.Add(new Suspension
            {
                EstablishmentId = est.EstablishmentId,
                StartDate = start,
                EndDate = endNullable,
                Reason = SuspensionReasons[rng.Next(SuspensionReasons.Length)]
            });
        }
        if (suspensions.Count > 0)
        {
            db.Suspensions.AddRange(suspensions);
        }

        // ---- Inspection rollups: every region × current+previous year × 12 months × 4 indicators ----
        var rollups = new List<InspectionRollup>();
        var years = new[] { today.Year - 1, today.Year };
        foreach (var (region, _) in Regions)
        {
            // Each region has a baseline activity level proportional to its population
            // (Montreal & Capitale Nationale see far more inspections than Côte-Nord).
            var baseline = BaselineFor(region);
            foreach (var year in years)
            {
                for (var month = 1; month <= 12; month++)
                {
                    foreach (var indicator in Indicators)
                    {
                        // Skip future months in the current year.
                        if (year == today.Year && month > today.Month)
                        {
                            continue;
                        }

                        var seasonalMultiplier = 0.85 + 0.30 * Math.Sin((month - 1) / 12.0 * Math.PI * 2);
                        var indicatorScale = indicator switch
                        {
                            "01-Inspections"        => 1.00,
                            "02-AvisNonConformite"  => 0.22,
                            "03-AmendesEmises"      => 0.08,
                            "04-PermisSuspendus"    => 0.015,
                            _                       => 1.00
                        };
                        var noise = 0.85 + rng.NextDouble() * 0.30;
                        var value = (decimal)Math.Round(baseline * seasonalMultiplier * indicatorScale * noise, 0);

                        rollups.Add(new InspectionRollup
                        {
                            Region = region,
                            Year = year,
                            Month = month,
                            IndicatorCode = indicator,
                            Value = value
                        });
                    }
                }
            }
        }
        db.InspectionRollups.AddRange(rollups);

        // ---- Sync jobs: a couple of recent successful runs for the dashboard ----
        db.SyncJobs.AddRange(new[]
        {
            new SyncJob
            {
                StartedUtc = DateTime.UtcNow.AddDays(-7),
                CompletedUtc = DateTime.UtcNow.AddDays(-7).AddSeconds(45),
                Status = "Succeeded",
                RowsRead = 16203,
                RowsUpserted = 1432,
                OperationId = "demo-seed-week"
            },
            new SyncJob
            {
                StartedUtc = DateTime.UtcNow.AddHours(-3),
                CompletedUtc = DateTime.UtcNow.AddHours(-3).AddSeconds(58),
                Status = "Succeeded",
                RowsRead = 16241,
                RowsUpserted = 38,
                OperationId = "demo-seed-today"
            }
        });

        db.SaveChanges();
    }

    private static int WeightedZeroBiased(Random rng, int max)
    {
        // ~50% have 0 convictions, ~25% have 1, then taper.
        var roll = rng.NextDouble();
        if (roll < 0.50) { return 0; }
        if (roll < 0.75) { return 1; }
        if (roll < 0.90) { return 2; }
        if (roll < 0.97) { return 3; }
        return rng.Next(4, max + 1);
    }

    private static double BaselineFor(string region) => region switch
    {
        "06-MONTREAL"            => 420,
        "16-MONTEREGIE"          => 260,
        "03-CAPITALE-NATIONALE"  => 220,
        "13-LAVAL"               => 180,
        "12-CHAUDIERE-APPALACHES" => 130,
        "07-OUTAOUAIS"           => 120,
        "14-LANAUDIERE"          => 110,
        "15-LAURENTIDES"         => 110,
        "05-ESTRIE"              =>  95,
        "04-MAURICIE"            =>  80,
        "17-CENTRE-DU-QUEBEC"    =>  70,
        "02-SAGUENAY-LAC-SAINT-JEAN" => 65,
        "01-BAS-SAINT-LAURENT"   =>  45,
        "08-ABITIBI-TEMISCAMINGUE" => 40,
        "11-GASPESIE-ILES-DE-LA-MADELEINE" => 30,
        "09-COTE-NORD"           =>  25,
        "10-NORD-DU-QUEBEC"      =>  15,
        _                         =>  60
    };

    private static string GeneratePostalCode(Random rng)
    {
        const string letters = "ABCEGHJKLMNPRSTVXY";
        char L() => letters[rng.Next(letters.Length)];
        char D() => (char)('0' + rng.Next(10));
        return $"{L()}{D()}{L()} {D()}{L()}{D()}";
    }
}
