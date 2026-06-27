# Version Agent Instructions

These instructions define the required release workflow for this repository.

Expected `DotnetSemVerPs` script version: `1.16.1` or newer.

## Project Path File

Project handled by this release workflow:

```powershell
$ProjectPath = Get-Content "ProjectPath.txt" -Raw
```

When this file is reused in another .NET repository, create `ProjectPath.txt` in the repository root if it does not exist. If it already exists, update it only when the target project path must change. The file content must be the unixlike path to the target `.csproj` file relative to the repository root, without a leading `./`, for example:

```text
MySolution/MyProject/MyProject.csproj
```

Do not edit `$ProjectPath` in this file. The agent reads the project path from `ProjectPath.txt`.

## Goal

Create a safe release by:

- validating the current code before versioning
- committing the actual change with Conventional Commits
- letting `Tools/DotnetSemVerPs/Version.ps1` calculate the SemVer release
- letting the script create and push the release commit and Git tag

The agent must not calculate the next version manually.

## Required Flow

Always execute the release workflow in this order:

1. Ensure the `Tools/DotnetSemVerPs` submodule exists.

   If the submodule does not exist, add it:

   ```powershell
   git submodule add https://github.com/Satancito/DotnetSemVerPs.git Tools/DotnetSemVerPs
   ```

   If the submodule already exists, do not add it again.

2. Sync and update the `Tools/DotnetSemVerPs` submodule.

   ```powershell
   git submodule sync --recursive Tools/DotnetSemVerPs
   git submodule update --init --recursive Tools/DotnetSemVerPs
   git submodule update --remote --recursive Tools/DotnetSemVerPs
   ```

3. Refresh this file from the updated submodule instructions only when the submodule has new changes.

   If step 2 updates `Tools/DotnetSemVerPs` to a new commit, copy the updated agent instructions from:

   ```text
   Tools/DotnetSemVerPs/Agent-DotnetSemVerPs.MD
   ```

   ```powershell
   Copy-Item -Path ./Tools/DotnetSemVerPs/Agent-DotnetSemVerPs.MD -Destination ./Agent-DotnetSemVerPs.MD -Force
   ```

   Replace the root `Agent-DotnetSemVerPs.MD` with that file. Do not preserve or edit `$ProjectPath` in the Markdown file because the project path is read from root `ProjectPath.txt`.

   If step 2 does not update the submodule to a new commit, do not copy `Agent-DotnetSemVerPs.MD`; continue with the current root file.

4. Inspect the working tree and identify only the files that belong to the current change.

   ```powershell
   git status --short
   ```

5. Build the project referenced by `$ProjectPath`.

   ```powershell
   dotnet build $ProjectPath --configuration Release
   ```

6. Run tests if test projects exist.

   ```powershell
   dotnet test --configuration Release
   ```

   If no test projects exist, state that tests were not available and continue only after the build succeeds.

7. Stage only files that belong to the current change.

   ```powershell
   git add <required-file-1> <required-file-2>
   ```

   Prefer explicit file paths. Use `git add -A` only when every current change has been inspected and belongs to the commit.

8. Review staged changes for secrets, credentials, private URLs, connection strings, certificates, tokens, or sensitive personal data.

   ```powershell
   git diff --cached
   ```

9. Create one or more normal commits as needed.

   ```powershell
   git commit -m "<type>: <description>"
   ```

   Every commit must use Conventional Commits. Use a short description in the subject and add a longer body when the change needs details for a future changelog. Make the longer description as detailed as possible: include what changed, why it changed, relevant implementation details, user-visible impact, validation performed, and any limitations or follow-up notes. Do not include personal data, secrets, credentials, tokens, certificates, private URLs, or connection strings.

   ```powershell
   git commit -m "<type>: <description>" -m "<longer description with relevant technical details>"
   ```

   Repeat steps 7 through 9 as needed until every intended change has been committed.

