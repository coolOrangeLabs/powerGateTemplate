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

function Add-VaultTab($name, $EntityType, $Action){
	Add-Type -AssemblyName PresentationFramework

	$xamlReader = New-Object System.Xml.XmlNodeReader ([xml]@'
	<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
		<Window.Resources>
			<Style TargetType="{x:Type Window}">
				<Setter Property="FontFamily" Value="Segoe UI" />
				<Setter Property="Background" Value="#FFFDFDFD" />
			</Style>
		</Window.Resources>
	</Window>
'@)
	$debugERPTab_window = [Windows.Markup.XamlReader]::Load($xamlReader)
	$debugERPTab_window.Title = "powerGate Debug Window for Tab: $name"
    $debugERPTab_window.AddChild($action.InvokeReturnAsIs($selectedFile))
	$debugERPTab_window.ShowDialog()
}


Import-Module powergate
Connect-ERP -Service 'http://thomas-rossi:8080/PGS/ErpServices'
#endregion

$global:addinPath = $PSScriptRoot
Import-Module "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1" -Global
Initialize-CoolOrange

Remove-CoolOrangeLogging
$logPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\VDS_Vault-powerGate.log"
Set-LogFilePath -Path $logPath


Add-VaultTab -Name 'ERP Item' -EntityType 'File' -Action {
	param($selectedFile)

	$erpItemTab_control = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new([xml](Get-Content "$PSScriptRoot\ERPItem_Tab.xaml")))

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
	$erpItemTab_Description = $erpItemTab_control.FindName('Description')
	$erpItemTab_Description.Add_TextChanged({
		param($Sender)

		ValidateErpMaterialTab -MaterialTabContext $Sender.DataContext
	})

	$erpItemTab_MaterialTypeList = $erpItemTab_control.FindName('MaterialTypeList')
	$erpItemTab_MaterialTypeList.Add_SelectionChanged({
		param($Sender)

		ValidateErpMaterialTab -MaterialTabContext $Sender.DataContext
	})
	#endregion Register Validate tab events

	$erpItemTab_LinkMaterialButton = $erpItemTab_control.FindName("LinkMaterialButton")
	$erpItemTab_LinkMaterialButton.IsEnabled = (IsEntityUnlocked -Entity $selectedFile)
	$erpItemTab_LinkMaterialButton.Add_Click({
		param($Sender)

		LinkErpMaterial -MaterialTabContext $Sender.DataContext
	})

	$erpItemTab_CreateOrUpdateMaterialButton = $erpItemTab_control.FindName("CreateOrUpdateMaterialButton")
	$erpItemTab_CreateOrUpdateMaterialButton.Add_Click({
		param($Sender)

		CreateOrUpdateErpMaterial -MaterialTabContext $Sender.DataContext
	})

	$erpItemTab_GoToMaterialButton = $erpItemTab_control.FindName("GoToMaterialButton")
	$erpItemTab_GoToMaterialButton.IsEnabled = $true
	$erpItemTab_GoToMaterialButton.Add_Click({
		param($Sender)

		GoToErpMaterial -MaterialTabContext $Sender.DataContext
	})
	#endregion Initialize UI Components


	$erpServices = Get-ERPServices -Available
	if (-not $erpServices) {
		$erpItemTab_control.FindName("lblStatusMessage").Content = "One or more services are not available!"
		$erpItemTab_control.FindName("lblStatusMessage").Foreground = "Red"
		$erpItemTab_control.IsEnabled = $false
		return $erpItemTab
	}

	$number = GetEntityNumber -entity $selectedFile
	$erpMaterial = Get-ERPObject -EntitySet "Materials" -Keys @{ Number = $number }
	if(-not $?) {
		$erpItemTab_control.FindName("lblStatusMessage").Content = $Error[0]
		$erpItemTab_control.FindName("lblStatusMessage").Foreground = "Red"
		$erpItemTab_control.IsEnabled = $false
		return $erpItemTab
	}

	if (-not $erpMaterial) {
		$erpMaterial = NewErpMaterial
		$erpMaterial = PrepareErpMaterialForCreate -erpMaterial $erpMaterial -vaultEntity $selectedFile
		$materialTabContext.IsCreate = $true
		$materialTabContext.ErpEntity = $erpMaterial
		$erpItemTab_control.FindName("GoToMaterialButton").IsEnabled = $false
	}
	else {
		$materialTabContext.ErpEntity = $erpMaterial
		$erpItemTab_control.FindName("GoToMaterialButton").IsEnabled = $true
	}

	$erpItemTab_control.DataContext = $materialTabContext
	ValidateErpMaterialTab
}
