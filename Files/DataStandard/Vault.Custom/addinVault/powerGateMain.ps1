$global:addinPath = $PSScriptRoot
Import-Module "C:\ProgramData\coolOrange\powerGate\Modules\Initialize.psm1" -Global
Initialize-CoolOrange
function OnTabContextChanged_powerGate($xamlFile) {
	Open-VaultConnection

	$erpServices = Get-ERPServices -Available
	if (-not $erpServices -or $erpServices.Count -le 0) {
		$dswindow.FindName("lblStatusMessage").Content = "One or more services are not available!"
		$dswindow.FindName("lblStatusMessage").Foreground = "Red"
		$dsWindow.IsEnabled = $false
		return
	}
	if ($xamlFile -eq "ERP Item.xaml") {
		InitMaterialTab
	}
	elseif ($xamlFile -eq "erpBom.xaml") {
		InitBomTab
	}
}

function GetSelectedObject {
	$entity = $null

	$selectedObject = $VaultContext.SelectedObject
	if (-not $selectedObject) {
		$selectedObject = $VaultContext.CurrentSelectionSet | Select-Object -First 1
	}
	if ($selectedObject.TypeId.SelectionContext -eq "FileMaster") {
		$entity = Get-VaultFile -FileId $selectedObject.Id
	}
	elseif ($selectedObject.TypeId.SelectionContext -eq "ItemMaster") {
		$entity = Get-VaultItem -ItemId $selectedObject.Id
	}
	return $entity
}

function InitBomTab {
	$entity = GetSelectedObject
	$number = GetEntityNumber -entity $entity
	$getErpBomHeaderResult = Get-ERPObject -EntitySet "BomHeaders" -Keys @{Number = $number } -Expand "BomRows"

	if(-not $getErpBomHeaderResult) {
		$goToEnabled = $false
	}
	else {
		$goToEnabled = $true
	}
	$dswindow.FindName("DataGrid").DataContext = $getErpBomHeaderResult
	$dswindow.FindName("GoToBomButton").IsEnabled = $goToEnabled
}

function InitMaterialTab {
	$entity = GetSelectedObject
	$number = GetEntityNumber -entity $entity

	$getErpMaterialResult = Get-ERPObject -EntitySet "Materials" -Keys @{ Number = $number }

	$materialTabContext = New-Object -Type PsObject -Property @{
		Entity = $getErpMaterialResult
		IsCreate = $false
	}

	if (-not $getErpMaterialResult) {
		$erpMaterial = NewErpMaterial
		$erpMaterial = PrepareErpMaterialForCreate -erpMaterial $erpMaterial -vaultEntity $entity
		$materialTabContext.IsCreate = $true
		$materialTabContext.Entity = $erpMaterial
		$goToEnabled = $false
	}
 	else {
		$goToEnabled = $true
	}
	$dswindow.FindName("Category").ItemsSource = GetCategoryList
	$dswindow.FindName("DataGrid").DataContext = $materialTabContext
	$dsWindow.FindName("LinkMaterialButton").IsEnabled = IsEntityUnlocked
	$dswindow.FindName("GoToMaterialButton").IsEnabled = $goToEnabled
}

function IsEntityUnlocked {
	$entity = GetSelectedObject
	if ($entity._EntityTypeID -eq "ITEM") {
		$item = $vault.ItemService.GetLatestItemByItemMasterId($entity.MasterId)
		$entityUnlocked = $item.Locked -ne $true
	}
 else {
		$entityUnlocked = $entity._VaultStatus.Status.LockState -ne "Locked" -and $entity.IsCheckedOut -ne $true
	}

	return $entityUnlocked
}

function ValidateErpMaterialTab {
	$materialTabContext = $dsWindow.FindName("DataGrid").DataContext
	$erpMaterial = $materialTabContext.Entity

	if ($erpMaterial.Number) {
		$entityUnlocked = $true
	}
 	else {
		$entityUnlocked = IsEntityUnlocked
	}

	#TODO: Setup obligatory fields that need to be filled out to activate the 'Create' button
	$enabled = $false
	if ($null -ne $erpMaterial.Type -and $erpMaterial.Type -ne "") {
		$type = $true
	}
	if ($null -ne $erpMaterial.Description -and $erpMaterial.Description -ne "") {
		$description = $true
	}
	$enabled = $entityUnlocked -and $type -and $description

	$dsWindow.FindName("CreateOrUpdateMaterialButton").IsEnabled = $enabled
}

