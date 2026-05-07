# Changelog

All notable changes to this project are documented in this file.

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
