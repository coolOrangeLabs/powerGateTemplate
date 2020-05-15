Import-module "C:\ProgramData\coolOrange\powerGate\Modules\Logging.psm1" -Force
$global:loggingSettings.LogFile = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\powerEvents.txt"

$Global:ErrorActionPreference = "STOP"