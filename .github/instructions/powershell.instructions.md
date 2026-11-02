---
applyTo: "**/*.ps1,**/*.psm1"
---
<!-- AUTO-SYNCED from github.com/Chemin-Neuf/dev-standards DO NOT EDIT HERE — edit in dev-standards and re-sync -->
<!--
  Chemin-Neuf dev-standards — PowerShell rules
  Last Updated: 2026-05-23

  Original Author: Claude Sonnet 4.6 (Anthropic / GitHub Copilot)
  This file is AI-generated operational instructions for use by AI coding assistants.
  It extends global.instructions.md with language-specific rules.
  The authoritative source of principles is PRINCIPLES.md (human-authored, never AI-edited).
-->

# PowerShell Rules

<!-- HUMAN NAVIGATION AID ONLY — non-normative. AI agents: do not use this block for rule content; use the titled sections below as the sole authoritative source. -->
<details>
<summary>Quick reference (non-normative — expand for human overview)</summary>

| Topic | In brief |
|---|---|
| File Naming | Modules: PascalCase; Scripts: kebab-case |
| Function Naming | Approved Verb-Noun pattern |
| Variable & Parameter Naming | Local: camelCase; Global: `$Global:` prefix; Parameters: PascalCase |
| Code Style | `[CmdletBinding()]`; config block near top; full cmdlet names; no aliases; LF line endings |
| Comment Style | `<#…#>` for block comments; `#` for inline; keep concise |
| License Notice | 3-line SPDX block at top of file; also in `.NOTES` for scripts |
| Comment-Based Help | `.ps1` only: SYNOPSIS, DESCRIPTION, PARAMETER, EXAMPLE, NOTES, LINK; blank line before `<#`; no dot-starting lines; one URL per `.LINK` |
| Standard Parameters | Verbosity, LogVerbosity, Quiet, Version — required on all scripts |
| Shared Utilities | Use `ps-shared-utils`; check before writing new utilities; import via `$PSScriptRoot` |
| Logging | `YYYY-MM-DD HH:mm:ss \| LEVEL \| message`; one file per run; `logs\` subfolder |
| Console Output | Colour + ASCII status symbols; UTF-8 encoding set at startup |
| Error Handling | try-catch with `-ErrorAction Stop`; graceful degradation; halt only on critical failures |
| Safe File Output | `Test-Path` before writing; `-Force` switch to allow overwrite; never silent overwrite |
| Compatibility | Target PS 5.1+; declare `#Requires` if a higher version is needed |
| Versioning | `$scriptVersion` is the single source of truth; `.NOTES Version:` references it, never duplicates it; MAJOR.MINOR.PATCH |
| Security | `Get-Credential`; never log credentials; manual elevation check; no `Invoke-Expression` |
| Testing | Manual checklist: PS 5.1, PS 7, restricted policy, with/without admin; Pester TBD |

</details>

## File Naming

**STATUS: DECIDED**

- Modules (`.psm1`): PascalCase — e.g. `SharedUtils.psm1`
- Scripts (`.ps1`): kebab-case — e.g. `check-windows-info.ps1`

## Function Naming

**STATUS: DECIDED**

Use PowerShell approved verb-noun patterns:
- `Get-*`, `Set-*`, `Write-*`, `Initialize-*`, `Show-*`, `Test-*`
- Full verb list: https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands

## Variable and Parameter Naming

**STATUS: DECIDED**

- Local variables: camelCase — e.g. `$logFile`
- Global variables: `$Global:` prefix — e.g. `$Global:LogFile`
- Parameters: PascalCase with `[Parameter()]` attributes when needed

## Code Style

**STATUS: DECIDED**

