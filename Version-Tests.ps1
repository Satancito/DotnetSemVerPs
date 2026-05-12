$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "Version.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("VersionTests-" + [Guid]::NewGuid().ToString("N"))
$testGitHome = Join-Path $testRoot "GitHome"
$testGitConfig = Join-Path $testGitHome ".gitconfig"
$displayProjectPath = "/path/to/MyProject.csproj"
$script:CompletedTests = 0
$script:TotalTests = if ($env:VERSION_TESTS_SKIP_TESTS_PARAMETER -eq "1") { 55 } else { 56 }

function Reset-LastExitCode {
    $global:LASTEXITCODE = 0
}

function Invoke-WithIsolatedGitEnvironment {
    param([scriptblock]$ScriptBlock)

    New-Item -ItemType Directory -Path $testGitHome -Force | Out-Null
    if (-not (Test-Path $testGitConfig)) {
        Set-Content -Path $testGitConfig -Value "" -Encoding UTF8
    }

    $names = @("GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM", "HOME", "USERPROFILE", "XDG_CONFIG_HOME")
    $saved = @{}

    foreach ($name in $names) {
        $item = Get-Item -Path "Env:$name" -ErrorAction SilentlyContinue
        if ($null -ne $item) {
            $saved[$name] = $item.Value
        } else {
            $saved[$name] = $null
        }
    }

    try {
        $env:GIT_CONFIG_GLOBAL = $testGitConfig
        $env:GIT_CONFIG_NOSYSTEM = "1"
        $env:HOME = $testGitHome
        $env:USERPROFILE = $testGitHome
        $env:XDG_CONFIG_HOME = $testGitHome

        & $ScriptBlock
    }
    finally {
        foreach ($name in $names) {
            if ($null -eq $saved[$name]) {
                Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
            } else {
                Set-Item -Path "Env:$name" -Value $saved[$name]
            }
        }
    }
}

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

function New-TestProjectWithoutVersionProperties {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $path = Join-Path $testRoot ([Guid]::NewGuid().ToString("N") + ".csproj")

    $content = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
  </PropertyGroup>
</Project>
"@

    Set-Content -Path $path -Value $content -Encoding UTF8
    return $path
}

function Invoke-TestGit {
    param(
        [string]$RepositoryPath,
        [string[]]$Arguments
    )

    $result = Invoke-WithIsolatedGitEnvironment {
        $gitOutput = & git -C $RepositoryPath @Arguments 2>&1
        return @{
            ExitCode = $LASTEXITCODE
            Output = $gitOutput
        }
    }

    if ($result.ExitCode -ne 0) {
        throw "Git test command failed: git -C $RepositoryPath $($Arguments -join ' '). $($result.Output -join ' ')"
    }

    return $result.Output
}

function New-TestGitProject {
    param(
        [string]$Version = "7.3.0",
        [string]$NumVer = "7.3.0",
        [string]$ProjectRelativeDirectory = ""
    )

    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $repositoryPath = Join-Path $testRoot ([Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $repositoryPath -Force | Out-Null

    $projectDirectory = $repositoryPath
    if (-not [string]::IsNullOrWhiteSpace($ProjectRelativeDirectory)) {
        $projectDirectory = Join-Path $repositoryPath $ProjectRelativeDirectory
        New-Item -ItemType Directory -Path $projectDirectory -Force | Out-Null
    }

    $path = Join-Path $projectDirectory "MyProject.csproj"
    $content = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Version>$Version</Version>
    <NumVer>$NumVer</NumVer>
    <BuildNumber></BuildNumber>
    <PrereleaseName></PrereleaseName>
    <BuildName></BuildName>
    <IsPrerelease>False</IsPrerelease>
    <IsBuild>False</IsBuild>
  </PropertyGroup>
</Project>
"@

    Set-Content -Path $path -Value $content -Encoding UTF8
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("init") | Out-Null
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("config", "user.email", "version-tests@example.local") | Out-Null
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("config", "user.name", "Version Tests") | Out-Null
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("add", "--", $path) | Out-Null
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("commit", "-m", "Initial project") | Out-Null

    $remotePath = Join-Path $testRoot ([Guid]::NewGuid().ToString("N") + ".git")
    Invoke-TestGit -RepositoryPath $testRoot -Arguments @("init", "--bare", $remotePath) | Out-Null
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("remote", "add", "origin", $remotePath) | Out-Null
    $branchName = @(Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("rev-parse", "--abbrev-ref", "HEAD"))[0].ToString().Trim()
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("push", "origin", $branchName) | Out-Null

    return @{
        RepositoryPath = $repositoryPath
        RemotePath = $remotePath
        BranchName = $branchName
        ProjectPath = $path
    }
}

function Add-TestGitCommit {
    param(
        [string]$RepositoryPath,
        [string]$Message,
        [string]$FileName = "changes.txt",
        [string]$Content = ""
    )

    $path = Join-Path $RepositoryPath $FileName
    if ([string]::IsNullOrWhiteSpace($Content)) {
        $Content = [Guid]::NewGuid().ToString("N")
    }

    Add-Content -Path $path -Value $Content -Encoding UTF8
    Invoke-TestGit -RepositoryPath $RepositoryPath -Arguments @("add", "--", $path) | Out-Null
    Invoke-TestGit -RepositoryPath $RepositoryPath -Arguments @("commit", "-m", $Message) | Out-Null
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
    Write-TestStatus "PASS" Green
    Write-Host ("─" * 60)
}

function Write-TestStatus {
    param(
        [string]$Status,
        [ConsoleColor]$Color
    )

    $script:CompletedTests++
    Write-Host ("TEST {0}/{1} {2}" -f $script:CompletedTests, $script:TotalTests, $Status) -ForegroundColor $Color
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
    Reset-LastExitCode
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
        Reset-LastExitCode
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
    Reset-LastExitCode
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
        Reset-LastExitCode
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
    Reset-LastExitCode
    $output = & $scriptPath -Version
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -Version failed with exit code $LASTEXITCODE."
    }

    Assert-Equal "1.15.3" $output "Script version output must match"

    Write-Host "./Version.ps1 -Version"
    Write-Host "Script Version: $output"
    Write-TestSeparator
}

function Invoke-ValidateVersionReturnsValidValue {
    Reset-LastExitCode
    $output = & $scriptPath -Validate -SemVer "1.2.3-rc.1+Build.5"
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -Validate failed with exit code $LASTEXITCODE."
    }

    Assert-Equal "1.2.3-rc.1+Build.5" $output "Validate must return the same version when valid"

    Write-Host "./Version.ps1 -Validate -SemVer 1.2.3-rc.1+Build.5"
    Write-Host "Validated Version: $output"
    Write-TestSeparator
}