function CreateOrUpdateErpMaterial {
	$dsDiag.Trace(">>CreateOrUpdateMaterial")

	$materialTabContext = $dswindow.FindName("DataGrid").DataContext

	if($materialTabContext.IsCreate) {
		$createErpMaterialResult = Add-ErpObject -EntitySet "Materials" -Properties $materialTabContext.Entity
		if ($? -eq $false) {
			return
		}

		ShowMessageBox -Message "$($createErpMaterialResult.Number) successfully created" -Title "powerGate ERP - Create Material" -Icon "Information" | Out-Null
		$vaultEntity = GetSelectedObject
		SetEntityProperties -erpMaterial $createErpMaterialResult -vaultEntity $vaultEntity

		RefreshView
	}
	else {
		$updateErpMaterialResult = Update-ERPObject -EntitySet "Materials" -Key $materialTabContext.Entity._Keys -Properties $materialTabContext.Entity._Properties
        if ($? -eq $false) {
            return
        }
		ShowMessageBox -Message "$($updateErpMaterialResult.Number) successfully updated" -Title "powerGate ERP - Update Material" -Icon "Information" | Out-Null
		InitMaterialTab
	}

	$dsDiag.Trace("<<CreateOrUpdateMaterial")
}

function GoToErpMaterial {
	$materialTabContext = $dswindow.FindName("DataGrid").DataContext
	$erpMaterial = $materialTabContext.Entity
	if ($erpMaterial.Link) {
		Start-Process -FilePath $erpMaterial.Link
	}
}

function LinkErpMaterial {
	$erpMaterial = OpenErpSearchWindow
	if (-not $erpMaterial) {
		return
	}

	$vaultEntity = GetSelectedObject
	if ($vaultEntity._EntityTypeID -eq "ITEM") {
		$existingEntity = Get-VaultItem -Number $erpMaterial.Number
		if ($existingEntity) {
			if ($existingEntity.MasterId -ne $vaultEntity.MasterId) {
				ShowMessageBox -Message "The ERP item $($erpMaterial.Number) cannot be assigned!`nAn item with an item number $($existingEntity._Number) already exists." -Button "Ok" -Icon "Warning" | Out-Null
				return
			}
		}
	}
 elseif ($vaultEntity._EntityTypeID -eq "FILE") {
		#TODO: Rename "Part Number" on a german system to "Teilenummer"
		$existingEntities = Get-VaultFiles -Properties @{"Part Number" = $erpMaterial.Number }
		if ($existingEntities) {
			$existingEntities = $existingEntities | Where-Object { $_.MasterId -ne $vaultEntity.MasterId }
			$message = ""
			if ($existingEntities) {
				$fileNames = $existingEntities._FullPath -join '`n'
				$message = "The ERP item $($erpMaterial.Number) is already assigned to `n$($fileNames).`n"
			}
		}
	}

	$answer = ShowMessageBox -Message ($message + "Do you really want to link the item '$($erpMaterial.Number)'?") -Title "powerGate ERP - Link Item" -Button "YesNo" -Icon "Question"
	if ($answer -eq "Yes") {
		SetEntityProperties -erpMaterial $erpMaterial -vaultEntity $vaultEntity
		RefreshView
	}
}

