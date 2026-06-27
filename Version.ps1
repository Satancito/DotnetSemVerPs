[CmdletBinding(DefaultParameterSetName = "Update", SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Update")]
    [Parameter(Mandatory = $true, ParameterSetName = "Release")]
    [Parameter(Mandatory = $true, ParameterSetName = "PrepareRelease")]
    [Parameter(Mandatory = $true, ParameterSetName = "PublishRelease")]
    [Parameter(Mandatory = $true, ParameterSetName = "Stable")]
    [Parameter(Mandatory = $true, ParameterSetName = "ProjectVersion")]
    [Parameter(Mandatory = $true, ParameterSetName = "ProjectBuildNumber")]
    [string]$ProjectPath,

    [Parameter(ParameterSetName = "Update")]
    [string]$Type,

    [Parameter(ParameterSetName = "Update")]
    [string]$PrereleaseName,

    [Parameter(ParameterSetName = "Update")]
    [string]$BuildName,

    [Parameter(ParameterSetName = "Update")]
    [switch]$IsPrerelease,

    [Parameter(ParameterSetName = "Update")]
    [switch]$IsNotPrerelease,

    [Parameter(ParameterSetName = "Update")]
    [switch]$IsBuild,

    [Parameter(ParameterSetName = "Update")]
    [switch]$IsNotBuild,

    [Parameter(ParameterSetName = "Update")]
    [Parameter(Mandatory = $true, ParameterSetName = "Stable")]
    [switch]$Stable,

    [Parameter(Mandatory = $true, ParameterSetName = "Release")]
    [switch]$Release,

    [Parameter(Mandatory = $true, ParameterSetName = "PrepareRelease")]
    [switch]$PrepareRelease,

    [Parameter(Mandatory = $true, ParameterSetName = "PublishRelease")]
    [switch]$PublishRelease,

    [Parameter(Mandatory = $true, ParameterSetName = "Usage")]
    [switch]$Usage,

    [Parameter(Mandatory = $true, ParameterSetName = "Tests")]
    [switch]$Tests,

    [Parameter(Mandatory = $true, ParameterSetName = "ScriptVersion")]
    [Parameter(Mandatory = $true, ParameterSetName = "ProjectVersion")]
    [switch]$Version,

    [Parameter(Mandatory = $true, ParameterSetName = "ProjectBuildNumber")]
    [switch]$BuildNumber,

    [Parameter(ParameterSetName = "ProjectBuildNumber")]
    [switch]$Refresh,

    [Parameter(Mandatory = $true, ParameterSetName = "Validate")]
    [switch]$Validate,

    [Parameter(ParameterSetName = "Validate")]
    [switch]$Detailed,

    [Parameter(ParameterSetName = "Validate")]
    [string]$SemVer
)

$ScriptVersion = "1.18.2"
$DefaultInitialVersionCore = "0.1.0"
$SemVerPattern = '^(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)(?:-(?<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?<buildmetadata>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'

function Show-Usage {
    Write-Host @"
Version.ps1

Generates complete SemVer versions for .NET projects.
Script version: $ScriptVersion

Usage:
  ./Version.ps1 -ProjectPath <path.csproj> -Type <Major|Minor|Patch> [options]
  ./Version.ps1 -ProjectPath <path.csproj> -Stable
  ./Version.ps1 -ProjectPath <path.csproj> -Release
  ./Version.ps1 -ProjectPath <path.csproj> -PrepareRelease
  ./Version.ps1 -ProjectPath <path.csproj> -PublishRelease
  ./Version.ps1 -ProjectPath <path.csproj> -Version
  ./Version.ps1 -ProjectPath <path.csproj> -BuildNumber
  ./Version.ps1 -Validate -SemVer <semver> [-Detailed]
  ./Version.ps1 -Tests
  ./Version.ps1 -Version
  ./Version.ps1 -Usage

csproj properties:
  Version          Generated full SemVer value.
  NumVer           Numeric Major.Minor.Patch version.
  BuildNumber      UTC epoch seconds. Recomputed on every version update.
  NuGetPush        true/false. Indicates whether the release contains version-bumping changes that should publish a NuGet package.
  PackageReleaseNotes Generated from Conventional Commit messages during Release or PrepareRelease. Written as CDATA.
  PrereleaseName   Prerelease identifier, for example rc, rc2, rc2.1.
  BuildName        Build identifier, for example Build.
  IsPrerelease     true/false.
  IsBuild          true/false.

Types:
  Major   Increments major and resets minor/patch. Reuses stored prerelease/build names when present.
  Minor   Increments minor and resets patch. Reuses stored prerelease/build names when present.
  Patch   Increments patch. Reuses stored prerelease/build names when present.

Options:
  -IsPrerelease              Enables prerelease for this run.
  -PrereleaseName <name>     Prerelease name. Required with -IsPrerelease.
  -IsNotPrerelease           Disables prerelease. Takes precedence over -IsPrerelease.
  -IsBuild                   Enables build metadata for this run.
  -BuildName <name>          Build name. Required with -IsBuild.
  -IsNotBuild                Disables build. Takes precedence over -IsBuild.
  -Stable                    Promotes to stable when used alone, or clears prerelease/build after Major, Minor, or Patch.
  -Release                   Requires a clean Git working tree, calculates release version from Conventional Commits, commits only the updated project file, creates a Git tag, and pushes both. Must be used without -Type. Uses stored prerelease/build state to publish non-stable SemVer tags when present.
  -PrepareRelease            Requires a clean Git working tree, calculates the release version from Conventional Commits, saves it to the project file, and returns the version without commit, tag, or push.
  -PublishRelease            Reads the prepared project Version, validates the tag, commits all current repository changes with tag: <version>, creates the Git tag, and pushes branch and tag.
  -WhatIf                    Shows the generated result without saving the project file.
  -Usage                     Shows this help. Must be used alone.
  -Version                   Shows the script version when used alone, or the project Version with -ProjectPath. Creates 0.1.0 when missing.
  -BuildNumber               Shows or creates the project BuildNumber with -ProjectPath.
  -Refresh                   Recomputes BuildNumber when used with -BuildNumber.
  -Validate                  Validates a SemVer string passed with -SemVer.
  -SemVer <semver>           SemVer string to validate when used with -Validate.
  -Detailed                  Prints validation details to the host when used with -Validate.
  -Tests                     Runs Version-Tests.ps1 when the test file exists.

Rules:
  -Usage must be used alone, without any other parameter.
  -Version must be used alone for the script version, or with only ProjectPath for the project version.
  -BuildNumber must be used with only ProjectPath, optionally with Refresh.
  -Validate must be used with -SemVer <semver>. It outputs the same version when valid, or empty output when invalid.
  -Tests must be used alone.
  -Stable can be used with only ProjectPath to promote without incrementing NumVer, or with Type Major, Minor, or Patch to promote after incrementing.
  -Release must be used with only ProjectPath. It calculates the version from Conventional Commits; do not pass -Type.
  -PrepareRelease must be used with only ProjectPath. It calculates and saves the version but does not commit, tag, or push.
  -PublishRelease must be used with only ProjectPath. It does not calculate a new version; it publishes the Version already stored in the project.
  Version stores the final SemVer value.
  NumVer stores only Major.Minor.Patch.
  Missing Version and NumVer values start from 0.1.0.
  Major, Minor, and Patch reuse stored PrereleaseName and BuildName values when present.
  Type must be Major, Minor, or Patch.
  Use -Stable by itself when no version increment is needed.
  IsPrerelease requires a non-empty PrereleaseName parameter.
  IsBuild requires a non-empty BuildName parameter.
  IsNotPrerelease clears PrereleaseName from the project.
  IsNotBuild clears BuildName from the project.
  Release requires a valid Git repository and a completely clean Git working tree before it starts.
  Release fails before saving if untracked, unstaged, or staged changes already exist.
  Release uses commits since the latest SemVer tag to calculate the next version. breaking changes increment major, feat increments minor, and fix/perf increment patch.
  Release and PrepareRelease set NuGetPush to True only when Conventional Commits include a version-bumping change. Otherwise NuGetPush is False.
  Release and PrepareRelease generate PackageReleaseNotes from Conventional Commit descriptions since the latest reachable tag and write each description as a separate CDATA bullet line.
  If the generated SemVer tag already exists, Release increments patch until it finds an available tag.
  If the latest tag is not SemVer, Release starts from the project version and scans commits after that tag.
  If no tag exists, Release starts from the project version and scans all commits.
  Release publishes stable tags when the project has no stored prerelease/build state. When stored PrereleaseName or BuildName values exist, Release publishes a non-stable SemVer tag from those project values.
  Existing Release tags are never moved. When the generated tag already exists, Release increments patch and updates the project with the available SemVer value.
  Release stages and commits only the project version change with tag: <version>, creates the SemVer tag, then pushes the branch and tag to origin.
  PrepareRelease is the first phase for consumer repositories that must update README, changelog, package metadata, or other files with the calculated version before publishing.
  PublishRelease is the second phase for consumer repositories. It commits all current repository changes, creates the SemVer tag from the prepared project Version, then pushes the branch and tag to origin.
  WhatIf calculates and prints the result without writing changes to the project file.
  If -IsPrerelease is used, -PrereleaseName is required.
  If -IsBuild is used, -BuildName is required.
  IsNotPrerelease and IsNotBuild take precedence over their positive flags.

Examples:
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Minor -IsPrerelease -PrereleaseName rc
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -IsBuild -BuildName Build
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -IsPrerelease -PrereleaseName rc2.1 -IsBuild -BuildName Build
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Stable
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Release
  `$releaseVersion = & ./Version.ps1 -ProjectPath ./MyProject.csproj -PrepareRelease
  ./Version.ps1 -ProjectPath ./MyProject.csproj -PublishRelease
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -WhatIf
  `$validated = & ./Version.ps1 -Validate -SemVer 1.2.3-rc.1+Build.5
  `$validated = & ./Version.ps1 -Validate -SemVer 1.2.3-rc.1+Build.5 -Detailed
  ./Version.ps1 -Tests
  `$projectVersion = & ./Version.ps1 -ProjectPath ./MyProject.csproj -Version
  `$projectBuildNumber = & ./Version.ps1 -ProjectPath ./MyProject.csproj -BuildNumber
  `$projectBuildNumber = & ./Version.ps1 -ProjectPath ./MyProject.csproj -BuildNumber -Refresh
  `$scriptVersion = & ./Version.ps1 -Version
"@
}

function Show-ScriptVersion {
    Write-Output $ScriptVersion
}

function New-BuildNumber {
    return [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
}

function Invoke-Tests {
    $testsPath = Join-Path $PSScriptRoot "Version-Tests.ps1"
    if (-not (Test-Path $testsPath -PathType Leaf)) {
        Write-Host "Tests not found: $testsPath"
        return
    }

    & $testsPath
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

function Test-SemVer {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    return [regex]::IsMatch($Value, $SemVerPattern)
}

function Get-SemVerValidationError {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "Version cannot be empty."
    }

    if (Test-SemVer $Value) {
        return ""
    }

    return "Version is not valid SemVer 2.0.0: $Value"
}

function Invoke-SemVerValidation {
    param(
        [string]$Value,
        [bool]$ShowDetails = $false
    )

    $errorMessage = Get-SemVerValidationError $Value
    if ([string]::IsNullOrWhiteSpace($errorMessage)) {
        if ($ShowDetails) {
            Write-Host "Valid SemVer: $Value"
        }

        Write-Output $Value
        return
    }

    if ($ShowDetails) {
        Write-Host $errorMessage
    }

    Write-Output ""
}

function Get-ProjectVersion {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    [xml]$project = Get-Content $Path
    $propertyGroup = @($project.Project.PropertyGroup)[0]
    if ($null -eq $propertyGroup) {
        $propertyGroup = $project.CreateElement("PropertyGroup")
        $project.Project.AppendChild($propertyGroup) | Out-Null
    }

    $versionProperty = Get-OrCreate-Property $project $propertyGroup "Version"
    if ([string]::IsNullOrWhiteSpace($versionProperty.InnerText)) {
        $versionProperty.InnerText = $DefaultInitialVersionCore

        $numVerProperty = Get-OrCreate-Property $project $propertyGroup "NumVer"
        if ([string]::IsNullOrWhiteSpace($numVerProperty.InnerText)) {
            $numVerProperty.InnerText = $DefaultInitialVersionCore
        }

        $project.Save((Resolve-Path $Path))
    }

    Write-Output $versionProperty.InnerText
}

function Get-OrCreate-ProjectBuildNumber {
    param(
        [string]$Path,
        [bool]$ForceRefresh = $false
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    [xml]$project = Get-Content $Path
    $propertyGroup = @($project.Project.PropertyGroup)[0]
    if ($null -eq $propertyGroup) {
        $propertyGroup = $project.CreateElement("PropertyGroup")
        $project.Project.AppendChild($propertyGroup) | Out-Null
    }

    $buildNumberProperty = $propertyGroup.SelectSingleNode("BuildNumber")
    if ($null -eq $buildNumberProperty) {
        $buildNumberProperty = $project.CreateElement("BuildNumber")
        $propertyGroup.AppendChild($buildNumberProperty) | Out-Null
    }

    if ($ForceRefresh -or [string]::IsNullOrWhiteSpace($buildNumberProperty.InnerText)) {
        $buildNumberProperty.InnerText = New-BuildNumber
        $project.Save((Resolve-Path $Path))
    }

    Write-Output $buildNumberProperty.InnerText
}

function Invoke-GitCommand {
    param(
        [string]$RepositoryPath,
        [string[]]$Arguments,
        [bool]$IgnoreFailure = $false
    )

    $output = & git -C $RepositoryPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0 -and -not $IgnoreFailure) {
        throw "Git command failed: git -C $RepositoryPath $($Arguments -join ' '). $($output -join ' ')"
    }

    return @{
        ExitCode = $exitCode
        Output = $output
    }
}

function Get-GitRepositoryRoot {
    param([string]$Path)

    $directory = if (Test-Path $Path -PathType Leaf) {
        Split-Path -Parent (Resolve-Path $Path)
    } else {
        Resolve-Path $Path
    }

    $result = Invoke-GitCommand -RepositoryPath $directory -Arguments @("rev-parse", "--show-toplevel") -IgnoreFailure $true
    $outputLines = @($result.Output)
    if ($result.ExitCode -ne 0 -or $outputLines.Count -eq 0) {
        throw "Release requires ProjectPath to be inside a valid Git repository."
    }

    return $outputLines[0].ToString().Trim()
}

function Test-GitTagExists {
    param(
        [string]$RepositoryPath,
        [string]$TagName
    )

    $result = Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("rev-parse", "-q", "--verify", "refs/tags/$TagName") -IgnoreFailure $true
    return $result.ExitCode -eq 0
}

function Assert-GitTagAvailable {
    param(
        [string]$RepositoryPath,
        [string]$TagName
    )

    Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("check-ref-format", "refs/tags/$TagName") | Out-Null

    if (Test-GitTagExists -RepositoryPath $RepositoryPath -TagName $TagName) {
        throw "Tag already exists: $TagName. Release stopped before saving project changes."
    }
}

function Get-LatestGitTag {
    param([string]$RepositoryPath)

    $result = Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("describe", "--tags", "--abbrev=0") -IgnoreFailure $true
    $outputLines = @($result.Output)
    if ($result.ExitCode -ne 0 -or $outputLines.Count -eq 0) {
        return ""
    }

    return $outputLines[0].ToString().Trim()
}

function Get-GitCommitMessagesSinceTag {
    param(
        [string]$RepositoryPath,
        [string]$TagName
    )

    $range = if ([string]::IsNullOrWhiteSpace($TagName)) { "HEAD" } else { "$TagName..HEAD" }
    $result = Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("log", "--reverse", "--format=%H", $range)
    $messages = @()

    foreach ($hash in @($result.Output)) {
        $commitHash = $hash.ToString().Trim()
        if ([string]::IsNullOrWhiteSpace($commitHash)) {
            continue
        }

        $messageResult = Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("log", "-1", "--format=%B", $commitHash)
        $message = (@($messageResult.Output) -join "`n").Trim()
        if (-not [string]::IsNullOrWhiteSpace($message)) {
            $messages += $message
        }
    }

    return $messages
}

