# return
#region TO BE REMOVED
if((Get-Process -Id $PID).ProcessName -eq 'powershell' -and $host.Name.StartsWith('powerEvents')){
	return
}
if([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq 'MTA' -and (Get-Process -Id $PID).ProcessName -ne 'powershell'){
	Start-Process powershell.exe -ArgumentList "-STA",$MyInvocation.InvocationName -WindowStyle hidden
	return
}

Import-Module powerEvents
Open-VaultConnection -Server $env:Computername -Vault Vault -User Administrator -Password ""
$selectedFile = Get-VaultFile -File '$/Designs/MultipageInv.idw'

Import-Module powergate
Connect-ERP -Service 'http://thomas-rossi:8080/PGS/ErpServices'
#endregion

$global:addinPath = $PSScriptRoot
Import-Module "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1" -Global
Initialize-CoolOrange


# if ($vaultConnection.Vault -notin $vaultToPgsMapping.Keys) {
# 	throw "The currently connected Vault '$($vaultConnection.Vault)' is not mapped to any powerGateServer URL. Please extend the configuration and re-submit the job!"
# }

# Write-Host "Connecting to powerGateServer on: $($vaultToPgsMapping[$vaultConnection.Vault])"
# $connected = Connect-ERP -Service "http://$($vaultToPgsMapping[$vaultConnection.Vault]):8080/PGS/ErpServices"
# if(-not $connected) {
# 	throw("Connection to ERP could not be established! Reason: $($Error[0]) (Source: $($Error[0].Exception.Source))")
# }

#region Initialize material tab
Add-Type -AssemblyName PresentationFramework
[xml]$erpMaterialTabXaml = Get-Content -LiteralPath "C:\ProgramData\coolOrange\powerEvents\Events\ErpTab.Item.xaml"
$xamlReader = [System.Xml.XmlNodeReader]::new($erpMaterialTabXaml)
$erpMaterialTab = [Windows.Markup.XamlReader]::Load($xamlReader)
#endregion Initialize material tab


#region Initialize viewmodel
$materialTabContext = New-Object -Type PsObject -Property @{
	ErpEntity = $null
	VaultEntity = $selectedFile
	IsCreate = $false

	Lists = @{
		UomList = @(GetUnitOfMeasuresList)
		MaterialTypeList = @(GetMaterialTypeList)
		CategoryList = @(GetCategoryList)
	}
}
#endregion Initialize viewmodel


#region Initialize UI Components
#region Register Validate tab events
$erpMaterialTab_Description = $erpMaterialTab.FindName('Description')
$erpMaterialTab_Description.Add_TextChanged({
	param($Sender)

	ValidateErpMaterialTab -MaterialTabContext $Sender.DataContext
})

$erpMaterialTab_MaterialTypeList = $erpMaterialTab.FindName('MaterialTypeList')
$erpMaterialTab_MaterialTypeList.Add_SelectionChanged({
	param($Sender)

	ValidateErpMaterialTab -MaterialTabContext $Sender.DataContext
})
#endregion Register Validate tab events

$erpMaterialTab_LinkMaterialButton = $erpMaterialTab.FindName("LinkMaterialButton")
$erpMaterialTab_LinkMaterialButton.IsEnabled = (IsEntityUnlocked -Entity $selectedFile)
$erpMaterialTab_LinkMaterialButton.Add_Click({
	param($Sender)

	LinkErpMaterial -MaterialTabContext $Sender.DataContext
})

$erpMaterialTab_CreateOrUpdateMaterialButton = $erpMaterialTab.FindName("CreateOrUpdateMaterialButton")
$erpMaterialTab_CreateOrUpdateMaterialButton.Add_Click({
	param($Sender)

	CreateOrUpdateErpMaterial -MaterialTabContext $Sender.DataContext
})

$erpMaterialTab_GoToMaterialButton = $erpMaterialTab.FindName("GoToMaterialButton")
$erpMaterialTab_GoToMaterialButton.IsEnabled = $true
$erpMaterialTab_GoToMaterialButton.Add_Click({
	param($Sender)

	GoToErpMaterial -MaterialTabContext $Sender.DataContext
})
#endregion Initialize UI Components


$erpServices = Get-ERPServices -Available
if (-not $erpServices) {
	$erpMaterialTab.FindName("lblStatusMessage").Content = "One or more services are not available!"
	$erpMaterialTab.FindName("lblStatusMessage").Foreground = "Red"
	$erpMaterialTab.IsEnabled = $false
	$erpMaterialTab.ShowDialog()
	return
}

$number = GetEntityNumber -entity $selectedFile
$erpMaterial = Get-ERPObject -EntitySet "Materials" -Keys @{ Number = $number }
if(-not $?) {
	$erpMaterialTab.FindName("lblStatusMessage").Content = $Error[0]
	$erpMaterialTab.FindName("lblStatusMessage").Foreground = "Red"
	$erpMaterialTab.IsEnabled = $false
	$tab_control.ShowDialog()
	return
}

if (-not $erpMaterial) {
	$erpMaterial = NewErpMaterial
	$erpMaterial = PrepareErpMaterialForCreate -erpMaterial $erpMaterial -vaultEntity $selectedFile
	$materialTabContext.IsCreate = $true
	$materialTabContext.ErpEntity = $erpMaterial
	$erpMaterialTab.FindName("GoToMaterialButton").IsEnabled = $false
}
else {
	$materialTabContext.ErpEntity = $erpMaterial
	$erpMaterialTab.FindName("GoToMaterialButton").IsEnabled = $true
}

$erpMaterialTab.DataContext = $materialTabContext
ValidateErpMaterialTab
$erpMaterialTab.ShowDialog()
