# Changelog

All notable changes to this project are documented in this file.

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
