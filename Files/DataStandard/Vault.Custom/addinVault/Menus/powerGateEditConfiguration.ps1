try {
	Import-Module "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1" -Global
	Initialize-CoolOrange

	$logPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\VDS_Vault-powerGate.log"
	Set-LogFilePath -Path $logPath

	$cfgPath = "c:\temp\powerGateCfg\powerGateConfiguration.xml"
	[xml]$cfg = Get-PowerGateConfigFromVault
	New-Item -Path "c:\temp\powerGateCfg" -ItemType Directory -Force
	$cfg.Save($cfgPath)

	Start-Process -FilePath C:\Windows\explorer.exe -ArgumentList "/select, ""$cfgPath"""
}
catch {
	($null = ShowMessageBox -Message $_.Exception.Message -Button  "OK" -Icon "Error")
}
finally {
	Remove-CoolOrangeLogging
}