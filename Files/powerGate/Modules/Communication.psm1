Import-Module powerVault
Import-Module powerGate
#TODO: configure the powerGate server port and map the Vaults with their related servernames
$powerGateServerPort = "8080"
# define here witch Vault is used for test and witch one for production
$testVaults = @(
	"Vault",
	"TestVault",
	"TestVault2"
	# ,...
)
$productiveVaults = @(
	"Vault1",
	"ProdVault2"
	# ,...
)

# define here witch Powergate Server is used for test and witch one for production
$PGServerDefinitions = @{
	"TEST" = $env:COMPUTERNAME;
	"PROD" = "ProductiveERP"
}
function getRelatedPGServerName {
	$connectedVault = $vaultConnection.Vault
	if ($connectedVault -in $testVaults){
		return $PGServerDefinitions["TEST"]
	}
	elseif ($connectedVault -in $productiveVaults){
		return $PGServerDefinitions["PROD"]
	}
}
function CreateUrlFromPGServerName {
	Log -Begin
	$powerGateServerName = getRelatedPGServerName
	if (-not $powerGateServerName) {
		return;
	}
	$powerGateServerErpPluginUrl = "http://$($powerGateServerName):$($powerGateServerPort)/PGS/ErpServices"
	#$powerGateServerErpPluginUrl = "http://$($powerGateServerName):$($powerGateServerPort)/PGS/DynamicsNav"
	# Dynamics NAV 2017 Plugin available here: https://github.com/coolOrangeLabs/powergate-dynamics-nav-sample/releases
	Log -End
	return $powerGateServerErpPluginUrl;

}
function ConnectToErpServerWithMessageBox {
	Log -Begin
	$powerGateServerErpPluginUrl = CreateUrlFromPGServerName
	if (-not $powerGateServerErpPluginUrl){
		ShowMessageBox -Message "The current connected VAULT $($vaultConnection.Vault) is not mapped in the configuration for any ERP.`nChange the configuration and restart vault!" -Icon Error | Out-Null
	}
	else {
		Write-Host "Connecting with URL: $powerGateServerErpPluginUrl"
		$connected = Connect-ERP -Service $PowerGateServerErpPluginUrl
		Write-Host "Connected: $connected"
	}
	Log -End
}
# Use this function in Jobs
function ConnectToConfiguredErpServer {
	Log -Begin
	$powerGateServerErpPluginUrl = CreateUrlFromPGServerName
	if (-not $powerGateServerErpPluginUrl){
		throw 'no ERP Server URL specified!'
	}
	else {
		Write-Host "Connecting to: $powerGateServerErpPluginUrl"
		$connected = Connect-ERP -Service $PowerGateServerErpPluginUrl
		if(-not $connected) {
			throw("Connection to ERP could not be established!! Reason: $($Error[0]) (Source: $($Error[0].Exception.Source))")
		}
	}
	Log -End
}



