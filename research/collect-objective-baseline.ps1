<#
Read-only baseline collector for anti-input-lag research.

Examples:

  .\collect-objective-baseline.ps1 -Label pre-test
  .\collect-objective-baseline.ps1 -Label frankfurt1-night -Target "1.1.1.1","8.8.8.8"
  .\collect-objective-baseline.ps1 -Label route-a -Target "example.com" -IncludeTraceRoute
#>

[CmdletBinding()]
param(
    [string]$Label = "baseline",
    [string[]]$Target = @(),
    [ValidateRange(5, 5000)]
    [int]$PingCount = 120,
    [ValidateRange(0, 5000)]
    [int]$PauseMs = 250,
    [switch]$IncludeTraceRoute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-SafeName {
    param([string]$Name)
    return ($Name -replace "[^A-Za-z0-9._-]", "_")
}

function Save-TextSnapshot {
    param(
        [string]$Path,
        [scriptblock]$ScriptBlock
    )

    try {
        & $ScriptBlock | Out-File -FilePath $Path -Width 4096 -Encoding utf8
    }
    catch {
        $_ | Out-File -FilePath $Path -Width 4096 -Encoding utf8
    }
}

function Save-Json {
    param(
        [string]$Path,
        [object]$InputObject
    )

    $InputObject | ConvertTo-Json -Depth 8 | Out-File -FilePath $Path -Encoding utf8
}

function Save-CommandSnapshot {
    param(
        [string]$Path,
        [string]$Command,
        [string[]]$ArgumentList = @()
    )

    try {
        & $Command @ArgumentList 2>&1 | Out-File -FilePath $Path -Width 4096 -Encoding utf8
    }
    catch {
        $_ | Out-File -FilePath $Path -Width 4096 -Encoding utf8
    }
}

function Get-Percentile {
    param(
        [double[]]$Values,
        [ValidateRange(0, 100)]
        [double]$Percentile
    )

    if (-not $Values -or $Values.Count -eq 0) {
        return $null
    }

    $index = [math]::Ceiling(($Percentile / 100) * $Values.Count) - 1
    if ($index -lt 0) {
        $index = 0
    }
    if ($index -ge $Values.Count) {
        $index = $Values.Count - 1
    }

    return [math]::Round($Values[$index], 2)
}

function Get-StandardDeviation {
    param([double[]]$Values)

    if (-not $Values -or $Values.Count -lt 2) {
        return 0.0
    }

    $mean = ($Values | Measure-Object -Average).Average
    $sumSquares = 0.0
    foreach ($value in $Values) {
        $sumSquares += [math]::Pow(($value - $mean), 2)
    }

    return [math]::Round([math]::Sqrt($sumSquares / $Values.Count), 2)
}

function Measure-PingSeries {
    param(
        [string]$ComputerName,
        [int]$Count,
        [int]$PauseMilliseconds
    )

    $ping = [System.Net.NetworkInformation.Ping]::new()
    $samples = New-Object "System.Collections.Generic.List[psobject]"

    try {
        for ($sampleNumber = 1; $sampleNumber -le $Count; $sampleNumber++) {
            $timestamp = Get-Date
            $reply = $null
            $status = "Unknown"
            $rttMs = $null

            try {
                $reply = $ping.Send($ComputerName, 1000)
                if ($null -ne $reply) {
                    $status = $reply.Status.ToString()
                    if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                        $rttMs = [double]$reply.RoundtripTime
                    }
                }
            }
            catch {
                $status = $_.Exception.Message
            }

            [void]$samples.Add([pscustomobject]@{
                Sample     = $sampleNumber
                Timestamp  = $timestamp.ToString("o")
                Status     = $status
                RttMs      = $rttMs
            })

            if ($sampleNumber -lt $Count -and $PauseMilliseconds -gt 0) {
                Start-Sleep -Milliseconds $PauseMilliseconds
            }
        }
    }
    finally {
        $ping.Dispose()
    }

    return $samples.ToArray()
}