function Invoke-ValidateVersionReturnsEmptyWhenInvalid {
    Reset-LastExitCode
    $output = & $scriptPath -Validate -SemVer "1.2.3-rc.01"
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -Validate failed with exit code $LASTEXITCODE."
    }

    Assert-Equal "" $output "Validate must return empty output when invalid"

    Write-Host "./Version.ps1 -Validate -SemVer 1.2.3-rc.01"
    Write-Host "Validated Version: <empty>"
    Write-TestSeparator
}

function Invoke-ValidateVersionDetailedKeepsCaptureClean {
    Write-Host "./Version.ps1 -Validate -SemVer 1.2.3-rc.01 -Detailed"
    Reset-LastExitCode
    $output = & $scriptPath -Validate -SemVer "1.2.3-rc.01" -Detailed
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -Validate -Detailed failed with exit code $LASTEXITCODE."
    }

    Assert-Equal "" $output "Detailed validate must keep capturable output empty when invalid"

    Write-Host "Validated Version: <empty>"
    Write-TestSeparator
}

function Invoke-ValidateWithoutSemVerReturnsEmpty {
    Reset-LastExitCode
    $output = & $scriptPath -Validate
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -Validate failed with exit code $LASTEXITCODE."
    }

    Assert-Equal "" $output "Validate must return empty output when SemVer is missing"

    Write-Host "./Version.ps1 -Validate"
    Write-Host "Validated Version: <empty>"
    Write-TestSeparator
}

function Invoke-TestsParameterRunsTests {
    $previousSkip = $env:VERSION_TESTS_SKIP_TESTS_PARAMETER

    try {
        $env:VERSION_TESTS_SKIP_TESTS_PARAMETER = "1"
        Reset-LastExitCode
        $output = & $scriptPath -Tests *>&1
        if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            throw "Version.ps1 -Tests failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        if ($null -eq $previousSkip) {
            Remove-Item -Path Env:VERSION_TESTS_SKIP_TESTS_PARAMETER -ErrorAction SilentlyContinue
        } else {
            $env:VERSION_TESTS_SKIP_TESTS_PARAMETER = $previousSkip
        }
    }

    $joinedOutput = $output -join "`n"
    Assert-Match $joinedOutput "All tests passed\." "Tests parameter must run Version-Tests.ps1"
    Assert-Match $joinedOutput "TEST \d+/\d+ PASS" "Tests parameter must print PASS status"

    Write-Host "./Version.ps1 -Tests"
    Write-Host "Tests Output: OK"
    Write-TestSeparator
}

function Invoke-ScriptVersionExpectFailure {
    $errorMessage = $null

    try {
        Reset-LastExitCode
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

function Invoke-ProjectVersion {
    $path = New-TestProject -Version "7.3.0-rc2+Build.123"
    Reset-LastExitCode
    $output = & $scriptPath -ProjectPath $path -Version
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -ProjectPath <path> -Version failed with exit code $LASTEXITCODE."
    }

    Assert-Equal "7.3.0-rc2+Build.123" $output "Project version output must match"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Version"
    Write-Host "Project Version: $output"
    Write-TestSeparator
}

function Invoke-ProjectVersionCreatesMissing {
    $path = New-TestProjectWithoutVersionProperties
    Reset-LastExitCode
    $output = & $scriptPath -ProjectPath $path -Version
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -ProjectPath <path> -Version failed with exit code $LASTEXITCODE."
    }

    $project = Read-Project $path

    Assert-Equal "0.1.0" $output "Project version output must use the default initial version when missing"
    Assert-Equal "0.1.0" $project.Version "Project Version must be created when missing"
    Assert-Equal "0.1.0" $project.NumVer "Project NumVer must be created with the default initial version when missing"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Version"
    Write-Host "Created Project Version: $output"
    Write-TestSeparator
}

function Invoke-ProjectVersionExpectFailure {
    $errorMessage = $null
    $path = New-TestProject

    try {
        Reset-LastExitCode
        & $scriptPath -ProjectPath $path -Version -Type Patch *> $null
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    if ($null -eq $errorMessage) {
        throw "Expected failure because project -Version cannot be combined with -Type."
    }

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Version -Type Patch"
    Write-Host "Expected Failure: True"
    Write-Host "Error: $errorMessage"
    Write-TestSeparator
}

function Invoke-ProjectBuildNumberReturnsExisting {
    $path = New-TestProject -BuildNumber "1234567890"
    Reset-LastExitCode
    $output = & $scriptPath -ProjectPath $path -BuildNumber
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -ProjectPath <path> -BuildNumber failed with exit code $LASTEXITCODE."
    }

    $project = Read-Project $path

    Assert-Equal "1234567890" $output "Project BuildNumber output must match existing value"
    Assert-Equal "1234567890" $project.BuildNumber "Project BuildNumber must remain unchanged"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -BuildNumber"
    Write-Host "Project BuildNumber: $output"
    Write-TestSeparator
}

function Invoke-ProjectBuildNumberGeneratesMissing {
    $path = New-TestProject
    Reset-LastExitCode
    $output = & $scriptPath -ProjectPath $path -BuildNumber
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -ProjectPath <path> -BuildNumber failed with exit code $LASTEXITCODE."
    }

    $project = Read-Project $path

    Assert-Match $output '^\d+$' "Project BuildNumber output must be an epoch value"
    Assert-Equal $output $project.BuildNumber "Generated BuildNumber must be saved to the project"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -BuildNumber"
    Write-Host "Generated BuildNumber: $output"
    Write-TestSeparator
}

