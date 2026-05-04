$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "Version.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("VersionTests-" + [Guid]::NewGuid().ToString("N"))

function New-TestProject {
    param(
        [string]$Version = "7.3.0",
        [string]$NumVer = "7.3.0",
        [string]$BuildNumber = "",
        [string]$PrereleaseName = "",
        [string]$BuildName = "",
        [bool]$IsPrerelease = $false,
        [bool]$IsBuild = $false
    )

    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $path = Join-Path $testRoot ([Guid]::NewGuid().ToString("N") + ".csproj")

    $content = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Version>$Version</Version>
    <NumVer>$NumVer</NumVer>
    <BuildNumber>$BuildNumber</BuildNumber>
    <PrereleaseName>$PrereleaseName</PrereleaseName>
    <BuildName>$BuildName</BuildName>
    <IsPrerelease>$IsPrerelease</IsPrerelease>
    <IsBuild>$IsBuild</IsBuild>
  </PropertyGroup>
</Project>
"@

    Set-Content -Path $path -Value $content -Encoding UTF8
    return $path
}

function Read-Project {
    param([string]$Path)

    [xml]$project = Get-Content $Path
    return $project.Project.PropertyGroup
}

function Assert-Equal {
    param(
        [object]$Expected,
        [object]$Actual,
        [string]$Message
    )

    if ($Expected -ne $Actual) {
        throw "$Message. Expected: '$Expected'. Actual: '$Actual'."
    }
}

function Assert-Match {
    param(
        [string]$Actual,
        [string]$Pattern,
        [string]$Message
    )

    if ($Actual -notmatch $Pattern) {
        throw "$Message. Value: '$Actual'. Pattern: '$Pattern'."
    }
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

function Write-TestSeparator {
    Write-Host ("─" * 60)
}

function Write-TestVersionState {
    param(
        [string]$Version,
        [string]$NumVer,
        [string]$IsPrerelease,
        [string]$PrereleaseName,
        [string]$IsBuild,
        [string]$BuildName
    )

    Write-Host "Version: $Version"
    Write-Host "NumVer: $NumVer"
    Write-Host "IsPrerelease: $IsPrerelease"
    Write-Host "PrereleaseName: $PrereleaseName"
    Write-Host "IsBuild: $IsBuild"
    Write-Host "BuildName: $BuildName"
}

function Invoke-Version {
    param(
        [string]$ProjectPath,
        [hashtable]$Parameters
    )

    $before = Read-Project $ProjectPath
    $originalVersion = $before.Version
    $originalNumVer = $before.NumVer
    $originalIsPrerelease = $before.IsPrerelease
    $originalPrereleaseName = $before.PrereleaseName
    $originalIsBuild = $before.IsBuild
    $originalBuildName = $before.BuildName
    $parameterSummary = Get-ParameterSummary $Parameters
    $commandText = Get-CommandText $ProjectPath $Parameters

    $Parameters["ProjectPath"] = $ProjectPath
    & $scriptPath @Parameters *> $null
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 failed with exit code $LASTEXITCODE."
    }

    $after = Read-Project $ProjectPath
    Write-Host $commandText
    Write-Host "Type: $($Parameters["Type"])"
    Write-Host "Params: $parameterSummary"
    Write-SectionTitle "Before"
    Write-TestVersionState $originalVersion $originalNumVer $originalIsPrerelease $originalPrereleaseName $originalIsBuild $originalBuildName
    Write-SectionTitle "After"
    Write-TestVersionState $after.Version $after.NumVer $after.IsPrerelease $after.PrereleaseName $after.IsBuild $after.BuildName
    Write-TestSeparator
}

function Invoke-VersionExpectFailure {
    param(
        [string]$ProjectPath,
        [hashtable]$Parameters
    )

    $before = Read-Project $ProjectPath
    $originalVersion = $before.Version
    $originalNumVer = $before.NumVer
    $originalIsPrerelease = $before.IsPrerelease
    $originalPrereleaseName = $before.PrereleaseName
    $originalIsBuild = $before.IsBuild
    $originalBuildName = $before.BuildName
    $parameterSummary = Get-ParameterSummary $Parameters
    $commandText = Get-CommandText $ProjectPath $Parameters

    $Parameters["ProjectPath"] = $ProjectPath
    $errorMessage = $null

    try {
        & $scriptPath @Parameters *> $null
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    if ($null -ne $errorMessage) {
        $after = Read-Project $ProjectPath
        Write-Host $commandText
        Write-Host "Type: $($Parameters["Type"])"
        Write-Host "Params: $parameterSummary"
        Write-Host "Expected Failure: True"
        Write-SectionTitle "Before"
        Write-TestVersionState $originalVersion $originalNumVer $originalIsPrerelease $originalPrereleaseName $originalIsBuild $originalBuildName
        Write-SectionTitle "After"
        Write-TestVersionState $after.Version $after.NumVer $after.IsPrerelease $after.PrereleaseName $after.IsBuild $after.BuildName
        Write-Host "Error: $errorMessage"
        Write-TestSeparator
        return
    }

    if ($LASTEXITCODE -eq 0) {
        throw "Expected failure, but Version.ps1 completed successfully."
    }
}

function Invoke-Usage {
    & $scriptPath -Usage *> $null
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -Usage failed with exit code $LASTEXITCODE."
    }

    Write-Host "./Version.ps1 -Usage"
    Write-Host "Usage Output: OK"
    Write-TestSeparator
}