function Get-PingSummary {
    param([object[]]$Samples)

    $normalizedSamples = @($Samples)
    $successValues = New-Object "System.Collections.Generic.List[double]"
    foreach ($sample in $normalizedSamples) {
        $rttProperty = $sample.PSObject.Properties["RttMs"]
        if ($null -ne $rttProperty -and $null -ne $rttProperty.Value) {
            [void]$successValues.Add([double]$rttProperty.Value)
        }
    }

    $successArray = $successValues.ToArray()
    $sent = $normalizedSamples.Count
    $success = $successArray.Count
    $lossPct = if ($sent -gt 0) {
        [math]::Round((($sent - $success) / $sent) * 100, 2)
    }
    else {
        $null
    }

    if ($success -eq 0) {
        return [pscustomobject]@{
            Sent                 = $sent
            Success              = $success
            LossPct              = $lossPct
            MinRttMs             = $null
            MeanRttMs            = $null
            P95RttMs             = $null
            P99RttMs             = $null
            MaxRttMs             = $null
            JitterStdDevMs       = $null
            JitterMeanAbsDeltaMs = $null
        }
    }

    $sortedValues = @($successArray | Sort-Object)
    $meanRtt = [math]::Round(($successArray | Measure-Object -Average).Average, 2)
    $minRtt = [math]::Round(($sortedValues | Measure-Object -Minimum).Minimum, 2)
    $maxRtt = [math]::Round(($sortedValues | Measure-Object -Maximum).Maximum, 2)

    $deltas = New-Object "System.Collections.Generic.List[double]"
    for ($index = 1; $index -lt $successArray.Count; $index++) {
        [void]$deltas.Add([math]::Abs($successArray[$index] - $successArray[$index - 1]))
    }

    $deltaArray = $deltas.ToArray()
    $meanAbsDelta = if ($deltaArray.Count -gt 0) {
        [math]::Round(($deltaArray | Measure-Object -Average).Average, 2)
    }
    else {
        0.0
    }

    return [pscustomobject]@{
        Sent                 = $sent
        Success              = $success
        LossPct              = $lossPct
        MinRttMs             = $minRtt
        MeanRttMs            = $meanRtt
        P95RttMs             = Get-Percentile -Values $sortedValues -Percentile 95
        P99RttMs             = Get-Percentile -Values $sortedValues -Percentile 99
        MaxRttMs             = $maxRtt
        JitterStdDevMs       = Get-StandardDeviation -Values $successArray
        JitterMeanAbsDeltaMs = $meanAbsDelta
    }
}

function Get-ActivePowerPlanText {
    try {
        return (powercfg /GETACTIVESCHEME | Out-String).Trim()
    }
    catch {
        return $_.Exception.Message
    }
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$sessionRoot = Join-Path $PSScriptRoot "test-baselines"
$runRoot = Join-Path $sessionRoot ("{0}-{1}" -f $timestamp, (Get-SafeName -Name $Label))
New-Item -Path $runRoot -ItemType Directory -Force | Out-Null

$os = Get-CimInstance Win32_OperatingSystem
$computerSystem = Get-CimInstance Win32_ComputerSystem
$processors = Get-CimInstance Win32_Processor
$gpus = Get-CimInstance Win32_VideoController

Write-Step "Saving read-only baseline snapshots to $runRoot"

Save-TextSnapshot -Path (Join-Path $runRoot "system-summary.txt") -ScriptBlock {
    "== Operating system =="
    $os | Format-List Caption, Version, BuildNumber, OSArchitecture, LastBootUpTime
    ""
    "== Computer system =="
    $computerSystem | Format-List Manufacturer, Model, TotalPhysicalMemory
    ""
    "== Processor =="
    $processors | Format-List Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
    ""
    "== Video controller =="
    $gpus | Format-Table -AutoSize Name, DriverVersion
}

Save-CommandSnapshot -Path (Join-Path $runRoot "power-plan.txt") -Command "powercfg.exe" -ArgumentList @("/GETACTIVESCHEME")
Save-CommandSnapshot -Path (Join-Path $runRoot "tcp-global.txt") -Command "netsh.exe" -ArgumentList @("int", "tcp", "show", "global")
Save-CommandSnapshot -Path (Join-Path $runRoot "ipconfig-all.txt") -Command "ipconfig.exe" -ArgumentList @("/all")

Save-TextSnapshot -Path (Join-Path $runRoot "net-adapters.txt") -ScriptBlock {
    if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
        Get-NetAdapter -IncludeHidden | Sort-Object Name | Format-Table -AutoSize Name, InterfaceDescription, Status, LinkSpeed, MacAddress
    }
    else {
        "Get-NetAdapter is not available on this system."
    }
}