function Invoke-ProjectBuildNumberRefreshesExisting {
    $path = New-TestProject -BuildNumber "1"
    Reset-LastExitCode
    $output = & $scriptPath -ProjectPath $path -BuildNumber -Refresh
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -ProjectPath <path> -BuildNumber -Refresh failed with exit code $LASTEXITCODE."
    }

    $project = Read-Project $path

    Assert-Match $output '^\d+$' "Refreshed BuildNumber output must be an epoch value"
    Assert-Equal $output $project.BuildNumber "Refreshed BuildNumber must be saved to the project"
    if ($output -eq "1") {
        throw "Refreshed BuildNumber must not keep the old value."
    }

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -BuildNumber -Refresh"
    Write-Host "Refreshed BuildNumber: $output"
    Write-TestSeparator
}

function Invoke-ProjectBuildNumberExpectFailure {
    $errorMessage = $null
    $path = New-TestProject

    try {
        Reset-LastExitCode
        & $scriptPath -ProjectPath $path -BuildNumber -Type Patch *> $null
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    if ($null -eq $errorMessage) {
        throw "Expected failure because project -BuildNumber cannot be combined with -Type."
    }

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -BuildNumber -Type Patch"
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

    $parts = @("./Version.ps1", "-ProjectPath", $displayProjectPath)

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

function Test-StableSwitchPromotesPrereleaseAndBuildWithoutBump {
    $path = New-TestProject -Version "7.3.0-rc2+Build.123" -NumVer "7.3.0" -PrereleaseName "rc2" -BuildName "Build" -IsPrerelease $true -IsBuild $true
    Invoke-Version $path @{ Stable = $true }
    $project = Read-Project $path

    Assert-Equal "7.3.0" $project.NumVer "Stable must not increment the numeric version"
    Assert-Equal "7.3.0" $project.Version "Stable must promote Version to normal SemVer"
    Assert-Equal "False" $project.IsPrerelease "Stable must disable prerelease"
    Assert-Equal "False" $project.IsBuild "Stable must disable build"
    Assert-Equal "" $project.PrereleaseName "Stable must clear PrereleaseName"
    Assert-Equal "" $project.BuildName "Stable must clear BuildName"
}

function Test-StableSwitchPromotesPrereleaseOnlyWithoutBump {
    $path = New-TestProject -Version "7.3.0-rc2.1" -NumVer "7.3.0" -PrereleaseName "rc2.1" -IsPrerelease $true
    Invoke-Version $path @{ Stable = $true }
    $project = Read-Project $path

    Assert-Equal "7.3.0" $project.NumVer "Stable must not increment the numeric version from prerelease"
    Assert-Equal "7.3.0" $project.Version "Stable must clear prerelease"
    Assert-Equal "False" $project.IsPrerelease "Stable must disable prerelease"
    Assert-Equal "" $project.PrereleaseName "Stable must clear PrereleaseName"
}

function Test-StableSwitchPromotesBuildOnlyWithoutBump {
    $path = New-TestProject -Version "7.3.0+Build.123" -NumVer "7.3.0" -BuildName "Build" -IsBuild $true
    Invoke-Version $path @{ Stable = $true }
    $project = Read-Project $path

    Assert-Equal "7.3.0" $project.NumVer "Stable must not increment the numeric version from build"
    Assert-Equal "7.3.0" $project.Version "Stable must clear build"
    Assert-Equal "False" $project.IsBuild "Stable must disable build"
    Assert-Equal "" $project.BuildName "Stable must clear BuildName"
}

function Test-StableSwitchWithPatchBumpsAndPromotes {
    $path = New-TestProject -Version "7.3.0" -PrereleaseName "rc" -BuildName "Build" -IsPrerelease $true -IsBuild $true
    Invoke-Version $path @{ Type = "Patch"; Stable = $true }
    $project = Read-Project $path

    Assert-Equal "7.3.1" $project.NumVer "Patch with Stable switch must increment patch"
    Assert-Equal "7.3.1" $project.Version "Patch with Stable switch must generate normal Version"
    Assert-Equal "False" $project.IsPrerelease "Patch with Stable switch must disable prerelease"
    Assert-Equal "False" $project.IsBuild "Patch with Stable switch must disable build"
}

function Test-StableSwitchAlonePromotesWithoutBump {
    $path = New-TestProject -Version "7.3.0-rc+Build.123" -NumVer "7.3.0" -PrereleaseName "rc" -BuildName "Build" -IsPrerelease $true -IsBuild $true
    Invoke-Version $path @{ Stable = $true }
    $project = Read-Project $path

    Assert-Equal "7.3.0" $project.NumVer "Stable switch alone must not increment NumVer"
    Assert-Equal "7.3.0" $project.Version "Stable switch alone must promote to stable"
    Assert-Equal "False" $project.IsPrerelease "Stable switch alone must disable prerelease"
    Assert-Equal "False" $project.IsBuild "Stable switch alone must disable build"
    Assert-Equal "" $project.PrereleaseName "Stable switch alone must clear PrereleaseName"
    Assert-Equal "" $project.BuildName "Stable switch alone must clear BuildName"
}

function Test-StableTypeRejected {
    $path = New-TestProject -Version "7.3.0"
    Invoke-VersionExpectFailure $path @{ Type = "Stable" }
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

function Test-BumpKeepsStoredNames {
    $path = New-TestProject -Version "7.3.0" -PrereleaseName "beta" -BuildName "Build" -IsPrerelease $true -IsBuild $true
    Invoke-Version $path @{ Type = "Patch" }
    $project = Read-Project $path

    Assert-Match $project.Version '^7\.3\.1-beta\+Build\.\d+$' "Bump must keep stored prerelease and build values"
    Assert-Equal "7.3.1" $project.NumVer "Bump must increment the numeric version"
    Assert-Equal "True" $project.IsPrerelease "Bump must keep stored prerelease active"
    Assert-Equal "True" $project.IsBuild "Bump must keep stored build active"
    Assert-Equal "beta" $project.PrereleaseName "Bump must keep stored PrereleaseName"
    Assert-Equal "Build" $project.BuildName "Bump must keep stored BuildName"
}

function Test-StoredPrereleaseNameAppliesWithoutFlag {
    $path = New-TestProject -Version "7.3.0" -PrereleaseName "rc.1"
    Invoke-Version $path @{ Type = "Patch" }
    $project = Read-Project $path

    Assert-Equal "7.3.1-rc.1" $project.Version "Stored PrereleaseName must be applied without IsPrerelease"
    Assert-Equal "True" $project.IsPrerelease "Stored PrereleaseName must enable prerelease"
    Assert-Equal "rc.1" $project.PrereleaseName "Stored PrereleaseName must remain stored"
}

function Test-StoredBuildNameAppliesWithoutFlag {
    $path = New-TestProject -Version "7.3.0" -BuildName "Build"
    Invoke-Version $path @{ Type = "Patch" }
    $project = Read-Project $path

    Assert-Match $project.Version '^7\.3\.1\+Build\.\d+$' "Stored BuildName must be applied without IsBuild"
    Assert-Equal "True" $project.IsBuild "Stored BuildName must enable build"
    Assert-Equal "Build" $project.BuildName "Stored BuildName must remain stored"
}

function Test-VersionUpdateRefreshesBuildNumber {
    $path = New-TestProject -Version "7.3.0" -BuildNumber "1"
    Invoke-Version $path @{ Type = "Patch" }
    $project = Read-Project $path

    Assert-Match $project.BuildNumber '^\d+$' "Version update must store BuildNumber epoch"
    if ($project.BuildNumber -eq "1") {
        throw "Version update must refresh an existing BuildNumber."
    }

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Type Patch"
    Write-Host "Refreshed BuildNumber: $($project.BuildNumber)"
    Write-TestSeparator
}

function Test-MissingVersionStartsFromDefaultInitialVersion {
    $path = New-TestProjectWithoutVersionProperties
    Invoke-Version $path @{ Stable = $true }
    $project = Read-Project $path

    Assert-Equal "0.1.0" $project.Version "Missing Version and NumVer must start from the default initial version"
    Assert-Equal "0.1.0" $project.NumVer "Missing NumVer must store the default initial version"
    Assert-Match $project.BuildNumber '^\d+$' "Default initial version must still store BuildNumber epoch"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Stable"
    Write-Host "Default Initial Version: $($project.Version)"
    Write-TestSeparator
}

function Test-MissingVersionPatchBumpsFromDefaultInitialVersion {
    $path = New-TestProjectWithoutVersionProperties
    Invoke-Version $path @{ Type = "Patch" }
    $project = Read-Project $path

    Assert-Equal "0.1.1" $project.Version "Patch must bump from the default initial version"
    Assert-Equal "0.1.1" $project.NumVer "Patch must store the bumped default initial version"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Type Patch"
    Write-Host "Default Initial Patch Version: $($project.Version)"
    Write-TestSeparator
}

function Test-ReleaseCreatesCommitAndTag {
    $fixture = New-TestGitProject -Version "7.3.0" -NumVer "7.3.0"
    $path = $fixture.ProjectPath
    $repositoryPath = $fixture.RepositoryPath
    $remotePath = $fixture.RemotePath
    $branchName = $fixture.BranchName
    Add-TestGitCommit -RepositoryPath $repositoryPath -Message "fix: prepare patch release"

    $result = Invoke-WithIsolatedGitEnvironment {
        Reset-LastExitCode
        $scriptOutput = & $scriptPath -ProjectPath $path -Release *>&1
        return @{
            ExitCode = $LASTEXITCODE
            Output = $scriptOutput
        }
    }

    if ($null -ne $result.ExitCode -and $result.ExitCode -ne 0) {
        throw "Version.ps1 -Release failed with exit code $($result.ExitCode)."
    }

    $output = $result.Output

    $project = Read-Project $path
    $tag = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "--list", "7.3.1")
    $subject = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("log", "-1", "--pretty=%s")
    $changedFiles = @(Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD"))
    $remoteTag = Invoke-TestGit -RepositoryPath $remotePath -Arguments @("tag", "--list", "7.3.1")
    $remoteSubject = Invoke-TestGit -RepositoryPath $remotePath -Arguments @("log", "-1", "--pretty=%s", "refs/heads/$branchName")

    Assert-Equal "7.3.1" $project.Version "Release must update Version"
    Assert-Equal "7.3.1" $project.NumVer "Release must update NumVer"
    Assert-Equal "7.3.1" $tag "Release must create a matching tag"
    Assert-Equal "tag: 7.3.1" $subject "Release must create a conventional tag commit"
    Assert-Equal "7.3.1" $remoteTag "Release must push the matching tag to origin"
    Assert-Equal "tag: 7.3.1" $remoteSubject "Release must push the release commit to origin"
    Assert-Equal 1 $changedFiles.Count "Release commit must include only one file"
    Assert-Equal "MyProject.csproj" $changedFiles[0] "Release commit must include only the project file"
    Assert-Match ($output -join "`n") "Release: True" "Release output must indicate release mode"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Release"
    Write-Host "Release Tag: $tag"
    Write-Host "Pushed Tag: $remoteTag"
    Write-TestSeparator
}

function Test-ReleaseWorksFromProjectSubdirectory {
    $fixture = New-TestGitProject -Version "7.3.0" -NumVer "7.3.0" -ProjectRelativeDirectory "src/MyProject"
    $path = $fixture.ProjectPath
    $repositoryPath = $fixture.RepositoryPath
    $remotePath = $fixture.RemotePath
    $branchName = $fixture.BranchName
    Add-TestGitCommit -RepositoryPath $repositoryPath -Message "feat: prepare minor release"

    $result = Invoke-WithIsolatedGitEnvironment {
        Reset-LastExitCode
        $scriptOutput = & $scriptPath -ProjectPath $path -Release *>&1
        return @{
            ExitCode = $LASTEXITCODE
            Output = $scriptOutput
        }
    }

    if ($null -ne $result.ExitCode -and $result.ExitCode -ne 0) {
        throw "Version.ps1 -Release from subdirectory failed with exit code $($result.ExitCode)."
    }

    $output = $result.Output

    $project = Read-Project $path
    $tag = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "--list", "7.4.0")
    $subject = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("log", "-1", "--pretty=%s")
    $remoteTag = Invoke-TestGit -RepositoryPath $remotePath -Arguments @("tag", "--list", "7.4.0")
    $remoteSubject = Invoke-TestGit -RepositoryPath $remotePath -Arguments @("log", "-1", "--pretty=%s", "refs/heads/$branchName")

    Assert-Equal "7.4.0" $project.Version "Release from subdirectory must update Version"
    Assert-Equal "7.4.0" $project.NumVer "Release from subdirectory must update NumVer"
    Assert-Equal "7.4.0" $tag "Release from subdirectory must create a matching tag in the parent repository"
    Assert-Equal "tag: 7.4.0" $subject "Release from subdirectory must create a conventional tag commit in the parent repository"
    Assert-Equal "7.4.0" $remoteTag "Release from subdirectory must push the matching tag to origin"
    Assert-Equal "tag: 7.4.0" $remoteSubject "Release from subdirectory must push the release commit to origin"
    Assert-Match ($output -join "`n") "Release: True" "Release from subdirectory output must indicate release mode"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Release"
    Write-Host "Release Subdirectory Tag: $tag"
    Write-Host "Pushed Subdirectory Tag: $remoteTag"
    Write-TestSeparator
}

function Add-TestReleaseScenarioCommits {
    param([string]$RepositoryPath)

    Add-TestGitCommit -RepositoryPath $RepositoryPath -Message "feat: add release analysis"
    Add-TestGitCommit -RepositoryPath $RepositoryPath -Message "fix: repair first issue"
    Add-TestGitCommit -RepositoryPath $RepositoryPath -Message "fix: repair second issue"
    Add-TestGitCommit -RepositoryPath $RepositoryPath -Message "fix: repair third issue"
    Add-TestGitCommit -RepositoryPath $RepositoryPath -Message "perf: improve release scan"
    Add-TestGitCommit -RepositoryPath $RepositoryPath -Message "docs: update usage"
    Add-TestGitCommit -RepositoryPath $RepositoryPath -Message "test: cover release scan"
    Add-TestGitCommit -RepositoryPath $RepositoryPath -Message "feat(api)!: change release baseline"
    Add-TestGitCommit -RepositoryPath $RepositoryPath -Message "feat: add final release behavior"
}

function Test-ReleaseUsesConventionalCommitsSinceLatestSemVerTag {
    $fixture = New-TestGitProject -Version "0.1.0" -NumVer "0.1.0"
    $path = $fixture.ProjectPath
    $repositoryPath = $fixture.RepositoryPath
    $remotePath = $fixture.RemotePath
    $branchName = $fixture.BranchName

    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "0.1.0") | Out-Null
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("push", "origin", "0.1.0") | Out-Null
    Add-TestReleaseScenarioCommits -RepositoryPath $repositoryPath

    $result = Invoke-WithIsolatedGitEnvironment {
        Reset-LastExitCode
        $scriptOutput = & $scriptPath -ProjectPath $path -Release *>&1
        return @{
            ExitCode = $LASTEXITCODE
            Output = $scriptOutput
        }
    }

    if ($null -ne $result.ExitCode -and $result.ExitCode -ne 0) {
        throw "Version.ps1 -Release conventional commit calculation failed with exit code $($result.ExitCode)."
    }

    $project = Read-Project $path
    $tag = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "--list", "1.1.0")
    $remoteTag = Invoke-TestGit -RepositoryPath $remotePath -Arguments @("tag", "--list", "1.1.0")
    $remoteSubject = Invoke-TestGit -RepositoryPath $remotePath -Arguments @("log", "-1", "--pretty=%s", "refs/heads/$branchName")

    Assert-Equal "1.1.0" $project.Version "Release must calculate Version from chronological conventional commits"
    Assert-Equal "1.1.0" $project.NumVer "Release must calculate NumVer from chronological conventional commits"
    Assert-Equal "1.1.0" $tag "Release must create the conventional commit SemVer tag"
    Assert-Equal "1.1.0" $remoteTag "Release must push the conventional commit SemVer tag"
    Assert-Equal "tag: 1.1.0" $remoteSubject "Release must push the calculated conventional tag commit"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Release"
    Write-Host "Conventional Release Tag: $tag"
    Write-TestSeparator
}

