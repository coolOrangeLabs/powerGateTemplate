function OnTabContextChanged {
	$global:ErrorActionPreference = "Stop"
	$xamlFile = [System.IO.Path]::GetFileName($VaultContext.UserControl.XamlFile)
	OnTabContextChanged_powerGate -xamlFile $xamlFile	
	if ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "FileMaster" -and $xamlFile -eq "CAD BOM.xaml") {
		$fileMasterId = $vaultContext.SelectedObject.Id
		$file = $vault.DocumentService.GetLatestFileByMasterId($fileMasterId)
		$bom = @(GetFileBOM($file.id))
		$dsWindow.FindName("bomList").ItemsSource = $bom
	}
	if ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "ItemMaster" -and $xamlFile -eq "Associated Files.xaml") {
		$items = $vault.ItemService.GetItemsByIds(@($vaultContext.SelectedObject.Id))
		$item = $items[0]
		$itemids = @($item.Id)
		$assocFiles = @(GetAssociatedFiles $itemids $([System.IO.Path]::GetDirectoryName($VaultContext.UserControl.XamlFile)))
		$dsWindow.FindName("AssoicatedFiles").ItemsSource = $assocFiles
	}
}

function OnLogOn {
	#Executed when User logs on Vault
	#$vaultUsername can be used to get the username, which is used in Vault on login

	Import-Module "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1" -Global
	Initialize-CoolOrange

	$logPath = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\VDS_Vault-powerGate.log"
	Set-LogFilePath -Path $logPath
}
function OnLogOff {
	#Executed when User logs off Vault
	Remove-CoolOrangeLogging
}