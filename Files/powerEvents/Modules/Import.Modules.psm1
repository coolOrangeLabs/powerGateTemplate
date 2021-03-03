Import-Module "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1" -Global
Initialize-CoolOrange 

$logPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\powerEvents.log"
Set-LogFilePath -Path $logPath

ConnectToErpServer