function Test-ReleaseIgnoresNonConventionalCommits {
    $fixture = New-TestGitProject -Version "0.1.0" -NumVer "0.1.0"
    $path = $fixture.ProjectPath
    $repositoryPath = $fixture.RepositoryPath

    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "0.1.0") | Out-Null
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("push", "origin", "0.1.0") | Out-Null
    Add-TestGitCommit -RepositoryPath $repositoryPath -Message "Initial cleanup before release"
    Add-TestGitCommit -RepositoryPath $repositoryPath -Message "feat: add release analysis"
    Add-TestGitCommit -RepositoryPath $repositoryPath -Message "quick patch for old script"
    Add-TestGitCommit -RepositoryPath $repositoryPath -Message "fix: repair first issue"
    Add-TestGitCommit -RepositoryPath $repositoryPath -Message "Merge branch main into release"
    Add-TestGitCommit -RepositoryPath $repositoryPath -Message "perf: improve release scan"
    Add-TestGitCommit -RepositoryPath $repositoryPath -Message "random notes"

    $result = Invoke-WithIsolatedGitEnvironment {
        Reset-LastExitCode
        $scriptOutput = & $scriptPath -ProjectPath $path -Release *>&1
        return @{
            ExitCode = $LASTEXITCODE
            Output = $scriptOutput
        }
    }

    if ($null -ne $result.ExitCode -and $result.ExitCode -ne 0) {
        throw "Version.ps1 -Release non-conventional commit ignore failed with exit code $($result.ExitCode)."
    }

    $project = Read-Project $path
    $tag = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "--list", "0.2.2")

    Assert-Equal "0.2.2" $project.Version "Release must ignore non-conventional commits while calculating Version"
    Assert-Equal "0.2.2" $project.NumVer "Release must ignore non-conventional commits while calculating NumVer"
    Assert-Equal "0.2.2" $tag "Release must create the tag calculated only from conventional commits"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Release"
    Write-Host "Ignored Non-Conventional Commits Tag: $tag"
    Write-TestSeparator
}

