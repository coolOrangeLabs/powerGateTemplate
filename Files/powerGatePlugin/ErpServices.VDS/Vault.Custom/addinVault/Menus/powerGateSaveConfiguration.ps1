$cfgPath = "c:\temp\powerGateCfg\powerGateConfiguration.xml"
$testPath = Test-Path $cfgPath
if ($testPath -eq $false) {
    $null = [System.Windows.Forms.MessageBox]::Show("No config file found. Please download/edit the config file first and then save it back to the Vault server", "powerGate configuration", "OK", "Warning")
    return
}

[xml]$cfg = Get-Content $cfgPath
$vault.KnowledgeVaultService.SetVaultOption("powerGateConfig", $cfg.InnerXml)
$null = [System.Windows.Forms.MessageBox]::Show("Config file saved to Vault server", "powerGate configuration", "OK", "Information")

Remove-Item $cfgPath -Force