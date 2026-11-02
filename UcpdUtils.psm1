<#
  Copyright (C) Chemin-Neuf IT Team
  SPDX-License-Identifier: GPL-3.0-only
  Full license text: see LICENSE at the repository root
#>
# Original Author: Claude Sonnet 4.6 (GitHub Copilot)
# Major Contributors: Claude (GitHub Copilot)
<#
.SYNOPSIS
    Shared UCPD (UserChoice Protection Driver) functions for the pc-set-default-applications toolset.

.DESCRIPTION
    Provides Get-UcpdStatus and Set-UcpdState for reading and changing the UCPD driver state,
    including the UCPD scheduled task(s) that can re-enable the driver.
    Consumed by get-ucpd-status.ps1, set-ucpd-service.ps1, and set-default-applications.ps1.
    Never calls exit. Returns structured PSCustomObjects so callers can decide how to handle results.
#>

# ============================================================
# CONFIGURATION (module-level constants)
# ============================================================
$script:ucpdDriverPath      = Join-Path $env:SystemRoot 'System32\drivers\UCPD.sys'
$script:ucpdServiceName     = 'UCPD'
$script:ucpdRegistryPath    = 'HKLM:\SYSTEM\CurrentControlSet\Services\UCPD'
$script:ucpdDefaultScToken  = 'system' # sc.exe token for System (Windows default for this file system filter driver)
$script:ucpdDefaultStartDword = 1      # must match $script:ucpdDefaultScToken
# Scheduled task(s) running UCPDMgr.exe can re-enable the UCPD service after it was disabled.
# Tasks are only visible to elevated sessions.
$script:ucpdKnownTaskPaths    = @('\Microsoft\Windows\AppxDeploymentClient\UCPD velocity')
$script:ucpdTaskExecutable    = 'UCPDMgr.exe' # fallback discovery: any task whose action runs this file
$script:ucpdTaskDisabledState = 'Disabled'

# ============================================================
# PRIVATE HELPERS
# ============================================================

<#
.SYNOPSIS
    Translates a service Start DWORD to a readable label.
#>
function Get-UcpdStartTypeLabel {
    param(
        [Parameter(Mandatory=$true)]
        [int]$StartDword
    )
    switch ($StartDword) {
        0       { return 'Boot'      }
        1       { return 'System'    }
        2       { return 'Automatic' }
        3       { return 'Manual'    }
        4       { return 'Disabled'  }
        default { return ('Unknown ({0})' -f $StartDword) }
    }
}

<#
.SYNOPSIS
    Finds the scheduled task(s) that can re-enable UCPD.

.DESCRIPTION
    Looks up the known task paths first, then any task whose action runs UCPDMgr.exe.
    Requires an elevated session: the UCPD tasks are hidden from standard users.

.OUTPUTS
    PSCustomObject with:
      QueryStatus - [string] OK | NotAdmin | Unavailable | Error
      Message     - [string] Detail when QueryStatus is not OK.
      Tasks       - [object[]] One entry per task: FullPath, TaskPath, TaskName, State.