function Test-ReleaseMovesExistingTagWhenNoConventionalBumpExists {
    $fixture = New-TestGitProject -Version "1.2.3" -NumVer "1.2.3"
    $path = $fixture.ProjectPath
    $repositoryPath = $fixture.RepositoryPath
    $remotePath = $fixture.RemotePath
    $branchName = $fixture.BranchName

    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "1.2.3") | Out-Null
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("push", "origin", "1.2.3") | Out-Null
    Add-TestGitCommit -RepositoryPath $repositoryPath -Message "docs: update examples"

    $result = Invoke-WithIsolatedGitEnvironment {
        Reset-LastExitCode
        $scriptOutput = & $scriptPath -ProjectPath $path -Release *>&1
        return @{
            ExitCode = $LASTEXITCODE
            Output = $scriptOutput
        }
    }

    if ($null -ne $result.ExitCode -and $result.ExitCode -ne 0) {
        throw "Version.ps1 -Release existing tag move failed with exit code $($result.ExitCode)."
    }

    $project = Read-Project $path
    $head = @(Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("rev-parse", "HEAD"))[0].ToString().Trim()
    $tagCommit = @(Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("rev-parse", "1.2.3"))[0].ToString().Trim()
    $remoteTagCommit = @(Invoke-TestGit -RepositoryPath $remotePath -Arguments @("rev-parse", "1.2.3"))[0].ToString().Trim()
    $remoteBranchCommit = @(Invoke-TestGit -RepositoryPath $remotePath -Arguments @("rev-parse", "refs/heads/$branchName"))[0].ToString().Trim()

    Assert-Equal "1.2.3" $project.Version "Release must keep the latest SemVer tag when no conventional bump exists"
    Assert-Equal "1.2.3" $project.NumVer "Release must keep NumVer when no conventional bump exists"
    Assert-Equal $head $tagCommit "Release must move the existing local tag to the release commit"
    Assert-Equal $remoteBranchCommit $remoteTagCommit "Release must move the remote tag to the pushed release commit"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Release"
    Write-Host "Moved Release Tag: 1.2.3"
    Write-TestSeparator
}

