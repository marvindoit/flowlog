#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 || ( $# -eq 1 && $1 != --installed-smoke ) ]]; then
  echo "Usage: $0 [--installed-smoke]" >&2
  exit 2
fi

project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
command -v cmd.exe >/dev/null || { echo "cmd.exe not found in PATH" >&2; exit 1; }

# Detect pwsh.exe by running a small PowerShell probe
pwsh=""
probe=$(cmd.exe /c "\"C:\Program Files\PowerShell\7\pwsh.exe\" -Command \"Write-Output \$PSVersionTable.PSVersion.ToString()\"" 2>/dev/null || true)
if [[ -n "$probe" ]]; then
  pwsh="C:\\Program Files\\PowerShell\\7\\pwsh.exe"
else
  pwsh="powershell.exe"
fi

batch=$(mktemp "$project/scripts/.wsl-build-XXXXXXXX.cmd")
trap 'rm -f -- "$batch"' EXIT

WSLPROJECT="$project"
if command -v wslpath >/dev/null 2>&1; then
  WSLPROJECT=$(wslpath -w "$project")
fi
PROXY_VAR=""
if [[ -n "${FLOWLOG_HTTP_PROXY:-}" ]]; then
  PROXY_VAR="set PSDefaultParameterValues[Invoke-WebRequest:Proxy]=http://$FLOWLOG_HTTP_PROXY"
fi

cat > "$batch" <<BAT
@echo off
cd /d "$WSLPROJECT"
$PROXY_VAR
"$pwsh" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts\\build-native.ps1 -Tests
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
"$pwsh" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts\\package-native.ps1 -SkipBuild
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
if "%1"=="--installed-smoke" (
  "$pwsh" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts\\smoke-native.ps1 -Installed
  exit /b %ERRORLEVEL%
)
BAT

cmd.exe /c "$batch" ${1:-}
