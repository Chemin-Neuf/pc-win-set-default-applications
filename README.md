# pc-set-default-applications

Restores Windows 11 default application associations (file extensions and protocols) after a Microsoft update resets them. Intended for power users, to run either manually or via a login script / GPO. Associations can be stored either in one CSV file or in several CSV files referenced by an ordered TXT manifest.

## Structure

| File/Folder | Purpose |
|---|---|
| `set-default-applications.ps1` | Main script — resolves SetUserFTA and applies all associations |
| `get-application-associations.ps1` | Discovery tool — queries the registry to find app names, categories, and ProgIDs |
| `get-ucpd-status.ps1` | Read-only diagnostic — reports current UCPD driver, service and scheduled task state |
| `set-ucpd-service.ps1` | Administrative tool — disables or restores the UCPD service start type and scheduled task(s) |
| `ApplicationRegistry.psm1` | Internal module — registry discovery, capabilities resolution, and friendly name derivation |
| `UcpdUtils.psm1` | Internal module — `Get-UcpdStatus` and `Set-UcpdState` shared by the UCPD scripts |
| `SharedUtils.psm1` | Shared logging and console utilities (synced from ps-shared-utils) |
| `SharedUtils.psd1` | PowerShell module manifest for SharedUtils |
| `default-applications.csv` | Configuration: one row per extension or protocol with its target application name |
| `default-applications.txt` | Sample ordered manifest listing one or more CSV configuration files |
| `logs\` | Per-run log files (created automatically next to the script, or in %TEMP% as fallback) |

## Prerequisites

- PowerShell 5.1+
- Network access to `setuserfta.com` **or** access to `\\your-server\your-share\SetUserFTA.exe`
- No administrator rights required (except `set-ucpd-service.ps1`; `get-ucpd-status.ps1` needs them only to read the UCPD scheduled task)

### About SetUserFTA

[SetUserFTA](https://setuserfta.com) is a third-party command-line tool by Christoph Kolbicz. It sets a user's default application for a file extension or protocol by writing the `UserChoice` registry key with the hash Windows expects, so the change is accepted without user interaction. `set-default-applications.ps1` resolves the ProgID and calls SetUserFTA once per association.

We deliberately stay on **version 1.8.4**, the last free edition, because this toolset is used for non-professional purposes only. Newer releases require a paid licence. Professional use would require a licence or a switch to the supported XML method described below.

## Quick Start

```powershell
# Run with the default configuration file
.\set-default-applications.ps1

# Run with a custom configuration file
.\set-default-applications.ps1 -ConfigPath "C:\IT\my-defaults.csv"

# Run with an ordered TXT manifest listing multiple CSV files
.\set-default-applications.ps1 -ConfigType TXT -ConfigPath ".\default-applications.txt"