function Get-ConventionalCommitBumpType {
    param([string]$Message)

    $info = Get-ConventionalCommitInfo -Message $Message
    if ($null -eq $info) {
        return ""
    }

    return $info.BumpType
}

function Get-ConventionalCommitInfo {
    param([string]$Message)

    if ([string]::IsNullOrWhiteSpace($Message)) {
        return $null
    }

    $header = (($Message -split "`r?`n") | Select-Object -First 1).Trim()
    $match = [regex]::Match($header, '^(?<type>[A-Za-z]+)(?:\((?<scope>[^)]+)\))?(?<breaking>!)?:\s*(?<description>.+)$')
    if (-not $match.Success) {
        return $null
    }

    $type = $match.Groups["type"].Value
    $isBreaking = -not [string]::IsNullOrWhiteSpace($match.Groups["breaking"].Value) -or $Message -match '(?m)^BREAKING[ -]CHANGE:'
    $bumpType = ""
    if ($isBreaking) {
        $bumpType = "Major"
    } elseif ($type -eq "feat") {
        $bumpType = "Minor"
    } elseif ($type -in @("fix", "perf")) {
        $bumpType = "Patch"
    }

    return @{
        Header = $header
        Type = $type
        Scope = $match.Groups["scope"].Value
        Description = $match.Groups["description"].Value
        IsBreaking = $isBreaking
        BumpType = $bumpType
    }
}