Save-TextSnapshot -Path (Join-Path $runRoot "net-offload-global.txt") -ScriptBlock {
    if (Get-Command Get-NetOffloadGlobalSetting -ErrorAction SilentlyContinue) {
        Get-NetOffloadGlobalSetting | Format-List *
    }
    else {
        "Get-NetOffloadGlobalSetting is not available on this system."
    }
}

Save-TextSnapshot -Path (Join-Path $runRoot "net-rss.txt") -ScriptBlock {
    if (Get-Command Get-NetAdapterRss -ErrorAction SilentlyContinue) {
        Get-NetAdapterRss -Name "*" | Format-List *
    }
    else {
        "Get-NetAdapterRss is not available on this system."
    }
}

Save-TextSnapshot -Path (Join-Path $runRoot "net-rsc.txt") -ScriptBlock {
    if (Get-Command Get-NetAdapterRsc -ErrorAction SilentlyContinue) {
        Get-NetAdapterRsc -Name "*" | Format-List *
    }
    else {
        "Get-NetAdapterRsc is not available on this system."
    }
}

Save-TextSnapshot -Path (Join-Path $runRoot "net-checksum-offload.txt") -ScriptBlock {
    if (Get-Command Get-NetAdapterChecksumOffload -ErrorAction SilentlyContinue) {
        Get-NetAdapterChecksumOffload -Name "*" | Format-List *
    }
    else {
        "Get-NetAdapterChecksumOffload is not available on this system."
    }
}

Save-TextSnapshot -Path (Join-Path $runRoot "net-advanced-properties.txt") -ScriptBlock {
    if (Get-Command Get-NetAdapterAdvancedProperty -ErrorAction SilentlyContinue) {
        Get-NetAdapterAdvancedProperty -Name "*" -IncludeHidden | Sort-Object Name, DisplayName | Format-Table -AutoSize Name, DisplayName, RegistryKeyword, RegistryValue
    }
    else {
        "Get-NetAdapterAdvancedProperty is not available on this system."
    }
}

$targetSummaries = @()
foreach ($currentTarget in $Target) {
    $safeTargetName = Get-SafeName -Name $currentTarget
    Write-Step "Measuring ping series for $currentTarget"

    $samples = Measure-PingSeries -ComputerName $currentTarget -Count $PingCount -PauseMilliseconds $PauseMs
    $summary = Get-PingSummary -Samples $samples

    $samples | Export-Csv -Path (Join-Path $runRoot ("ping-{0}-raw.csv" -f $safeTargetName)) -NoTypeInformation -Encoding utf8
    Save-Json -Path (Join-Path $runRoot ("ping-{0}-summary.json" -f $safeTargetName)) -InputObject $summary

    Save-TextSnapshot -Path (Join-Path $runRoot ("tnc-{0}.txt" -f $safeTargetName)) -ScriptBlock {
        if (Get-Command Test-NetConnection -ErrorAction SilentlyContinue) {
            Test-NetConnection -ComputerName $currentTarget -InformationLevel Detailed
        }
        else {
            "Test-NetConnection is not available on this system."
        }
    }

    if ($IncludeTraceRoute) {
        Save-CommandSnapshot -Path (Join-Path $runRoot ("tracert-{0}.txt" -f $safeTargetName)) -Command "tracert.exe" -ArgumentList @("-d", $currentTarget)
    }

    $targetSummaries += [pscustomobject]@{
        Target  = $currentTarget
        Summary = $summary
    }
}

$manifest = [pscustomobject]@{
    Label            = $Label
    CollectedAt      = (Get-Date).ToString("o")
    OutputPath       = $runRoot
    PingCount        = $PingCount
    PauseMs          = $PauseMs
    MachineName      = $env:COMPUTERNAME
    OSCaption        = $os.Caption
    OSVersion        = $os.Version
    OSBuild          = $os.BuildNumber
    ComputerModel    = $computerSystem.Model
    ActivePowerPlan  = Get-ActivePowerPlanText
    Targets          = $targetSummaries
}

Save-Json -Path (Join-Path $runRoot "baseline-manifest.json") -InputObject $manifest

Write-Host ""
Write-Host "Baseline collection complete." -ForegroundColor Green
Write-Host "Output: $runRoot" -ForegroundColor Green
if ($Target.Count -gt 0) {
    Write-Host "Measured targets: $($Target -join ', ')" -ForegroundColor Green
}
Write-Host "Files created under: $runRoot" -ForegroundColor Green
