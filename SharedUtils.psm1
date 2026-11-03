# AUTO-SYNCED from github.com/Chemin-Neuf/dev-standards DO NOT EDIT HERE - edit in dev-standards and re-sync
<#
  Copyright (C) Chemin-Neuf IT Team
  SPDX-License-Identifier: GPL-3.0-only
  Full license text: see LICENSE at the repository root
#>
# Original Author: Claude 3.5 Sonnet (Anthropic / GitHub Copilot)
# Major Contributors: GPT-5.4 (GitHub Copilot), Gemini 3.5 Flash (Google / GitHub Copilot), Claude Sonnet 4.6 (Anthropic / GitHub Copilot), Gemini 3.8 Flash (Google / GitHub Copilot)

<#
.SYNOPSIS
    Appends a timestamped entry to the current log file.

.PARAMETER Message
    Plain-text message to write to the log.

.PARAMETER Level
    Log level for the entry.
#>
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DETAIL')]
        [string]$Level = 'INFO'
    )
    if (-not $Global:LogVerbosity) { $Global:LogVerbosity = 'Detailed' }
    if ($Global:LogVerbosity -eq 'None') { return }
    if ($Global:LogVerbosity -eq 'Normal' -and $Level -eq 'DETAIL') { return }
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $logEntry = "{0} | {1} | {2}" -f $timestamp, $Level, $Message
    if ($logEntry.Length -gt 200) {
        $logEntry = "{0}..." -f $logEntry.Substring(0, 197)
    }
    if ($Global:LogFile) {
        $logEntry | Out-File -FilePath $Global:LogFile -Append -Encoding utf8
    }
}

<#
.SYNOPSIS
    Writes a console status line without logging it.

.PARAMETER Message
    Message to display.

.PARAMETER Symbol
    Prefix symbol displayed before the message.

.PARAMETER Color
    Console color used for the message.
#>
function Write-Status {
    param(
        [string]$Message,
        [string]$Symbol = '*',
        [string]$Color = 'Cyan'
    )
    Write-Host "$Symbol $Message" -ForegroundColor $Color
}

<#
.SYNOPSIS
    Writes an informational console message and logs it.

.PARAMETER Message
    Message to display and log.
#>
function Write-Info {
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Message)
    if (-not $Global:ConsoleVerbosity) { $Global:ConsoleVerbosity = 'Detailed' }
    if ($Global:ConsoleVerbosity -ne 'None') { Write-Host $Message -ForegroundColor Cyan }
    Write-Log $Message 'INFO'
}

<#
.SYNOPSIS
    Writes a warning console message and logs it.

.PARAMETER Message
    Message to display and log.
#>
function Write-Warn {
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Message)
    if (-not $Global:ConsoleVerbosity) { $Global:ConsoleVerbosity = 'Detailed' }
    if ($Global:ConsoleVerbosity -ne 'None') { Write-Host $Message -ForegroundColor Yellow }
    Write-Log $Message 'WARN'
}

<#
.SYNOPSIS
    Writes an error console message and logs it.

.PARAMETER Message
    Message to display and log.
#>
function Write-ErrorLog {
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Message)
    if (-not $Global:ConsoleVerbosity) { $Global:ConsoleVerbosity = 'Detailed' }
    if ($Global:ConsoleVerbosity -ne 'None') { Write-Host $Message -ForegroundColor Red }
    Write-Log $Message 'ERROR'
}

<#
.SYNOPSIS
    Writes a fatal error message unconditionally and logs it.

.DESCRIPTION
    Unlike Write-ErrorLog, this function always writes to the console regardless of the current
    ConsoleVerbosity setting (including None and Quiet), because the caller must be informed
    of the reason the script is halting. Output is routed through the error stream so that
    calling scripts can capture informational and error output separately.
    Use only for conditions that prevent the script from continuing.

.PARAMETER Message
    The fatal error message to display and log.
#>
function Write-FatalError {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Message)

    # Always write to the error stream - bypasses ConsoleVerbosity even when set to 'None' or Quiet.
    $Host.UI.WriteErrorLine($Message)
    Write-Log $Message 'ERROR'
}

<#
.SYNOPSIS
    Writes a success console message and logs it.

.PARAMETER Message
    Message to display and log.
#>
function Write-Success {
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Message)
    if (-not $Global:ConsoleVerbosity) { $Global:ConsoleVerbosity = 'Detailed' }
    if ($Global:ConsoleVerbosity -ne 'None') { Write-Host $Message -ForegroundColor Green }
    Write-Log $Message 'SUCCESS'
}

<#
.SYNOPSIS
    Writes a detailed console message and detailed log entry.

.PARAMETER Message
    Detail message to display and log.
