$allowedProcesses = @("Connectivity.VaultPro","Inventor", "Acad")
if ($allowedProcesses -contains $processName) {
    $initModulePath = "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1"
    $moduleName = [io.path]::GetFileNameWithoutExtension($initModulePath)
    if( (Get-Module -Name $moduleName) ) {
        Remove-Module -Name $moduleName
    }
    Import-Module -Name $initModulePath -Global -Force
    Initialize-CoolOrange

    $logPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\powerEvents.log"
    Set-LogFilePath -Path $logPath

    ConnectToConfiguredErpServer
}
