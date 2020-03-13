Import-Module powerVault
Import-Module powerGate

#TODO: configure the powerGate server url and port
$powerGateServerName = "localhost"
$powerGateServerPort = "8080"
$powerGateServerErpPluginUrl = "http://$($powerGateServerName):$($powerGateServerPort)/coolOrange/ErpServices"

function ConnectToErpServer {
	$connected = Connect-ERP -Service $powerGateServerErpPluginUrl -OnConnect $onConnect
	if (-not $connected) {
		Show-MessageBox -message "Connection to $powerGateServerErpPluginUrl could not be established!!!" -icon "Error"
	}
}

function Show-MessageBox($message, $title = "powerGate ERP Integration", $icon = "Information") {
	#icons: Error, Exclamation, Hand, Information, Question, Stop, Warning
	$button = "OK"
	$null = [System.Windows.Forms.MessageBox]::Show($message, $title, $button, $icon)	
}

function GetPowerGateError {
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
	return $powerGateErrMsg
}

function CheckResponse($entity) {
	if ($null -eq $entity) {
		$entity = $false
		$pGError = GetPowerGateError
		if ($pGError) {
			$message = "The communication with ERP failed!`n '$pGError'"
			Add-Member -InputObject $entity -Name "_ErrorMessage" -Value $message -MemberType NoteProperty -Force
			Show-MessageBox -message $message -icon "Error"
		}
	}
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