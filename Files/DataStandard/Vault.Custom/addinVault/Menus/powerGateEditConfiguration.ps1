try {    
    Import-Module "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1" -Global
    Initialize-CoolOrange 

    $cfgPath = "c:\temp\powerGateCfg\powerGateConfiguration.xml"
    [xml]$cfg = Get-PowerGateConfigFromVault
    New-Item -Path "c:\temp\powerGateCfg" -ItemType Directory -Force
    $cfg.Save($cfgPath)

    Start-Process -FilePath C:\Windows\explorer.exe -ArgumentList "/select, ""$cfgPath"""
}
catch {
    ($null = ShowMessageBox -Message $_.Exception.Message -Button  "OK" -Icon "Error")
}