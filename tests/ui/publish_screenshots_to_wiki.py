"""
Render the Playwright screenshots from the latest pipeline run into a project
wiki page (Markdown). Designed to be executed inside an Azure DevOps job after
Playwright has produced PNGs in `tests/ui/screenshots/`.

Workflow when invoked from .azuredevops/pipelines/ui-tests.yml:

    1. Clone the project wiki Git repo (`<project>.wiki`) into a temp folder.
    2. Copy every PNG from --screenshots-dir into
       `.attachments/ui-tests/build-<id>/` so the images live alongside the wiki
       (project wikis serve `.attachments/...` as the canonical image storage).
    3. Generate `UI-Tests-Latest.md` referencing the freshly copied images.
    4. Commit + push back to the wiki branch (default `wikiMaster`).

Authentication: the script relies on Git credentials already configured in the
caller (typically the pipeline injects an `Authorization: Bearer $SYSTEM_ACCESSTOKEN`
header via `git -c http.extraHeader=...`). This script never reads PATs itself.

Usage:

    python publish_screenshots_to_wiki.py \\
        --wiki-repo-url https://dev.azure.com/MngEnvMCAP675646/AppInsightsDotNet/_git/AppInsightsDotNet.wiki \\
        --screenshots-dir tests/ui/screenshots \\
        --build-id $(Build.BuildId) \\
        --build-number $(Build.BuildNumber) \\
        --build-url   $(System.CollectionUri)$(System.TeamProject)/_build/results?buildId=$(Build.BuildId) \\
        --target-env  $(targetEnv) \\
        --git-user    "Mapaq UI Pipeline" \\
        --git-email   pipeline@mapaq.local

Pure-stdlib so no `pip install` step is required on the agent.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def _run(cmd: list[str], cwd: str | None = None, check: bool = True, env: dict[str, str] | None = None) -> int:
    """Run *cmd*, streaming its output. Raise on non-zero when *check*."""
    print(f"::> {' '.join(cmd)}")
    proc = subprocess.run(cmd, cwd=cwd, env=env, check=False)
    if check and proc.returncode != 0:
        raise SystemExit(f"Command failed (exit {proc.returncode}): {' '.join(cmd)}")
    return proc.returncode


def _build_markdown(
    *,
    images: list[Path],
    attachments_relpath: str,
    build_number: str,
    build_id: str,
    build_url: str,
    target_env: str,
    timestamp: _dt.datetime,
) -> str:
    """Return the wiki page body as Markdown."""
    lines: list[str] = []
    lines.append("# Mapaq UI tests — latest run")
    lines.append("")
    lines.append(
        "_Auto-generated from the most recent successful run of the_ "
        "[Mapaq UI Tests pipeline]("
        f"{build_url})._"
    )
    lines.append("")
    lines.append("| Field | Value |")
    lines.append("|---|---|")
    lines.append(f"| Build number | `{build_number}` |")
    lines.append(f"| Build id | `{build_id}` |")
    lines.append(f"| Target environment | `{target_env}` |")
    lines.append(f"| Captured (UTC) | `{timestamp.strftime('%Y-%m-%d %H:%M:%S')}` |")
    lines.append(f"| Screenshots | `{len(images)}` |")
    lines.append("")
    lines.append("## Screenshots")
    lines.append("")
    for img in sorted(images, key=lambda p: p.name.lower()):
        # Title from the file stem: "etablissements--search-region-montreal" → "etablissements · search-region-montreal"
        stem = img.stem
        if "--" in stem:
            spec, name = stem.split("--", 1)
            title = f"{spec} · {name.replace('-', ' ')}"
        else:
            title = stem.replace("-", " ")
        rel = f"/{attachments_relpath}/{img.name}".replace("\\", "/")
        lines.append(f"### {title}")
        lines.append("")
        lines.append(f"![{img.name}]({rel})")
        lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument("--wiki-repo-url", required=True, help="HTTPS URL of the wiki Git repo.")
    parser.add_argument("--screenshots-dir", required=True, help="Folder containing the *.png screenshots.")
    parser.add_argument("--build-id", required=True)
    parser.add_argument("--build-number", required=True)
    parser.add_argument("--build-url", required=True)
    parser.add_argument("--target-env", required=True, help="Free-form label, e.g. 'dev-001' or 'azurewebsites.net'.")
    parser.add_argument("--git-user", default="Mapaq UI Pipeline")
    parser.add_argument("--git-email", default="pipeline@mapaq.local")
    parser.add_argument("--branch", default="wikiMaster", help="Branch to push to (project wikis use 'wikiMaster').")
    parser.add_argument("--page-name", default="UI-Tests-Latest", help="Wiki page filename (no extension).")
    parser.add_argument("--retain-runs", type=int, default=10, help="How many historical attachment folders to keep.")
    args = parser.parse_args(argv)

    screenshots = sorted(Path(args.screenshots_dir).glob("*.png"))
    if not screenshots:
        print(f"##vso[task.logissue type=warning]No PNG screenshots found in {args.screenshots_dir}; nothing to publish.")
        return 0

    timestamp = _dt.datetime.now(_dt.timezone.utc)

    with tempfile.TemporaryDirectory(prefix="mapaq-wiki-") as tmp:
        wiki_dir = Path(tmp) / "wiki"
        _run(["git", "clone", "--depth", "1", "--branch", args.branch, args.wiki_repo_url, str(wiki_dir)])

        _run(["git", "config", "user.name", args.git_user], cwd=str(wiki_dir))
        _run(["git", "config", "user.email", args.git_email], cwd=str(wiki_dir))

        attachments_relpath = f".attachments/ui-tests/build-{args.build_id}"
        attachments_dir = wiki_dir / attachments_relpath
        attachments_dir.mkdir(parents=True, exist_ok=True)
        for src in screenshots:
            shutil.copy2(src, attachments_dir / src.name)

        # Retain only the most recent N historical attachment folders to stop the
        # wiki repo from growing without bound across hundreds of pipeline runs.
        ui_tests_root = wiki_dir / ".attachments" / "ui-tests"
        if ui_tests_root.exists() and args.retain_runs > 0:
            run_dirs = sorted(
                (p for p in ui_tests_root.iterdir() if p.is_dir() and p.name.startswith("build-")),
                key=lambda p: p.stat().st_mtime,
                reverse=True,
            )
            for stale in run_dirs[args.retain_runs:]:
                print(f"Pruning stale attachment folder: {stale.relative_to(wiki_dir)}")
                shutil.rmtree(stale, ignore_errors=True)

        page_body = _build_markdown(
            images=screenshots,
            attachments_relpath=attachments_relpath,
            build_number=args.build_number,
            build_id=args.build_id,
            build_url=args.build_url,
            target_env=args.target_env,
            timestamp=timestamp,
        )
        page_path = wiki_dir / f"{args.page_name}.md"
        page_path.write_text(page_body, encoding="utf-8")

        # Stage everything (including pruned files via -A so deletions are recorded).
        _run(["git", "add", "-A"], cwd=str(wiki_dir))

        # Skip the commit when nothing actually changed (re-run on identical content).
        diff_status = subprocess.run(
            ["git", "diff", "--cached", "--quiet"], cwd=str(wiki_dir), check=False
        ).returncode
        if diff_status == 0:
            print("No wiki changes to commit; skipping push.")
            return 0

        commit_msg = f"UI tests build {args.build_number} ({args.target_env}) — {len(screenshots)} screenshot(s)"
        _run(["git", "commit", "-m", commit_msg], cwd=str(wiki_dir))
        _run(["git", "push", "origin", args.branch], cwd=str(wiki_dir))

    print(f"Published {len(screenshots)} screenshot(s) to wiki page '{args.page_name}'.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