function Get-PackageReleaseNotes {
    param([object[]]$CommitInfos)

    $headers = @()
    foreach ($info in @($CommitInfos)) {
        if ($null -ne $info -and -not [string]::IsNullOrWhiteSpace($info.Description)) {
            $headers += "- $($info.Description)"
        }
    }

    if ($headers.Count -eq 0) {
        return "No Conventional Commit release notes."
    }

    return $headers -join "`n"
}

function Get-ProjectVersionCore {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    [xml]$project = Get-Content $Path
    $propertyGroup = @($project.Project.PropertyGroup)[0]
    if ($null -eq $propertyGroup) {
        return Get-InitialSemVerCore
    }

    $numVer = $propertyGroup.SelectSingleNode("NumVer")?.InnerText
    if (-not [string]::IsNullOrWhiteSpace($numVer)) {
        return ConvertTo-SemVerCore $numVer
    }

    $version = $propertyGroup.SelectSingleNode("Version")?.InnerText
    if (-not [string]::IsNullOrWhiteSpace($version)) {
        return ConvertTo-SemVerCore $version
    }

    return Get-InitialSemVerCore
}

function Get-ReleaseVersionPlan {
    param(
        [string]$RepositoryPath,
        [string]$ProjectPath
    )

    $latestTag = Get-LatestGitTag -RepositoryPath $RepositoryPath
    $commitInfos = @()
    $hasVersionBump = $false

    if ([string]::IsNullOrWhiteSpace($latestTag) -or -not (Test-SemVer $latestTag)) {
        $versionCore = Get-ProjectVersionCore -Path $ProjectPath
        $messages = Get-GitCommitMessagesSinceTag -RepositoryPath $RepositoryPath -TagName $latestTag
        foreach ($message in $messages) {
            $info = Get-ConventionalCommitInfo -Message $message
            if ($null -ne $info) {
                $commitInfos += $info
                if (-not [string]::IsNullOrWhiteSpace($info.BumpType)) {
                    $hasVersionBump = $true
                    $versionCore = Update-SemVerCore $versionCore $info.BumpType
                }
            }
        }

        return @{
            HasSemVerTag = $false
            LatestTag = $latestTag
            VersionCore = $versionCore
            HasVersionBump = $hasVersionBump
            PackageReleaseNotes = Get-PackageReleaseNotes -CommitInfos $commitInfos
        }
    }

    $versionCore = ConvertTo-SemVerCore $latestTag
    $messages = Get-GitCommitMessagesSinceTag -RepositoryPath $RepositoryPath -TagName $latestTag

    foreach ($message in $messages) {
        $info = Get-ConventionalCommitInfo -Message $message
        if ($null -ne $info) {
            $commitInfos += $info
            if (-not [string]::IsNullOrWhiteSpace($info.BumpType)) {
                $hasVersionBump = $true
                $versionCore = Update-SemVerCore $versionCore $info.BumpType
            }
        }
    }

    return @{
        HasSemVerTag = $true
        LatestTag = $latestTag
        VersionCore = $versionCore
        HasVersionBump = $hasVersionBump
        PackageReleaseNotes = Get-PackageReleaseNotes -CommitInfos $commitInfos
    }
}