10. Confirm the Git working tree is completely clean before releasing.

   ```powershell
   git status --short
   ```

   Do not continue if there are untracked files, unstaged changes, or staged changes waiting to be committed.

11. Run `Version.ps1 -Release` against `$ProjectPath`.

   ```powershell
   ./Tools/DotnetSemVerPs/Version.ps1 -ProjectPath $ProjectPath -Release
   ```

   Do not pass `-Type` with `-Release`.

## Conventional Commits

Conventional Commits is the commit message format used by the release script to decide the next SemVer version. The agent must write the normal commit in this format before running `Version.ps1 -Release`.

Required format:

```text
<type>: <description>
```

Optional scope:

```text
<type>(<scope>): <description>
```

Examples:

```text
feat: add legal entity seed data
fix(auth): map invalid credentials to problem details
ci: clean up Azure pipeline deployment step
```

Commit message rules:

| Rule | Requirement |
|---|---|
| Format | Use `<type>: <description>` or `<type>(<scope>): <description>`. |
| Detail | Write enough detail to explain the technical change clearly. |
| Privacy | Do not include personal, private, or sensitive information. |
| Secrets | Do not include credentials, API keys, tokens, passwords, secrets, connection strings, certificates, or private URLs. |
| Staged review | Before committing, verify staged changes do not contain sensitive data. |

Commit types:

| Type | Use When | SemVer Impact |
|---|---|---|
| `feat` | Adds a backward-compatible feature or capability. | Minor |
| `fix` | Fixes a bug. | Patch |
| `perf` | Improves performance. | Patch |
| `docs` | Changes documentation only. | No increment |
| `test` | Changes tests only. | No increment |
| `chore` | Maintenance work that does not affect runtime behavior. | No increment |
| `refactor` | Restructures code without changing behavior. | No increment |
| `style` | Formatting-only change. | No increment |
| `build` | Changes build system, dependencies, or packaging. | No increment |
| `ci` | Changes CI/CD configuration or pipeline behavior. | No increment |
| `tag` | Release commit created by the version script. | No increment |
| Non-conventional message | Any message that does not follow Conventional Commits. | Ignored |

Breaking changes must be explicit:

```text
feat!: change public API contract
feat(api)!: change request payload format
```

Or in the commit body:

```text
BREAKING CHANGE: describe the incompatible behavior.
```

A breaking change always increments major, even when the commit type would normally have no version impact.

Breaking change examples:

| Commit Message | SemVer Impact |
|---|---|
| `feat!: remove legacy authentication flow` | Major |
| `feat(api)!: change request payload format` | Major |
| `fix!: rename public configuration property` | Major |
| `refactor(core)!: remove deprecated compatibility layer` | Major |
| `docs!: remove old documented API contract` | Major |

## Release Rules

- Do not release before build succeeds.
- Do not release before tests pass, when tests exist.
- Do not run `Version.ps1 -Release` with untracked, unstaged, or staged files.
- Do not create the release commit manually.
- Do not create the Git tag manually.
- Do not push manually after `Version.ps1 -Release`; the script pushes the branch and generated tag.
- Do not commit unrelated local changes.
- Prefer staging explicit file paths.
- Do not use `git add -A` unless every current change was inspected and belongs to the commit.
- Do not use prerelease or build metadata unless the user explicitly asks for it.
- Do not promote to stable unless the user explicitly asks for it.
- When the project already stores `PrereleaseName` or `BuildName`, `Version.ps1 -Release` publishes a non-stable SemVer tag using those project values.
- Existing release tags are never moved. If the generated stable or non-stable tag already exists, the script increments patch until it finds an available tag and updates the `.csproj` with that final SemVer value.
- If no test projects exist, state that tests were not available and continue only after build succeeds.

## Explicit Non-Release Versioning

Only use non-release versioning when the user explicitly asks for prerelease, build metadata, stable promotion, or local version preview.

Those commands are not part of the normal release flow and must not be mixed with `-Release`.

For exact parameter usage, read:

```text
Tools/DotnetSemVerPs/Readme.md
```
