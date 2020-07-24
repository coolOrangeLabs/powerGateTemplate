Import-Module powerVault
Import-Module powerGate

#TODO: configure the powerGate server url and port
$powerGateServerName = $ENV:Computername
$powerGateServerPort = "8080"
$powerGateServerErpPluginUrl = "http://$($powerGateServerName):$($powerGateServerPort)/coolOrange/ErpServices"

function ConnectToErpServerWithMessageBox {
	Log -Begin
	$connected = ConnectToErpServer
	if (-not $connected) {
		Log -Message "Connection to $powerGateServerErpPluginUrl could not be established!" -MessageBox -LogLevel "Error"
	}
	Log -End
}

function ConnectToErpServer {
	Log -Begin
	Log -Message "Connecting with URL: $powerGateServerErpPluginUrl"
	$connected = Connect-ERP -Service $powerGateServerErpPluginUrl -OnConnect $onConnect
	Log -Message "Connection: $connected"
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

function CheckResponse($entity) {
	Log -Begin
	if ($null -eq $entity) {
		$entity = $false
		$pGError = GetPowerGateError
		if ($pGError) {
			$message = "The communication with ERP failed!`n '$pGError'"
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