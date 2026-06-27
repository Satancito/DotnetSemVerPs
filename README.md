# DotnetSemVerPs

PowerShell tooling for managing SemVer versions in .NET project files.

`DotnetSemVerPs` updates `.csproj` version properties, supports stable, prerelease, and build metadata flows, generates UTC epoch build numbers, and includes a test script to validate versioning scenarios.

Current script version: `1.16.0`.

### Features

- Updates `.csproj` files directly.
- Stores the full SemVer value in `Version`.
- Stores the numeric version core in `NumVer`.
- Supports stable versions, prerelease versions, build metadata versions, and prerelease plus build metadata versions.
- Generates `BuildNumber` as UTC epoch seconds on every version update.
- Creates missing version properties automatically.
- Can create and push Git release commits and SemVer tags with `-Release`.
- Can validate an external SemVer string with `-Validate -SemVer <semver>`.
- Can run the local test script with `-Tests`.
- Includes a test script with common versioning scenarios.

### Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes.

Spanish documentation is available in [LEEME.md](LEEME.md).

### Agent Instructions File

`Version-Agent.MD` is a reusable instruction file for coding agents that need to
apply this release workflow in another .NET repository.

To use it in a target repository:

1. Copy `Version-Agent.MD` to the desired repository root.
2. Create `ProjectPath.txt` in that same root folder.
3. Put only the unixlike path to the target `.csproj` file inside
   `ProjectPath.txt`. The path is relative to the repository root and should not
   start with `./`, for example `MySolution/MyProject/MyProject.csproj`.
4. Tell the agent to apply the instructions from `Version-Agent.MD`.

The agent should then follow the ordered workflow in `Version-Agent.MD`: ensure
or update the `Tools/DotnetSemVerPs` submodule, copy the latest
`Tools/DotnetSemVerPs/Version-Agent.MD` to the repository root, read the project
path from `ProjectPath.txt`, validate/build/test the project, create
Conventional Commits, and finally run `Version.ps1 -Release`.

### Version Properties

The script manages these properties in the target `.csproj`:

```xml
<Version>7.3.1-rc2.1+Build.1777848010</Version>
<NumVer>7.3.1</NumVer>
<BuildNumber>1777848010</BuildNumber>
<PrereleaseName>rc2.1</PrereleaseName>
<BuildName>Build</BuildName>
<IsPrerelease>True</IsPrerelease>
<IsBuild>True</IsBuild>
```

| Property | Description |
|---|---|
| `Version` | Full generated SemVer value. |
| `NumVer` | Numeric version only: `Major.Minor.Patch`. |
| `BuildNumber` | UTC epoch seconds generated on each version update. |
| `PrereleaseName` | Prerelease identifier, for example `rc`, `rc2`, `rc2.1`. |
| `BuildName` | Build metadata prefix, for example `Build`. |
| `IsPrerelease` | Indicates whether prerelease should be used. |
| `IsBuild` | Indicates whether build metadata should be used. |

When both `Version` and `NumVer` are missing or empty, the script starts from
`0.1.0` as the initial development version. Version updates then apply the
requested type from that base, so `-Type Patch` produces `0.1.1`.

### SemVer Output

Supported formats:

```text
7.3.0
7.3.0-rc
7.3.0+Build.4545454
7.3.0-rc2+Build.995269
7.3.0-rc2.1+Build.995269
```

### Usage

Show help:

```powershell
./Version.ps1 -Usage
```

Show the script version:

```powershell
./Version.ps1 -Version
```

Read or create the current project version:

```powershell
$projectVersion = & ./Version.ps1 -ProjectPath ./MyProject.csproj -Version
```

Read or create the current project build number:

```powershell
$projectBuildNumber = & ./Version.ps1 -ProjectPath ./MyProject.csproj -BuildNumber
```

Refresh the current project build number:

```powershell
$projectBuildNumber = & ./Version.ps1 -ProjectPath ./MyProject.csproj -BuildNumber -Refresh
```

Read the script version:

```powershell
$scriptVersion = & ./Version.ps1 -Version
```

Validate an external SemVer value:

```powershell
$validated = & ./Version.ps1 -Validate -SemVer 1.2.3-rc.1+Build.5
```

Print validation details while keeping the capturable output clean:

```powershell
$validated = & ./Version.ps1 -Validate -SemVer 1.2.3-rc.01 -Detailed
```

Run the local test script:

```powershell
./Version.ps1 -Tests
```

