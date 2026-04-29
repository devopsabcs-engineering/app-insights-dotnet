using System.Globalization;
using System.Reflection;

namespace Mapaq.Infrastructure;

/// <summary>
/// Loads CSV seed files shipped under <c>data/seed/</c> at design time.
/// Used by <see cref="MapaqDbContext.OnModelCreating"/> via <c>HasData</c>
/// so EF Core migrations can embed a small representative dataset without
/// performing runtime IO from the application itself.
/// </summary>
public static class SeedLoader
{
    /// <summary>
    /// Resolves a CSV file under the repository's <c>data/seed/</c> folder.
    /// Walks up from the assembly location looking for the <c>data/seed</c>
    /// folder; returns an empty collection if the file cannot be found
    /// (the Distro / EF Core tooling will then emit no <c>HasData</c> rows).
    /// </summary>
    /// <param name="fileName">CSV file name (e.g. <c>condamnations.csv</c>).</param>
    /// <returns>Parsed rows where each row is a dictionary keyed by header.</returns>
    public static IReadOnlyList<IReadOnlyDictionary<string, string>> Load(string fileName)
    {
        var path = ResolvePath(fileName);
        if (path is null)
        {
            return Array.Empty<IReadOnlyDictionary<string, string>>();
        }

        var lines = File.ReadAllLines(path);
        if (lines.Length < 2)
        {
            return Array.Empty<IReadOnlyDictionary<string, string>>();
        }

        var headers = SplitCsv(lines[0]);
        var rows = new List<IReadOnlyDictionary<string, string>>(lines.Length - 1);
        for (var i = 1; i < lines.Length; i++)
        {
            var values = SplitCsv(lines[i]);
            var row = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            for (var c = 0; c < headers.Count && c < values.Count; c++)
            {
                row[headers[c]] = values[c];
            }
            rows.Add(row);
        }
        return rows;
    }

    /// <summary>
    /// Parses a decimal value using the invariant culture, returning
    /// <c>0</c> when the input is null, empty, or unparseable.
    /// </summary>
    public static decimal ParseDecimal(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return 0m;
        }
        return decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out var d)
            ? d
            : 0m;
    }

    /// <summary>
    /// Parses an ISO-8601 date (<c>yyyy-MM-dd</c>), returning <c>DateOnly.MinValue</c>
    /// when the input is null, empty, or unparseable.
    /// </summary>
    public static DateOnly ParseDate(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return DateOnly.MinValue;
        }
        return DateOnly.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.None, out var d)
            ? d
            : DateOnly.MinValue;
    }

    private static string? ResolvePath(string fileName)
    {
        var dir = Path.GetDirectoryName(typeof(SeedLoader).Assembly.Location)
                  ?? AppContext.BaseDirectory;
        for (var i = 0; i < 8 && dir is not null; i++)
        {
            var candidate = Path.Combine(dir, "data", "seed", fileName);
            if (File.Exists(candidate))
            {
                return candidate;
            }
            dir = Path.GetDirectoryName(dir);
        }
        return null;
    }

    private static IReadOnlyList<string> SplitCsv(string line)
    {
        // Minimal RFC-4180-ish split: handles quoted fields with embedded commas.
        var result = new List<string>();
        var sb = new System.Text.StringBuilder();
        var inQuotes = false;
        for (var i = 0; i < line.Length; i++)
        {
            var ch = line[i];
            if (inQuotes)
            {
                if (ch == '"')
                {
                    if (i + 1 < line.Length && line[i + 1] == '"')
                    {
                        sb.Append('"');
                        i++;
                    }
                    else
                    {
                        inQuotes = false;
                    }
                }
                else
                {
                    sb.Append(ch);
                }
            }
            else if (ch == ',')
            {
                result.Add(sb.ToString());
                sb.Clear();
            }
            else if (ch == '"')
            {
                inQuotes = true;
            }
            else
            {
                sb.Append(ch);
            }
        }
        result.Add(sb.ToString());
        return result;
    }
}
