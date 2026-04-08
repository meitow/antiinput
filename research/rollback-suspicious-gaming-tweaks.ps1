#requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string[]]$AdapterName = @("*"),
    [switch]$FactoryResetAdvancedNicProperties,
    [switch]$TryEnableHpetDevice
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-WarnStep {
    param([string]$Message)
    Write-Warning $Message
}

function Save-Snapshot {
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

function Invoke-External {
    param(
        [string]$Label,
        [string]$FilePath,
        [string[]]$ArgumentList,
        [switch]$IgnoreExitCode
    )

    Write-Step $Label
    & $FilePath @ArgumentList
    $exitCode = $LASTEXITCODE

    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        Write-WarnStep "$Label returned exit code $exitCode."
    }
}

function Try-DeleteBcdValue {
    param([string]$Name)

    if (-not $PSCmdlet.ShouldProcess("BCD current entry", "Delete value '$Name'")) {
        return
    }

    Invoke-External -Label "Deleting BCD value '$Name'" -FilePath "bcdedit.exe" -ArgumentList @("/deletevalue", $Name) -IgnoreExitCode
}

function Remove-TcpRegistryTweaks {
    $interfaceRoot = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    $valueNames = @(
        "TcpAckFrequency",
        "TcpNoDelay",
        "TCPNoDelay",
        "TcpDelAckTicks"
    )

    if (-not (Test-Path $interfaceRoot)) {
        Write-WarnStep "TCP interface registry path not found: $interfaceRoot"
        return
    }

    Get-ChildItem -Path $interfaceRoot -ErrorAction SilentlyContinue | ForEach-Object {
        $keyPath = $_.PSPath
        $guid = $_.PSChildName

        foreach ($valueName in $valueNames) {
            $property = Get-ItemProperty -Path $keyPath -Name $valueName -ErrorAction SilentlyContinue
            if ($null -eq $property) {
                continue
            }

            if ($PSCmdlet.ShouldProcess($guid, "Remove registry value '$valueName'")) {
                Write-Step "Removing $valueName from interface $guid"
                Remove-ItemProperty -Path $keyPath -Name $valueName -ErrorAction SilentlyContinue
            }
        }
    }
}

function Get-TargetAdapters {
    $adapters = Get-NetAdapter -Name $AdapterName -IncludeHidden -ErrorAction SilentlyContinue | Sort-Object -Property Name -Unique
    if (-not $adapters) {
        Write-WarnStep "No adapters matched: $($AdapterName -join ', ')"
        return @()
    }

    return @($adapters)
}

function Enable-GlobalOffloads {
    if (-not (Get-Command Set-NetOffloadGlobalSetting -ErrorAction SilentlyContinue)) {
        Write-WarnStep "Set-NetOffloadGlobalSetting is not available on this system."
        return
    }

    if ($PSCmdlet.ShouldProcess("Global TCP/IP offload settings", "Enable RSS, RSC, and Task Offload")) {
        Write-Step "Enabling global RSS / RSC / Task Offload"
        try {
            Set-NetOffloadGlobalSetting -ReceiveSideScaling Enabled -ReceiveSegmentCoalescing Enabled -TaskOffload Enabled
        }
        catch {
            Write-WarnStep "Failed to enable one or more global offload settings: $($_.Exception.Message)"
        }
    }
}

function Restore-AdapterDefaults {
    param([Object[]]$Adapters)

    foreach ($adapter in $Adapters) {
        $name = $adapter.Name

        if (Get-Command Enable-NetAdapterRss -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess($name, "Enable RSS")) {
                try {
                    Write-Step "Enabling RSS on adapter '$name'"
                    Enable-NetAdapterRss -Name $name -Confirm:$false
                }
                catch {
                    Write-WarnStep "Could not enable RSS on '$name': $($_.Exception.Message)"
                }
            }
        }

        if (Get-Command Enable-NetAdapterRsc -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess($name, "Enable RSC")) {
                try {
                    Write-Step "Enabling RSC on adapter '$name'"
                    Enable-NetAdapterRsc -Name $name -Confirm:$false
                }
                catch {
                    Write-WarnStep "Could not enable RSC on '$name': $($_.Exception.Message)"
                }
            }
        }

        if (Get-Command Enable-NetAdapterChecksumOffload -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess($name, "Enable checksum offload")) {
                try {
                    Write-Step "Enabling checksum offload on adapter '$name'"
                    Enable-NetAdapterChecksumOffload -Name $name -Confirm:$false
                }
                catch {
                    Write-WarnStep "Could not enable checksum offload on '$name': $($_.Exception.Message)"
                }
            }
        }

        if ($FactoryResetAdvancedNicProperties -and (Get-Command Reset-NetAdapterAdvancedProperty -ErrorAction SilentlyContinue)) {
            if ($PSCmdlet.ShouldProcess($name, "Factory reset NIC advanced properties")) {
                try {
                    Write-Step "Resetting all advanced NIC properties on '$name' to factory defaults"
                    Reset-NetAdapterAdvancedProperty -Name $name -DisplayName "*" -Confirm:$false
                }
                catch {
                    Write-WarnStep "Could not reset advanced properties on '$name': $($_.Exception.Message)"
                }
            }
        }
    }
}

