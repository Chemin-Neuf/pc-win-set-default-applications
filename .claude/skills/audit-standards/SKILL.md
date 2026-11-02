---
# Chemin-Neuf dev-standards — audit-standards skill
# Last Updated: 2026-05-10
# Original Author: Claude Sonnet 4.6 (Anthropic / GitHub Copilot)
name: audit-standards
description: Audit a file or directory for compliance with Chemin-Neuf dev-standards. Checks all STATUS: DECIDED rules, fixes unambiguous issues, and asks about anything requiring judgment. Use when reviewing scripts, modules, or HTML files before committing, or when onboarding an existing repo.
argument-hint: "path/to/file-or-directory"
disable-model-invocation: true
allowed-tools: Read Glob Grep Edit Write
---
<!-- AUTO-SYNCED from github.com/Chemin-Neuf/dev-standards DO NOT EDIT HERE — edit in dev-standards and re-sync -->

# Standards Audit

Audit `$ARGUMENTS` against the Chemin-Neuf dev-standards and apply fixes where unambiguous.
If `$ARGUMENTS` is empty, audit the current working directory.

## Step 1 — Load the standards

Read these four files in full before doing anything else:

- `${CLAUDE_SKILL_DIR}/../../../.github/instructions/global.instructions.md`
- `${CLAUDE_SKILL_DIR}/../../../.github/instructions/powershell.instructions.md`
- `${CLAUDE_SKILL_DIR}/../../../.github/instructions/bash.instructions.md`
- `${CLAUDE_SKILL_DIR}/../../../.github/instructions/html.instructions.md`

## Step 2 — Identify scope

Inspect `$ARGUMENTS`:
- Single file → audit that file only
- Directory → audit all files recursively; limit to: `.ps1`, `.psm1`, `.psd1`, `.sh`, `.html`, `.htm`, `.md`, `LICENSE`, `.gitignore`

## Step 3 — Match rules to file type

Apply only rules marked `STATUS: DECIDED`. Ignore all `STATUS: TBD` rules entirely — do not flag, guess, or mention them.
For `STATUS: PARTIAL` rules, read the inline notes and apply only the decided subset.

| File type | Standards to apply |
|---|---|
| `.ps1`, `.psm1`, `.psd1` | Global + PowerShell |
| `.sh` | Global + Bash (decided rules only — most are TBD, so few apply) |
| `.html`, `.htm` | Global + HTML |
| `README.md` | Global README requirements |
| `CHANGELOG.md` | Global CHANGELOG requirements |
| `LICENSE` | Verify it contains the GPL-3.0-only full text |
| `.gitignore` | No standards rules apply — skip |
| Other files | Global rules only |

## Step 4 — For each file, take one of two actions

### Fix without asking (mechanical, unambiguous)
- Wrong or missing license notice → insert the correct block
- Wrong file encoding declaration (HTML `<meta charset>`) → correct it
- Wrong file extension (`.htm` → `.htm` is not permitted, report only — do not rename)
- Missing required README sections → add the missing section(s) using the standard template
- Missing required CHANGELOG → report only, do not create
- AI attribution header present but incomplete → complete it if the information is available

### Ask before acting (requires judgment)
- Ambiguous original authorship for AI attribution
- Conflicting rules between versions of a file
- Any case where applying a rule would delete or restructure substantial existing content
- Anything in a `STATUS: TBD` area where the current state seems wrong

## Step 5 — Report

After processing all files, output a single structured report:

```
## Audit report — [path audited]

### Fixed
- [file]: [what was fixed and which rule]

### Needs review (questions)
- [file]: [what was found, what the question is]

### Compliant
- [file]: all checked rules pass
```

Skip files with no applicable rules from the report entirely.
