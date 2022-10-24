$services = @(
	'/PGS/ERP/BomService',
	'/PGS/ERP/MaterialService'
)

$vaultToPgsMapping = @{
	'Vault'     = '$($vaultConnection.Server)';
	'TestVault' = '$env:COMPUTERNAME';
}

function ConnectToPowerGateServer() {
	$connectedVault = $vaultConnection.Vault
	if ($connectedVault -in $vaultToPgsMapping.Keys) {
		$pgsHost = "http://" + $ExecutionContext.InvokeCommand.ExpandString($vaultToPgsMapping[$connectedVault]) + ":8080"
		foreach ($serviceUrl in $services) {
			$powerGateServerPluginUrl = $pgsHost + $serviceUrl
			Write-Host "Connecting to: $powerGateServerPluginUrl"
			$connected = Connect-ERP -Service $powerGateServerPluginUrl
			Write-Host "Connected: $connected"
		}
	}
	else {
		throw "The currently connected Vault '$($vaultConnection.Vault)' is not mapped in the configuration to any powerGateServer.`r`nPlease extend the configuration and restart the application."
	}
}