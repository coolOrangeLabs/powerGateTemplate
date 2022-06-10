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

function ConnectToErpServerWithMessageBox {
	Log -Begin
	$powerGateServerName = getRelatedPGServerName
	$powerGateServerErpPluginUrl = "http://$($powerGateServerName):$($powerGateServerPort)/coolOrange/ErpServices"
	#$powerGateServerErpPluginUrl = "http://$($powerGateServerName):$($powerGateServerPort)/coolOrange/DynamicsNav"
	# Dynamics NAV 2017 Plugin available here: https://github.com/coolOrangeLabs/powergate-dynamics-nav-sample/releases

	if (-not $powerGateServerName){
		ShowMessageBox -Message "The current connected VAULT $($vaultConnection.Vault) is not mapped in the configuration for any ERP.`nChange the configuration and restart vault!" -Icon Error | Out-Null
	}
	else {
		$connected = ConnectToErpServer
		if (-not $connected) {
			$connectionError = ("Error on connecting to powerGateServer service! Check if powerGateServer is running on following host: '{0}' or try to access following link via your browser: '{1}'" -f (([Uri]$powerGateServerErpPluginUrl).Authority), $powerGateServerErpPluginUrl)
			Write-Error -Message $connectionError
			ShowMessageBox -Message $connectionError -Icon Error
		}
	}
	Log -End
}

function ConnectToErpServer {
	Log -Begin
	if ($powerGateServerName){
		Write-Host "Connecting with URL: $powerGateServerErpPluginUrl"
		$connected = Connect-ERP -Service $powerGateServerErpPluginUrl -OnConnect $onConnect
		Write-Host "Connection: $connected"
		return $connected
	}else{
	}
	Log -End
}

function GetPowerGateError {
	Log -Begin
	$powerGateErrMsg = $null
	$powerGateLastResponse = [AppDomain]::CurrentDomain.GetData("powerGate_lastResponse")
	if ($powerGateLastResponse) {
		if ($powerGateLastResponse.Code -eq "500") {
			$powerGateErrMsg = [string]$powerGateLastResponse.Body.error.message.innertext
			if ($powerGateLastResponse.Body.error.innererror) {
				$powerGateErrMsg = [string]$powerGateLastResponse.Body.error.innererror.message
			}
			if ($powerGateLastResponse.Body.error.innererror.internalexception) {
				$powerGateErrMsg = [string]$powerGateLastResponse.Body.error.innererror.internalexception.message
			}
		}
	}
	Log -End
	return $powerGateErrMsg
}
function Get-PgsErrorForLastResponse {
	param(
		$Entity,
		[Switch]$WriteOperation
	)
	if($? -eq $false) { #Condition must be evaluated first as every other command like logging would change $?
		$message = $null
		$powerGateLastResponse = [AppDomain]::CurrentDomain.GetData("powerGate_lastResponse")
		if($WriteOperation) {
			# In case NO error message from the ERP returned and this means that no request at all was sent out by powerGate, therefore its required to look for a internal error in the powerGate Logs file.
			$logFileLocation = "$($env:LocalAppdata)\coolOrange\powerGate\Logs\powerGate.log"
			$message = "Unexpected error:`n Failed bacause probably some passed values for the create/update operation are not valid, for example 'the input was a text but should be a number'. Therefore check the last error message in the log file, then change your inputs and re-execute the operation: $logFileLocation"
		}
		elseif($powerGateLastResponse.Status -as [int] -gt 500) {
			$pGError = GetPowerGateError
			$message = "{1} - Status: {0}; Message: {2}" -f `
				$powerGateLastResponse.Code, `
				$powerGateLastResponse.Status, `
				$pGError
		}
	}
	else { $message = $null }

	Log -Begin
	$result = @{
		Entity = $Entity
		ErrorMessage = $message
	}
	Log -End
	return $result
}

$collectResponse = {
	param($settings)
	$settings.AfterResponse = [System.Delegate]::Combine([Action[System.Net.Http.HttpResponseMessage]] {
		param($response)
		$global:powerGate_lastResponse = New-Object PSObject @{
			'RequestUri' = $response.RequestMessage.RequestUri
			'Code'       = [int]$response.StatusCode
			'Status'     = $response.StatusCode.ToString()
			'Protocol'   = 'HTTP/' + $response.Version
			'Headers'    = @{ }
			'Body'       = $null
		} 
		$response.Headers | ForEach-Object { $powerGate_lastResponse.Headers[$_.Key] = $_.Value }
		if ($response.Content -ne $null) {
			$body = $response.Content.ReadAsStringAsync().Result
			try {
				$powerGate_lastResponse.Body = $body | ConvertFrom-Json
			}
			catch {
				$powerGate_lastResponse.Body = [xml]$body
			}
			$response.Content.Headers | ForEach-Object { $powerGate_lastResponse.Headers[$_.Key] = $_.Value }
		}
		$currentDomain = [AppDomain]::CurrentDomain
		$currentDomain.SetData("powerGate_lastResponse", $global:powerGate_lastResponse)
	}, $settings.AfterResponse)
}

$onConnect = {
	param($settings)
	$collectResponse.Invoke($settings);
}