$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "Version.ps1"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("VersionTests-" + [Guid]::NewGuid().ToString("N"))
$testGitHome = Join-Path $testRoot "GitHome"
$testGitConfig = Join-Path $testGitHome ".gitconfig"

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

    return @{
        RepositoryPath = $repositoryPath
        ProjectPath = $path
    }
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

    Assert-Equal "1.7.1" $output "Script version output must match"

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

function Invoke-ProjectVersion {
    $path = New-TestProject -Version "7.3.0-rc2+Build.123"
    $output = & $scriptPath -ProjectPath $path -Version
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -ProjectPath <path> -Version failed with exit code $LASTEXITCODE."
    }

    Assert-Equal "7.3.0-rc2+Build.123" $output "Project version output must match"

    Write-Host "./Version.ps1 -ProjectPath $path -Version"
    Write-Host "Project Version: $output"
    Write-TestSeparator
}

function Invoke-ProjectVersionExpectFailure {
    $errorMessage = $null
    $path = New-TestProject

    try {
        & $scriptPath -ProjectPath $path -Version -Type Patch *> $null
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    if ($null -eq $errorMessage) {
        throw "Expected failure because project -Version cannot be combined with -Type."
    }

    Write-Host "./Version.ps1 -ProjectPath $path -Version -Type Patch"
    Write-Host "Expected Failure: True"
    Write-Host "Error: $errorMessage"
    Write-TestSeparator
}

function Invoke-ProjectBuildNumberReturnsExisting {
    $path = New-TestProject -BuildNumber "1234567890"
    $output = & $scriptPath -ProjectPath $path -BuildNumber
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -ProjectPath <path> -BuildNumber failed with exit code $LASTEXITCODE."
    }

    $project = Read-Project $path

    Assert-Equal "1234567890" $output "Project BuildNumber output must match existing value"
    Assert-Equal "1234567890" $project.BuildNumber "Project BuildNumber must remain unchanged"

    Write-Host "./Version.ps1 -ProjectPath $path -BuildNumber"
    Write-Host "Project BuildNumber: $output"
    Write-TestSeparator
}

function Invoke-ProjectBuildNumberGeneratesMissing {
    $path = New-TestProject
    $output = & $scriptPath -ProjectPath $path -BuildNumber
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Version.ps1 -ProjectPath <path> -BuildNumber failed with exit code $LASTEXITCODE."
    }

    $project = Read-Project $path

    Assert-Match $output '^\d+$' "Project BuildNumber output must be an epoch value"
    Assert-Equal $output $project.BuildNumber "Generated BuildNumber must be saved to the project"

    Write-Host "./Version.ps1 -ProjectPath $path -BuildNumber"
    Write-Host "Generated BuildNumber: $output"
    Write-TestSeparator
}

function Invoke-ProjectBuildNumberRefreshesExisting {
    $path = New-TestProject -BuildNumber "1"
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

    Write-Host "./Version.ps1 -ProjectPath $path -BuildNumber -Refresh"
    Write-Host "Refreshed BuildNumber: $output"
    Write-TestSeparator
}