function Test-ReleaseUsesProjectVersionAndCommitsAfterNonSemVerLatestTag {
    $fixture = New-TestGitProject -Version "0.1.0" -NumVer "0.1.0"
    $path = $fixture.ProjectPath
    $repositoryPath = $fixture.RepositoryPath

    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "0.1.0--") | Out-Null
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("push", "origin", "0.1.0--") | Out-Null
    Add-TestReleaseScenarioCommits -RepositoryPath $repositoryPath

    $result = Invoke-WithIsolatedGitEnvironment {
        Reset-LastExitCode
        $scriptOutput = & $scriptPath -ProjectPath $path -Release *>&1
        return @{
            ExitCode = $LASTEXITCODE
            Output = $scriptOutput
        }
    }

    if ($null -ne $result.ExitCode -and $result.ExitCode -ne 0) {
        throw "Version.ps1 -Release non-SemVer tag fallback failed with exit code $($result.ExitCode)."
    }

    $project = Read-Project $path
    $tag = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "--list", "1.1.0")

    Assert-Equal "1.1.0" $project.Version "Release must calculate Version from project version and commits after a non-SemVer tag"
    Assert-Equal "1.1.0" $project.NumVer "Release must calculate NumVer from project version and commits after a non-SemVer tag"
    Assert-Equal "1.1.0" $tag "Release must create the calculated SemVer tag when the latest tag is not SemVer"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Release"
    Write-Host "Non-SemVer Latest Tag Conventional Release: $tag"
    Write-TestSeparator
}

function Test-ReleaseUsesProjectVersionAndAllCommitsWhenNoTagsExist {
    $fixture = New-TestGitProject -Version "0.1.0" -NumVer "0.1.0"
    $path = $fixture.ProjectPath
    $repositoryPath = $fixture.RepositoryPath

    Add-TestReleaseScenarioCommits -RepositoryPath $repositoryPath

    $result = Invoke-WithIsolatedGitEnvironment {
        Reset-LastExitCode
        $scriptOutput = & $scriptPath -ProjectPath $path -Release *>&1
        return @{
            ExitCode = $LASTEXITCODE
            Output = $scriptOutput
        }
    }

    if ($null -ne $result.ExitCode -and $result.ExitCode -ne 0) {
        throw "Version.ps1 -Release no-tag conventional calculation failed with exit code $($result.ExitCode)."
    }

    $project = Read-Project $path
    $tag = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "--list", "1.1.0")

    Assert-Equal "1.1.0" $project.Version "Release must calculate Version from project version and all commits when there are no tags"
    Assert-Equal "1.1.0" $project.NumVer "Release must calculate NumVer from project version and all commits when there are no tags"
    Assert-Equal "1.1.0" $tag "Release must create the calculated SemVer tag when there are no tags"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Release"
    Write-Host "No-Tag Conventional Release: $tag"
    Write-TestSeparator
}