function Invoke-UsageExpectFailure {
    $errorMessage = $null

    try {
        & $scriptPath -Usage -Type Patch *> $null
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    if ($null -eq $errorMessage) {
        throw "Expected failure because -Usage must be used alone."
    }

    Write-Host "./Version.ps1 -Usage -Type Patch"
    Write-Host "Expected Failure: True"
    Write-Host "Error: $errorMessage"
    Write-TestSeparator
}

function Invoke-ScriptVersion {
    $output = & $scriptPath -Version
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -Version failed with exit code $LASTEXITCODE."
    }

    Assert-Equal "1.2.1" $output "Script version output must match"

    Write-Host "./Version.ps1 -Version"
    Write-Host "Script Version: $output"
    Write-TestSeparator
}

function Invoke-ScriptVersionExpectFailure {
    $errorMessage = $null

    try {
        & $scriptPath -Version -Type Patch *> $null
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    if ($null -eq $errorMessage) {
        throw "Expected failure because -Version must be used alone."
    }

    Write-Host "./Version.ps1 -Version -Type Patch"
    Write-Host "Expected Failure: True"
    Write-Host "Error: $errorMessage"
    Write-TestSeparator
}

function Get-ParameterSummary {
    param([hashtable]$Parameters)

    $items = $Parameters.GetEnumerator() |
        Where-Object { $_.Key -ne "ProjectPath" } |
        Sort-Object Key |
        ForEach-Object { "$($_.Key)=$($_.Value)" }

    return ($items -join "; ")
}

function Get-CommandText {
    param(
        [string]$ProjectPath,
        [hashtable]$Parameters
    )

    $parts = @("./Version.ps1", "-ProjectPath", $ProjectPath)

    foreach ($entry in ($Parameters.GetEnumerator() | Sort-Object Key)) {
        if ($entry.Key -eq "ProjectPath") {
            continue
        }

        if ($entry.Value -is [bool]) {
            if ($entry.Value) {
                $parts += "-$($entry.Key)"
            }

            continue
        }

        $parts += "-$($entry.Key)"
        $parts += $entry.Value
    }

    return ($parts -join " ")
}

function Test-StableTypePromotesPrereleaseAndBuildWithoutBump {
    $path = New-TestProject -Version "7.3.0-rc2+Build.123" -NumVer "7.3.0" -PrereleaseName "rc2" -BuildName "Build" -IsPrerelease $true -IsBuild $true
    Invoke-Version $path @{ Type = "Stable" }
    $project = Read-Project $path

    Assert-Equal "7.3.0" $project.NumVer "Stable must not increment the numeric version"
    Assert-Equal "7.3.0" $project.Version "Stable must promote Version to normal SemVer"
    Assert-Equal "False" $project.IsPrerelease "Stable must disable prerelease"
    Assert-Equal "False" $project.IsBuild "Stable must disable build"
    Assert-Equal "" $project.PrereleaseName "Stable must clear PrereleaseName"
    Assert-Equal "" $project.BuildName "Stable must clear BuildName"
}

function Test-StableTypePromotesPrereleaseOnlyWithoutBump {
    $path = New-TestProject -Version "7.3.0-rc2.1" -NumVer "7.3.0" -PrereleaseName "rc2.1" -IsPrerelease $true
    Invoke-Version $path @{ Type = "Stable" }
    $project = Read-Project $path

    Assert-Equal "7.3.0" $project.NumVer "Stable must not increment the numeric version from prerelease"
    Assert-Equal "7.3.0" $project.Version "Stable must clear prerelease"
    Assert-Equal "False" $project.IsPrerelease "Stable must disable prerelease"
    Assert-Equal "" $project.PrereleaseName "Stable must clear PrereleaseName"
}

function Test-StableTypePromotesBuildOnlyWithoutBump {
    $path = New-TestProject -Version "7.3.0+Build.123" -NumVer "7.3.0" -BuildName "Build" -IsBuild $true
    Invoke-Version $path @{ Type = "Stable" }
    $project = Read-Project $path

    Assert-Equal "7.3.0" $project.NumVer "Stable must not increment the numeric version from build"
    Assert-Equal "7.3.0" $project.Version "Stable must clear build"
    Assert-Equal "False" $project.IsBuild "Stable must disable build"
    Assert-Equal "" $project.BuildName "Stable must clear BuildName"
}

function Test-StableSwitchWithPatchStillBumps {
    $path = New-TestProject -Version "7.3.0" -PrereleaseName "rc" -BuildName "Build" -IsPrerelease $true -IsBuild $true
    Invoke-Version $path @{ Type = "Patch"; Stable = $true }
    $project = Read-Project $path

    Assert-Equal "7.3.1" $project.NumVer "Patch with Stable switch must increment patch"
    Assert-Equal "7.3.1" $project.Version "Patch with Stable switch must generate normal Version"
    Assert-Equal "False" $project.IsPrerelease "Patch con Stable must disable prerelease"
    Assert-Equal "False" $project.IsBuild "Patch con Stable must disable build"
}

function Test-PrereleaseFromParameter {
    $path = New-TestProject -Version "7.3.0"
    Invoke-Version $path @{ Type = "Minor"; IsPrerelease = $true; PrereleaseName = "rc" }
    $project = Read-Project $path

    Assert-Equal "7.4.0" $project.NumVer "Minor must increment minor"
    Assert-Equal "7.4.0-rc" $project.Version "Debe generar prerelease en Version"
    Assert-Equal "rc" $project.PrereleaseName "Must store PrereleaseName"
    Assert-Equal "True" $project.IsPrerelease "Must store IsPrerelease true"
}

function Test-BuildFromParameter {
    $path = New-TestProject -Version "7.3.0"
    Invoke-Version $path @{ Type = "Patch"; IsBuild = $true; BuildName = "Build" }
    $project = Read-Project $path

    Assert-Equal "7.3.1" $project.NumVer "Patch must increment patch"
    Assert-Match $project.Version '^7\.3\.1\+Build\.\d+$' "Debe generar metadata de build en Version"
    Assert-Equal "Build" $project.BuildName "Must store BuildName"
    Assert-Equal "True" $project.IsBuild "Must store IsBuild true"
    Assert-Match $project.BuildNumber '^\d+$' "Must store BuildNumber epoch"
}

function Test-PrereleaseAndBuild {
    $path = New-TestProject -Version "7.3.0"
    Invoke-Version $path @{ Type = "Patch"; IsPrerelease = $true; PrereleaseName = "rc2.1"; IsBuild = $true; BuildName = "Build" }
    $project = Read-Project $path

    Assert-Match $project.Version '^7\.3\.1-rc2\.1\+Build\.\d+$' "Must generate prerelease and build in Version"
}

function Test-BumpClearsStoredNames {
    $path = New-TestProject -Version "7.3.0" -PrereleaseName "beta" -BuildName "Build" -IsPrerelease $true -IsBuild $true
    Invoke-Version $path @{ Type = "Patch" }
    $project = Read-Project $path

    Assert-Equal "7.3.1" $project.Version "Bump must clear stored prerelease and build values"
    Assert-Equal "7.3.1" $project.NumVer "Bump must increment the numeric version"
    Assert-Equal "False" $project.IsPrerelease "Bump must disable stored prerelease"
    Assert-Equal "False" $project.IsBuild "Bump must disable stored build"
    Assert-Equal "" $project.PrereleaseName "Bump must clear stored PrereleaseName"
    Assert-Equal "" $project.BuildName "Bump must clear stored BuildName"
}

function Test-PrereleaseNameRequired {
    $path = New-TestProject -Version "7.3.0"
    Invoke-VersionExpectFailure $path @{ Type = "Patch"; IsPrerelease = $true }
}

function Test-BuildNameRequired {
    $path = New-TestProject -Version "7.3.0"
    Invoke-VersionExpectFailure $path @{ Type = "Patch"; IsBuild = $true }
}

function Test-NegativeFlagsWin {
    $path = New-TestProject -Version "7.3.0" -PrereleaseName "rc" -BuildName "Build"
    Invoke-Version $path @{ Type = "Patch"; IsPrerelease = $true; IsNotPrerelease = $true; IsBuild = $true; IsNotBuild = $true }
    $project = Read-Project $path

    Assert-Equal "7.3.1" $project.Version "Negative flags must win"
    Assert-Equal "False" $project.IsPrerelease "IsNotPrerelease must store false"
    Assert-Equal "False" $project.IsBuild "IsNotBuild must store false"
    Assert-Equal "" $project.PrereleaseName "IsNotPrerelease must clear PrereleaseName"
    Assert-Equal "" $project.BuildName "IsNotBuild must clear BuildName"
}

function Test-IsNotPrereleaseClearsOnlyPrerelease {
    $path = New-TestProject -Version "7.3.0" -PrereleaseName "rc" -BuildName "Build"
    Invoke-Version $path @{ Type = "Patch"; IsPrerelease = $true; IsNotPrerelease = $true; IsBuild = $true; BuildName = "Build" }
    $project = Read-Project $path

    Assert-Match $project.Version '^7\.3\.1\+Build\.\d+$' "IsNotPrerelease must allow build"
    Assert-Equal "False" $project.IsPrerelease "IsNotPrerelease must disable prerelease"
    Assert-Equal "" $project.PrereleaseName "IsNotPrerelease must clear PrereleaseName"
    Assert-Equal "True" $project.IsBuild "IsBuild must remain active"
    Assert-Equal "Build" $project.BuildName "BuildName must remain unchanged"
}

function Test-IsNotBuildClearsOnlyBuild {
    $path = New-TestProject -Version "7.3.0" -PrereleaseName "rc" -BuildName "Build"
    Invoke-Version $path @{ Type = "Patch"; IsPrerelease = $true; PrereleaseName = "rc"; IsBuild = $true; IsNotBuild = $true }
    $project = Read-Project $path

    Assert-Equal "7.3.1-rc" $project.Version "IsNotBuild must allow prerelease"
    Assert-Equal "True" $project.IsPrerelease "IsPrerelease must remain active"
    Assert-Equal "rc" $project.PrereleaseName "PrereleaseName must remain unchanged"
    Assert-Equal "False" $project.IsBuild "IsNotBuild must disable build"
    Assert-Equal "" $project.BuildName "IsNotBuild must clear BuildName"
}

function Test-MajorResets {
    $path = New-TestProject -Version "7.3.9"
    Invoke-Version $path @{ Type = "Major"; Stable = $true }
    $project = Read-Project $path

    Assert-Equal "8.0.0" $project.NumVer "Major must reset minor and patch"
    Assert-Equal "8.0.0" $project.Version "Stable major must leave normal Version"
}

function Test-WhatIfDoesNotSaveProject {
    $path = New-TestProject -Version "7.3.0"
    $output = & $scriptPath -ProjectPath $path -Type Patch -WhatIf *>&1
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -WhatIf failed with exit code $LASTEXITCODE."
    }

    $project = Read-Project $path

    Assert-Equal "7.3.0" $project.Version "WhatIf must not update Version"
    Assert-Equal "7.3.0" $project.NumVer "WhatIf must not update NumVer"
    Assert-Match ($output -join "`n") "(?m)^┌─{28}┐$" "WhatIf must print the fixed title box top"
    Assert-Match ($output -join "`n") "(?m)^│\s+Current\s+│$" "WhatIf must print the current block title"
    Assert-Match ($output -join "`n") "(?s)│\s+Current\s+│\r?\n└─{28}┘\r?\nVersion: 7\.3\.0" "WhatIf must print the current Version"
    Assert-Match ($output -join "`n") "(?s)│\s+Current\s+│\r?\n└─{28}┘\r?\nVersion: 7\.3\.0\r?\nNumVer: 7\.3\.0" "WhatIf must print the current NumVer"
    Assert-Match ($output -join "`n") "(?m)^│\s+Next\s+│$" "WhatIf must print the next block title"
    Assert-Match ($output -join "`n") "(?s)│\s+Next\s+│\r?\n└─{28}┘\r?\nVersion: 7\.3\.1" "WhatIf must print the calculated Version"
    Assert-Match ($output -join "`n") "(?s)│\s+Next\s+│\r?\n└─{28}┘\r?\nVersion: 7\.3\.1\r?\nNumVer: 7\.3\.1" "WhatIf must print the calculated NumVer"
    Assert-Match ($output -join "`n") 'WhatIf: True' "WhatIf output must indicate preview mode"

    Write-Host "./Version.ps1 -ProjectPath $path -Type Patch -WhatIf"
    Write-Host "WhatIf Output: OK"
    Write-TestSeparator
}

try {
    Invoke-Usage
    Invoke-UsageExpectFailure
    Invoke-ScriptVersion
    Invoke-ScriptVersionExpectFailure
    Test-StableTypePromotesPrereleaseAndBuildWithoutBump
    Test-StableTypePromotesPrereleaseOnlyWithoutBump
    Test-StableTypePromotesBuildOnlyWithoutBump
    Test-StableSwitchWithPatchStillBumps
    Test-PrereleaseFromParameter
    Test-BuildFromParameter
    Test-PrereleaseAndBuild
    Test-BumpClearsStoredNames
    Test-PrereleaseNameRequired
    Test-BuildNameRequired
    Test-NegativeFlagsWin
    Test-IsNotPrereleaseClearsOnlyPrerelease
    Test-IsNotBuildClearsOnlyBuild
    Test-MajorResets
    Test-WhatIfDoesNotSaveProject

    Write-Host "All tests passed."
}
finally {
    if (Test-Path $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
