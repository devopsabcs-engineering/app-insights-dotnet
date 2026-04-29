<!-- markdownlint-disable MD013 -->
# Contributing

Thanks for helping improve the MAPAQ App Insights .NET 10 workshop.

## Bilingual parity rule

Content is authored in **English first** but **French is the published default** language. Every change to a lab, deck slide, or top-level prose page must:

1. Update the English source (`labs/`, `index.md`, `slides/content/en/deck.yaml`, `README.md`).
2. Update the French parallel (`fr/labs/`, `fr/index.md`, `slides/content/fr/deck.yaml`, the `## En français` section in `README.md`).
3. Keep stable slide `key:` values aligned across `slides/content/en/deck.yaml` and `slides/content/fr/deck.yaml`.

Pull requests that update only one language will be marked **Changes requested** until parity is restored.

## Local checks before pushing

```pwsh
dotnet build Mapaq.sln /warnaserror
dotnet test Mapaq.sln
bicep build infra/main.bicep
markdownlint-cli2 "**/*.md"
bundle exec jekyll build --baseurl /app-insights-dotnet
node slides/build/render-mermaid.mjs
node slides/build/build-html-deck.mjs
python slides/build/build-pptx-deck.py
actionlint .github/workflows/*.yml
```

If you do not have one or more toolchains installed locally, the equivalent workflows in [`.github/workflows/`](.github/workflows/) will run them in CI.

## Commit messages

Follow Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `ci:`. Keep the subject line in **English** for grep-ability; the body may contain a French paragraph if the change is content-only.

## En français — Contribuer

Le contenu est rédigé d'abord en **anglais** mais le **français est la langue publiée par défaut**. Chaque modification doit mettre à jour les deux versions (EN sous `labs/`, FR sous `fr/labs/`). Les demandes de tirage qui n'actualisent qu'une seule langue seront refusées jusqu'à rétablissement de la parité.

Avant de pousser : exécutez les commandes ci-dessus pour valider .NET, Bicep, Markdown, Jekyll, les diaporamas et les workflows GitHub Actions.
