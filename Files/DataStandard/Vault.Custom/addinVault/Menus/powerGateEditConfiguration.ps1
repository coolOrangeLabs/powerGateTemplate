$global:ErrorActionPreference = "Stop"
$commonModulePath = "C:\ProgramData\coolOrange\powerGate\Modules"
$modules = Get-ChildItem -path $commonModulePath -Recurse -Filter *.ps*
$modules | ForEach-Object { Import-Module -Name $_.FullName -Global }

$cfgPath = "c:\temp\powerGateCfg\powerGateConfiguration.xml"
[xml]$cfg = Get-PowerGateConfigFromVault
New-Item -Path "c:\temp\powerGateCfg" -ItemType Directory -Force
$cfg.Save($cfgPath)

Start-Process -FilePath C:\Windows\explorer.exe -ArgumentList "/select, ""$cfgPath"""