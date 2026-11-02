# Copyright (C) Chemin-Neuf IT Team
# SPDX-License-Identifier: GPL-3.0-only
# Full license text: see LICENSE at the repository root

<#
.SYNOPSIS
    Sets the Windows UCPD (UserChoice Protection Driver) state.

.DESCRIPTION
    UCPD is a Microsoft kernel driver, shipped through Windows updates since early 2024,
    that blocks non-Microsoft tools from writing the UserChoice registry keys of protected
    associations (such as http, https and the PDF and HTML file types). Disabling it is
    needed when SetUserFTA must set those associations; the supported alternative is a
    default associations XML file deployed with DISM or Group Policy.
    Changes the effective state of the UCPD protection mechanism that protects default
    application UserChoice registry keys from third-party modification. Requires
    administrator rights. This includes configuring the service start type and, when
    disabling, attempting to stop the running driver immediately. Reports the state
    before and after the change. A reboot is required for any change to take full
    effect. When disabling, a stop of the running driver is attempted;
    kernel-mode drivers typically cannot be stopped without a reboot, so the stop attempt
    may fail gracefully and a reboot reminder is always emitted.
    The UCPD scheduled task(s) (such as \Microsoft\Windows\AppxDeploymentClient\UCPD velocity,
    which runs UCPDMgr.exe and can re-enable the driver) are disabled with -State Disabled and
    re-enabled with -State Default. The script exits with code 1 if a task cannot be changed.
    Results are logged to a logs\ subfolder next to the script, with fallback to %TEMP%.

.PARAMETER State
    Target UCPD state.
    Disabled - Configures the service start type to Disabled, disables the UCPD scheduled
               task(s), and attempts to stop the running driver immediately. A reboot is
               required if the stop attempt fails.
    Default  - Restores the Windows default configuration (System start type, UCPD scheduled
               task(s) enabled). A reboot is required for the driver to load if it is not
               already running.

.PARAMETER Verbosity
    Controls the amount of output written to the console.
    None     - no console output.
    Normal   - key steps and results only (default).
    Detailed - all steps including detail messages.

.PARAMETER LogVerbosity
    Controls the amount of output written to the log file.
    None     - no log file.
    Normal   - key steps and results only.
    Detailed - all steps including detail messages (default).

.PARAMETER Quiet
    Suppresses all console output. Takes priority over Verbosity.

.PARAMETER Version
    Displays the script name and version, then exits.

.EXAMPLE
    .\set-ucpd-service.ps1 -State Disabled

    Disables the UCPD service and its scheduled task(s), and attempts to stop the driver immediately.

.EXAMPLE
    .\set-ucpd-service.ps1 -State Default

    Restores the UCPD service to the Windows default start type (System) and re-enables its scheduled task(s).

.NOTES
    File:           set-ucpd-service.ps1
    Version:        3.1.0
    Author:         Claude Sonnet 4.6 (GitHub Copilot)
    Contributors:   Claude (GitHub Copilot)
    License:        GPL-3.0-only
    Prerequisites:  PowerShell 5.1+; administrator rights required

.LINK
    https://github.com/Chemin-Neuf/pc-set-default-applications
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Disabled', 'Default')]
    [string]$State,

    [Parameter()]
    [ValidateSet('None', 'Normal', 'Detailed')]
    [string]$Verbosity = 'Normal',

    [Parameter()]
    [ValidateSet('None', 'Normal', 'Detailed')]
    [string]$LogVerbosity = 'Detailed',

    [Parameter()]
    [switch]$Quiet,

    [Parameter()]
    [switch]$Version
)

# ============================================================
# VERSION
# ============================================================
$scriptVersion = '3.1.0'
if ($Version) {
    Write-Host ('set-ucpd-service.ps1  v{0}' -f $scriptVersion)
    exit 0
}

# ============================================================
# GLOBALS
# ============================================================
if ($Quiet) { $Verbosity = 'None' }
$Global:ConsoleVerbosity = $Verbosity
$Global:LogVerbosity     = $LogVerbosity

# ============================================================
# IMPORTS
# ============================================================
$sharedUtilsPath = Join-Path $PSScriptRoot 'SharedUtils.psd1'
if (-not (Test-Path $sharedUtilsPath)) {
    Write-Error ('SharedUtils.psd1 not found at: {0}' -f $sharedUtilsPath)
    exit 1
}
Import-Module $sharedUtilsPath -Force

$ucpdUtilsPath = Join-Path $PSScriptRoot 'UcpdUtils.psm1'
if (-not (Test-Path $ucpdUtilsPath)) {
    Write-Error ('UcpdUtils.psm1 not found at: {0}' -f $ucpdUtilsPath)
    exit 1
}
Import-Module $ucpdUtilsPath -Force

# ============================================================
# LOGGING
# ============================================================
Initialize-Log -ScriptName 'set-ucpd-service' -Version $scriptVersion
Initialize-ConsoleEncoding

# ============================================================
# MAIN
# ============================================================
Write-Info ('set-ucpd-service.ps1 v{0} starting' -f $scriptVersion)
Write-Detail ('Log file: {0}' -f $Global:LogFile)
Write-Info ('Requested state: {0}' -f $State)

$before = Get-UcpdStatus
Write-Info ('Before - Start type: {0} | Status: {1}' -f $before.StartTypeLabel, $before.RunningStatus)
foreach ($task in $before.Tasks) {
    Write-Info ('Before - Scheduled task: {0} | State: {1}' -f $task.FullPath, $task.State)
}

$result = Set-UcpdState -State $State

if (-not $result.Success) {
    switch ($result.Reason) {
        'NotAdmin' {
            Write-ErrorLog $result.Message
            Write-ErrorLog ('Re-run from an elevated PowerShell prompt: .\set-ucpd-service.ps1 -State {0}' -f $State)
            exit 1
        }
        'ConfigFailed' {
            Write-ErrorLog $result.Message
            if (-not $result.TaskSuccess) { Write-ErrorLog $result.TaskMessage }
            exit 1
        }
        default {
            Write-ErrorLog $result.Message
            if (-not $result.TaskSuccess) { Write-ErrorLog $result.TaskMessage }
            exit 1
        }
    }
}

if ($result.TaskSuccess) {
    Write-Info $result.TaskMessage
}
else {
    Write-ErrorLog $result.TaskMessage
}

switch ($result.Reason) {
    'NotRegistered'  { Write-Warn  $result.Message }
    'AlreadyAtTarget'{
        Write-Info $result.Message
        if ($result.RequiresReboot) { Write-Warn 'A reboot is required for the driver to stop.' }
    }
    'Stopped'        {
        $after = Get-UcpdStatus
        Write-Success $result.Message
        Write-Info ('After  - Start type: {0} | Status: {1}' -f $after.StartTypeLabel, $after.RunningStatus)
    }
    'RequiresReboot' {
        $after = Get-UcpdStatus
        Write-Success ('UCPD state set to {0}.' -f $State)
        Write-Info ('After  - Start type: {0} | Status: {1}' -f $after.StartTypeLabel, $after.RunningStatus)
        Write-Warn $result.Message
    }
    default          { Write-Info $result.Message }
}

$after = Get-UcpdStatus
foreach ($task in $after.Tasks) {
    Write-Info ('After  - Scheduled task: {0} | State: {1}' -f $task.FullPath, $task.State)
}

if (-not $result.TaskSuccess) {
    Write-ErrorLog ('The UCPD scheduled task(s) could not be set to {0}. If left enabled, they may re-enable UCPD.' -f $State)
    exit 1
}

exit 0