$global:ErrorActionPreference = "Stop"
$commonModulePath = "C:\ProgramData\coolOrange\powerGate\Modules"
$modules = Get-ChildItem -path $commonModulePath -Filter *.psm1
$modules | ForEach-Object { Import-Module -Name $_.FullName -Global }

$cfgPath = "c:\temp\powerGateCfg\powerGateConfiguration.xml"
$testPath = Test-Path $cfgPath
if ($testPath -eq $false) {
    $null = [System.Windows.Forms.MessageBox]::Show("No config file found. Please download/edit the config file first and then save it back to the Vault server", "powerGate configuration", "OK", "Warning")
    return
}

[xml]$cfg = Get-Content $cfgPath
Set-PowerGateConfigFromVault -Content $cfg.InnerXml
$null = [System.Windows.Forms.MessageBox]::Show("Config file saved to Vault server", "powerGate configuration", "OK", "Information")

Remove-Item $cfgPath -Force