function Assert-GitWorkingTreeClean {
    param([string]$RepositoryPath)

    $result = Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("status", "--porcelain")
    $untrackedItems = @()
    $unstagedItems = @()
    $stagedItems = @()

    foreach ($line in @($result.Output)) {
        $text = $line.ToString()
        if ([string]::IsNullOrWhiteSpace($text) -or $text.Length -lt 2) {
            continue
        }

        if ($text.StartsWith("??")) {
            $untrackedItems += $text
            continue
        }

        if ($text[0] -ne " ") {
            $stagedItems += $text
        }

        if ($text[1] -ne " ") {
            $unstagedItems += $text
        }
    }

    if ($untrackedItems.Count -gt 0 -or $unstagedItems.Count -gt 0 -or $stagedItems.Count -gt 0) {
        $details = @()
        if ($untrackedItems.Count -gt 0) {
            $details += "Untracked files: $($untrackedItems -join '; ')"
        }

        if ($unstagedItems.Count -gt 0) {
            $details += "Unstaged changes: $($unstagedItems -join '; ')"
        }

        if ($stagedItems.Count -gt 0) {
            $details += "Staged changes: $($stagedItems -join '; ')"
        }

        throw "Release requires a completely clean Git working tree before it starts. $($details -join ' ')"
    }
}