function Invoke-ProjectBuildNumberExpectFailure {
    $errorMessage = $null
    $path = New-TestProject

    try {
        & $scriptPath -ProjectPath $path -BuildNumber -Type Patch *> $null
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    if ($null -eq $errorMessage) {
        throw "Expected failure because project -BuildNumber cannot be combined with -Type."
    }

    Write-Host "./Version.ps1 -ProjectPath $path -BuildNumber -Type Patch"
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

function Test-VersionUpdateRefreshesBuildNumber {
    $path = New-TestProject -Version "7.3.0" -BuildNumber "1"
    Invoke-Version $path @{ Type = "Patch" }
    $project = Read-Project $path

    Assert-Match $project.BuildNumber '^\d+$' "Version update must store BuildNumber epoch"
    if ($project.BuildNumber -eq "1") {
        throw "Version update must refresh an existing BuildNumber."
    }

    Write-Host "./Version.ps1 -ProjectPath $path -Type Patch"
    Write-Host "Refreshed BuildNumber: $($project.BuildNumber)"
    Write-TestSeparator
}

function Test-MissingVersionStartsFromDefaultInitialVersion {
    $path = New-TestProjectWithoutVersionProperties
    Invoke-Version $path @{ Type = "Stable" }
    $project = Read-Project $path

    Assert-Equal "0.1.0" $project.Version "Missing Version and NumVer must start from the default initial version"
    Assert-Equal "0.1.0" $project.NumVer "Missing NumVer must store the default initial version"
    Assert-Match $project.BuildNumber '^\d+$' "Default initial version must still store BuildNumber epoch"

    Write-Host "./Version.ps1 -ProjectPath $path -Type Stable"
    Write-Host "Default Initial Version: $($project.Version)"
    Write-TestSeparator
}

function Test-MissingVersionPatchBumpsFromDefaultInitialVersion {
    $path = New-TestProjectWithoutVersionProperties
    Invoke-Version $path @{ Type = "Patch" }
    $project = Read-Project $path

    Assert-Equal "0.1.1" $project.Version "Patch must bump from the default initial version"
    Assert-Equal "0.1.1" $project.NumVer "Patch must store the bumped default initial version"

    Write-Host "./Version.ps1 -ProjectPath $path -Type Patch"
    Write-Host "Default Initial Patch Version: $($project.Version)"
    Write-TestSeparator
}

function Test-ReleaseCreatesCommitAndTag {
    $fixture = New-TestGitProject -Version "7.3.0" -NumVer "7.3.0"
    $path = $fixture.ProjectPath
    $repositoryPath = $fixture.RepositoryPath

    $result = Invoke-WithIsolatedGitEnvironment {
        $scriptOutput = & $scriptPath -ProjectPath $path -Type Patch -Release *>&1
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

    Assert-Equal "7.3.1" $project.Version "Release must update Version"
    Assert-Equal "7.3.1" $project.NumVer "Release must update NumVer"
    Assert-Equal "7.3.1" $tag "Release must create a matching tag"
    Assert-Equal "Release 7.3.1" $subject "Release must create a matching commit"
    Assert-Match ($output -join "`n") "Release: True" "Release output must indicate release mode"

    Write-Host "./Version.ps1 -ProjectPath $path -Type Patch -Release"
    Write-Host "Release Tag: $tag"
    Write-TestSeparator
}

function Test-ReleaseWorksFromProjectSubdirectory {
    $fixture = New-TestGitProject -Version "7.3.0" -NumVer "7.3.0" -ProjectRelativeDirectory "src/MyProject"
    $path = $fixture.ProjectPath
    $repositoryPath = $fixture.RepositoryPath

    $result = Invoke-WithIsolatedGitEnvironment {
        $scriptOutput = & $scriptPath -ProjectPath $path -Type Minor -Release *>&1
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

    Assert-Equal "7.4.0" $project.Version "Release from subdirectory must update Version"
    Assert-Equal "7.4.0" $project.NumVer "Release from subdirectory must update NumVer"
    Assert-Equal "7.4.0" $tag "Release from subdirectory must create a matching tag in the parent repository"
    Assert-Equal "Release 7.4.0" $subject "Release from subdirectory must create a matching commit in the parent repository"
    Assert-Match ($output -join "`n") "Release: True" "Release from subdirectory output must indicate release mode"

    Write-Host "./Version.ps1 -ProjectPath $path -Type Minor -Release"
    Write-Host "Release Subdirectory Tag: $tag"
    Write-TestSeparator
}

function Test-ReleaseFailsBeforeSavingWhenTagExists {
    $fixture = New-TestGitProject -Version "7.3.0" -NumVer "7.3.0"
    $path = $fixture.ProjectPath
    $repositoryPath = $fixture.RepositoryPath
    Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "7.3.1") | Out-Null

    $headBefore = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("rev-parse", "HEAD")
    $errorMessage = $null

    try {
        Invoke-WithIsolatedGitEnvironment {
            & $scriptPath -ProjectPath $path -Type Patch -Release *> $null
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    if ($null -eq $errorMessage) {
        throw "Expected failure because release tag already exists."
    }

    $project = Read-Project $path
    $headAfter = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("rev-parse", "HEAD")

    Assert-Equal "7.3.0" $project.Version "Release must not save project when tag already exists"
    Assert-Equal "7.3.0" $project.NumVer "Release must not save NumVer when tag already exists"
    Assert-Equal $headBefore $headAfter "Release must not create a commit when tag already exists"
    Assert-Match $errorMessage "Tag already exists: 7\.3\.1" "Release must explain existing tag failure"

    Write-Host "./Version.ps1 -ProjectPath $path -Type Patch -Release"
    Write-Host "Expected Failure: True"
    Write-Host "Error: $errorMessage"
    Write-TestSeparator
}

function Test-ReleaseFailsBeforeSavingWhenPendingAddExists {
    $fixture = New-TestGitProject -Version "7.3.0" -NumVer "7.3.0"
    $path = $fixture.ProjectPath
    $repositoryPath = $fixture.RepositoryPath
    $untrackedPath = Join-Path $repositoryPath "notes.txt"
    Set-Content -Path $untrackedPath -Value "Untracked release note." -Encoding UTF8

    $headBefore = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("rev-parse", "HEAD")
    $errorMessage = $null

    try {
        Invoke-WithIsolatedGitEnvironment {
            & $scriptPath -ProjectPath $path -Type Patch -Release *> $null
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    if ($null -eq $errorMessage) {
        throw "Expected failure because release has pending git add items."
    }

    $project = Read-Project $path
    $headAfter = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("rev-parse", "HEAD")
    $tag = Invoke-TestGit -RepositoryPath $repositoryPath -Arguments @("tag", "--list", "7.3.1")
    $tagText = ($tag -join "")

    Assert-Equal "7.3.0" $project.Version "Release must not save project when pending git add items exist"
    Assert-Equal "7.3.0" $project.NumVer "Release must not save NumVer when pending git add items exist"
    Assert-Equal $headBefore $headAfter "Release must not create a commit when pending git add items exist"
    Assert-Equal "" $tagText "Release must not create a tag when pending git add items exist"
    Assert-Match $errorMessage "Release requires all repository changes to be staged" "Release must explain pending git add failure"

    Write-Host "./Version.ps1 -ProjectPath $path -Type Patch -Release"
    Write-Host "Expected Failure: True"
    Write-Host "Error: $errorMessage"
    Write-TestSeparator
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
    Invoke-ProjectVersion
    Invoke-ProjectVersionExpectFailure
    Invoke-ProjectBuildNumberReturnsExisting
    Invoke-ProjectBuildNumberGeneratesMissing
    Invoke-ProjectBuildNumberRefreshesExisting
    Invoke-ProjectBuildNumberExpectFailure
    Test-StableTypePromotesPrereleaseAndBuildWithoutBump
    Test-StableTypePromotesPrereleaseOnlyWithoutBump
    Test-StableTypePromotesBuildOnlyWithoutBump
    Test-StableSwitchWithPatchStillBumps
    Test-PrereleaseFromParameter
    Test-BuildFromParameter
    Test-PrereleaseAndBuild
    Test-BumpClearsStoredNames
    Test-VersionUpdateRefreshesBuildNumber
    Test-MissingVersionStartsFromDefaultInitialVersion
    Test-MissingVersionPatchBumpsFromDefaultInitialVersion
    Test-ReleaseCreatesCommitAndTag
    Test-ReleaseWorksFromProjectSubdirectory
    Test-ReleaseFailsBeforeSavingWhenTagExists
    Test-ReleaseFailsBeforeSavingWhenPendingAddExists
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
