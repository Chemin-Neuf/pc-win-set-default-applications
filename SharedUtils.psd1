# AUTO-SYNCED from github.com/Chemin-Neuf/dev-standards DO NOT EDIT HERE — edit in dev-standards and re-sync
# Copyright (C) Chemin-Neuf IT Team
# SPDX-License-Identifier: GPL-3.0-only
# Full license text: see LICENSE at the repository root
# Original Author: GPT-5.4 (GitHub Copilot)
# Major Contributors: Gemini 3.8 Flash (Google / GitHub Copilot)

@{
    RootModule        = 'SharedUtils.psm1'
    ModuleVersion     = '1.3.3'
    GUID              = 'eecf4c73-8eae-4295-93b1-12a329f341aa'
    Author            = 'Chemin-Neuf IT Team'
    CompanyName       = 'Chemin-Neuf'
    Copyright         = '(C) Chemin-Neuf IT Team'
    Description       = 'Shared PowerShell utility functions for logging, status output, console encoding, and elevation checks.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Write-Log',
        'Write-Status',
        'Write-Info',
        'Write-Warn',
        'Write-ErrorLog',
        'Write-FatalError',
        'Write-Success',
        'Write-Detail',
        'Initialize-Log',
        'Get-StatusSymbol',
        'Test-AdminPrivilege',
        'Get-ScriptVersion',
        'Initialize-ConsoleEncoding',
        'Join-UniqueStrings',
        'Get-FirstValue',
        'Export-CsvSafely',
        'Backup-File'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}