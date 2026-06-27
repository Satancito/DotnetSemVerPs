# Release Version Guide

This file defines the required workflow for publishing changes from this repository to the remote Git repository.

This file is for this repository only. For reusable agent instructions that are copied into other repositories, use:

```text
Version-Agent.MD
```

## Release Flow

1. Decide the next SemVer version before editing any version value.

   Review all changes already made in the working tree and choose the next version based on their public impact.

   Example version:

   ```text
   1.16.1
   ```

   Use semantic versioning to decide which part of the version must be increased:

   - Increase **Major** for breaking changes, removed parameters, renamed flags, incompatible output changes, incompatible `.csproj` property behavior, incompatible release behavior, or any change that requires consumers to update their usage.
   - Increase **Minor** for new commands, new flags, new behavior, new release workflows, new documentation workflows, or backward-compatible features.
   - Increase **Patch** for bug fixes, help text fixes, README fixes, LEEME fixes, release guide fixes, agent instruction fixes, small internal improvements, or any change that does not alter public behavior.

   Examples:

   ```text
   1.16.0 -> 1.16.1  Patch
   1.16.0 -> 1.17.0  Minor
   1.16.0 -> 2.0.0   Major
   ```

2. Update the selected version everywhere it is represented.

   Update the script version in:

   ```text
   Version.ps1
   ```

   Update the script version test expectation in:

   ```text
   Version-Tests.ps1
   ```

   Update any documentation that shows the current version, such as:

   ```text
   README.md
   LEEME.md
   Version-Agent.MD
   ```

   Add or update the matching release notes in:

   ```text
   CHANGELOG.md
   ```

## Update Usage And Documentation

Always update the command usage exposed by:

```powershell
./Version.ps1 -Usage
```

The `-Usage` output must describe the current parameters, parameter sets, behavior, return values, release rules, and important safety rules.

Also update repository documentation when the change affects usage, installation, release flow, Conventional Commits, agent instructions, or generated output:

```text
README.md
LEEME.md
CHANGELOG.md
Version-Agent.MD
Version.MD
```

Keep `README.md` and `LEEME.md` aligned. Keep `Version-Agent.MD` focused on reusable agent workflow for other repositories. Keep this `Version.MD` focused on releasing this repository itself.

## Validate Before Commit

Validate the PowerShell script before staging:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path ./Version.ps1), [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { $_.Message }
    exit 1
}
```

Confirm the script returns the expected version:

```powershell
./Version.ps1 -Version
```

Run the full test suite:

```powershell
./Version-Tests.ps1
```

The full test suite must run and pass before commit. If tests fail, hang, cannot be executed, or cannot be verified, stop the release immediately. Do not stage, commit, tag, or push until the test problem is fixed and the full suite passes.

## Stage Changes

Stage only the files required for the release.

Do not stage local project environment files, temporary files, generated scratch files, or unrelated changes unless the release explicitly requires them.

Example:

```powershell
git add Version.ps1 Version-Tests.ps1 README.md LEEME.md CHANGELOG.md Version-Agent.MD Version.MD
```

Adjust the staged file list to match the actual changes.

## Commit

Create a commit using Conventional Commits. Use a short subject and a detailed body when the change needs context for future changelog generation.

Example:

```powershell
git commit -m "docs: update release guide" -m "Update the internal release guide for DotnetSemVerPs with the current validation, documentation, staging, tagging, and push workflow. This change does not alter script behavior."
```

Use commit types according to the release impact:

- `feat` for backward-compatible features.
- `fix` or `perf` for patch-level runtime changes.
- `docs` for documentation-only changes.
- `test` for test-only changes.
- `chore`, `refactor`, `style`, `build`, or `ci` for maintenance changes that do not affect runtime behavior.
- Add `!` or `BREAKING CHANGE:` only for breaking changes.

Do not include personal data, secrets, credentials, tokens, certificates, private URLs, or connection strings in commit messages.

## Tag

Create a Git tag using only the SemVer release version.

Example:

```powershell
git tag 1.16.1
```

Do not prefix the tag with `v`.

## Push

Push the branch:

```powershell
git push origin main
```

Push the release tag:

```powershell
git push origin 1.16.1
```

## Final Check

Confirm the working tree is clean:

```powershell
git status --short
```

Confirm the tag points at the release commit:

```powershell
git tag --points-at HEAD
```

Confirm the tag exists on the remote:

```powershell
git ls-remote --tags origin 1.16.1
```