`-Usage` has its own parameter set. `-Version` can be used alone to return the
script version, or with `-ProjectPath` to return the current `.csproj` `Version`
value. If the project `Version` is missing or empty, the script creates `Version`
and `NumVer` with `0.1.0`, saves the project, and returns `0.1.0`.
`-BuildNumber` can be used with `-ProjectPath` to return the current
`.csproj` `BuildNumber` value; if it is missing or empty, the script creates one
with UTC epoch seconds and returns it. Add `-Refresh` to force a new UTC epoch
seconds value and save it to the project.

`-Validate -SemVer <semver>` returns the same version when it is valid SemVer
2.0.0, or empty output when it is invalid. `-Detailed` writes the validation
reason to the host so assignments like `$validated = & ./Version.ps1 ...` still
capture only the version or an empty value. Validation uses the SemVer.org
recommended regular expression with named groups, adapted to .NET named-group
syntax.

`-Tests` runs `Version-Tests.ps1` when it exists beside `Version.ps1`. If the
test file does not exist, the script prints that tests were not found.

Versioning syntax:

```powershell
./Version.ps1 -ProjectPath <path.csproj> -Type <Major|Minor|Patch> [options]
```

`-ProjectPath` and `-Type` are required for the versioning parameter set.

Create a local release commit and tag:

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Release
```

`-Release` has its own parameter set and must be used without `-Type`; the
release version is calculated from Conventional Commits. It first locates the
Git repository that contains the `.csproj` by
searching upward from the project file's folder. The project can be nested any
number of folders inside the repository; it only needs to be inside a valid Git
repo. The script then requires a completely clean Git working tree before it
starts: no untracked files, no unstaged changes, and no staged changes waiting to
be committed.

When the latest reachable Git tag is valid SemVer, `-Release` calculates the next
version from commits after that tag in chronological order using Conventional
Commits: breaking changes increment major, `feat` increments minor, and `fix` or
`perf` increment patch. Commit messages that are not Conventional Commits are
ignored by the calculation; Conventional Commit types that do not map to a bump,
such as `docs` or `test`, do not change the version. If no commit increments the
version, the generated version starts equal to the latest SemVer tag and then
increments patch until it finds an available tag. If the latest reachable
tag is not valid SemVer, the script treats the repository as
having no SemVer tags, starts from the current project version, and analyzes
commits after that tag. If no tag exists, the script starts from the current
project version and analyzes all commits.

If the release is valid, the script updates the `.csproj`, stages only that
project file, commits only that project file with `tag: <version>`, creates a
tag named exactly as the generated SemVer value, then pushes the current
branch and that tag to `origin`.

`-Release` checks the stored project state before saving. If the project has no
stored prerelease or build metadata state, the release is stable and keeps the
existing stable tag behavior. If `PrereleaseName` or `BuildName` is stored in the
project, `-Release` publishes a non-stable SemVer tag from those project values.
Existing tags are never moved. When the generated stable or non-stable tag
already exists, the script increments patch until it finds an available tag and
updates the `.csproj` with that final SemVer value.

### Release Conventional Commits

Only Conventional Commit messages are considered during `-Release` version
calculation.

| Commit message | Version change | Example result from `0.1.0` |
|---|---|---|
| `feat: ...` | Minor | `0.2.0` |
| `fix: ...` | Patch | `0.1.1` |
| `perf: ...` | Patch | `0.1.1` |
| `feat!: ...` or `feat(scope)!: ...` | Major | `1.0.0` |
| Message body containing `BREAKING CHANGE:` | Major | `1.0.0` |
| `docs: ...` | No change | `0.1.0` |
| `test: ...` | No change | `0.1.0` |
| `chore: ...`, `refactor: ...`, `style: ...`, `build: ...`, `ci: ...` | No change | `0.1.0` |
| `tag: <version>` | No change | `0.1.0` |
| Any message that is not a Conventional Commit | Ignored | `0.1.0` |

The calculation is cumulative and chronological. For example, starting at
`0.1.0`: `feat` -> `0.2.0`, `fix` -> `0.2.1`, `perf` -> `0.2.2`,
`docs` -> `0.2.2`, breaking change -> `1.0.0`, then `feat` -> `1.1.0`.

Preview without saving:

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -WhatIf
```

`-WhatIf` prints the current project state and the generated next state without
writing changes to the `.csproj` file.

Example preview output:

```text
┌────────────────────────────┐
│          Current           │
└────────────────────────────┘
Version: 7.3.0
NumVer: 7.3.0

┌────────────────────────────┐
│            Next            │
└────────────────────────────┘
Version: 7.3.1
NumVer: 7.3.1
WhatIf: True
```

### Version Types

#### Patch

