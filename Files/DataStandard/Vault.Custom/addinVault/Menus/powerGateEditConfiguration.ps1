$global:ErrorActionPreference = "Stop"
$commonModulePath = "C:\ProgramData\coolOrange\powerGate\Modules"
$modules = Get-ChildItem -path $commonModulePath -Filter *.psm1
$modules | ForEach-Object { Import-Module -Name $_.FullName -Global }

$cfgPath = "c:\temp\powerGateCfg\powerGateConfiguration.xml"
[xml]$cfg = Get-PowerGateConfigFromVault
New-Item -Path "c:\temp\powerGateCfg" -ItemType Directory -Force
if ($null -eq $cfg) {
    Copy-Item "C:\ProgramData\coolOrange\powerGate\powerGateConfigurationTemplate.xml" $cfgPath -Force
}
else {
    $cfg.Save($cfgPath)
}

Start-Process -FilePath C:\Windows\explorer.exe -ArgumentList "/select, ""$cfgPath"""