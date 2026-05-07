# DotnetSemVerPs

PowerShell tooling for managing SemVer versions in .NET project files.

`DotnetSemVerPs` updates `.csproj` version properties, supports stable, prerelease, and build metadata flows, generates UTC epoch build numbers, and includes a test script to validate versioning scenarios.

Current script version: `1.8.1`.

### Features

- Updates `.csproj` files directly.
- Stores the full SemVer value in `Version`.
- Stores the numeric version core in `NumVer`.
- Supports stable versions, prerelease versions, build metadata versions, and prerelease plus build metadata versions.
- Generates `BuildNumber` as UTC epoch seconds on every version update.
- Creates missing version properties automatically.
- Can create local Git release commits and SemVer tags with `-Release`.
- Can validate an external SemVer string with `-Validate -SemVer <semver>`.
- Can run the local test script with `-Tests`.
- Includes a test script with common versioning scenarios.

### Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes.

Spanish documentation is available in [LEEME.md](LEEME.md).

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

Read the current project version:

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
value. `-BuildNumber` can be used with `-ProjectPath` to return the current
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
./Version.ps1 -ProjectPath <path.csproj> -Type <Major|Minor|Patch|Stable> [options]
```

`-ProjectPath` and `-Type` are required for the versioning parameter set.

Create a local release commit and tag:

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -Release
```

`-Release` first locates the Git repository that contains the `.csproj` by
searching upward from the project file's folder. The project can be nested any
number of folders inside the repository; it only needs to be inside a valid Git
repo. The script then requires a completely clean Git working tree before it
starts: no untracked files, no unstaged changes, and no staged changes waiting to
be committed. It calculates the next version and checks that the matching Git tag
does not already exist before saving the project file. If the release is valid,
the script updates the `.csproj`, stages only that project file, commits only
that project file with `Release <version>`, and creates a local tag named exactly
as the generated SemVer value. It does not push.

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

Increments patch and clears stored prerelease/build values by default.

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

Increments minor, resets patch, and clears stored prerelease/build values by default.

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Minor
```

Example:

```text
7.3.0 -> 7.4.0
```

#### Major

Increments major, resets minor/patch, and clears stored prerelease/build values by default.

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
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Stable
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

If `IsPrerelease` ends as `True`, `PrereleaseName` is required.

Invalid example:

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -IsPrerelease
```

Expected error:

```text
PrereleaseName cannot be empty.
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

If `IsBuild` ends as `True`, `BuildName` is required.

Invalid example:

```powershell
./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -IsBuild
```

Expected error:

```text
BuildName cannot be empty.
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

Negative flags override positive flags.

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

`-Stable` can be combined with `Major`, `Minor`, or `Patch` to increment the numeric version but force the result to be stable.

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
- `Major`, `Minor`, and `Patch` clear stored prerelease/build values by default.
- `Stable` as `Type` does not increment `NumVer`.
- `-Stable` as a switch clears prerelease/build after incrementing.
- `-Release` requires the `.csproj` folder or one of its parent folders to be a valid Git repository.
- `-Release` requires a completely clean Git working tree before it starts.
- `-Release` fails when untracked, unstaged, or staged changes already exist.
- `-Release` stages and commits only the project version change, then creates a local tag after validating that the tag does not exist.
- `-IsNotPrerelease` overrides `-IsPrerelease`.
- `-IsNotBuild` overrides `-IsBuild`.
- `-WhatIf` previews current and next generated values without saving the project file.
- `-Usage` belongs to an exclusive parameter set and cannot be combined with versioning parameters.
- `-Version` returns the script version when used alone.
- `-ProjectPath <path.csproj> -Version` returns the current project `Version` value.
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
./Version.ps1 -ProjectPath C:\...\test.csproj -Type Stable
Type: Stable
Params: Type=Stable
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
TEST 16/44 PASS
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
- invalid project `-Version` parameter set combinations
- project build number output
- generated project build number output
- refreshed project build number output
- invalid project `-BuildNumber` parameter set combinations
- `-WhatIf` preview without saving
- release commit and tag creation
- release from a project nested under a repository
- release failure before saving when a tag already exists
- release failure before saving when untracked files exist
- release failure before saving when unstaged changes exist
- release failure before saving when staged changes exist
- release commit scope limited to the updated project file
- stable promotion
- stable promotion from prerelease
- stable promotion from build metadata
- patch/minor/major increments
- prerelease generation
- build metadata generation
- prerelease + build metadata generation
- required prerelease name validation
- required build name validation
- invalid prerelease/build identifier validation
- negative flag precedence
- automatic clearing of stored prerelease/build values during version bumps