Increments patch and reuses stored prerelease/build names when they exist.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch
```

Example:

```text
Before Version: 7.3.0
Before NumVer: 7.3.0

After Version: 7.3.1
After NumVer: 7.3.1
```

#### Minor

Increments minor, resets patch, and reuses stored prerelease/build names when they exist.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Minor
```

Example:

```text
7.3.0 -> 7.4.0
```

#### Major

Increments major, resets minor/patch, and reuses stored prerelease/build names when they exist.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Major
```

Example:

```text
7.3.9 -> 8.0.0
```

#### Stable

Promotes the current numeric version to stable without incrementing `NumVer`.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Stable
```

Example:

```text
7.3.0-rc2+Build.123 -> 7.3.0
7.3.0-rc2.1 -> 7.3.0
7.3.0+Build.123 -> 7.3.0
```

### Prerelease Versions

Use `-IsPrerelease` and `-PrereleaseName`.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Minor -IsPrerelease -PrereleaseName rc
```

Example output:

```text
Version: 7.4.0-rc
NumVer: 7.4.0
BuildNumber: 1777848010
IsPrerelease: True
IsBuild: False
PrereleaseName: rc
BuildName:
```

When `-IsPrerelease` is used, `-PrereleaseName` is required and cannot be empty or whitespace. Stored prerelease names are reused by future `Major`, `Minor`, and `Patch` runs until `-IsNotPrerelease` or a stable flow clears them.

Invalid example:

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -IsPrerelease
```

Expected error:

```text
PrereleaseName is required when IsPrerelease is used.
```

### Build Metadata

Use `-IsBuild` and `-BuildName`.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -IsBuild -BuildName Build
```

Example output:

```text
Version: 7.3.1+Build.1777848010
NumVer: 7.3.1
BuildNumber: 1777848010
IsPrerelease: False
IsBuild: True
PrereleaseName:
BuildName: Build
```

When `-IsBuild` is used, `-BuildName` is required and cannot be empty or whitespace. Stored build names are reused by future `Major`, `Minor`, and `Patch` runs until `-IsNotBuild` or a stable flow clears them.

Invalid example:

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -IsBuild
```

Expected error:

```text
BuildName is required when IsBuild is used.
```

### Prerelease And Build Metadata

```powershell
./Version.ps1 `
  -ProjectPath ./MyProject.csproj `
  -Type Patch `
  -IsPrerelease `
  -PrereleaseName rc2.1 `
  -IsBuild `
  -BuildName Build
```

Example output:

```text
Version: 7.3.1-rc2.1+Build.1777848010
NumVer: 7.3.1
BuildNumber: 1777848010
IsPrerelease: True
IsBuild: True
PrereleaseName: rc2.1
BuildName: Build
```

### Negative Flags

Negative flags override positive flags and clear the matching stored project value.

#### Disable Prerelease

```powershell
./Version.ps1 `
  -ProjectPath ./MyProject.csproj `
  -Type Patch `
  -IsPrerelease `
  -IsNotPrerelease `
  -IsBuild `
  -BuildName Build
```

Expected result:

```text
Version: 7.3.1+Build.<BuildNumber>
IsPrerelease: False
IsBuild: True
```

#### Disable Build

```powershell
./Version.ps1 `
  -ProjectPath ./MyProject.csproj `
  -Type Patch `
  -IsPrerelease `
  -PrereleaseName rc `
  -IsBuild `
  -IsNotBuild
```

Expected result:

```text
Version: 7.3.1-rc
IsPrerelease: True
IsBuild: False
```

### Stable Switch

`-Stable` can also be combined with `Major`, `Minor`, or `Patch` to increment
the numeric version and force the generated version to be stable.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -Stable
```

Example:

```text
Before Version: 7.3.0-rc
Before NumVer: 7.3.0

