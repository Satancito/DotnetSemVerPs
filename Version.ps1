[CmdletBinding(DefaultParameterSetName = "Update", SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Update")]
    [Parameter(Mandatory = $true, ParameterSetName = "Release")]
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

$ScriptVersion = "1.15.1"
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
  -Release                   Requires a clean Git working tree, calculates release version from Conventional Commits, commits only the updated project file, creates or moves a Git tag, and pushes both. Must be used without -Type.
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
  If no commit increments the version, Release moves the existing SemVer tag to the new release commit.
  If the latest tag is not SemVer, Release starts from the project version and scans commits after that tag.
  If no tag exists, Release starts from the project version and scans all commits.
  Release stages and commits only the project version change with tag: <version>, creates or moves the SemVer tag, then pushes the branch and tag to origin.
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

    if ([string]::IsNullOrWhiteSpace($Message)) {
        return ""
    }

    $header = (($Message -split "`r?`n") | Select-Object -First 1).Trim()
    $isBreaking = $header -match '^[A-Za-z]+(?:\([^)]+\))?!:' -or $Message -match '(?m)^BREAKING[ -]CHANGE:'
    if ($isBreaking) {
        return "Major"
    }

    if ($header -match '^feat(?:\([^)]+\))?:') {
        return "Minor"
    }

    if ($header -match '^(fix|perf)(?:\([^)]+\))?:') {
        return "Patch"
    }

    return ""
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
    if ([string]::IsNullOrWhiteSpace($latestTag) -or -not (Test-SemVer $latestTag)) {
        $versionCore = Get-ProjectVersionCore -Path $ProjectPath
        $messages = Get-GitCommitMessagesSinceTag -RepositoryPath $RepositoryPath -TagName $latestTag
        foreach ($message in $messages) {
            $bumpType = Get-ConventionalCommitBumpType -Message $message
            if (-not [string]::IsNullOrWhiteSpace($bumpType)) {
                $versionCore = Update-SemVerCore $versionCore $bumpType
            }
        }

        return @{
            HasSemVerTag = $false
            LatestTag = $latestTag
            VersionCore = $versionCore
            ShouldMoveExistingTag = $false
        }
    }

    $versionCore = ConvertTo-SemVerCore $latestTag
    $messages = Get-GitCommitMessagesSinceTag -RepositoryPath $RepositoryPath -TagName $latestTag

    foreach ($message in $messages) {
        $bumpType = Get-ConventionalCommitBumpType -Message $message
        if (-not [string]::IsNullOrWhiteSpace($bumpType)) {
            $versionCore = Update-SemVerCore $versionCore $bumpType
        }
    }

    return @{
        HasSemVerTag = $true
        LatestTag = $latestTag
        VersionCore = $versionCore
        ShouldMoveExistingTag = ($versionCore -eq (ConvertTo-SemVerCore $latestTag))
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
        [string]$Version,
        [bool]$MoveExistingTag = $false
    )

    $resolvedProjectPath = (Resolve-Path $ProjectPath).Path
    $branchResult = Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("rev-parse", "--abbrev-ref", "HEAD")
    $branchName = @($branchResult.Output)[0].ToString().Trim()
    if ([string]::IsNullOrWhiteSpace($branchName) -or $branchName -eq "HEAD") {
        throw "Release requires the repository to be on a named Git branch before it can push."
    }

    Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("add", "--", $resolvedProjectPath) | Out-Null
    Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("commit", "-m", "tag: $Version", "--", $resolvedProjectPath) | Out-Null
    $tagArguments = if ($MoveExistingTag) { @("tag", "-f", $Version) } else { @("tag", $Version) }
    Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments $tagArguments | Out-Null
    Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments @("push", "origin", $branchName) | Out-Null
    $pushTagArguments = if ($MoveExistingTag) { @("push", "--force", "origin", $Version) } else { @("push", "origin", $Version) }
    Invoke-GitCommand -RepositoryPath $RepositoryPath -Arguments $pushTagArguments | Out-Null
}

function Test-Parameters {
    if ($Usage -or $Tests -or $Validate -or $Version -or $BuildNumber) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        throw "ProjectPath is required. Use -Usage to show help."
    }

    if ($Release) {
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
        [string]$VersionCoreOverride = ""
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
    $prereleaseNameProperty = Get-OrCreate-Property $project $propertyGroup "PrereleaseName"
    $buildNameProperty = Get-OrCreate-Property $project $propertyGroup "BuildName"
    $isPrereleaseProperty = Get-OrCreate-Property $project $propertyGroup "IsPrerelease"
    $isBuildProperty = Get-OrCreate-Property $project $propertyGroup "IsBuild"

    $currentState = @{
        Version = $versionProperty.InnerText
        NumVer = $numVerProperty.InnerText
        BuildNumber = $buildNumberProperty.InnerText
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
        $versionProperty.InnerText = $semVer
        $numVerProperty.InnerText = $newCore
        $buildNumberProperty.InnerText = $buildNumber
        $prereleaseNameProperty.InnerText = $effectivePrereleaseName
        $buildNameProperty.InnerText = $effectiveBuildName
        $isPrereleaseProperty.InnerText = $effectiveIsPrerelease.ToString()
        $isBuildProperty.InnerText = $effectiveIsBuild.ToString()

        $project.Save((Resolve-Path $Path))
    }

    $nextState = @{
        Version = $semVer
        NumVer = $newCore
        BuildNumber = $buildNumber
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

    if ($Release -and -not $WhatIfPreference) {
        $releaseBuildNumber = New-BuildNumber
        $repositoryRoot = Get-GitRepositoryRoot -Path $ProjectPath
        Assert-GitWorkingTreeClean -RepositoryPath $repositoryRoot
        $releasePlan = Get-ReleaseVersionPlan -RepositoryPath $repositoryRoot -ProjectPath $ProjectPath
        $versionCoreOverride = $releasePlan.VersionCore
        $preview = Update-ProjectVersion -Path $ProjectPath -BumpType "" -PreviewOnly $true -BuildNumberOverride $releaseBuildNumber -VersionCoreOverride $versionCoreOverride
        if (-not $releasePlan.ShouldMoveExistingTag) {
            Assert-GitTagAvailable -RepositoryPath $repositoryRoot -TagName $preview.Next.Version
        }

        $result = Update-ProjectVersion -Path $ProjectPath -BumpType "" -PreviewOnly $false -BuildNumberOverride $releaseBuildNumber -VersionCoreOverride $versionCoreOverride
        Complete-GitRelease -RepositoryPath $repositoryRoot -ProjectPath $ProjectPath -Version $result.Next.Version -MoveExistingTag $releasePlan.ShouldMoveExistingTag
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
