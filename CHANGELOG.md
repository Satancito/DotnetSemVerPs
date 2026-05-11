# Changelog

All notable changes to this project are documented in this file.

## 1.12.1 - 2026-05-11

### Fixed

- Reset test `$LASTEXITCODE` before invoking `Version.ps1` so earlier native command exit codes cannot make successful script calls fail.
- Moved the detailed invalid SemVer test command label before its output so TEST 6 owns its own detailed message.

## 1.12.0 - 2026-05-11

### Added

- `-Release` now calculates the release version from chronological Conventional Commits since the latest SemVer tag.
- `-Release` now moves the existing SemVer tag to the new release commit when no conventional commit increments the version.
- `-Release` now starts from the project version and scans commits after the latest tag when that tag is not SemVer.
- `-Release` now starts from the project version and scans all commits when no tag exists.
- `-Release` now ignores commit messages that are not Conventional Commits while calculating the release version.
- Release commits now use the Conventional Commit message `tag: <version>`.

### Documentation

- Added Conventional Commit release tables showing which commit types increment major, minor, or patch, which types do not increment, and which messages are ignored.

### Tests

- Added release coverage for Conventional Commit version calculation, non-conventional commit ignores, existing tag movement, non-SemVer latest tags, and repositories without tags.

## 1.11.0 - 2026-05-11

### Added

- `-ProjectPath <path.csproj> -Version` now creates missing project `Version` and `NumVer` values as `0.1.0`, saves the project, and returns `0.1.0`.

### Tests

- Added coverage for project version reads that initialize missing version properties.

## 1.10.0 - 2026-05-11

### Changed

- `Major`, `Minor`, and `Patch` now reuse stored `PrereleaseName` and `BuildName` values when present instead of clearing them by default.
- `-IsNotPrerelease` and `-IsNotBuild` now explicitly clear the matching stored project values.
- `-IsPrerelease` now requires a non-empty `-PrereleaseName`, and `-IsBuild` now requires a non-empty `-BuildName`.

### Tests

- Added coverage for stored prerelease/build reuse, negative flag clearing, and required prerelease/build names when positive flags are used.

## 1.9.0 - 2026-05-07

### Added

- `-Release` now pushes the current branch and generated SemVer tag to `origin` after creating the release commit and tag.

### Tests

- Added isolated local remote coverage to verify release branch and tag pushes without depending on GitHub.

## 1.8.1 - 2026-05-07

### Changed

- `-Release` now requires a completely clean Git working tree before modifying the project file.
- `-Release` now fails before saving when untracked, unstaged, or staged changes already exist.
- Documented that `-Release` stages and commits only the updated project file before creating the SemVer tag.

### Tests

- Added release safety coverage for untracked files, unstaged changes, staged changes, clean release success, and release commit scope.

## 1.8.0 - 2026-05-06

### Added

- Added `-Validate -SemVer <semver>` to validate external SemVer strings and return only the valid version or empty output for script consumption.
- Added `-Detailed` for validation details on a non-capturable host output stream.
- Added `-Tests` to run `Version-Tests.ps1` when the test file exists, or print that tests were not found.

### Changed

- Validates generated project `Version` values against the SemVer.org recommended regex with named groups before saving.
- Tightened `PrereleaseName` and `BuildName` validation so invalid SemVer identifier lists are rejected before generating a project version.
- Prints each test result as `TEST <current>/<total> PASS` in green after the test separator, or `FAIL` in red when a test stops early.

## 1.7.1 - 2026-05-05

### Added

- Added `LEEME.md` as the Spanish equivalent of `README.md`.
- Linked the English and Spanish documentation files to each other.

## 1.7.0 - 2026-05-05

### Added

- Added a `-Release` guard that stops before saving when the repository has untracked or unstaged files pending `git add`.

## 1.6.0 - 2026-05-05

### Added

- Added `-Release` to validate that the generated SemVer tag is available, update the project, create a local `Release <version>` commit, and create a local tag without pushing.
- Added isolated Git release tests that use temporary repositories and temporary Git environment configuration.

## 1.5.2 - 2026-05-05

### Changed

- Changed the default initial version for projects without `Version` or `NumVer` from `0.0.0` to `0.1.0`.

## 1.5.1 - 2026-05-04

### Changed

- Updated version changes to explicitly refresh the project `BuildNumber` on each version update while keeping `-BuildNumber` as a read-or-create command.

## 1.5.0 - 2026-05-04

### Added

- Added `-Refresh` for `-ProjectPath <path.csproj> -BuildNumber` to force a new UTC epoch build number and return it.

## 1.4.0 - 2026-05-04

### Added

- Added `-ProjectPath <path.csproj> -BuildNumber` to return the current project `BuildNumber` value, creating and saving one when it is missing.

## 1.3.0 - 2026-05-04

### Added

- Added `-ProjectPath <path.csproj> -Version` to return the current project `Version` value for use in other scripts.

## 1.2.1 - 2026-05-04

### Changed

- Updated `-WhatIf` and test output formatting with boxed section titles and 60-character separators.

## 1.2.0 - 2026-05-04

### Added

- Added `-WhatIf` preview mode to print current and next generated values without saving project file changes.

## 1.1.0 - 2026-05-04

### Added

- Added an exclusive `-Version` parameter set to print the script version.

## 1.0.0 - 2026-05-04

Initial stable release.

### Added

- Added `Version.ps1` for managing SemVer values in `.csproj` files.
- Added support for `Major`, `Minor`, `Patch`, and `Stable` version flows.
- Added support for stable, prerelease, build metadata, and prerelease plus build metadata versions.
- Added `NumVer`, `BuildNumber`, `PrereleaseName`, `BuildName`, `IsPrerelease`, and `IsBuild` project property management.
- Added automatic creation of missing version properties.
- Added UTC epoch build number generation.
- Added `Version-Tests.ps1` with coverage for usage output, version increments, stable promotion, prerelease/build validation, negative flag precedence, and clearing stored prerelease/build values.
- Added an exclusive `-Usage` parameter set so help cannot be combined with versioning parameters.

### Changed

- Renamed internal SemVer helper functions to use approved PowerShell verbs.