# Show full console output
.\set-default-applications.ps1 -Verbosity Detailed
```

Edit `default-applications.csv` to add your associations. Each uncommented row maps one file extension (`.pdf`) or protocol (`http`) to a registered application name such as `Windows Photo Viewer` or `VLC media player`. Spaces in names are fine; only quote a value if it contains a comma. If you want to split the configuration into several CSV files, list them in `default-applications.txt` in the exact order they should be applied; later files win when the same association appears more than once. In a TXT manifest, relative CSV paths are resolved from the manifest file's directory, while absolute paths are kept as-is.

`get-application-associations.ps1 -ListApps` groups registered applications by a friendly display name resolved from Windows metadata, so entries such as `Brave.R6XA3SEV5DUAGVO75MIQPSAUGE` appear as `Brave`, and related registrations such as `CDBurnerXP.axp`, `CDBurnerXP.dxp`, and `CDBurnerXP.iso` are grouped under `CDBurnerXP`. `get-application-associations.ps1 -ListAppsRaw` shows the raw names stored in `RegisteredApplications` for compatibility. The old `-ListAppsFriendly` switch still works as an alias for `-ListApps`.

`get-application-associations.ps1 -App <name>` and `-Category <type>` output detailed association objects and can export them directly to a CSV with `-ExportCsv`. `-ListCategories` lists all perceived-type category names (such as `video`, `audio`) that exist on the current machine.

`get-ucpd-status.ps1` checks whether the UCPD (UserChoice Protection Driver) is present, registered, and running, and whether its scheduled task is enabled — this driver can block SetUserFTA from writing UserChoice keys. No changes are made; the output includes color-coded OK / WARNING / ERROR indicators. Run this first if associations are not being applied.

UCPD (`C:\Windows\System32\drivers\UCPD.sys`) is a Microsoft file system filter driver registered as the `UCPD` service (display name `UCPD`). By default it starts with the system (start type System, `Start = 1`), early in the boot process. A scheduled task, `\Microsoft\Windows\AppxDeploymentClient\UCPD velocity`, runs `UCPDMgr.exe` and can re-enable the service after it was disabled. This task is only visible from an elevated session.

`set-ucpd-service.ps1 -State Disabled` configures the UCPD service start type to Disabled, disables the UCPD scheduled task(s) and attempts to stop the running driver immediately; `-State Default` restores the Windows default (System start type, task(s) enabled). Administrator rights are required. A reboot is normally needed for any change to take full effect. Windows updates may restore the task or the service; re-run `get-ucpd-status.ps1` after major updates.

## Comparison with Microsoft's Supported Methods

Windows offers three ways to set default applications:

- **This script (SetUserFTA)** writes the current user's `UserChoice` keys directly. It needs no administrator rights, applies immediately to existing profiles, and resolves the ProgID on each machine from a friendly application name. UCPD-protected associations are skipped while UCPD is active; disable UCPD first with `set-ucpd-service.ps1 -State Disabled` (administrator rights and a reboot required) to allow them.
- **`Dism /Online /Import-DefaultAppAssociations:file.xml`** stores a default associations XML file in the Windows image. Windows applies it only when a new user profile is created; existing users are not affected. Requires administrator rights.
- **Group Policy "Set a default associations configuration file"** (Computer Configuration > Administrative Templates > Windows Components > File Explorer) points to the same XML format and is applied at every sign-in for all users. This is the supported way to enforce defaults, including UCPD-protected associations, on existing profiles.

The XML file can be exported from a reference machine with `Dism /Online /Export-DefaultAppAssociations:file.xml`. It requires exact ProgIDs.

| Capability | Script (SetUserFTA) | DISM import | GPO + XML |
|---|---|---|---|
| File extensions and protocols | Yes | Yes | Yes |
| Existing user profiles | Yes | No, new profiles only | Yes, at sign-in |
| Immediate effect, no sign-out | Yes | No | No, next sign-in |
| No administrator rights needed | Yes | No | Configured centrally once |
| UCPD-protected associations (http, https, `.pdf`, `.html`...) while UCPD is active | No, skipped | Yes | Yes |
| Requires UCPD to be disabled | Only for protected associations | No | No |
| Restores defaults after a Windows update reset | Yes, when re-run | No | Yes, at next sign-in |
| Friendly application names, ProgID resolved per machine | Yes | No, exact ProgID required | No, exact ProgID required |
| Layered configuration (several CSV files, later wins) | Yes | No, one XML | No, one XML per GPO |
| Logging and per-association result | Yes | No | No |
| Detects applications not declaring the association | Yes, with a warning | No, silently ignored | No, silently ignored |
| Users can keep their own later changes | Yes, one-shot | Yes | No, re-applied at each sign-in |
| Targeting by user or computer group | Through the login script | No | Yes, GPO filtering |
| Officially supported by Microsoft | No | Yes | Yes |
| Third-party dependency | SetUserFTA | None | None |

## Built-in Help

Every script in this toolset includes full PowerShell comment-based help. Use `Get-Help` to read it without leaving the terminal:

```powershell
# Synopsis and syntax overview
Get-Help .\set-default-applications.ps1

# Full help including all parameters and examples
Get-Help .\set-default-applications.ps1 -Full

# Parameters only
Get-Help .\set-default-applications.ps1 -Parameter *

# Examples only
Get-Help .\set-default-applications.ps1 -Examples
```

Replace the script name with any other script in the toolset (`get-application-associations.ps1`, `get-ucpd-status.ps1`, `set-ucpd-service.ps1`) to read its help.

## License

GPL-3.0-only — see [LICENSE](LICENSE).