#>
function Get-UcpdScheduledTask {
    [CmdletBinding()]
    param()

    $result = [PSCustomObject]@{
        QueryStatus = 'Error'
        Message     = ''
        Tasks       = @()
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        $result.QueryStatus = 'NotAdmin'
        $result.Message     = 'UCPD scheduled tasks are only visible to an elevated session.'
        return $result
    }

    if (-not (Get-Command -Name 'Get-ScheduledTask' -ErrorAction SilentlyContinue)) {
        $result.QueryStatus = 'Unavailable'
        $result.Message     = 'The ScheduledTasks module is not available on this system.'
        return $result
    }

    $found = [ordered]@{}

    foreach ($knownPath in $script:ucpdKnownTaskPaths) {
        $splitIndex = $knownPath.LastIndexOf('\')
        $taskPath   = $knownPath.Substring(0, $splitIndex + 1)
        $taskName   = $knownPath.Substring($splitIndex + 1)
        try {
            $task = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop
            $found[$knownPath] = $task
        }
        catch {
            Write-Detail ('UCPD: Known task not found: {0}' -f $knownPath)
        }
    }

    try {
        $allTasks = Get-ScheduledTask -ErrorAction Stop
        foreach ($task in $allTasks) {
            $fullPath = '{0}{1}' -f $task.TaskPath, $task.TaskName
            if ($found.Contains($fullPath)) { continue }
            $runsUcpdMgr = $task.Actions | Where-Object {
                $_.Execute -and ([System.IO.Path]::GetFileName($_.Execute.Trim('"')) -eq $script:ucpdTaskExecutable)
            }
            if ($runsUcpdMgr) {
                Write-Detail ('UCPD: Discovered task running {0}: {1}' -f $script:ucpdTaskExecutable, $fullPath)
                $found[$fullPath] = $task
            }
        }
    }
    catch {
        $result.QueryStatus = 'Error'
        $result.Message     = ('Could not enumerate scheduled tasks: {0}' -f $_.Exception.Message)
        return $result
    }

    $result.Tasks = @(foreach ($key in $found.Keys) {
        [PSCustomObject]@{
            FullPath = $key
            TaskPath = $found[$key].TaskPath
            TaskName = $found[$key].TaskName
            State    = $found[$key].State.ToString()
        }
    })
    $result.QueryStatus = 'OK'
    return $result
}

<#
.SYNOPSIS
    Disables or re-enables the UCPD scheduled task(s).

.PARAMETER State
    Disabled - disables every enabled UCPD task.
    Default  - re-enables every disabled UCPD task.

.OUTPUTS
    PSCustomObject with:
      Success  - [bool]     $false when the tasks could not be queried or a change failed.
      Changed  - [string[]] Full paths of tasks whose state was changed.
      Failed   - [string[]] Failure messages, one per task.
      Message  - [string]   Human-readable summary.
#>
function Set-UcpdScheduledTaskState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Disabled', 'Default')]
        [string]$State
    )

    $result = [PSCustomObject]@{
        Success = $false
        Changed = @()
        Failed  = @()
        Message = ''
    }

    $query = Get-UcpdScheduledTask
    if ($query.QueryStatus -ne 'OK') {
        $result.Message = ('UCPD scheduled tasks not processed: {0}' -f $query.Message)
        return $result
    }

    if ($query.Tasks.Count -eq 0) {
        $result.Success = $true
        $result.Message = 'No UCPD scheduled task found. Nothing to do.'
        return $result
    }

    $changed = [System.Collections.Generic.List[string]]::new()
    $failed  = [System.Collections.Generic.List[string]]::new()

    foreach ($task in $query.Tasks) {
        $isDisabled = $task.State -eq $script:ucpdTaskDisabledState
        if (($State -eq 'Disabled' -and $isDisabled) -or ($State -eq 'Default' -and -not $isDisabled)) {
            Write-Detail ('UCPD: Task already at target ({0}): {1}' -f $task.State, $task.FullPath)
            continue
        }
        try {
            if ($State -eq 'Disabled') {
                Disable-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -ErrorAction Stop | Out-Null
            }
            else {
                Enable-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -ErrorAction Stop | Out-Null
            }
            Write-Detail ('UCPD: Task {0}: {1}' -f $State.ToLower(), $task.FullPath)
            $changed.Add($task.FullPath)
        }
        catch {
            $failed.Add(('{0}: {1}' -f $task.FullPath, $_.Exception.Message))
        }
    }

    $result.Changed = $changed.ToArray()
    $result.Failed  = $failed.ToArray()
    $result.Success = ($failed.Count -eq 0)
    $verb = if ($State -eq 'Disabled') { 'disabled' } else { 'enabled' }
    if (-not $result.Success) {
        $result.Message = ('Failed to change UCPD scheduled task(s): {0}' -f ($failed -join ' | '))
    }
    elseif ($changed.Count -gt 0) {
        $result.Message = ('UCPD scheduled task(s) {0}: {1}' -f $verb, ($changed -join ', '))
    }
    else {
        $result.Message = ('UCPD scheduled task(s) already {0}. No change needed.' -f $verb)
    }
    return $result
}