- Use `[CmdletBinding()]` at the top of every script
- Place all user-tunable configuration variables in a clearly marked block near the top of the script, before the main logic
- Never use literal values (file paths, names, thresholds, flags) directly in the script logic — declare them as named variables in the configuration section
- Use full cmdlet names — no aliases (`Get-ChildItem` not `ls` or `dir`)
- Use `-ErrorAction SilentlyContinue` for non-critical operations
- Use backtick (`` ` ``) for line continuation only inside functions
- Use `@{}` for hashtables; use `[ordered]@{}` to preserve insertion order
- String formatting: use the `-f` operator for cross-version compatibility
- Save all PowerShell files with LF (`\n`) line endings — Windows editors and Git for Windows may default to CRLF; configure your editor and `.gitattributes` accordingly

## Comment Style

**STATUS: DECIDED**

- `<#...#>` for block comments at function heads
- `#` for inline comments
- Keep comments concise and actionable
- Document parameters and return values in block comments

## License Notice

**STATUS: DECIDED**

Global rules apply (see `global.instructions.md`). PowerShell-specific wording and placement:

### Approved wording

Use this exact 4-line block — no more, no less (do not forget the emppty line at the end!):

```powershell
# Copyright (C) Chemin-Neuf IT Team
# SPDX-License-Identifier: GPL-3.0-only
# Full license text: see LICENSE at the repository root

```

### Placement — `.ps1` scripts

Place the 3-line block as the very first lines of the file, immediately above the comment-based help block (`.SYNOPSIS`, etc.).
Also keep `license: GPL-3.0-only` in the `.NOTES` section of comment-based help — it serves discoverability via `Get-Help` and is not duplication.

### Placement — `.psm1` modules

Place the same 3 lines inside a `<# ... #>` block at the very top of the file:

```powershell
<#
  Copyright (C) Chemin-Neuf IT Team
  SPDX-License-Identifier: GPL-3.0-only
  Full license text: see LICENSE at the repository root
#>
```

## Comment-Based Help (Script Headers)

**STATUS: DECIDED**

Applies to `.ps1` scripts only. For `.psm1` modules, use per-function `<# … #>` block comments instead — no file-level help block.

### File structure order (`.ps1`)

1. License notice (3-line block — see License Notice section)
2. `#Requires` statement(s) — if needed
3. Comment-based help block
4. `[CmdletBinding()]` and `param()`

### Required sections

- `.SYNOPSIS` — one sentence describing the script's purpose
- `.DESCRIPTION` — 2–5 sentences: what the script does, its capabilities, logging behavior
- `.PARAMETER` — one block per parameter; include valid values, defaults, use cases
- `.EXAMPLE` — 2–3 realistic examples showing different usage patterns
- `.NOTES` — use the key:value format below
- `.LINK` — GitHub repo URL first, then 1–2 relevant Microsoft docs URLs

### `.NOTES` key:value format

```
File:           script-name.ps1
Version:        see $scriptVersion in the Configuration section below
Author:         Name  (or "Model name (GitHub Copilot)" for AI-generated files)
License:        GPL-3.0-only
Prerequisites:  PowerShell 5.1+; administrator rights  (use "None" if not applicable)
```

> **Note:** `Version:` must not contain a literal number — use the exact phrase `see $scriptVersion in the Configuration section below`. `$scriptVersion` (declared in the configuration block) is the single source of truth; there is no second copy to keep in sync.

Do NOT implement a custom `-Help` switch. Use `Get-Help .\script.ps1` instead.

### Known Get-Help pitfalls

1. **Empty line required before `<#`** — there must be a blank line between the license notice block and the `<#` that opens the comment-based help block. Omitting it silently breaks `Get-Help` on all PowerShell versions.
2. **No line may start with a dot** — inside a comment-based help block, any line whose first non-space character is a dot followed by letters is parsed as a keyword. Avoid line-wrapping sentences so that tokens like `.bak` or `.git` start a new line.
3. **One URL per `.LINK` keyword** — PowerShell renders the entire `RELATED LINKS` block once for each `.LINK` entry found. Placing multiple URLs under a single `.LINK` therefore causes the full list to be repeated. Each URL must have its own `.LINK` keyword.
4. **UNC paths / mapped drives (PS 5.1 only)** — `Get-Help` does not work for scripts on UNC paths (`\\server\share\script.ps1`) or mapped network drives under PowerShell 5.1. This is caused by the Windows Security Zone restriction, which prevents the .NET Framework from reading comment-based help on network-backed locations. PowerShell 7 is not affected. **Workaround:** copy the script to a local drive before calling `Get-Help` when running PS 5.1.

## Standard Parameters

**STATUS: DECIDED**

All scripts must support these parameters:
- `Verbosity` — console verbosity: `None`, `Normal`, `Detailed` (default: `Normal`)
- `LogVerbosity` — log verbosity: `None`, `Normal`, `Detailed` (default: `Detailed`)
- `Quiet` — switch; suppresses console output; takes priority over `Verbosity`
- `Version` — displays `script-name.ps1  v$scriptVersion` and exits (reads `$scriptVersion` directly — no hardcoded string)

### Verbosity level behavior

**Console (`Verbosity`):**
- `None` — no console output; intended for scripts called from other scripts
- `Normal` — key results and status shown to the operator running the script; the default
- `Detailed` — step-by-step progress in addition to `Normal` output, so the administrator can follow exactly what the script is doing at each point

**Log (`LogVerbosity`):**
- `None` — no log file created
- `Normal` — script start and end entries; all warnings and errors; a summary of the information shown to the user
- `Detailed` — everything in `Normal` plus step-by-step progress entries; content and cadence may mirror the `Detailed` console output

Notes:
- `Detailed` is used (not `Debug`) to avoid conflict with the built-in `-Debug` common parameter from `[CmdletBinding()]`
- Helper scripts with no user-facing output may override the default to `None` in their own `param()` block

## Shared Utilities

**STATUS: DECIDED**

Shared utility functions live in the dedicated repository
`github.com/Chemin-Neuf/ps-shared-utils`. Each project receives a copy of
`SharedUtils.psm1` via manual sync (a sync script is planned; see `scripts/`).

- Before creating any new utility function, check the `ps-shared-utils` README
  for the current list of exported functions
- Do not duplicate utility logic inside a project — fix or extend `ps-shared-utils`
  and re-sync
- **Dedicated PowerShell repositories** (primary artifact = PS scripts): the module file is placed at the repository root alongside the scripts that use it
- **Non-PowerShell repositories** with helper PS scripts: the module file goes in the `scripts/` subfolder alongside those scripts (see global script placement rule)
- The import pattern is the same in both cases — `$PSScriptRoot` resolves to wherever the calling script lives:

```powershell
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'SharedUtils.psm1') -Force
```

## Logging

**STATUS: DECIDED**

- Log format: `YYYY-MM-DD HH:mm:ss | LEVEL | message`
- Levels: `INFO`, `WARN`, `ERROR`, `SUCCESS`, `DETAIL`
- One log file per script execution
- Log filename: `<script-name>_YYYYMMDD_HHmmss.log` — e.g. `check-windows-info_20260503_143022.log`
- Log location: `logs\` subfolder relative to the script; fall back to `$env:TEMP` if that path is not writable
- Log lines: keep under 200 characters
- Log messages: plain strings only — no objects or formatting markers
- Verbosity behavior: see the Verbosity level behavior table in the Standard Parameters section
- Log cleanup: no automated retention — manual task for the administrator

## Console Output

**STATUS: DECIDED**

- Colors: `Cyan`=info, `Yellow`=warn, `Red`=error, `Green`=success, `DarkGray`=detail, `Gray`=unknown
- Status symbols (ASCII): `[V]`=OK (green), `[!]`=WARNING (yellow), `[X]`=ERROR (red), `[?]`=UNKNOWN (gray)
- Set console output encoding to UTF-8 at startup to support non-ASCII content (e.g. French output)

## Error Handling

**STATUS: DECIDED**

- Wrap all potentially failing operations in try-catch blocks
- Add `-ErrorAction Stop` to cmdlets inside try blocks — without it, most PowerShell errors are non-terminating and will silently bypass the catch block
- In catch blocks, log `$_.Exception.Message`; do not log the full `$_` object
- Use `finally` for cleanup that must run regardless of outcome (e.g. closing handles, restoring state)
- Default behavior is graceful degradation: log the error and continue; do not halt execution
- Exception — halt immediately for these critical conditions:
  - Required dependency or module is missing
  - Elevation check fails when the script requires administrator rights
  - A precondition is unmet and continuing would produce misleading results

## Safe File Output

**STATUS: DECIDED**

Global rule applies: never overwrite or delete an existing file silently. PowerShell-specific implementation:

- Use `Test-Path` to check whether the output file exists before writing
- Add a `-Force` switch parameter (`[switch]$Force = $false`) to allow the caller to opt into overwriting
- If the file exists and `-Force` is not set, write an error and stop — do not prompt interactively, as scripts may run unattended:
  ```powershell
  if (Test-Path -Path $outputFile) {
      if (-not $Force) {
          Write-Error "Output file already exists: $outputFile — use -Force to overwrite."
          return
      }
      Write-Warning "Overwriting existing file: $outputFile"
  }
  ```
- Log a warning when `-Force` causes an overwrite
- Document the `-Force` parameter in `.PARAMETER` and in an `.EXAMPLE` that shows the overwrite case

## Compatibility

**STATUS: DECIDED**

- Write broadly compatible code by default — do not rely on version-specific features unless necessary
- If a script or function requires a minimum PowerShell version, declare it explicitly with `#Requires -Version X.Y`
- Avoid PowerShell 7-only syntax (`? :` ternary, `??` / `??=` null coalescing, `ForEach-Object -Parallel`) unless a `#Requires -Version 7` is in place
- If a cmdlet may not be available in all environments, check with `Get-Command` at runtime before using it; provide a fallback (e.g. WMI/CIM, .NET, registry) rather than failing

## Versioning

**STATUS: DECIDED**

Global versioning rules apply (see `global.instructions.md`). PowerShell-specific location:

- `$scriptVersion` — declared as a plain string at the top of the script, inside the user-tunable configuration block — is the **single source of truth** for the script's version number
- The `.NOTES` `Version:` field must contain `see $scriptVersion in the Configuration section below` — never a literal number; it is a pointer, not a copy
- The `-Version` parameter displays `$scriptVersion` at runtime — no hardcoded string
- Declare the variable like this, at the top of the configuration block:
  ```powershell
  $scriptVersion = '1.0.0'
  ```
- A `scripts-manifest.json` at the project root is optional and may be used as a convenience overview; it is not authoritative and does not need to be kept in sync
- When modifying a script, update `$scriptVersion` according to the nature of the change before committing; no other version field needs touching

## Security

**STATUS: DECIDED**

All global security rules apply. PowerShell-specific implementation:

- Use `Get-Credential` for interactive credential prompts — it is cross-version safe; `Read-Host -AsSecureString` is acceptable on Windows PS5.1 only (`SecureString` provides no real protection on PS7+/.NET Core)
- Read credentials from environment variables with `$env:VAR_NAME`; document which variables are expected at the top of the script
- Never log credential values; scrub sensitive variables before passing them to log functions
- For scripts requiring elevation, use the manual check below rather than `#Requires -RunAsAdministrator` — the manual check allows logging the failure before halting; `#Requires` exits silently before any script code runs:
  ```powershell
  if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
      # log error then exit
  }
  ```
- Validate file path parameters with `Test-Path` before use
- Validate enum-style string parameters with `[ValidateSet('Value1', 'Value2')]` on the parameter declaration — this enforces allowed values at call time and enables tab-completion
- Never use `Invoke-Expression` — it evaluates arbitrary strings as code and is an injection risk; there is always a safer alternative

## Testing

**STATUS: PARTIAL**

Manual testing checklist (decided):

- Test with Windows PowerShell 5.1
- Test with PowerShell 7+ if installed
- Test with restricted execution policy
- Test with and without administrator privileges
- Verify log output format and UTF-8 encoding
- Verify Unicode symbols display correctly
- Automated testing (TBD): Pester framework is the candidate — not yet adopted.