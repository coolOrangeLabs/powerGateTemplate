Import-Module powerVault
Import-Module powerGate

#TODO: configure the powerGate server url and port
$powerGateServerName = $ENV:Computername
$powerGateServerPort = "8080"
$powerGateServerErpPluginUrl = "http://$($powerGateServerName):$($powerGateServerPort)/coolOrange/ErpServices"
#$powerGateServerErpPluginUrl = "http://$($powerGateServerName):$($powerGateServerPort)/coolOrange/DynamicsNav"
# Dynamics NAV 2017 Plugin available here: https://github.com/coolOrangeLabs/powergate-dynamics-nav-sample/releases

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
        $integerStatusCode = ($powerGateLastResponse.Code) -as [int]
        if ($integerStatusCode -ge 500 -and $integerStatusCode -lt 600) {
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
	$result = @{
		Entity = $entity
		ErrorMessage = $null
	}
	if ($null -eq $entity) {
		if($WriteOperation) {
			# In case NO error message from the ERP returned and this means that no request at all was sent out by powerGate, therefore its required to look for a internal error in the powerGate Logs file.
			$logFileLocation = "$($env:LocalAppdata)\coolOrange\powerGate\Logs\powerGate.log"
			$result.ErrorMessage = "Unexpected error:`n Failed bacause probably some passed values for the create/update operation are not valid, for example 'the input was a text but should be a number'. Therefore check the last error message in the log file, then change your inputs and re-execute the operation: $logFileLocation"
		}
		$pGError = GetPowerGateError
		if ($pGError) {
			$message = "Direct error message from the ERP:`n '$pGError'"
			$result.ErrorMessage = $message
		}
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