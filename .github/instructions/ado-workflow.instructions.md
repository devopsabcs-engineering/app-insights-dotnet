---
description: "Required workflow for Azure DevOps work item tracking, Git branching, pull requests, and branch cleanup in the AppInsightsDotNet project."
applyTo: "**"
maturity: stable
---

# Azure DevOps Workflow

## ADO Organization and Project

* Organization: `MngEnvMCAP675646`
* Project: `AppInsightsDotNet`

All work items, boards, and test plans live in this project.

## Work Item Hierarchy

Follow this strict hierarchy for every piece of work:

```text
Epic
 └── Feature
      ├── User Story
      └── Bug
```

* Every commit must trace back to a User Story or Bug.
* Every User Story or Bug must belong to a Feature.
* Every Feature must belong to an Epic.
* Create the parent items first if they do not exist before creating child items.
* When creating the hierarchy from scratch, create items top-down (Epic → Feature → User Story/Bug) and record each assigned ID before proceeding. Do not create the branch until the User Story or Bug ID is confirmed.
* Every work item (Epic, Feature, User Story, Bug) must include the tag `Agentic AI`.

## Branching Strategy

Create a feature branch for each work item using this naming convention:

```text
feature/{work-item-id}-short-description
```

Examples:

```text
feature/1234-citizen-submission-form
feature/1235-fix-notification-bug
```

Rules:

* One branch per User Story or Bug.
* If a User Story requires parallel sub-tasks, create child Task work items under the User Story and open one branch per Task, naming them `feature/{task-id}-short-description`. Each Task must still link back to its parent User Story.
* Use lowercase and hyphens for the description portion.
* Keep the description concise (three to five words).
* Branch from `main` unless otherwise specified.

## Commit Messages

Include the ADO work item ID in every commit message using the `AB#` linking syntax:

```text
feat: add citizen submission form AB#1234
fix: correct notification email template AB#1235
```

This links commits to ADO work items automatically through GitHub and Azure DevOps integration.

Use plain `AB#{id}` (without `Fixes`) when you only want to link the commit. Use `Fixes AB#{id}` only when you want the work item to auto-close on merge. These two forms are mutually exclusive: never combine both in the same message (for example, do not write `AB#1234 Fixes AB#1234`).

To auto-close a work item when the PR merges, add `Fixes AB#{id}` to the PR description (preferred). If squash-merging, you may alternatively include it in the squash commit message. Do not use both simultaneously:

```text
feat: add citizen submission form Fixes AB#1234
```

## Pull Request Workflow

1. Push the feature branch to the remote.
2. Create a pull request targeting `main`.
3. Reference the work item in the PR description using `Fixes AB#{work-item-id}` to auto-close the work item on merge.
4. Complete code review and obtain required approvals.
5. Merge the PR (squash merge preferred for a clean history).

## Post-Merge Branch Cleanup

After the pull request is merged and closed in GitHub:

1. Switch to `main` locally:

   ```bash
   git checkout main
   ```

2. Pull the latest changes:

   ```bash
   git pull origin main
   ```

3. Delete the remote branch:

   ```bash
   git push origin --delete feature/{work-item-id}-short-description
   ```

4. Delete the local branch:

   ```bash
   git branch -d feature/{work-item-id}-short-description
   ```

   If `git branch -d` fails because Git reports unmerged changes (which can occur if the local branch was never fully synced), verify the PR is merged in GitHub, then force-delete with `git branch -D feature/{work-item-id}-short-description`.

Always delete both the remote and local feature branch after a successful merge. Do not keep stale branches.

## Quick Reference

| Step | Command or Action |
|------|-------------------|
| Create branch | `git checkout -b feature/{id}-description` |
| Commit with link | `git commit -m "feat: description AB#{id}"` |
| Push branch | `git push -u origin feature/{id}-description` |
| Create PR | Target `main`, reference `AB#{id}` |
| After merge: sync | `git checkout main && git pull origin main` |
| After merge: delete remote | `git push origin --delete feature/{id}-description` |
| After merge: delete local | `git branch -d feature/{id}-description` |