# ============================================================
# PUBLIC FUNCTIONS
# ============================================================

<#
.SYNOPSIS
    Returns the current UCPD driver and service status as a structured object.

.OUTPUTS
    PSCustomObject with:
      IsActive         - [bool]   $true when driver is present, service registered, and running.
      ServiceRegistered- [bool]   $true when the UCPD registry key exists.
      DriverPresent    - [bool]   $true when UCPD.sys exists on disk.
      StartTypeDword   - [int]    Raw Start DWORD from registry, or $null if unreadable.
      StartTypeLabel   - [string] Human-readable start type.
      RunningStatus    - [string] Current SCM status string (e.g. 'Running', 'Stopped').
      IsAdmin          - [bool]   $true when the current session is elevated.
      TaskQueryStatus  - [string] OK | NotAdmin | Unavailable | Error (scheduled task lookup).
      TaskQueryMessage - [string] Detail when TaskQueryStatus is not OK.
      Tasks            - [object[]] UCPD scheduled tasks: FullPath, TaskPath, TaskName, State.
#>
function Get-UcpdStatus {
    [CmdletBinding()]
    param()

    $result = [PSCustomObject]@{
        IsActive          = $false
        ServiceRegistered = $false
        DriverPresent     = $false
        StartTypeDword    = $null
        StartTypeLabel    = 'N/A'
        RunningStatus     = 'N/A'
        IsAdmin           = $false
        TaskQueryStatus   = 'Error'
        TaskQueryMessage  = ''
        Tasks             = @()
    }

    $result.IsAdmin          = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $result.DriverPresent    = Test-Path $script:ucpdDriverPath
    $result.ServiceRegistered = Test-Path $script:ucpdRegistryPath

    if ($result.ServiceRegistered) {
        try {
            $startDword              = (Get-ItemProperty -Path $script:ucpdRegistryPath -Name 'Start' -ErrorAction Stop).Start
            $result.StartTypeDword   = $startDword
            $result.StartTypeLabel   = Get-UcpdStartTypeLabel -StartDword $startDword
        }
        catch {
            Write-Detail ('UCPD: Could not read Start registry value: {0}' -f $_.Exception.Message)
        }

        try {
            $svc                  = Get-Service -Name $script:ucpdServiceName -ErrorAction Stop
            $result.RunningStatus = $svc.Status.ToString()
        }
        catch {
            Write-Detail ('UCPD: Get-Service could not query UCPD: {0}' -f $_.Exception.Message)
            $result.RunningStatus = 'Not found by SCM'
        }
    }

    $taskQuery               = Get-UcpdScheduledTask
    $result.TaskQueryStatus  = $taskQuery.QueryStatus
    $result.TaskQueryMessage = $taskQuery.Message
    $result.Tasks            = $taskQuery.Tasks

    # IsActive: driver file present AND service not disabled AND currently running
    $result.IsActive = (
        $result.DriverPresent -and
        $result.ServiceRegistered -and
        $result.RunningStatus -eq 'Running'
    )

    return $result
}

<#
.SYNOPSIS
    Configures the UCPD service start type and scheduled task(s), and optionally stops the running driver.

.DESCRIPTION
    The UCPD scheduled task(s) are processed first, even when the service is already at the
    target start type, because an enabled task can re-enable the service later.

.PARAMETER State
    Target UCPD state: Disabled (service and tasks disabled) or Default (Windows defaults restored).

.OUTPUTS
    PSCustomObject with:
      Success         - [bool]   $true when the service configuration change was applied.
      Reason          - [string] NotAdmin | NotRegistered | AlreadyAtTarget | ConfigFailed |
                                 RequiresReboot | Stopped | Error
      RequiresReboot  - [bool]   $true when a reboot is needed for the change to fully take effect.
      Message         - [string] Human-readable summary for logging or display.
      TaskSuccess     - [bool]   $true when the scheduled task(s) are at the target state.
      TaskMessage     - [string] Human-readable summary of the scheduled task step.
