namespace Mapaq.Web;

/// <summary>
/// Marker type for shared (cross-page) localization resources.
/// Resources live under <c>Resources/SharedResource.{culture}.resx</c>.
/// The marker is intentionally placed in the <c>Mapaq.Web</c> namespace
/// (not <c>Mapaq.Web.Resources</c>) so that combined with
/// <c>RequestLocalizationOptions.ResourcesPath = "Resources"</c>, the
/// resource manager resolves <c>Resources/SharedResource.resx</c>
/// rather than <c>Resources/Resources/SharedResource.resx</c>.
/// </summary>
public sealed class SharedResource
{
}
