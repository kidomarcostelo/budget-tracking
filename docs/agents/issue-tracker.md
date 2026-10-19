# Issue tracker: GitHub & Local Markdown

Issues and specs for this repo live as GitHub issues on the fork (`kidomarcostelo/budget-tracking`). Use the `gh` CLI for all operations, explicitly targeting the fork.

Local scratchpads, offline tracking, and working notes live under `.scratch/<feature>/`.

## Target Repository

- Primary fork: `kidomarcostelo/budget-tracking`
- Always pass `--repo kidomarcostelo/budget-tracking` to `gh` commands to ensure operations target your fork instead of upstream (`jameskokoska/Cashew`).

## Conventions

- **Create an issue**: `gh issue create --repo kidomarcostelo/budget-tracking --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --repo kidomarcostelo/budget-tracking --json number,title,body,labels,comments`.
- **List issues**: `gh issue list --repo kidomarcostelo/budget-tracking --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Make an issue a sub-issue of a parent**: `gh issue create --repo kidomarcostelo/budget-tracking --parent <parent> ...`, or `gh issue edit <parent> --repo kidomarcostelo/budget-tracking --add-sub-issue <child>` afterwards (`gh` 2.94+). Older `gh`: `gh api --method POST repos/kidomarcostelo/budget-tracking/issues/<parent>/sub_issues -F sub_issue_id=<child-db-id>` (database id, as in **Blocking** below). Without sub-issues, put `Part of #<parent>` at the top of the child body.
- **Comment on an issue**: `gh issue comment <number> --repo kidomarcostelo/budget-tracking --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --repo kidomarcostelo/budget-tracking --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --repo kidomarcostelo/budget-tracking --comment "..."`

## Local Markdown (.scratch/)

- Issues, drafts, and notes can be stored locally as markdown files under `.scratch/<feature>/` in this repo.
- For local or offline tasks, markdown files under `.scratch/<feature>/` serve as the ticket source before or alongside publishing to GitHub.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr` equivalents (with `--repo kidomarcostelo/budget-tracking`):

- **Read a PR**: `gh pr view <number> --repo kidomarcostelo/budget-tracking --comments` and `gh pr diff <number> --repo kidomarcostelo/budget-tracking` for the diff.
- **List external PRs for triage**: `gh api --paginate 'repos/kidomarcostelo/budget-tracking/pulls?state=open' --jq '.[] | select(.author_association | IN("OWNER","MEMBER","COLLABORATOR") | not) | {number, title, author: .user.login, author_association, labels: [.labels[].name]}'`.
- **Comment / label / close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either: resolve with `gh pr view 42 --repo kidomarcostelo/budget-tracking` and fall back to `gh issue view 42 --repo kidomarcostelo/budget-tracking`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue in `kidomarcostelo/budget-tracking`.

## When a skill says "fetch the relevant ticket"

Read it as in **Read an issue** above. If a local ticket is specified, read the corresponding file in `.scratch/<feature>/`.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body: `gh issue create --repo kidomarcostelo/budget-tracking --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue (see **Make an issue a sub-issue of a parent**). Where sub-issues aren't enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: GitHub's **native issue dependencies**, the canonical, UI-visible representation. Add an edge with `gh api --method POST repos/kidomarcostelo/budget-tracking/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is the blocker's numeric **database id** (`gh api repos/kidomarcostelo/budget-tracking/issues/<n> --jq .id`, _not_ the `#number` or `node_id`). GitHub reports `issue_dependencies_summary.blocked_by` (open blockers only, the live gate). Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's open children (`gh issue list --repo kidomarcostelo/budget-tracking --state open`, scoped to the map's sub-issues / task list), drop any with an open blocker (`issue_dependencies_summary.blocked_by > 0`, or an open issue in the `Blocked by` line) or an assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --repo kidomarcostelo/budget-tracking --add-assignee @me`, the session's first write.
- **Resolve**: `gh issue comment <n> --repo kidomarcostelo/budget-tracking --body "<answer>"`, then `gh issue close <n> --repo kidomarcostelo/budget-tracking`, then append a context pointer (gist + link) to the map's Decisions-so-far.
