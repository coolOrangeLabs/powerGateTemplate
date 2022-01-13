Import-Module powerVault
Import-Module powerGate

#TODO: configure the powerGate server url and port
$powerGateServerName = $ENV:Computername
$powerGateServerPort = "8080"
$vaultDefinitions = @{
	"TEST" = "TestVault";
	"STD" = "StandartVault"
}
$ERPDefinitions = @{
	"TEST" = "TestERP";
	"STD" = "StandartERP"
}
$powerGateServerErpPluginUrl = "http://$($powerGateServerName):$($powerGateServerPort)/coolOrange/ErpServices"
#$powerGateServerErpPluginUrl = "http://$($powerGateServerName):$($powerGateServerPort)/coolOrange/DynamicsNav"
# Dynamics NAV 2017 Plugin available here: https://github.com/coolOrangeLabs/powergate-dynamics-nav-sample/releases

function getRelatedERPName {
	switch ($vaultConnection.Vault) {
		$VaultDefinitions["TEST"] {
			return $ERPDefinitions["TEST"]
		}
		$VaultDefinitions["STD"] {
			return $ERPDefinitions["STD"]
		}
		Default { return $null}
	}
}
function ConnectToErpServerWithMessageBox {
	Log -Begin
	$connected = ConnectToErpServer
	if (-not $connected) {
		$connectionError = ("Error on connecting to powerGateServer service! Check if powerGateServer is running on following host: '{0}' or try to access following link via your browser: '{1}'" -f (([Uri]$powerGateServerErpPluginUrl).Authority), $powerGateServerErpPluginUrl)
		Write-Error -Message $connectionError
		ShowMessageBox -Message $connectionError -Icon Error
	}
	Log -End
}

function ConnectToErpServer {
	Log -Begin
	Write-Host "Connecting with URL: $powerGateServerErpPluginUrl"
	$connected = Connect-ERP -Service $powerGateServerErpPluginUrl -OnConnect $onConnect
	Write-Host "Connection: $connected"
	Log -End
	return $connected
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

function Edit-ResponseWithErrorMessage {
	param(
		$Entity,
		[Switch]$WriteOperation = $false
	)
	Log -Begin
	if ($null -eq $entity) {
		$entity = $false
		if($WriteOperation) {
			# In case NO error message from the ERP returned and this means that no request at all was sent out by powerGate, therefore its required to look for a internal error in the powerGate Logs file.
			$logFileLocation = "$($env:LocalAppdata)\coolOrange\powerGate\Logs\powerGate.log"
			Add-Member -InputObject $entity -Name "_ErrorMessage" -Value "Unexpected error:`n Failed bacause probably some passed values for the create/update operation are not valid, for example 'the input was a text but should be a number'. Therefore check the last error message in the log file, then change your inputs and re-execute the operation: $logFileLocation" -MemberType NoteProperty -Force
		}
		$pGError = GetPowerGateError
		if ($pGError) {
			$message = "Direct error message from the ERP:`n '$pGError'"
			Add-Member -InputObject $entity -Name "_ErrorMessage" -Value $message -MemberType NoteProperty -Force
		}
	}
	Log -End
	return $entity
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