function Try-EnableHpetPnPDevice {
    if (-not $TryEnableHpetDevice) {
        return
    }

    if (-not (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue)) {
        Write-WarnStep "PnpDevice cmdlets are not available. Skipping HPET device step."
        return
    }

    $devices = Get-PnpDevice -PresentOnly:$false -ErrorAction SilentlyContinue | Where-Object {
        $_.FriendlyName -eq "High Precision Event Timer"
    }

    if (-not $devices) {
        Write-WarnStep "No 'High Precision Event Timer' device was found."
        return
    }

    foreach ($device in $devices) {
        if ($device.Status -eq "OK") {
            Write-Step "HPET PnP device is already enabled"
            continue
        }

        if ($PSCmdlet.ShouldProcess($device.FriendlyName, "Enable PnP device")) {
            try {
                Write-Step "Enabling HPET PnP device"
                Enable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false
            }
            catch {
                Write-WarnStep "Could not enable HPET device: $($_.Exception.Message)"
            }
        }
    }
}

$logRoot = Join-Path $PSScriptRoot "rollback-logs"
$sessionRoot = Join-Path $logRoot (Get-Date -Format "yyyyMMdd-HHmmss")
New-Item -Path $sessionRoot -ItemType Directory -Force | Out-Null

$transcriptPath = Join-Path $sessionRoot "transcript.txt"
Start-Transcript -Path $transcriptPath | Out-Null

try {
    Write-Step "Saving pre-rollback snapshots"

    Save-Snapshot -Path (Join-Path $sessionRoot "before-bcdedit.txt") -ScriptBlock { bcdedit /enum }
    Save-Snapshot -Path (Join-Path $sessionRoot "before-netsh-tcp-global.txt") -ScriptBlock { netsh int tcp show global }
    Save-Snapshot -Path (Join-Path $sessionRoot "before-offload-global.txt") -ScriptBlock { Get-NetOffloadGlobalSetting | Format-List * }
    Save-Snapshot -Path (Join-Path $sessionRoot "before-netadapter.txt") -ScriptBlock { Get-NetAdapter -IncludeHidden | Sort-Object Name | Format-Table -AutoSize Name, InterfaceDescription, Status, LinkSpeed }
    Save-Snapshot -Path (Join-Path $sessionRoot "before-rss.txt") -ScriptBlock { Get-NetAdapterRss -Name $AdapterName | Format-List * }
    Save-Snapshot -Path (Join-Path $sessionRoot "before-checksum-offload.txt") -ScriptBlock { Get-NetAdapterChecksumOffload -Name $AdapterName | Format-List * }
    Save-Snapshot -Path (Join-Path $sessionRoot "before-advanced-properties.txt") -ScriptBlock { Get-NetAdapterAdvancedProperty -Name $AdapterName -IncludeHidden | Sort-Object Name, DisplayName | Format-Table -AutoSize Name, DisplayName, RegistryKeyword, RegistryValue }

    $adapters = Get-TargetAdapters

    Write-Step "Rolling back BCD timer overrides"
    foreach ($name in @("useplatformclock", "useplatformtick", "disabledynamictick", "tscsyncpolicy")) {
        Try-DeleteBcdValue -Name $name
    }

    Write-Step "Removing per-interface TCP registry tweaks"
    Remove-TcpRegistryTweaks

    if ($PSCmdlet.ShouldProcess("TCP global settings", "Set autotuning level to normal")) {
        Invoke-External -Label "Setting TCP autotuning level to normal" -FilePath "netsh.exe" -ArgumentList @("int", "tcp", "set", "global", "autotuninglevel=normal") -IgnoreExitCode
    }

    Enable-GlobalOffloads
    Restore-AdapterDefaults -Adapters $adapters
    Try-EnableHpetPnPDevice

    Write-Step "Saving post-rollback snapshots"

    Save-Snapshot -Path (Join-Path $sessionRoot "after-bcdedit.txt") -ScriptBlock { bcdedit /enum }
    Save-Snapshot -Path (Join-Path $sessionRoot "after-netsh-tcp-global.txt") -ScriptBlock { netsh int tcp show global }
    Save-Snapshot -Path (Join-Path $sessionRoot "after-offload-global.txt") -ScriptBlock { Get-NetOffloadGlobalSetting | Format-List * }
    Save-Snapshot -Path (Join-Path $sessionRoot "after-netadapter.txt") -ScriptBlock { Get-NetAdapter -IncludeHidden | Sort-Object Name | Format-Table -AutoSize Name, InterfaceDescription, Status, LinkSpeed }
    Save-Snapshot -Path (Join-Path $sessionRoot "after-rss.txt") -ScriptBlock { Get-NetAdapterRss -Name $AdapterName | Format-List * }
    Save-Snapshot -Path (Join-Path $sessionRoot "after-checksum-offload.txt") -ScriptBlock { Get-NetAdapterChecksumOffload -Name $AdapterName | Format-List * }
    Save-Snapshot -Path (Join-Path $sessionRoot "after-advanced-properties.txt") -ScriptBlock { Get-NetAdapterAdvancedProperty -Name $AdapterName -IncludeHidden | Sort-Object Name, DisplayName | Format-Table -AutoSize Name, DisplayName, RegistryKeyword, RegistryValue }

    Write-Host ""
    Write-Host "Rollback complete." -ForegroundColor Green
    Write-Host "Logs and before/after snapshots: $sessionRoot" -ForegroundColor Green
    Write-Host "A reboot is recommended now." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This script does NOT change BIOS settings, router settings, ExitLag profiles, or other third-party tool configs." -ForegroundColor Yellow
    Write-Host "If your NIC was heavily modified through vendor-specific advanced properties, consider re-running with -FactoryResetAdvancedNicProperties." -ForegroundColor Yellow
}
finally {
    Stop-Transcript | Out-Null
}
