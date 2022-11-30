#region Debugging
if((Get-Process -Id $PID).ProcessName -in @('powershell','powershell_ise') -and $host.Name.StartsWith('powerEvents') -eq $false){
	Import-Module powerEvents
	
	Open-VaultConnection -Server $env:Computername -Vault Vault -User Administrator -Password ""
	$selectedItem = Get-VaultItem -Number 'co-00000'
	
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
		$debugERPTab_window.AddChild($action.InvokeReturnAsIs($selectedItem))
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

function CanCreateOrUpdateErpMaterial {
	param(
		$erpMaterial
	)

	#TODO: Setup obligatory fields that need to be filled out to activate the 'Create' button
	if ($null -ne $erpMaterial.Type -and $erpMaterial.Type -ne "") {
		$type = $true
	}
	if ($null -ne $erpMaterial.Description -and $erpMaterial.Description -ne "") {
		$description = $true
	}
	return $type -and $description
}

Add-VaultTab -Name 'ERP Item' -EntityType 'Item' -Action {
	param($selectedItem)
	$erpItemTab_control = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new([xml](Get-Content "$PSScriptRoot\TransferERPItemTab.xaml")))
	
	$statusMessage_label = $erpItemTab_control.FindName("lblStatusMessage")
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

	$Script:erpItemTab_CreateOrUpdateMaterialButton = $erpItemTab_control.FindName('CreateOrUpdateMaterialButton')
	$erpItemTab_GoToMaterialButton = $erpItemTab_control.FindName('GoToMaterialButton')

	$erpMaterial = Get-ERPObject -EntitySet "Materials" -Keys @{ Number = $selectedItem._Number  }
	if(-not $?) {
		$statusMessage_label.Content = $Error[0]
		$statusMessage_label.Foreground = "Red"
		$erpItemTab_control.IsEnabled = $false
		return $erpItemTab_control
	}
	
	if (-not $erpMaterial) {
		$statusMessage_label.Content = 'ERP: Create Material'

		$erpMaterial = NewErpMaterial
		$erpMaterial = PrepareErpMaterialForCreate -erpMaterial $erpMaterial -vaultEntity $selectedItem

		$erpItemTab_CreateOrUpdateMaterialButton.Content = 'Create ERP Item'
		$erpItemTab_CreateOrUpdateMaterialButton.Add_Click({
			param($Sender)
	
			$createdErpMaterial = Add-ErpObject -EntitySet "Materials" -Properties $erpMaterial
			if ($? -eq $false) {
				return
			}
	
			$null = ShowMessageBox -Message "$($createdErpMaterial.Number) successfully created" -Title "powerGate ERP - Create Material" -Icon "Information"
			SetEntityProperties -erpMaterial $createdErpMaterial -vaultEntity $selectedItem
	
			[System.Windows.Forms.SendKeys]::SendWait("{F5}")
		})

		$erpItemTab_GoToMaterialButton.IsEnabled = $false
	}
	else {
		$statusMessage_label.Content = 'ERP: View/Update Material'

		$erpItemTab_CreateOrUpdateMaterialButton.Content = 'Update ERP Item'
		$erpItemTab_CreateOrUpdateMaterialButton.Add_Click({
			param($Sender)
	
			$updatedErpMaterial = Update-ERPObject -EntitySet "Materials" -Key $erpMaterial._Keys -Properties $erpMaterial._Properties
			if ($? -eq $false) {
				return
			}
			$null = ShowMessageBox -Message "$($updatedErpMaterial.Number) successfully updated" -Title "powerGate ERP - Update Material" -Icon "Information"
		})

		$erpItemTab_control.FindName('ModifiedDateLabel').Visibility = 'Visible'
		$erpItemTab_control.FindName('ModifiedDateTextBox').Visibility = 'Visible'

		$erpItemTab_GoToMaterialButton.Add_Click({
			param($Sender)
	
			if ($erpMaterial.Link) {
				Start-Process -FilePath $erpMaterial.Link
			}
		})

		$unitOfMeasure_combobox.IsEnabled = $false
		$materialTypes_combobox.IsEnabled = $false
	}
	$erpItemTab_control.DataContext = $erpMaterial

	$item = $vault.ItemService.GetLatestItemByItemMasterId($selectedItem.MasterId)
	$entityUnlocked =$item.Locked -ne $true

	$erpItemTab_LinkMaterialButton = $erpItemTab_control.FindName('LinkMaterialButton')
	$erpItemTab_LinkMaterialButton.IsEnabled = $item.Locked -ne $true
	$erpItemTab_LinkMaterialButton.Add_Click({
		param($Sender, $EventArgs)

		$foundErpMaterial = OpenErpSearchWindow
		if (-not $foundErpMaterial) {
			return
		}
		$existingEntity = Get-VaultItem -Number $foundErpMaterial.Number
		if ($existingEntity) {
			if ($existingEntity.MasterId -ne $selectedItem.MasterId) {
				$null = ShowMessageBox -Message "The ERP item $($foundErpMaterial.Number) cannot be assigned!`nAn item with an item number $($selectedItem._Number) already exists." -Button "Ok" -Icon "Warning"
				return
			}
		}
		
		$answer = ShowMessageBox -Message ($message + "Do you really want to link the item '$($foundErpMaterial.Number)'?") -Title "powerGate ERP - Link Item" -Button "YesNo" -Icon "Question"
		if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
			SetEntityProperties -erpMaterial $foundErpMaterial -vaultEntity $selectedItem
			[System.Windows.Forms.SendKeys]::SendWait("{F5}")
		}
	})

	$materialTypes_combobox.Add_SelectionChanged({
		param($Sender)

		$erpItemTab_CreateOrUpdateMaterialButton.IsEnabled = $entityUnlocked -and (CanCreateOrUpdateErpMaterial $erpMaterial)
	})

	$erpItemTab_Description = $erpItemTab_control.FindName('Description')
	$erpItemTab_Description.Add_TextChanged({
		param($Sender)

		$erpItemTab_CreateOrUpdateMaterialButton.IsEnabled = $entityUnlocked -and (CanCreateOrUpdateErpMaterial $erpMaterial)
	})

	$erpItemTab_CreateOrUpdateMaterialButton.IsEnabled = $entityUnlocked -and (CanCreateOrUpdateErpMaterial $erpMaterial)
	return $erpItemTab_control
}