[CmdletBinding(DefaultParameterSetName = "Update", SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Update")]
    [Parameter(Mandatory = $true, ParameterSetName = "ProjectVersion")]
    [Parameter(Mandatory = $true, ParameterSetName = "ProjectBuildNumber")]
    [string]$ProjectPath,

    [Parameter(Mandatory = $true, ParameterSetName = "Update")]
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
    [switch]$Stable,

    [Parameter(Mandatory = $true, ParameterSetName = "Usage")]
    [switch]$Usage,

    [Parameter(Mandatory = $true, ParameterSetName = "ScriptVersion")]
    [Parameter(Mandatory = $true, ParameterSetName = "ProjectVersion")]
    [switch]$Version,

    [Parameter(Mandatory = $true, ParameterSetName = "ProjectBuildNumber")]
    [switch]$BuildNumber
)

$ScriptVersion = "1.4.0"

function Show-Usage {
    Write-Host @"
Version.ps1

Generates complete SemVer versions for .NET projects.
Script version: $ScriptVersion

Usage:
  ./Version.ps1 -ProjectPath <path.csproj> -Type <Major|Minor|Patch|Stable> [options]
  ./Version.ps1 -ProjectPath <path.csproj> -Version
  ./Version.ps1 -ProjectPath <path.csproj> -BuildNumber
  ./Version.ps1 -Version
  ./Version.ps1 -Usage

csproj properties:
  Version          Generated full SemVer value.
  NumVer           Numeric Major.Minor.Patch version.
  BuildNumber      UTC epoch seconds. Recomputed on every run.
  PrereleaseName   Prerelease identifier, for example rc, rc2, rc2.1.
  BuildName        Build identifier, for example Build.
  IsPrerelease     true/false.
  IsBuild          true/false.

Types:
  Major   Increments major and resets minor/patch. Clears prerelease/build by default.
  Minor   Increments minor and resets patch. Clears prerelease/build by default.
  Patch   Increments patch. Clears prerelease/build by default.
  Stable  Does not increment NumVer. Promotes Version to stable and clears prerelease/build.

Options:
  -IsPrerelease              Enables prerelease for this run.
  -PrereleaseName <name>     Prerelease name. If omitted, uses the csproj value.
  -IsNotPrerelease           Disables prerelease. Takes precedence over -IsPrerelease.
  -IsBuild                   Enables build metadata for this run.
  -BuildName <name>          Build name. If omitted, uses the csproj value.
  -IsNotBuild                Disables build. Takes precedence over -IsBuild.
  -Stable                    Clears prerelease/build after the increment.
  -WhatIf                    Shows the generated result without saving the project file.
  -Usage                     Shows this help. Must be used alone.
  -Version                   Shows the script version when used alone, or the project Version with -ProjectPath.
  -BuildNumber               Shows or creates the project BuildNumber with -ProjectPath.

Rules:
  -Usage must be used alone, without any other parameter.
  -Version must be used alone for the script version, or with only ProjectPath for the project version.
  -BuildNumber must be used with only ProjectPath.
  Version stores the final SemVer value.
  NumVer stores only Major.Minor.Patch.
  Major, Minor, and Patch clear stored prerelease/build values unless explicitly enabled.
  Stable as Type does not increment the version; it only promotes to stable.
  WhatIf calculates and prints the result without writing changes to the project file.
  If IsPrerelease ends as true, PrereleaseName is required.
  If IsBuild ends as true, BuildName is required.
  IsNotPrerelease and IsNotBuild take precedence over their positive flags.

Examples:
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Minor -IsPrerelease -PrereleaseName rc
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -IsBuild -BuildName Build
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -IsPrerelease -PrereleaseName rc2.1 -IsBuild -BuildName Build
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Stable
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -WhatIf
  `$projectVersion = & ./Version.ps1 -ProjectPath ./MyProject.csproj -Version
  `$projectBuildNumber = & ./Version.ps1 -ProjectPath ./MyProject.csproj -BuildNumber
  `$scriptVersion = & ./Version.ps1 -Version
"@
}

function Show-ScriptVersion {
    Write-Output $ScriptVersion
}

function Get-ProjectVersion {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    [xml]$project = Get-Content $Path
    $propertyGroup = @($project.Project.PropertyGroup)[0]
    if ($null -eq $propertyGroup) {
        throw "PropertyGroup not found in project file: $Path"
    }

    $versionProperty = $propertyGroup.SelectSingleNode("Version")
    if ($null -eq $versionProperty -or [string]::IsNullOrWhiteSpace($versionProperty.InnerText)) {
        throw "Version property not found in project file: $Path"
    }

    Write-Output $versionProperty.InnerText
}

function Get-OrCreate-ProjectBuildNumber {
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

    $buildNumberProperty = $propertyGroup.SelectSingleNode("BuildNumber")
    if ($null -eq $buildNumberProperty) {
        $buildNumberProperty = $project.CreateElement("BuildNumber")
        $propertyGroup.AppendChild($buildNumberProperty) | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($buildNumberProperty.InnerText)) {
        $buildNumberProperty.InnerText = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
        $project.Save((Resolve-Path $Path))
    }

    Write-Output $buildNumberProperty.InnerText
}

function Test-Parameters {
    if ($Usage -or $Version -or $BuildNumber) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        throw "ProjectPath is required. Use -Usage to show help."
    }

    if ([string]::IsNullOrWhiteSpace($Type)) {
        throw "Type is required. Use -Usage to show help."
    }

    if ($Type -notin @("Major", "Minor", "Patch", "Stable")) {
        throw "Type must be Major, Minor, Patch, or Stable."
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
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name cannot be empty."
    }

    $pattern = '^[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*$'
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
        [bool]$PreviewOnly = $false
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
    if ([string]::IsNullOrWhiteSpace($currentNumVer)) {
        $currentNumVer = ConvertTo-SemVerCore $versionProperty.InnerText
    }

    if ([string]::IsNullOrWhiteSpace($currentNumVer)) {
        $currentNumVer = "0.0.0"
    }

    $newCore = Update-SemVerCore $currentNumVer $BumpType
    $buildNumber = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()

    $isVersionBump = $BumpType -in @("Major", "Minor", "Patch")
    $effectiveIsPrerelease = if ($isVersionBump) { $false } else { Get-BoolProperty $propertyGroup "IsPrerelease" }
    $effectiveIsBuild = if ($isVersionBump) { $false } else { Get-BoolProperty $propertyGroup "IsBuild" }
    $effectivePrereleaseName = if ($isVersionBump) { "" } else { Get-EffectiveName $PrereleaseName $prereleaseNameProperty.InnerText }
    $effectiveBuildName = if ($isVersionBump) { "" } else { Get-EffectiveName $BuildName $buildNameProperty.InnerText }

    if ($Stable -or $BumpType -eq "Stable") {
        $effectiveIsPrerelease = $false
        $effectiveIsBuild = $false
        $effectivePrereleaseName = ""
        $effectiveBuildName = ""
    } else {
        if ($IsPrerelease) {
            $effectiveIsPrerelease = $true
            $effectivePrereleaseName = Get-EffectiveName $PrereleaseName $prereleaseNameProperty.InnerText
        }

        if ($IsBuild) {
            $effectiveIsBuild = $true
            $effectiveBuildName = Get-EffectiveName $BuildName $buildNameProperty.InnerText
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
        Test-SemVerIdentifierList $effectivePrereleaseName "PrereleaseName"
    }

    if ($effectiveIsBuild) {
        Test-SemVerIdentifierList $effectiveBuildName "BuildName"
    }

    $semVer = $newCore
    if ($effectiveIsPrerelease) {
        $semVer = "$semVer-$effectivePrereleaseName"
    }

    if ($effectiveIsBuild) {
        $semVer = "$semVer+$effectiveBuildName.$buildNumber"
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

    if ($Version) {
        if ($PSCmdlet.ParameterSetName -eq "ProjectVersion") {
            Get-ProjectVersion -Path $ProjectPath
            return
        }

        Show-ScriptVersion
        return
    }

    if ($BuildNumber) {
        Get-OrCreate-ProjectBuildNumber -Path $ProjectPath
        return
    }

    $result = Update-ProjectVersion -Path $ProjectPath -BumpType $Type -PreviewOnly $WhatIfPreference

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
    Write-Host "PrereleaseName: $($result.Next.PrereleaseName)"
    Write-Host "BuildName: $($result.Next.BuildName)"
}
catch {
    Write-Error $_
    exit 1
}
