# Type-check, lint and format-check the whole codebase.
# Usage:  .\scripts\check.ps1          (check only)
#         .\scripts\check.ps1 -Fix     (also run StyLua formatter)
param([switch]$Fix)
$ErrorActionPreference = "Stop"
$env:PATH = "$env:USERPROFILE\.rokit\bin;$env:PATH"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path "Packages")) { wally install }

rojo sourcemap default.project.json -o sourcemap.json
if ($Fix) { stylua src }
luau-lsp analyze --definitions=tools/globalTypes.d.luau --sourcemap=sourcemap.json --settings=.luau-lsp.json --ignore "**/_Index/**" --ignore "Packages/**" --ignore "ServerPackages/**" src
if ($LASTEXITCODE -ne 0) { Write-Error "luau-lsp analyze reported errors" }
stylua --check src
Write-Host "OK: types, lint and formatting all pass" -ForegroundColor Green