#>
function Set-UcpdState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Disabled', 'Default')]
        [string]$State
    )

    $result = [PSCustomObject]@{
        Success        = $false
        Reason         = 'Error'
        RequiresReboot = $false
        Message        = ''
        TaskSuccess    = $false
        TaskMessage    = ''
    }

    # Elevation check
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        $result.Reason  = 'NotAdmin'
        $result.Message = 'Administrator rights are required to change the UCPD state.'
        return $result
    }

    # Scheduled task(s) - handled before the service so an early return cannot skip them
    $taskResult         = Set-UcpdScheduledTaskState -State $State
    $result.TaskSuccess = $taskResult.Success
    $result.TaskMessage = $taskResult.Message

    # Service must be registered
    if (-not (Test-Path $script:ucpdRegistryPath)) {
        $result.Success = $true
        $result.Reason  = 'NotRegistered'
        $result.Message = 'UCPD service is not registered on this machine. Nothing to do.'
        return $result
    }

    # Read current state
    $currentStartDword = $null
    try {
        $currentStartDword = (Get-ItemProperty -Path $script:ucpdRegistryPath -Name 'Start' -ErrorAction Stop).Start
    }
    catch {
        Write-Detail ('UCPD: Could not read Start registry value: {0}' -f $_.Exception.Message)
    }

    $currentRunningStatus = 'N/A'
    try {
        $svc                  = Get-Service -Name $script:ucpdServiceName -ErrorAction Stop
        $currentRunningStatus = $svc.Status.ToString()
    }
    catch {
        $currentRunningStatus = 'Not found by SCM'
    }

    $targetScToken    = if ($State -eq 'Disabled') { 'disabled' } else { $script:ucpdDefaultScToken }
    $targetStartDword = if ($State -eq 'Disabled') { 4 } else { $script:ucpdDefaultStartDword }

    # Already at target
    if ($currentStartDword -eq $targetStartDword) {
        $result.Success = $true
        $result.Reason  = 'AlreadyAtTarget'
        if ($State -eq 'Disabled' -and $currentRunningStatus -eq 'Running') {
            $result.RequiresReboot = $true
            $result.Message = 'UCPD is already configured as Disabled but the driver is still running. A reboot is required.'
        }
        else {
            $result.Message = ('UCPD is already configured as {0}. No change needed.' -f $State)
        }
        return $result
    }

    # Apply sc.exe change
    Write-Detail ('UCPD: Applying state {0} via sc.exe...' -f $State)
    try {
        $scOutput = & sc.exe config $script:ucpdServiceName start= $targetScToken 2>&1
        if ($LASTEXITCODE -ne 0) {
            $result.Reason  = 'ConfigFailed'
            $result.Message = ('sc.exe config failed (exit {0}): {1}' -f $LASTEXITCODE, ($scOutput -join ' '))
            return $result
        }
        Write-Detail ('UCPD: sc.exe output: {0}' -f ($scOutput -join ' '))
    }
    catch {
        $result.Reason  = 'Error'
        $result.Message = ('Failed to configure UCPD service: {0}' -f $_.Exception.Message)
        return $result
    }

    $result.Success = $true

    # Attempt immediate stop when disabling
    if ($State -eq 'Disabled' -and $currentRunningStatus -eq 'Running') {
        Write-Detail 'UCPD: Attempting to stop the running driver...'
        try {
            Stop-Service -Name $script:ucpdServiceName -Force -ErrorAction Stop
            $result.Reason         = 'Stopped'
            $result.RequiresReboot = $false
            $result.Message        = 'UCPD configured as Disabled and driver stopped successfully.'
        }
        catch {
            $result.Reason         = 'RequiresReboot'
            $result.RequiresReboot = $true
            $result.Message        = ('UCPD configured as Disabled. Driver stop failed (kernel drivers require a reboot): {0}' -f $_.Exception.Message)
        }
    }
    else {
        $result.Reason         = 'RequiresReboot'
        $result.RequiresReboot = $true
        $result.Message        = ('UCPD state set to {0}. A reboot is required for this change to take full effect.' -f $State)
    }

    return $result
}

Export-ModuleMember -Function Get-UcpdStatus, Set-UcpdState