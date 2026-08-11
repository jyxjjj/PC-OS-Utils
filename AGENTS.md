# Agent Instructions

## Issues

Before creating an issue, review the available issue templates in the `.github`
directory.

When drafting the issue:

- Use the title format required by the template.
- Fill in or remove each section according to the template guidance.
- Include testing details, or explain why testing was not run.
- Do not invent testing results.
- Do not claim validation, verification, or review steps that were not actually
  performed.

## Automated Contributions

Fully automated contributions are not considered equivalent to normal community
participation.

A contribution may be considered fully automated if it is submitted through an
automated agent, or if the submitting account participates in project
discussions through an automated agent, without meaningful human review or
intervention.

When making this determination, maintainers may consider the overall behavior of
the account, including but not limited to disclosed agent usage, interaction
patterns, response characteristics, and other available evidence. No single
factor is determinative.

Maintainers reserve the right to accept, reject, modify, or reimplement any
contribution independently of any action taken against the submitting account.
Acceptance of a contribution does not imply acceptance of the submitting account
or its contribution method. If an account is determined to be primarily operated
through automated processes, we may need to restrict its future participation in
contributions until that determination is rescinded.

## Git Commits

When creating commits, follow the repository `git-commit` skill rules:

- Use Conventional Commits title format: `type(scope): subject`.
- Allowed types: `feat`, `fix`, `refactor`, `perf`, `docs`, `style`, `test`,
  `build`, `ci`, `chore`, `revert`.
- Use a meaningful scope based on the main module, package, or feature.
- Write the subject in imperative mood and describe the actual change.
- Use a concise Markdown list in the commit body, with each item describing one
  key change.
- Do not invent changes that are not present in the diff.
- Do not describe behavior, refactors, fixes, or tests that are not reflected in
  the commit.

Include at most one `Co-authored-by` trailer that matches the AI assistant
actually used to produce the change.

Examples:

- `Co-authored-by: Codex <267193182+codex@users.noreply.github.com>`
- `Co-authored-by: GitHub Copilot <copilot@github.com>`
- `Co-authored-by: Claude <81847+claude@users.noreply.github.com>`

If you are not one of the listed assistants, do not add a `Co-authored-by`
trailer.

Instead, ask the human collaborator to provide the exact `Co-authored-by`
trailer to use. Do not invent, infer, or generate one yourself.

## Project Scope

This branch contains several independent macOS utilities.

- Keep changes limited to the affected utility or module.
- Do not modify multiple utilities unless the task actually requires it.
- Do not regenerate or replace checked-in executable files unless explicitly
  requested.

## Project Areas

- `AppleTerminalFixer` contains shell tooling that modifies system behavior and
  installs a system launchd service.
- `ScreenShotsWatcher` contains a standalone Swift tool and related shell
  scripts. It modifies screenshot settings, installs a user launchd service,
  accesses screenshot files and the clipboard, and may move or delete files.
- `Utilities` is a native SwiftUI macOS application containing `Authenticator`
  and `SubTrack`. `Authenticator` handles TOTP data and its import and export;
  `SubTrack` uses local persistent storage to manage subscriptions and purchase
  records.

## Safety

- Do not execute scripts that install launchd services, modify system settings,
  or modify system files without explicit authorization.
- Use synthetic data when testing authentication, import, export, and
  persistence features.
- Do not include real TOTP secrets, credentials, private screenshots, or other
  personal data in source code, logs, screenshots, or test data.
