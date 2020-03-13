$cfgPath = "c:\temp\powerGateCfg\powerGateConfiguration.xml"
[xml]$cfg = $vault.KnowledgeVaultService.GetVaultOption("powerGateConfig")
New-Item -Path "c:\temp\powerGateCfg" -ItemType Directory -Force
if ($null -eq $cfg) {
    Copy-Item "$addinPath\Menus\powerGateConfigurationTemplate.xml" $cfgPath -Force
}
else {
    $cfg.Save($cfgPath)
}

Start-Process -FilePath C:\Windows\explorer.exe -ArgumentList "/select, ""$cfgPath"""