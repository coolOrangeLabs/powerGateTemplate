try {  
    Import-Module "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1" -Global
    Initialize-CoolOrange 

    $cfgPath = "c:\temp\powerGateCfg\powerGateConfiguration.xml"
    $testPath = Test-Path $cfgPath
    if ($testPath -eq $false) {
        ShowMessageBox -Message "No config file found in '$cfgPath' `n Please download/edit the config file first and then save it back to the Vault server!" -Button  "OK" -Icon "Warning" | Out-Null
        return
    }
        [byte[]]$cfg = [System.IO.File]::ReadAllBytes($cfgPath)
        Set-PowerGateConfigFromVault -Content $cfg
        ShowMessageBox -Message "Config file saved to Vault server" -Button "OK" -Icon "Information" | Out-Null
  

    Remove-Item $cfgPath -Force
}
catch {
    (ShowMessageBox -Message $_.Exception.Message -Button  "OK" -Icon "Error") | Out-Null
}