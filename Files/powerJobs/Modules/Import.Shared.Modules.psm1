$initModulePath = "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1"
$moduleName = [io.path]::GetFileNameWithoutExtension($initModulePath)
if ( (Get-Module -Name $moduleName) ) {
    Remove-Module -Name $moduleName
}
Import-Module -Name $initModulePath -Global -Force
Initialize-CoolOrange

$logPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\powerJobs.log"
Set-LogFilePath -Path $logPath
