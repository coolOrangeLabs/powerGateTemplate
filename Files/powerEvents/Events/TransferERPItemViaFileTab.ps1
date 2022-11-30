#region Debugging
if((Get-Process -Id $PID).ProcessName -in @('powershell','powershell_ise') -and $host.Name.StartsWith('powerEvents') -eq $false){
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
	Connect-ERP -Service 'http://localhost:8080/PGS/ErpServices'
}
#endregion

$global:addinPath = $PSScriptRoot
Import-Module "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1" -Global
Initialize-CoolOrange

Remove-CoolOrangeLogging
$logPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\VDS_Vault-powerGate.log"
Set-LogFilePath -Path $logPath


Add-VaultTab -Name 'ERP Item' -EntityType 'File' -Action {
	param($selectedFile)

	$erpItemTab_control = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new([xml](Get-Content "$PSScriptRoot\TransferERPItemTab.xaml")))
	
	$statusMessage_label = $erpItemTab_control.FindName('lblStatusMessage')
	$erpServices = Get-ERPServices -Available
	if (-not $erpServices) {
		$statusMessage_label.Content = "One or more services are not available!"
		$statusMessage_label.Foreground = "Red"
		$erpItemTab_control.IsEnabled = $false
		return $erpItemTab_control
	}

	$unitOfMeasure_combobox = $erpItemTab_control.FindName('UomList')
	$unitOfMeasure_combobox.ItemsSource = @(GetUnitOfMeasuresList)

	$materialTypes_combobox = $erpItemTab_control.FindName('MaterialTypeList')
	$materialTypes_combobox.ItemsSource = @(GetMaterialTypeList)

	$categories_combobox = $erpItemTab_control.FindName('CategoryList')
	$categories_combobox.ItemsSource = @(GetCategoryList)

	$erpItemTab_CreateOrUpdateMaterialButton = $erpItemTab_control.FindName('CreateOrUpdateMaterialButton')
	$erpItemTab_GoToMaterialButton = $erpItemTab_control.FindName('GoToMaterialButton')

	$erpMaterial = Get-ERPObject -EntitySet "Materials" -Keys @{ Number = $selectedFile._PartNumber }
	if(-not $?) {
		$statusMessage_label.Content = $Error[0]
		$statusMessage_label.Foreground = "Red"
		$erpItemTab_control.IsEnabled = $false
		return $erpItemTab_control
	}
	
	if (-not $erpMaterial) {
		$statusMessage_label.Content = 'ERP: Create Material'

		$erpItemTab_CreateOrUpdateMaterialButton.Content = 'Create ERP Item'
		
		$erpItemTab_GoToMaterialButton.IsEnabled = $false

		$erpMaterial = NewErpMaterial
		$erpMaterial = PrepareErpMaterialForCreate -erpMaterial $erpMaterial -vaultEntity $selectedFile
	}
	else {
		$statusMessage_label.Content = 'ERP: View/Update Material'

		$erpItemTab_CreateOrUpdateMaterialButton.Content = 'Update ERP Item'

		$erpItemTab_control.FindName('ModifiedDateLabel').Visibility = 'Visible'
		$erpItemTab_control.FindName('ModifiedDateTextBox').Visibility = 'Visible'

		$erpItemTab_GoToMaterialButton.Add_Click({
			param($Sender)
	
			GoToErpMaterial -MaterialTabContext $erpMaterial
		})

		$unitOfMeasure_combobox.IsEnabled = $false
		$materialTypes_combobox.IsEnabled = $false
	}
	$erpItemTab_control.DataContext = $erpMaterial

	$erpItemTab_CreateOrUpdateMaterialButton.Add_Click({
		param($Sender)

		CreateOrUpdateErpMaterial -MaterialTabContext $erpMaterial
	})

	$erpItemTab_LinkMaterialButton = $erpItemTab_control.FindName('LinkMaterialButton')
	$erpItemTab_LinkMaterialButton.IsEnabled = (IsEntityUnlocked -Entity $selectedFile)
	$erpItemTab_LinkMaterialButton.Add_Click({
		param($Sender, $EventArgs)

		LinkErpMaterial -ErpItemTab $erpItemTab_control
	})

	$materialTypes_combobox.Add_SelectionChanged({
		param($Sender)

		ValidateErpMaterialTab -ErpItemTab $erpItemTab_control
	})

	$erpItemTab_Description = $erpItemTab_control.FindName('Description')
	$erpItemTab_Description.Add_TextChanged({
		param($Sender)

		ValidateErpMaterialTab -ErpItemTab $erpItemTab_control
	})

	ValidateErpMaterialTab -ErpItemTab $erpItemTab_control
	return $erpItemTab_control
}