#>
function Write-Detail {
    param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Message)
    if (-not $Global:ConsoleVerbosity) { $Global:ConsoleVerbosity = 'Detailed' }
    if (-not $Global:LogVerbosity) { $Global:LogVerbosity = 'Detailed' }
    
    # Only output detail when verbosity is Detailed
    if ($Global:ConsoleVerbosity -eq 'Detailed') {
        Write-Host ("    [detail] $Message") -ForegroundColor DarkGray
    }
    
    if ($Global:LogVerbosity -eq 'Detailed') {
        Write-Log -Message $Message -Level 'DETAIL'
    }
}

<#
.SYNOPSIS
    Initializes the per-run log file used by calling scripts.

.PARAMETER ScriptName
    Name used in the generated log file name.

.PARAMETER Version
    Version written to the log header when provided.
#>
function Initialize-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ScriptName,
        [Parameter(Mandatory=$false)]
        [string]$Version
    )
    if (-not $Global:LogVerbosity) { $Global:LogVerbosity = 'Detailed' }
    if ($Global:LogVerbosity -eq 'None') { return }
    $ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $defaultLogsDir = Join-Path -Path $PSScriptRoot -ChildPath 'logs'
    $logsDir = $defaultLogsDir

    try {
        if (-not (Test-Path -Path $logsDir -PathType Container)) {
            New-Item -ItemType Directory -Path $logsDir -Force -ErrorAction Stop | Out-Null
        }

        $probeFile = Join-Path -Path $logsDir -ChildPath ('.write-test-{0}.tmp' -f $ts)
        Set-Content -Path $probeFile -Value 'write-test' -Encoding utf8 -ErrorAction Stop
        Remove-Item -Path $probeFile -Force -ErrorAction SilentlyContinue
    } catch {
        $logsDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
        Write-Warn ("Logs directory '{0}' is not writable. Falling back to '{1}'." -f $defaultLogsDir, $logsDir)
    }

    try {
        $Global:LogFile = Join-Path -Path $logsDir -ChildPath "${ScriptName}_$ts.log"
        "Log initialized: $Global:LogFile" | Out-File -FilePath $Global:LogFile -Encoding utf8 -ErrorAction Stop
        if ($Version) {
            $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            "$timestamp | INFO | Script: $ScriptName | Version: $Version" | Out-File -FilePath $Global:LogFile -Append -Encoding utf8 -ErrorAction Stop
        }
    } catch {
        $Global:LogFile = $null
        Write-ErrorLog ("Could not initialize log file: {0}" -f $_.Exception.Message)
    }
}

<#
.SYNOPSIS
    Returns the symbol and color for a readiness status.

.PARAMETER Status
    Readiness status to map.

.OUTPUTS
    Hashtable with Symbol and Color keys.
#>
function Get-StatusSymbol {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Status
    )
    
    switch ($Status) {
        'OK'      { return @{ Symbol = '[V]'; Color = 'Green' } }
        'WARNING' { return @{ Symbol = '[!]'; Color = 'Yellow' } }
        'ERROR'   { return @{ Symbol = '[X]'; Color = 'Red' } }
        'UNKNOWN' { return @{ Symbol = '[?]'; Color = 'Gray' } }
        default   { return @{ Symbol = '[-]'; Color = 'Gray' } }
    }
}

<#
.SYNOPSIS
    Returns whether the current PowerShell session is elevated.

.OUTPUTS
    System.Boolean
