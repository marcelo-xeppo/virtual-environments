function Get-XcodeRootPath {
    Param (
        [Parameter(Mandatory)]
        [string] $Version
    )

    return "/Applications/Xcode_$Version.app"
}

function Get-DefaultXcodeRootPath {
    return (Get-Item -Path "/Applications/Xcode.app").Target
}

function Get-XcodeToolPath {
    param (
        [Parameter(ParameterSetName = 'Version')]
        [string] $Version,
        [Parameter(ParameterSetName = 'Path')]
        [string] $XcodeRootPath,
        [string] $ToolName
    )

    if ($PSCmdlet.ParameterSetName -eq "Version") {
        $XcodeRootPath = Get-XcodeRootPath $Version
    }

    return Join-Path $XcodeRootPath "Contents/Developer/usr/bin" $ToolName
}

function Get-XcodeVersionInfo {
    param(
        [Parameter(Mandatory)]
        [string]$XcodeRootPath
    )

    $xcodebuildPath = Get-XcodeToolPath -XcodeRootPath $XcodeRootPath -ToolName "xcodebuild"
    [string]$output = Invoke-Expression "$xcodebuildPath -version"
    $versionOutputParts = $output.Split(" ")
    return @{
        Version = [System.Version]::Parse($versionOutputParts[1])
        Build = $versionOutputParts[4]
    }
}


function Switch-Xcode {
    param (
        [Parameter(ParameterSetName = 'Version')]
        [string] $Version,
        [Parameter(ParameterSetName = 'Path')]
        [string] $XcodeRootPath
    )

    if ($PSCmdlet.ParameterSetName -eq "Version") {
        $XcodeRootPath = Get-XcodeRootPath $Version
    }

    Write-Verbose "Switching Xcode to '${XcodeRootPath}'"
    Invoke-Expression "sudo xcode-select --switch ${XcodeRootPath}"
}

function Test-XcodeStableRelease {
    param (
        [Parameter(ParameterSetName = 'Version')]
        [string] $Version,
        [Parameter(ParameterSetName = 'Path')]
        [string] $XcodeRootPath
    )

    if ($PSCmdlet.ParameterSetName -eq "Version") {
        $XcodeRootPath = Get-XcodeRootPath $Version
    }

    $licenseInfoPlistPath = Join-Path $XcodeRootPath "Contents" "Resources" "LicenseInfo.plist"
    $releaseType = & defaults read $licenseInfoPlistPath "licenseType"
    return -not ($releaseType -match "beta")
}

function Get-XcodeSimulatorsInfo {
    param(
        [string] $Filter
    )

    [string]$rawSimulatorsInfo = Invoke-Expression "xcrun simctl list --json"
    $jsonSimulatorsInfo = $rawSimulatorsInfo | ConvertFrom-Json

    if ($Filter) {
        return $jsonSimulatorsInfo | Select-Object -ExpandProperty $Filter
    }

    return $jsonSimulatorsInfo
}

function Get-XcodeDevicesList {
    $result = @()

    $runtimes = Get-XcodeSimulatorsInfo -Filter "devices"
    $runtimes.PSObject.Properties | ForEach-Object {
        $runtimeName = $_.Name
        $devices = $_.Value
        $devices | Where-Object {
            $availability = $_.availability
            $isAvailable = $_.isAvailable
            return (($availability -eq "(available)") -or ($isAvailable -eq "YES") -or ($isAvailable -eq $true))
        } | ForEach-Object {
            $deviceName = $_.name
            $result += "$runtimeName $deviceName"
        }
    }
    return $result
}

function Get-XcodePairsList {
    $result = @()

    $runtimes = Get-XcodeSimulatorsInfo -Filter "pairs"
    $runtimes.PSObject.Properties | Where-Object {
        return $_.Value.state -match "active"
    } | ForEach-Object {
        $watchName = $_.Value.watch.name
        $phoneName = $_.Value.phone.name
        $result += "$watchName $phoneName"
    }
    return $result
}