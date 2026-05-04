[CmdletBinding(DefaultParameterSetName = "Version")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Version")]
    [string]$ProjectPath,

    [Parameter(Mandatory = $true, ParameterSetName = "Version")]
    [string]$Type,

    [Parameter(ParameterSetName = "Version")]
    [string]$PrereleaseName,

    [Parameter(ParameterSetName = "Version")]
    [string]$BuildName,

    [Parameter(ParameterSetName = "Version")]
    [switch]$IsPrerelease,

    [Parameter(ParameterSetName = "Version")]
    [switch]$IsNotPrerelease,

    [Parameter(ParameterSetName = "Version")]
    [switch]$IsBuild,

    [Parameter(ParameterSetName = "Version")]
    [switch]$IsNotBuild,

    [Parameter(ParameterSetName = "Version")]
    [switch]$Stable,

    [Parameter(Mandatory = $true, ParameterSetName = "Usage")]
    [switch]$Usage
)

function Show-Usage {
    Write-Host @"
Version.ps1

Generates complete SemVer versions for .NET projects.

Usage:
  ./Version.ps1 -ProjectPath <path.csproj> -Type <Major|Minor|Patch|Stable> [options]
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
  -Usage                     Shows this help. Must be used alone.

Rules:
  -Usage must be used alone, without any other parameter.
  Version stores the final SemVer value.
  NumVer stores only Major.Minor.Patch.
  Major, Minor, and Patch clear stored prerelease/build values unless explicitly enabled.
  Stable as Type does not increment the version; it only promotes to stable.
  If IsPrerelease ends as true, PrereleaseName is required.
  If IsBuild ends as true, BuildName is required.
  IsNotPrerelease and IsNotBuild take precedence over their positive flags.

Examples:
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Minor -IsPrerelease -PrereleaseName rc
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -IsBuild -BuildName Build
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Patch -IsPrerelease -PrereleaseName rc2.1 -IsBuild -BuildName Build
  ./Version.ps1 -ProjectPath ./MyProject.csproj -Type Stable
"@
}

function Test-Parameters {
    if ($Usage) {
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
        [string]$BumpType
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

    $versionProperty.InnerText = $semVer
    $numVerProperty.InnerText = $newCore
    $buildNumberProperty.InnerText = $buildNumber
    $prereleaseNameProperty.InnerText = $effectivePrereleaseName
    $buildNameProperty.InnerText = $effectiveBuildName
    $isPrereleaseProperty.InnerText = $effectiveIsPrerelease.ToString()
    $isBuildProperty.InnerText = $effectiveIsBuild.ToString()

    $project.Save((Resolve-Path $Path))

    return @{
        Version = $semVer
        NumVer = $newCore
        BuildNumber = $buildNumber
        IsPrerelease = $effectiveIsPrerelease
        IsBuild = $effectiveIsBuild
        PrereleaseName = $effectivePrereleaseName
        BuildName = $effectiveBuildName
    }
}

Write-Host "====================================="
Write-Host " VERSION SCRIPT"
Write-Host "====================================="

try {
    Test-Parameters

    if ($Usage) {
        Show-Usage
        return
    }

    $result = Update-ProjectVersion -Path $ProjectPath -BumpType $Type

    Write-Host "Version: $($result.Version)"
    Write-Host "NumVer: $($result.NumVer)"
    Write-Host "BuildNumber: $($result.BuildNumber)"
    Write-Host "IsPrerelease: $($result.IsPrerelease)"
    Write-Host "IsBuild: $($result.IsBuild)"
    Write-Host "PrereleaseName: $($result.PrereleaseName)"
    Write-Host "BuildName: $($result.BuildName)"
}
catch {
    Write-Error $_
    exit 1
}
