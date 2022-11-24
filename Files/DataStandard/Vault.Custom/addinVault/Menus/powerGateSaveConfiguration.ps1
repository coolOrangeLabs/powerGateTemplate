try {
	Import-Module "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1" -Global
	Initialize-CoolOrange

	$logPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\VDS_Vault-powerGate.log"
	Set-LogFilePath -Path $logPath

	$cfgPath = "c:\temp\powerGateCfg\powerGateConfiguration.xml"
	$testPath = Test-Path $cfgPath
	if ($testPath -eq $false) {
		$null = ShowMessageBox -Message "No config file found in '$cfgPath' `n Please download/edit the config file first and then save it back to the Vault server!" -Button  "OK" -Icon "Warning"
		return
	}
	[byte[]]$cfg = [System.IO.File]::ReadAllBytes($cfgPath)
	Set-PowerGateConfigFromVault -Content $cfg
	$null = ShowMessageBox -Message "Config file saved to Vault server" -Button "OK" -Icon "Information"


	Remove-Item $cfgPath -Force
}
catch {
	($null = ShowMessageBox -Message $_.Exception.Message -Button  "OK" -Icon "Error")
}
finally {
	Remove-CoolOrangeLogging
}