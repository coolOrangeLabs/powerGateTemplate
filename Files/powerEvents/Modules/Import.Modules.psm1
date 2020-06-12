
Import-module "C:\ProgramData\coolOrange\powerGate\Modules\Logging.psm1" -Force
$global:loggingSettings.LogFile = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\powerEvents.txt"
$Global:ErrorActionPreference = "STOP"

#TODO: This could be improved
Import-module "C:\ProgramData\Autodesk\Vault 2020\Extensions\DataStandard\Vault.Custom\addinVault\powerGateMain.ps1" -Force
Import-module "C:\ProgramData\coolOrange\powerGate\Modules\BomFunctions.psm1" -Force
