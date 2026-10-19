# Scratch Workspace (.scratch/)

This directory holds local issue tracking, implementation notes, exploratory spikes, and pre-publish task drafts for human developers and AI agents.

## Usage
- Create a subfolder for each task named `.scratch/BT-N-<slug>/` (for example `.scratch/BT-2-plan-bank-email-duplicate-detection/`). Take the next ID from `.scratch/index.md`.
- Copy `.scratch/templates/task.md` into `.scratch/BT-N-<slug>/task.md`
- Add the task to `.scratch/index.md` in ID order and bump its `Next ID`. IDs are never renumbered.
- Use the markdown file to track subtasks, store intermediate findings, and plan work offline before (or alongside) publishing to GitHub Issues.
- Files under `.scratch/` can be committed or kept locally.