function Complete-GitRelease {
    param(
        [string]$RepositoryPath,
        [string]$ProjectPath,
        [string]$Version
    )

    $resolvedProjectPath = (Resolve-Path $ProjectPath).Path
    $branchResult = Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
    $branchName = @($branchResult.Output)[0].ToString().Trim()
    if ([string]::IsNullOrWhiteSpace($branchName) -or $branchName -eq "HEAD") {
        throw "Release requires the repository to be on a named Git branch before it can push."
    }

    Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("add", "--", $resolvedProjectPath) | Out-Null
    Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("commit", "-m", "tag: $Version", "--", $resolvedProjectPath) | Out-Null
    Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("tag", $Version) | Out-Null
    Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("push", "origin", $branchName) | Out-Null
    Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("push", "origin", $Version) | Out-Null
}

function Complete-GitPreparedRelease {
    param(
        [string]$RepositoryPath,
        [string]$Version
    )

    if ([string]::IsNullOrWhiteSpace($Version)) {
        throw "PublishRelease requires the project Version to be prepared first."
    }

    $versionError = Get-SemVerValidationError $Version
    if (-not [string]::IsNullOrWhiteSpace($versionError)) {
        throw "PublishRelease requires a valid prepared SemVer project Version. $versionError"
    }

    Assert-GitTagAvailable -RepositoryPath $RepositoryPath -TagName $Version

    $branchResult = Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
    $branchName = @($branchResult.Output)[0].ToString().Trim()
    if ([string]::IsNullOrWhiteSpace($branchName) -or $branchName -eq "HEAD") {
        throw "PublishRelease requires the repository to be on a named Git branch before it can push."
    }

    $status = Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("status", "--porcelain")
    if (@($status.Output).Count -gt 0) {
        Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("add", "-A") | Out-Null
        Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("commit", "-m", "tag: $Version") | Out-Null
    }

    Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("tag", $Version) | Out-Null
    Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("push", "origin", $branchName) | Out-Null
    Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("push", "origin", $Version) | Out-Null
}

function Get-AvailableReleaseVersionCore {
    param(
        [string]$RepositoryPath,
        [string]$ProjectPath,
        [string]$VersionCore,
        [string]$BuildNumber
    )

    $candidateCore = ConvertTo-SemVerCore $VersionCore

    for ($attempt = 0; $attempt -lt 100; $attempt++) {
        $preview = Update-ProjectVersion -Path $ProjectPath -BumpType "" -PreviewOnly $true -BuildNumberOverride $BuildNumber -VersionCoreOverride $candidateCore
        Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("check-ref-format", "refs/tags/$($preview.Next.Version)") | Out-Null

        if (-not (Test-GitTagExists -RepositoryPath $RepositoryPath -TagName $preview.Next.Version)) {
            return $candidateCore
        }

        $candidateCore = Update-SemVerCore $candidateCore "Patch"
    }

    throw "Release could not find an available SemVer tag after 100 patch increments."
}

function Invoke-PrepareRelease {
    param(
        [string]$RepositoryPath,
        [string]$ProjectPath,
        [bool]$PreviewOnly = $false
    )

    $releaseBuildNumber = New-BuildNumber
    Assert-GitWorkingTreeClean -RepositoryPath $RepositoryPath
    $releasePlan = Get-ReleaseVersionPlan -RepositoryPath $RepositoryPath -ProjectPath $ProjectPath
    $versionCoreOverride = Get-AvailableReleaseVersionCore -RepositoryPath $RepositoryPath -ProjectPath $ProjectPath -VersionCore $releasePlan.VersionCore -BuildNumber $releaseBuildNumber
    $preview = Update-ProjectVersion -Path $ProjectPath -BumpType "" -PreviewOnly $true -BuildNumberOverride $releaseBuildNumber -VersionCoreOverride $versionCoreOverride
    Assert-GitTagAvailable -RepositoryPath $RepositoryPath -TagName $preview.Next.Version

    return Update-ProjectVersion -Path $ProjectPath -BumpType "" -PreviewOnly $PreviewOnly -BuildNumberOverride $releaseBuildNumber -VersionCoreOverride $versionCoreOverride -NuGetPushOverride $releasePlan.HasVersionBump -PackageReleaseNotesOverride $releasePlan.PackageReleaseNotes
}


function Test-Parameters {
    if ($Usage -or $Tests -or $Validate -or $Version -or $BuildNumber) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        throw "ProjectPath is required. Use -Usage to show help."
    }

    if ($Release -or $PrepareRelease -or $PublishRelease) {
        return
    }

    if ($Stable -and [string]::IsNullOrWhiteSpace($Type)) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($Type)) {
        throw "Type is required. Use -Usage to show help."
    }

    if ($IsPrerelease -and [string]::IsNullOrWhiteSpace($PrereleaseName)) {
        throw "PrereleaseName is required when IsPrerelease is used."
    }

    if ($IsBuild -and [string]::IsNullOrWhiteSpace($BuildName)) {
        throw "BuildName is required when IsBuild is used."
    }

    if ($Type -notin @("Major", "Minor", "Patch")) {
        throw "Type must be Major, Minor, or Patch."
    }

}

