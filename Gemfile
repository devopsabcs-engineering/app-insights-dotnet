# frozen_string_literal: true

# Gemfile — App Insights .NET 10 Workshop (MAPAQ)
# Pinned to the github-pages gem so the local build matches the GitHub Pages
# runtime exactly. The repo deploys via the `actions/jekyll-build-pages` action,
# which uses the same gem set under the hood.

source "https://rubygems.org"

# Pin to github-pages for runtime parity with GitHub Pages.
gem "github-pages", group: :jekyll_plugins

# Plugins not bundled by default with github-pages but used by this site.
group :jekyll_plugins do
  gem "jekyll-remote-theme"
  gem "jekyll-include-cache"
  gem "jekyll-seo-tag"
end

# Required on Ruby >= 3.0 for `jekyll serve` to start a local web server.
gem "webrick", "~> 1.8"
