$global:ErrorActionPreference = "Stop"
$commonModulePath = "C:\ProgramData\coolOrange\powerGate\Modules"
$modules = Get-ChildItem -path $commonModulePath -Recurse -Filter *.ps* 
$modules | ForEach-Object { Import-Module -Name $_.FullName -Global }
$global:loggingSettings.LogFile = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\powerEvents.txt"

ConnectToErpServer