function Test-ReleaseFailsBeforeSavingWhenUntrackedFilesExist {
    $fixture = New-TestGitProject -Version "7.3.0" -NumVer "7.3.0"
    $path = $fixture.ProjectPath
    $repositoryPath = $fixture.RepositoryPath
    $untrackedPath = Join-Path $repositoryPath "notes.txt"
    Set-Content -Path $untrackedPath -Value "Untracked release note." -Encoding UTF8

    $headBefore = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("rev-parse", "HEAD")
    $errorMessage = $null

    try {
        Invoke-WithIsolatedGitEnvironment {
            Reset-LastExitCode
            & $scriptPath -ProjectPath $path -Release *> $null
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    if ($null -eq $errorMessage) {
        throw "Expected failure because release has untracked files."
    }

    $project = Read-Project $path
    $headAfter = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("rev-parse", "HEAD")
    $tag = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "--list", "7.3.1")
    $tagText = ($tag -join "")

    Assert-Equal "7.3.0" $project.Version "Release must not save project when untracked files exist"
    Assert-Equal "7.3.0" $project.NumVer "Release must not save NumVer when untracked files exist"
    Assert-Equal $headBefore $headAfter "Release must not create a commit when untracked files exist"
    Assert-Equal "" $tagText "Release must not create a tag when untracked files exist"
    Assert-Match $errorMessage "Release requires a completely clean Git working tree" "Release must explain clean tree requirement"
    Assert-Match $errorMessage "Untracked files: \?\? notes\.txt" "Release must explain untracked files"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Release"
    Write-Host "Expected Failure: True"
    Write-Host "Error: $errorMessage"
    Write-TestSeparator
}

function Test-ReleaseFailsBeforeSavingWhenUnstagedChangesExist {
    $fixture = New-TestGitProject -Version "7.3.0" -NumVer "7.3.0"
    $path = $fixture.ProjectPath
    $repositoryPath = $fixture.RepositoryPath
    $trackedPath = Join-Path $repositoryPath "notes.txt"
    Set-Content -Path $trackedPath -Value "Committed release note." -Encoding UTF8
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("add", "--", $trackedPath) | Out-Null
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("commit", "-m", "Add release notes") | Out-Null
    Set-Content -Path $trackedPath -Value "Unstaged release note." -Encoding UTF8

    $headBefore = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("rev-parse", "HEAD")
    $errorMessage = $null

    try {
        Invoke-WithIsolatedGitEnvironment {
            Reset-LastExitCode
            & $scriptPath -ProjectPath $path -Release *> $null
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    if ($null -eq $errorMessage) {
        throw "Expected failure because release has unstaged changes."
    }

    $project = Read-Project $path
    $headAfter = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("rev-parse", "HEAD")
    $tag = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "--list", "7.3.1")
    $tagText = ($tag -join "")

    Assert-Equal "7.3.0" $project.Version "Release must not save project when unstaged changes exist"
    Assert-Equal "7.3.0" $project.NumVer "Release must not save NumVer when unstaged changes exist"
    Assert-Equal $headBefore $headAfter "Release must not create a commit when unstaged changes exist"
    Assert-Equal "" $tagText "Release must not create a tag when unstaged changes exist"
    Assert-Match $errorMessage "Release requires a completely clean Git working tree" "Release must explain clean tree requirement"
    Assert-Match $errorMessage "Unstaged changes:  M notes\.txt" "Release must explain unstaged changes"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Release"
    Write-Host "Expected Failure: True"
    Write-Host "Error: $errorMessage"
    Write-TestSeparator
}

function Test-ReleaseFailsBeforeSavingWhenStagedChangesExist {
    $fixture = New-TestGitProject -Version "7.3.0" -NumVer "7.3.0"
    $path = $fixture.ProjectPath
    $repositoryPath = $fixture.RepositoryPath
    $stagedPath = Join-Path $repositoryPath "notes.txt"
    Set-Content -Path $stagedPath -Value "Staged release note." -Encoding UTF8
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("add", "--", $stagedPath) | Out-Null

    $headBefore = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("rev-parse", "HEAD")
    $errorMessage = $null

    try {
        Invoke-WithIsolatedGitEnvironment {
            Reset-LastExitCode
            & $scriptPath -ProjectPath $path -Release *> $null
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    if ($null -eq $errorMessage) {
        throw "Expected failure because release has staged changes."
    }

    $project = Read-Project $path
    $headAfter = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("rev-parse", "HEAD")
    $tag = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "--list", "7.3.1")
    $tagText = ($tag -join "")

    Assert-Equal "7.3.0" $project.Version "Release must not save project when staged changes exist"
    Assert-Equal "7.3.0" $project.NumVer "Release must not save NumVer when staged changes exist"
    Assert-Equal $headBefore $headAfter "Release must not create a commit when staged changes exist"
    Assert-Equal "" $tagText "Release must not create a tag when staged changes exist"
    Assert-Match $errorMessage "Release requires a completely clean Git working tree" "Release must explain clean tree requirement"
    Assert-Match $errorMessage "Staged changes: A  notes\.txt" "Release must explain staged changes"

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Release"
    Write-Host "Expected Failure: True"
    Write-Host "Error: $errorMessage"
    Write-TestSeparator
}

function Test-ReleaseRejectsTypeParameter {
    $path = New-TestProject -Version "7.3.0" -NumVer "7.3.0"
    $errorMessage = $null

    try {
        Reset-LastExitCode
        & $scriptPath -ProjectPath $path -Release -Type Patch *> $null
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    if ($null -eq $errorMessage) {
        throw "Expected failure because -Release must calculate the version without -Type."
    }

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Release -Type Patch"
    Write-Host "Expected Failure: True"
    Write-Host "Error: $errorMessage"
    Write-TestSeparator
}

function Test-PrereleaseNameRequired {
    $path = New-TestProject -Version "7.3.0"
    Invoke-VersionExpectFailure $path @{ Type = "Patch"; IsPrerelease = $true }
}

function Test-PrereleaseNameRequiredEvenWhenStored {
    $path = New-TestProject -Version "7.3.0" -PrereleaseName "rc"
    Invoke-VersionExpectFailure $path @{ Type = "Patch"; IsPrerelease = $true }
}

function Test-BuildNameRequired {
    $path = New-TestProject -Version "7.3.0"
    Invoke-VersionExpectFailure $path @{ Type = "Patch"; IsBuild = $true }
}

function Test-BuildNameRequiredEvenWhenStored {
    $path = New-TestProject -Version "7.3.0" -BuildName "Build"
    Invoke-VersionExpectFailure $path @{ Type = "Patch"; IsBuild = $true }
}

function Test-InvalidPrereleaseNameRejected {
    $path = New-TestProject -Version "7.3.0"
    Invoke-VersionExpectFailure $path @{ Type = "Patch"; IsPrerelease = $true; PrereleaseName = "rc.1+5" }
}

function Test-InvalidBuildNameRejected {
    $path = New-TestProject -Version "7.3.0"
    Invoke-VersionExpectFailure $path @{ Type = "Patch"; IsBuild = $true; BuildName = "Build+5" }
}

function Test-NegativeFlagsWin {
    $path = New-TestProject -Version "7.3.0" -PrereleaseName "rc" -BuildName "Build"
    Invoke-Version $path @{ Type = "Patch"; IsPrerelease = $true; PrereleaseName = "rc"; IsNotPrerelease = $true; IsBuild = $true; BuildName = "Build"; IsNotBuild = $true }
    $project = Read-Project $path

    Assert-Equal "7.3.1" $project.Version "Negative flags must win"
    Assert-Equal "False" $project.IsPrerelease "IsNotPrerelease must store false"
    Assert-Equal "False" $project.IsBuild "IsNotBuild must store false"
    Assert-Equal "" $project.PrereleaseName "IsNotPrerelease must clear PrereleaseName"
    Assert-Equal "" $project.BuildName "IsNotBuild must clear BuildName"
}

function Test-IsNotPrereleaseClearsOnlyPrerelease {
    $path = New-TestProject -Version "7.3.0" -PrereleaseName "rc" -BuildName "Build"
    Invoke-Version $path @{ Type = "Patch"; IsPrerelease = $true; PrereleaseName = "rc"; IsNotPrerelease = $true; IsBuild = $true; BuildName = "Build" }
    $project = Read-Project $path

    Assert-Match $project.Version '^7\.3\.1\+Build\.\d+$' "IsNotPrerelease must allow build"
    Assert-Equal "False" $project.IsPrerelease "IsNotPrerelease must disable prerelease"
    Assert-Equal "" $project.PrereleaseName "IsNotPrerelease must clear PrereleaseName"
    Assert-Equal "True" $project.IsBuild "IsBuild must remain active"
    Assert-Equal "Build" $project.BuildName "BuildName must remain unchanged"
}

function Test-IsNotBuildClearsOnlyBuild {
    $path = New-TestProject -Version "7.3.0" -PrereleaseName "rc" -BuildName "Build"
    Invoke-Version $path @{ Type = "Patch"; IsPrerelease = $true; PrereleaseName = "rc"; IsBuild = $true; BuildName = "Build"; IsNotBuild = $true }
    $project = Read-Project $path

    Assert-Equal "7.3.1-rc" $project.Version "IsNotBuild must allow prerelease"
    Assert-Equal "True" $project.IsPrerelease "IsPrerelease must remain active"
    Assert-Equal "rc" $project.PrereleaseName "PrereleaseName must remain unchanged"
    Assert-Equal "False" $project.IsBuild "IsNotBuild must disable build"
    Assert-Equal "" $project.BuildName "IsNotBuild must clear BuildName"
}

function Test-MajorResets {
    $path = New-TestProject -Version "7.3.9"
    Invoke-Version $path @{ Type = "Major" }
    $project = Read-Project $path

    Assert-Equal "8.0.0" $project.NumVer "Major must reset minor and patch"
    Assert-Equal "8.0.0" $project.Version "Stable major must leave normal Version"
}

function Test-WhatIfDoesNotSaveProject {
    $path = New-TestProject -Version "7.3.0"
    Reset-LastExitCode
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

    Write-Host "./Version.ps1 -ProjectPath $displayProjectPath -Type Patch -WhatIf"
    Write-Host "WhatIf Output: OK"
    Write-TestSeparator
}

try {
    Invoke-Usage
    Invoke-UsageExpectFailure
    Invoke-ScriptVersion
    Invoke-ValidateVersionReturnsValidValue
    Invoke-ValidateVersionReturnsEmptyWhenInvalid
    Invoke-ValidateVersionDetailedKeepsCaptureClean
    Invoke-ValidateWithoutSemVerReturnsEmpty
    if ($env:VERSION_TESTS_SKIP_TESTS_PARAMETER -ne "1") {
        Invoke-TestsParameterRunsTests
    }
    Invoke-ScriptVersionExpectFailure
    Invoke-ProjectVersion
    Invoke-ProjectVersionCreatesMissing
    Invoke-ProjectVersionExpectFailure
    Invoke-ProjectBuildNumberReturnsExisting
    Invoke-ProjectBuildNumberGeneratesMissing
    Invoke-ProjectBuildNumberRefreshesExisting
    Invoke-ProjectBuildNumberExpectFailure
    Test-StableSwitchPromotesPrereleaseAndBuildWithoutBump
    Test-StableSwitchPromotesPrereleaseOnlyWithoutBump
    Test-StableSwitchPromotesBuildOnlyWithoutBump
    Test-StableSwitchWithPatchBumpsAndPromotes
    Test-StableSwitchAlonePromotesWithoutBump
    Test-StableTypeRejected
    Test-PrereleaseFromParameter
    Test-BuildFromParameter
    Test-PrereleaseAndBuild
    Test-BumpKeepsStoredNames
    Test-StoredPrereleaseNameAppliesWithoutFlag
    Test-StoredBuildNameAppliesWithoutFlag
    Test-VersionUpdateRefreshesBuildNumber
    Test-MissingVersionStartsFromDefaultInitialVersion
    Test-MissingVersionPatchBumpsFromDefaultInitialVersion
    Test-ReleaseCreatesCommitAndTag
    Test-ReleaseWorksFromProjectSubdirectory
    Test-ReleaseUsesConventionalCommitsSinceLatestSemVerTag
    Test-ReleaseIgnoresNonConventionalCommits
    Test-ReleaseMovesExistingTagWhenNoConventionalBumpExists
    Test-ReleaseUsesProjectVersionAndCommitsAfterNonSemVerLatestTag
    Test-ReleaseUsesProjectVersionAndAllCommitsWhenNoTagsExist
    Test-ReleaseFailsBeforeSavingWhenUntrackedFilesExist
    Test-ReleaseFailsBeforeSavingWhenUnstagedChangesExist
    Test-ReleaseFailsBeforeSavingWhenStagedChangesExist
    Test-ReleaseRejectsTypeParameter
    Test-PrereleaseNameRequired
    Test-PrereleaseNameRequiredEvenWhenStored
    Test-BuildNameRequired
    Test-BuildNameRequiredEvenWhenStored
    Test-InvalidPrereleaseNameRejected
    Test-InvalidBuildNameRejected
    Test-NegativeFlagsWin
    Test-IsNotPrereleaseClearsOnlyPrerelease
    Test-IsNotBuildClearsOnlyBuild
    Test-MajorResets
    Test-WhatIfDoesNotSaveProject

    Write-Host "All tests passed."
}
catch {
    if ($script:CompletedTests -lt $script:TotalTests) {
        Write-TestStatus "FAIL" Red
        Write-Host ("─" * 60)
    }

    throw
}
finally {
    if (Test-Path $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