#>
function Test-AdminPrivilege {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

<#
.SYNOPSIS
    Displays script or module version information from the manifest.

.PARAMETER ScriptName
    Name of the manifest entry to read.

.PARAMETER ScriptDir
    Directory that contains scripts-manifest.json.
#>
function Get-ScriptVersion {
    param(
        [Parameter(Mandatory=$true)][string]$ScriptName,
        [Parameter(Mandatory=$true)][string]$ScriptDir
    )
    
    $manifestPath = Join-Path -Path $ScriptDir -ChildPath 'scripts-manifest.json'
    
    if (-not (Test-Path -Path $manifestPath)) {
        Write-ErrorLog 'Error: scripts-manifest.json not found'
        return
    }
    
    try {
        $manifest = Get-Content -Path $manifestPath -Raw -ErrorAction Stop | ConvertFrom-Json
        $scriptInfo = $manifest.scripts.$ScriptName
        
        if ($scriptInfo) {
            $version = if ($scriptInfo.version) { $scriptInfo.version } elseif ($scriptInfo.moduleVersion) { $scriptInfo.moduleVersion } else { 'Unknown' }
            $description = if ($scriptInfo.description) { $scriptInfo.description } else { 'No description available' }
            $minPS = if ($scriptInfo.minPowerShell) { $scriptInfo.minPowerShell } else { 'Unknown' }
            
            Write-Host "$ScriptName version $version" -ForegroundColor Cyan
            Write-Host "Repository version: $($manifest.repoVersion)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Description: $description" -ForegroundColor White
            Write-Host "Minimum PowerShell: $minPS" -ForegroundColor Gray
        } else {
            Write-ErrorLog ("Error: Script '{0}' not found in manifest" -f $ScriptName)
        }
    } catch {
        Write-ErrorLog ("Error reading manifest: {0}" -f $_.Exception.Message)
    }
}

<#
.SYNOPSIS
    Sets the active console output encoding to UTF-8.
#>
function Initialize-ConsoleEncoding {
    try {
        # Set console code page to UTF-8 (65001)
        chcp 65001 > $null
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $Global:OutputEncoding = [System.Text.Encoding]::UTF8
    } catch {
        Write-Warn ("Could not set console encoding to UTF-8: {0}" -f $_.Exception.Message)
    }
}

# ============================================================
# General-purpose utilities
# ============================================================

<#
.SYNOPSIS
    Merges a sequence of values into a single semi-colon-delimited string, deduplicating entries.
.PARAMETER Values
    Any enumerable collection of values. Blank or whitespace-only entries are discarded.
.OUTPUTS
    System.String - values joined with "; ", or an empty string if all inputs are blank.
#>
function Join-UniqueStrings {
    param([System.Collections.IEnumerable]$Values)

    $list = New-Object System.Collections.Generic.List[string]
    foreach ($value in $Values) {
        $text = [string]$value
        if (-not [string]::IsNullOrWhiteSpace($text) -and -not $list.Contains($text)) {
            $list.Add($text)
        }
    }
    return ($list -join '; ')
}

<#
.SYNOPSIS
    Returns the first non-blank string value from an array.
.PARAMETER Values
    Array of candidate values.
.OUTPUTS
    System.String - first non-blank entry, or an empty string if all are blank.
#>
function Get-FirstValue {
    param([object[]]$Values)

    foreach ($value in $Values) {
        $text = [string]$value
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            return $text
        }
    }

    return ''
}

<#
.SYNOPSIS
    Exports objects to a CSV file with an existence check and optional overwrite guard.
.DESCRIPTION
    Checks whether the destination file already exists before writing. Without -Force the
    function writes an error and returns without creating the file. With -Force it overwrites
    after emitting a warning. Implements the Safe File Output principle from global.instructions.md.
.PARAMETER InputObject
    Objects to export. Passed directly to Export-Csv.
.PARAMETER LiteralPath
    Destination file path (passed as -LiteralPath to Export-Csv).
.PARAMETER Force
    When set, overwrites an existing file after emitting a warning. Without this switch the
    function refuses to overwrite.
.PARAMETER Quiet
    Suppresses the warning when overwriting (requires -Force).
.OUTPUTS
    None. Writes to file and logs via Write-Info / Write-Warn / Write-ErrorLog.
#>
function Export-CsvSafely {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$LiteralPath,

        [switch]$Force,
        [switch]$Quiet
    )

    begin { $collected = [System.Collections.Generic.List[object]]::new() }
    process { foreach ($obj in $InputObject) { $collected.Add($obj) } }
    end {
        if (Test-Path -LiteralPath $LiteralPath) {
            if (-not $Force) {
                Write-ErrorLog ("Output file already exists: {0} - use -Force to overwrite." -f $LiteralPath)
                return
            }
            if (-not $Quiet) {
                Write-Warn ("Overwriting existing file: {0}" -f $LiteralPath)
            }
        }

        $collected | Export-Csv -LiteralPath $LiteralPath -NoTypeInformation -Encoding UTF8
        Write-Info ("Wrote {0} rows to {1}" -f $collected.Count, $LiteralPath)
    }
}

function Backup-File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    $dir       = [System.IO.Path]::GetDirectoryName($Path)
    $leaf      = Split-Path -Path $Path -Leaf
    $baseName  = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $extension = [System.IO.Path]::GetExtension($Path)
    if ($baseName -eq '') {
        $baseName  = $leaf
        $extension = ''
    }
    $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmssfff')
    $backupFileName = "${baseName}_${timestamp}${extension}.bak"
    $backupPath = if ($dir) { Join-Path $dir $backupFileName } else { $backupFileName }
    Copy-Item -LiteralPath $Path -Destination $backupPath
    Write-Detail "Backed up existing file: $backupPath"
}

# Export all functions
Export-ModuleMember -Function Write-Log, Write-Status, Write-Info, Write-Warn, Write-ErrorLog, Write-FatalError, Write-Success, Write-Detail, Initialize-Log, Get-StatusSymbol, Test-AdminPrivilege, Get-ScriptVersion, Initialize-ConsoleEncoding, Join-UniqueStrings, Get-FirstValue, Export-CsvSafely, Backup-File