function RefreshView {
	$entity = GetSelectedObject
	if ($null -eq $entity) {
		return
	}

	if ($entity._EntityTypeID -eq "FILE") {
		$file = $vault.DocumentService.GetLatestFileByMasterId($entity.MasterId)
		$folder = $vault.DocumentService.GetFolderById($file.FolderId)
		$cFolder = New-Object Connectivity.Services.Document.Folder($folder)
		$cDocFolder = New-Object Connectivity.Explorer.Document.DocFolder($cFolder)
		$cFile = New-Object Connectivity.Services.Document.File($file)
		$cFileExplorerObject = New-Object Connectivity.Explorer.Document.FileExplorerObject($cFile)

		$vwCtx = New-Object Connectivity.Explorer.Framework.LocationContext($cFileExplorerObject, $cDocFolder)
		$navCtx = New-Object Connectivity.Explorer.Framework.LocationContext($cDocFolder)
	}
 elseif ($entity._EntityTypeID -eq "ITEM") {
		$item = $vault.ItemService.GetLatestItemByItemMasterId($entity.MasterId)
		$cItemRev = New-Object Connectivity.Services.Item.ItemRevision($vaultConnection, $item)
		$cItemRevExpObj = New-Object Connectivity.Explorer.Item.ItemRevisionExplorerObject($cItemRev)
		$cItemMaster = New-Object Connectivity.Explorer.Item.ItemMaster

		$vwCtx = New-Object Connectivity.Explorer.Framework.LocationContext($cItemRevExpObj)
		$navCtx = New-Object Connectivity.Explorer.Framework.LocationContext($cItemMaster)
	}
 else {
		return
	}

	[System.Windows.Forms.SendKeys]::SendWait("{F5}")

	$sc = New-Object Connectivity.Explorer.Framework.ShortcutMgr+Shortcut
	$sc.NavigationContext = $navCtx
	$sc.ViewContext = $vwCtx
	$sc.Select($null)
}

function SetEntityProperties($erpMaterial, $vaultEntity) {
	#TODO: Update Entity UDPs with values from ERP
	if ($vaultEntity._EntityTypeID -eq "ITEM") {
		try {
			Update-VaultItemWithErrorHandling -Number $vaultEntity._Number -Properties @{
				#the item description cannot be updated, since "Description (Item,CO)" is a system property!
				"_Description(Item,CO)" = $erpMaterial.Description
				"_Number" = $erpMaterial.Number
			}
		}catch {
			ShowMessageBox -Message $_.Exception.Message -Title "powerGate ERP - Link ERP Item" -Button "OK" -Icon "Error"
		}
	}
 elseif ($vaultEntity._EntityTypeID -eq "FILE") {
	try {
		Update-VaultFileWithErrorHandling -File $vaultEntity._FullPath -Properties @{
			"_PartNumber"  = $erpMaterial.Number
			"_Description" = $erpMaterial.Description
		}
		} catch {
			ShowMessageBox -Message $_.Exception.Message -Title "powerGate ERP - Link ERP Item" -Button "OK" -Icon "Error"
		}
	}
}

function PrepareErpMaterial($erpMaterial, $vaultEntity) {
	$number = GetEntityNumber -entity $vaultEntity

	if ($vaultEntity._EntityTypeID -eq "ITEM") { $descriptionProp = '_Description(Item,CO)' }
	else { $descriptionProp = '_Description' }

	#TODO: Property mapping for material creation
	$erpMaterial.Number = $number
	$erpMaterial.Description = $vaultEntity.$descriptionProp

	return $erpMaterial
}

function CompareErpMaterial($erpMaterial, $vaultEntity) {
	$number = GetEntityNumber -entity $vaultEntity

	if ($vaultEntity._EntityTypeID -eq "ITEM") { $descriptionProp = '_Description(Item,CO)' }
	else { $descriptionProp = '_Description' }

	$differences = @()

	#TODO: Property mapping for material comparison
	if ($erpMaterial.Number -or $number) {
		if ($erpMaterial.Number -ne $number) {
			$differences += "Number - ERP: $($erpMaterial.Number) <> Vault: $number"
		}
	}

	if ($erpMaterial.Description -or $vaultEntity.$descriptionProp) {
		if ($erpMaterial.Description -ne $vaultEntity.$descriptionProp) {
			$differences += "Description - ERP: $($erpMaterial.Description) <> Vault: $($vaultEntity.$descriptionProp)"
		}
	}

	return $differences -join '`n'
}

function GoToErpBom {
	$bom = $dswindow.FindName("DataGrid").DataContext
	if ($bom.Link) {
		Start-Process -FilePath $bom.Link
	}
}