After Version: 7.3.1
After NumVer: 7.3.1
```

### Rules

- `Version` stores the final SemVer value.
- `NumVer` stores only `Major.Minor.Patch`.
- Missing `Version` and `NumVer` values start from `0.1.0`.
- `BuildNumber` is recalculated on every version update.
- `Major`, `Minor`, and `Patch` reuse stored `PrereleaseName` and `BuildName` values when present.
- `Type` accepts only `Major`, `Minor`, or `Patch`.
- `-Stable` by itself promotes without incrementing `NumVer`.
- `-Type <Major|Minor|Patch> -Stable` increments and then clears prerelease/build.
- `-Release` requires the `.csproj` folder or one of its parent folders to be a valid Git repository.
- `-Release` must be used without `-Type`; release versions are calculated from Conventional Commits.
- `-Release` requires a completely clean Git working tree before it starts.
- `-Release` fails when untracked, unstaged, or staged changes already exist.
- `-Release` calculates the release version from chronological Conventional Commits since the latest SemVer tag when one exists.
- `-Release` starts from the project version and scans commits after the latest tag when that tag is not SemVer.
- `-Release` starts from the project version and scans all commits when no tag exists.
- `-Release` increments patch until it finds an available tag when the generated tag already exists.
- `-Release` publishes a non-stable tag when the project stores `PrereleaseName` or `BuildName`.
- `-Release` never moves existing tags.
- `-Release` stages and commits only the project version change with `tag: <version>`, creates the SemVer tag, then pushes the current branch and tag to `origin`.
- `-IsPrerelease` requires a non-empty `-PrereleaseName`.
- `-IsBuild` requires a non-empty `-BuildName`.
- `-IsNotPrerelease` overrides `-IsPrerelease` and clears stored `PrereleaseName`.
- `-IsNotBuild` overrides `-IsBuild` and clears stored `BuildName`.
- `-WhatIf` previews current and next generated values without saving the project file.
- `-Usage` belongs to an exclusive parameter set and cannot be combined with versioning parameters.
- `-Version` returns the script version when used alone.
- `-ProjectPath <path.csproj> -Version` returns the current project `Version` value and creates `Version`/`NumVer` as `0.1.0` when missing.
- `-ProjectPath <path.csproj> -BuildNumber` returns the current project `BuildNumber` value and creates it if missing.
- `-ProjectPath <path.csproj> -BuildNumber -Refresh` creates a new project `BuildNumber` value and returns it.
- `-Validate -SemVer <semver>` validates an external SemVer string and returns only the valid version or empty output.
- `-Tests` runs `Version-Tests.ps1` when the file exists.
- Generated `Version` values are validated against the SemVer.org regular expression before saving.
- `PrereleaseName` and `BuildName` must be valid SemVer identifier lists before they are used to generate `Version`.

### Running Tests

Run:

```powershell
./Version-Tests.ps1
```

The test script creates temporary `.csproj` files under the system temp directory, runs `Version.ps1` against them, validates the results, and removes the temporary files after completion.

Git release tests create isolated temporary repositories outside this project. They also run with temporary Git environment values for `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_NOSYSTEM`, `HOME`, `USERPROFILE`, and `XDG_CONFIG_HOME`, so they do not depend on this repository or the user's Git configuration.

Expected final output:

```text
All tests passed.
```

Each test prints the command executed, the before/after version state, and a green `TEST <current>/<total> PASS` marker before the separator line. If a test stops early, the marker is printed as red `FAIL`.

Example test output:

```text
./Version.ps1 -ProjectPath /path/to/MyProject.csproj -Stable
Type: <empty>
Params: Stable=True
┌────────────────────────────┐
│           Before           │
└────────────────────────────┘
Version: 7.3.0-rc2+Build.123
NumVer: 7.3.0
IsPrerelease: True
PrereleaseName: rc2
IsBuild: True
BuildName: Build
┌────────────────────────────┐
│           After            │
└────────────────────────────┘
Version: 7.3.0
NumVer: 7.3.0
IsPrerelease: False
PrereleaseName:
IsBuild: False
BuildName:
TEST 16/53 PASS
────────────────────────────────────────────────────────────
```

The tests cover:

- usage output
- invalid `-Usage` parameter set combinations
- script version output
- SemVer validation output
- `-Tests` parameter execution
- invalid `-Version` parameter set combinations
- project version output
- generated project version output
- invalid project `-Version` parameter set combinations
- project build number output
- generated project build number output
- refreshed project build number output
- invalid project `-BuildNumber` parameter set combinations
- `-WhatIf` preview without saving
- release commit and tag creation
- release version calculation from chronological Conventional Commits
- release ignoring commit messages that are not Conventional Commits
- release patch bumping when the calculated release tag already exists
- release calculation from the project version when the latest tag is not SemVer
- release calculation from the project version when no tag exists
- release push of the current branch and tag to `origin`
- release from a project nested under a repository
- release failure before saving when untracked files exist
- release failure before saving when unstaged changes exist
- release failure before saving when staged changes exist
- release commit scope limited to the updated project file
- stable promotion
- stable promotion from prerelease
- stable promotion from build metadata
- patch/minor/major increments
- reuse of stored prerelease/build values during patch/minor/major increments
- prerelease generation
- build metadata generation
- prerelease + build metadata generation
- required prerelease name validation
- required build name validation
- invalid prerelease/build identifier validation
- negative flag precedence
- clearing stored prerelease/build values with negative flags