<#
Core SemVer helpers.

The script treats Version as the final SemVer value and NumVer as the numeric
version core. Existing projects that only have Version can still be migrated:
NumVer is created automatically from Version's core.
#>
function ConvertTo-SemVerCore {
    param([string]$Version)

    if ([string]::IsNullOrWhiteSpace($Version)) {
        throw "The numeric version has no value."
    }

    $core = $Version.Split("-")[0].Split("+")[0]
    $parts = $core.Split(".")

    switch ($parts.Count) {
        1 { $core = "$($parts[0]).0.0" }
        2 { $core = "$($parts[0]).$($parts[1]).0" }
        3 { }
        default { throw "Invalid version format: $Version" }
    }

    if ($core -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') {
        throw "The version core is not valid SemVer: $core"
    }

    return $core
}

function Get-InitialSemVerCore {
    return $DefaultInitialVersionCore
}

function Get-SemVerCoreParts {
    param([string]$Version)

    $core = ConvertTo-SemVerCore $Version
    $parts = $core.Split(".")

    return @{
        Major = [int]$parts[0]
        Minor = [int]$parts[1]
        Patch = [int]$parts[2]
    }
}

function Update-SemVerCore {
    param(
        [string]$Version,
        [string]$Type
    )

    $parts = Get-SemVerCoreParts $Version

    switch ($Type) {
        "Major" { return "$($parts.Major + 1).0.0" }
        "Minor" { return "$($parts.Major).$($parts.Minor + 1).0" }
        "Patch" { return "$($parts.Major).$($parts.Minor).$($parts.Patch + 1)" }
        "Stable" { return ConvertTo-SemVerCore $Version }
        default { throw "Invalid increment type: $Type" }
    }
}

function Test-SemVerIdentifierList {
    param(
        [string]$Value,
        [string]$Name,
        [bool]$AllowLeadingZeroNumericIdentifiers = $true
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name cannot be empty."
    }

    $identifier = if ($AllowLeadingZeroNumericIdentifiers) {
        '[0-9A-Za-z-]+'
    } else {
        '(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)'
    }

    $pattern = "^$identifier(\.$identifier)*$"
    if ($Value -notmatch $pattern) {
        throw "$Name is not valid SemVer: $Value"
    }
}

function Get-OrCreate-Property {
    param(
        [xml]$Project,
        [System.Xml.XmlElement]$PropertyGroup,
        [string]$Name
    )

    $property = $PropertyGroup.SelectSingleNode($Name)
    if ($null -eq $property) {
        $property = $Project.CreateElement($Name)
        $PropertyGroup.AppendChild($property) | Out-Null
    }

    return $property
}

function Set-XmlElementText {
    param(
        [xml]$Document,
        [System.Xml.XmlElement]$Element,
        [string]$Value
    )

    $Element.RemoveAll()
    $Element.InnerText = $Value
}

function Set-XmlElementCDataText {
    param(
        [xml]$Document,
        [System.Xml.XmlElement]$Element,
        [string]$Value
    )

    $Element.RemoveAll()

    if ([string]::IsNullOrEmpty($Value)) {
        return
    }

    $parts = $Value -split [regex]::Escape("]]>")
    for ($index = 0; $index -lt $parts.Count; $index++) {
        if ($parts[$index].Length -gt 0) {
            $Element.AppendChild($Document.CreateCDataSection($parts[$index])) | Out-Null
        }

        if ($index -lt ($parts.Count - 1)) {
            $Element.AppendChild($Document.CreateTextNode("]]>")) | Out-Null
        }
    }
}

function Get-BoolProperty {
    param(
        [System.Xml.XmlElement]$PropertyGroup,
        [string]$Name
    )

    $value = $PropertyGroup.SelectSingleNode($Name)?.InnerText
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $false
    }

    $parsed = $false
    if (-not [bool]::TryParse($value, [ref]$parsed)) {
        throw "Property <$Name> must be true or false."
    }

    return $parsed
}

function Get-EffectiveName {
    param(
        [string]$ParameterValue,
        [string]$ProjectValue
    )

    if (-not [string]::IsNullOrWhiteSpace($ParameterValue)) {
        return $ParameterValue.Trim()
    }

    if (-not [string]::IsNullOrWhiteSpace($ProjectValue)) {
        return $ProjectValue.Trim()
    }

    return ""
}

function Update-ProjectVersion {
    param(
        [string]$Path,
        [string]$BumpType,
        [bool]$PreviewOnly = $false,
        [string]$BuildNumberOverride = "",
        [string]$VersionCoreOverride = "",
        [object]$NuGetPushOverride = $null,
        [string]$PackageReleaseNotesOverride = $null
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    [xml]$project = Get-Content $Path
    $propertyGroup = @($project.Project.PropertyGroup)[0]
    if ($null -eq $propertyGroup) {
        $propertyGroup = $project.CreateElement("PropertyGroup")
        $project.Project.AppendChild($propertyGroup) | Out-Null
    }

    $versionProperty = Get-OrCreate-Property $project $propertyGroup "Version"
    $numVerProperty = Get-OrCreate-Property $project $propertyGroup "NumVer"
    $buildNumberProperty = Get-OrCreate-Property $project $propertyGroup "BuildNumber"
    $nuGetPushProperty = Get-OrCreate-Property $project $propertyGroup "NuGetPush"
    $packageReleaseNotesProperty = Get-OrCreate-Property $project $propertyGroup "PackageReleaseNotes"
    $prereleaseNameProperty = Get-OrCreate-Property $project $propertyGroup "PrereleaseName"
    $buildNameProperty = Get-OrCreate-Property $project $propertyGroup "BuildName"
    $isPrereleaseProperty = Get-OrCreate-Property $project $propertyGroup "IsPrerelease"
    $isBuildProperty = Get-OrCreate-Property $project $propertyGroup "IsBuild"

    $currentState = @{
        Version = $versionProperty.InnerText
        NumVer = $numVerProperty.InnerText
        BuildNumber = $buildNumberProperty.InnerText
        NuGetPush = $nuGetPushProperty.InnerText
        PackageReleaseNotes = $packageReleaseNotesProperty.InnerText
        IsPrerelease = Get-BoolProperty $propertyGroup "IsPrerelease"
        IsBuild = Get-BoolProperty $propertyGroup "IsBuild"
        PrereleaseName = $prereleaseNameProperty.InnerText
        BuildName = $buildNameProperty.InnerText
    }

    $currentNumVer = $numVerProperty.InnerText
    if ([string]::IsNullOrWhiteSpace($currentNumVer) -and -not [string]::IsNullOrWhiteSpace($versionProperty.InnerText)) {
        $currentNumVer = ConvertTo-SemVerCore $versionProperty.InnerText
    }

    if ([string]::IsNullOrWhiteSpace($currentNumVer)) {
        $currentNumVer = Get-InitialSemVerCore
    }

    $newCore = if ([string]::IsNullOrWhiteSpace($VersionCoreOverride)) {
        Update-SemVerCore $currentNumVer $BumpType
    } else {
        ConvertTo-SemVerCore $VersionCoreOverride
    }
    $buildNumber = if ([string]::IsNullOrWhiteSpace($BuildNumberOverride)) { New-BuildNumber } else { $BuildNumberOverride }
    $nuGetPush = if ($null -eq $NuGetPushOverride) {
        if ([string]::IsNullOrWhiteSpace($nuGetPushProperty.InnerText)) { $false } else { [bool]::Parse($nuGetPushProperty.InnerText) }
    } else {
        [bool]$NuGetPushOverride
    }
    $packageReleaseNotes = if ($null -eq $PackageReleaseNotesOverride) { $packageReleaseNotesProperty.InnerText } else { $PackageReleaseNotesOverride }

    $effectivePrereleaseName = $prereleaseNameProperty.InnerText
    $effectiveBuildName = $buildNameProperty.InnerText
    $effectiveIsPrerelease = -not [string]::IsNullOrWhiteSpace($effectivePrereleaseName)
    $effectiveIsBuild = -not [string]::IsNullOrWhiteSpace($effectiveBuildName)

    if ($Stable -or $BumpType -eq "Stable") {
        $effectiveIsPrerelease = $false
        $effectiveIsBuild = $false
        $effectivePrereleaseName = ""
        $effectiveBuildName = ""
    } else {
        if ($IsPrerelease) {
            $effectiveIsPrerelease = $true
            $effectivePrereleaseName = $PrereleaseName
        }

        if ($IsBuild) {
            $effectiveIsBuild = $true
            $effectiveBuildName = $BuildName
        }

        if ($IsNotPrerelease) {
            $effectiveIsPrerelease = $false
            $effectivePrereleaseName = ""
        }

        if ($IsNotBuild) {
            $effectiveIsBuild = $false
            $effectiveBuildName = ""
        }
    }

    if (-not $effectiveIsPrerelease) {
        $effectivePrereleaseName = ""
    }

    if (-not $effectiveIsBuild) {
        $effectiveBuildName = ""
    }

    if ($effectiveIsPrerelease) {
        Test-SemVerIdentifierList $effectivePrereleaseName "PrereleaseName" $false
    }

    if ($effectiveIsBuild) {
        Test-SemVerIdentifierList $effectiveBuildName "BuildName" $true
    }

    $semVer = $newCore
    if ($effectiveIsPrerelease) {
        $semVer = "$semVer-$effectivePrereleaseName"
    }

    if ($effectiveIsBuild) {
        $semVer = "$semVer+$effectiveBuildName.$buildNumber"
    }

    $semVerError = Get-SemVerValidationError $semVer
    if (-not [string]::IsNullOrWhiteSpace($semVerError)) {
        throw $semVerError
    }

    if (-not $PreviewOnly) {
        Set-XmlElementText $project $versionProperty $semVer
        Set-XmlElementText $project $numVerProperty $newCore
        Set-XmlElementText $project $buildNumberProperty $buildNumber
        Set-XmlElementText $project $nuGetPushProperty $nuGetPush.ToString()
        Set-XmlElementCDataText $project $packageReleaseNotesProperty $packageReleaseNotes
        Set-XmlElementText $project $prereleaseNameProperty $effectivePrereleaseName
        Set-XmlElementText $project $buildNameProperty $effectiveBuildName
        Set-XmlElementText $project $isPrereleaseProperty $effectiveIsPrerelease.ToString()
        Set-XmlElementText $project $isBuildProperty $effectiveIsBuild.ToString()

        $project.Save((Resolve-Path $Path))
    }

    $nextState = @{
        Version = $semVer
        NumVer = $newCore
        BuildNumber = $buildNumber
        NuGetPush = $nuGetPush
        PackageReleaseNotes = $packageReleaseNotes
        IsPrerelease = $effectiveIsPrerelease
        IsBuild = $effectiveIsBuild
        PrereleaseName = $effectivePrereleaseName
        BuildName = $effectiveBuildName
    }

    return @{
        Current = $currentState
        Next = $nextState
        WhatIf = $PreviewOnly
    }
}

function Write-VersionState {
    param(
        [hashtable]$State
    )

    Write-Host "Version: $($State.Version)"
    Write-Host "NumVer: $($State.NumVer)"
    Write-Host "BuildNumber: $($State.BuildNumber)"
    Write-Host "NuGetPush: $($State.NuGetPush)"
    Write-Host "PackageReleaseNotes: $($State.PackageReleaseNotes)"
    Write-Host "IsPrerelease: $($State.IsPrerelease)"
    Write-Host "IsBuild: $($State.IsBuild)"
    Write-Host "PrereleaseName: $($State.PrereleaseName)"
    Write-Host "BuildName: $($State.BuildName)"
}

function Write-SectionTitle {
    param([string]$Title)

    $width = 30
    $innerWidth = $width - 2
    $padding = $innerWidth - $Title.Length
    $leftPadding = [Math]::Floor($padding / 2)
    $rightPadding = $padding - $leftPadding

    Write-Host ("┌" + ("─" * $innerWidth) + "┐")
    Write-Host ("│" + (" " * $leftPadding) + $Title + (" " * $rightPadding) + "│")
    Write-Host ("└" + ("─" * $innerWidth) + "┘")
}

try {
    Test-Parameters

    if ($Usage) {
        Show-Usage
        return
    }

    if ($Tests) {
        Invoke-Tests
        return
    }

    if ($Validate) {
        if ([string]::IsNullOrWhiteSpace($SemVer)) {
            if ($Detailed) {
                Write-Host "Validate requires -SemVer <semver>."
            }

            Write-Output ""
            return
        }

        Invoke-SemVerValidation -Value $SemVer -ShowDetails $Detailed
        return
    }

    if ($Version) {
        if ($PSCmdlet.ParameterSetName -eq "ProjectVersion") {
            Get-ProjectVersion -Path $ProjectPath
            return
        }

        Show-ScriptVersion
        return
    }

    if ($BuildNumber) {
        Get-OrCreate-ProjectBuildNumber -Path $ProjectPath -ForceRefresh $Refresh
        return
    }

    if ($PrepareRelease) {
        $repositoryRoot = Get-GitRepositoryRoot -Path $ProjectPath
        $result = Invoke-PrepareRelease -RepositoryPath $repositoryRoot -ProjectPath $ProjectPath -PreviewOnly $WhatIfPreference
        $global:LASTEXITCODE = 0
        Write-Output $result.Next.Version
        return
    }

    if ($PublishRelease) {
        $repositoryRoot = Get-GitRepositoryRoot -Path $ProjectPath
        $preparedVersion = Get-ProjectVersion -Path $ProjectPath
        if (-not $WhatIfPreference) {
            Complete-GitPreparedRelease -RepositoryPath $repositoryRoot -Version $preparedVersion
        } else {
            $versionError = Get-SemVerValidationError $preparedVersion
            if (-not [string]::IsNullOrWhiteSpace($versionError)) {
                throw "PublishRelease requires a valid prepared SemVer project Version. $versionError"
            }

            Assert-GitTagAvailable -RepositoryPath $repositoryRoot -TagName $preparedVersion
        }

        $global:LASTEXITCODE = 0
        Write-Output $preparedVersion
        return
    }

    if ($Release) {
        $repositoryRoot = Get-GitRepositoryRoot -Path $ProjectPath
        $result = Invoke-PrepareRelease -RepositoryPath $repositoryRoot -ProjectPath $ProjectPath -PreviewOnly $WhatIfPreference
        if (-not $WhatIfPreference) {
            Complete-GitRelease -RepositoryPath $repositoryRoot -ProjectPath $ProjectPath -Version $result.Next.Version
        }
    } else {
        $bumpType = if ($Stable -and [string]::IsNullOrWhiteSpace($Type)) { "Stable" } else { $Type }
        $result = Update-ProjectVersion -Path $ProjectPath -BumpType $bumpType -PreviewOnly $WhatIfPreference
    }

    if ($result.WhatIf) {
        Write-SectionTitle "Current"
        Write-VersionState -State $result.Current
        Write-SectionTitle "Next"
        Write-VersionState -State $result.Next
        Write-Host "WhatIf: $($result.WhatIf)"
        return
    }

    Write-Host "====================================="
    Write-Host " VERSION SCRIPT"
    Write-Host "====================================="

    Write-Host "Version: $($result.Next.Version)"
    Write-Host "NumVer: $($result.Next.NumVer)"
    Write-Host "BuildNumber: $($result.Next.BuildNumber)"
    Write-Host "NuGetPush: $($result.Next.NuGetPush)"
    Write-Host "PackageReleaseNotes: $($result.Next.PackageReleaseNotes)"
    Write-Host "IsPrerelease: $($result.Next.IsPrerelease)"
    Write-Host "IsBuild: $($result.Next.IsBuild)"
    Write-Host "WhatIf: $($result.WhatIf)"
    Write-Host "Release: $($Release -and -not $result.WhatIf)"
    Write-Host "PrereleaseName: $($result.Next.PrereleaseName)"
    Write-Host "BuildName: $($result.Next.BuildName)"
}
catch {
    Write-Error $_
    exit 1
}
