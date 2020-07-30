$global:ErrorActionPreference = "Stop"
$global:addinPath = $PSScriptRoot
$commonModulePath = "C:\ProgramData\coolOrange\powerGate\Modules"
$modules = Get-ChildItem -path $commonModulePath -Recurse -Filter *.ps* 
$modules | ForEach-Object { Import-Module -Name $_.FullName -Global }
$global:loggingSettings.LogFile = Join-Path $env:LOCALAPPDATA "coolOrange\Projects\VDS_Vault-powerGate.txt"

ConnectToErpServerWithMessageBox

function OnTabContextChanged_powerGate($xamlFile) {
	if ($xamlFile -eq "erpItem.xaml") {
		InitMaterialTab
	}
	elseif ($xamlFile -eq "erpBom.xaml") {
		InitBomTab
	}
}

function GetSelectedObject {
	$entity = $null

	$selectedObject = $VaultContext.SelectedObject
	if(-not $selectedObject) {
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
	$bom = GetErpBomHeader -number $number
	if (-not $bom -or $false -eq $bom) {
		$goToEnabled = $false
	} else {
		$goToEnabled = $true
	}
	$dswindow.FindName("DataGrid").DataContext = $bom
	$dswindow.FindName("GoToBomButton").IsEnabled = $goToEnabled
}

function InitMaterialTab {
	$entity = GetSelectedObject
	$number = GetEntityNumber -entity $entity
	$erpMaterial = GetErpMaterial -number $number
	if (-not $erpMaterial -or $false -eq $erpMaterial) {
		$erpMaterial = NewErpMaterial
		$erpMaterial = PrepareErpMaterial -erpMaterial $erpMaterial -vaultEntity $entity
		$goToEnabled = $false
	} else {
		$goToEnabled = $true
	}
	$dswindow.FindName("DataGrid").DataContext = $erpMaterial
	$dsWindow.FindName("LinkMaterialButton").IsEnabled = IsEntityUnlocked
	$dswindow.FindName("GoToMaterialButton").IsEnabled = $goToEnabled
}

function IsEntityUnlocked {
	$entity = GetSelectedObject
	if ($entity._EntityTypeID -eq "ITEM") { 
		$item = $vault.ItemService.GetLatestItemByItemMasterId($entity.MasterId)
		$entityUnlocked = $item.Locked -ne $true
	} else {
		$entityUnlocked = $entity._VaultStatus.Status.LockState -ne "Locked" -and $entity.IsCheckedOut -ne $true
	}

	return $entityUnlocked
}

function ValidateErpMaterialTab {
	$erpMaterial = $dsWindow.FindName("DataGrid").DataContext
	if ($erpMaterial.Number) {
		$entityUnlocked = $true
	} else {
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
	$erpMaterial = $dswindow.FindName("DataGrid").DataContext
	if ($erpMaterial.IsUpdate) {
		$erpMaterial = UpdateErpMaterial -erpMaterial $erpMaterial
		if (-not $erpMaterial -or $false -eq $erpMaterial) { 	
			ShowMessageBox -Message $erpMaterial._ErrorMessage -Icon "Error" -Title "powerGate ERP - Update Material" | Out-Null
		} else { 
			ShowMessageBox -Message "$($erpMaterial.Number) successfully updated" -Title "powerGate ERP - Update Material" -Icon "Information"  | Out-Null
		}
		InitMaterialTab
	} else {
		$erpMaterial = CreateErpMaterial -erpMaterial $erpMaterial
		if (-not $erpMaterial -or $false -eq $erpMaterial) { 	
			ShowMessageBox -Message $erpMaterial._ErrorMessage -Icon "Error" -Title "powerGate ERP - Create Material" | Out-Null
		} else { 
			ShowMessageBox -Message "$($erpMaterial.Number) successfully created" -Title "powerGate ERP - Create Material" -Icon "Information"  | Out-Null
			$vaultEntity = GetSelectedObject
			SetEntityProperties -erpMaterial $erpMaterial -vaultEntity $vaultEntity
		}

		RefreshView
	}
	$dsDiag.Trace("<<CreateOrUpdateMaterial")
}

function GoToErpMaterial {
	$erpMaterial = $dswindow.FindName("DataGrid").DataContext
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
	} elseif ($vaultEntity._EntityTypeID -eq "FILE") { 
		#TODO: Rename "Part Number" on a german system to "Teilenummer"
		$existingEntities = Get-VaultFiles -Properties @{"Part Number" = $erpMaterial.Number}
		if ($existingEntities) {
			$existingEntities = $existingEntities | Where-Object { $_.MasterId -ne $vaultEntity.MasterId }
			$message = ""
			if ($existingEntities) {
				$fileNames = $existingEntities._FullPath -join '\n'
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
	} elseif ($entity._EntityTypeID -eq "ITEM") {
		$item = $vault.ItemService.GetLatestItemByItemMasterId($entity.MasterId)
		$cItemRev = New-Object Connectivity.Services.Item.ItemRevision($vaultConnection, $item)
		$cItemRevExpObj = New-Object Connectivity.Explorer.Item.ItemRevisionExplorerObject($cItemRev)
		$cItemMaster = New-Object Connectivity.Explorer.Item.ItemMaster

		$vwCtx = New-Object Connectivity.Explorer.Framework.LocationContext($cItemRevExpObj)
		$navCtx = New-Object Connectivity.Explorer.Framework.LocationContext($cItemMaster)
	} else {
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
		$vaultEntity = Update-VaultItem -Number $vaultEntity._Number -NewNumber $erpMaterial.Number
		Update-VaultItem -Number $vaultEntity._Number -Properties @{
			#the item description cannot be updated, since "Description (Item,CO)" is a system property!
			"_Description(Item,CO)" = $erpMaterial.Description
		}
		$vaultEntity._Number = $erpMaterial.Number
	} elseif ($vaultEntity._EntityTypeID -eq "FILE") { 
		Update-VaultFile -File $vaultEntity._FullPath -Properties @{
			"_PartNumber" = $erpMaterial.Number
			"_Description" = $erpMaterial.Description
		}
		$vaultEntity._PartNumber = $erpMaterial.Number
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

	return $differences -join '\n'
}

function PrepareErpBomHeader($erpBomHeader, $vaultEntity) {
	$number = GetEntityNumber -entity $vaultEntity

	if ($vaultEntity._EntityTypeID -eq "ITEM") { $descriptionProp = '_Description(Item,CO)' }
	else { $descriptionProp = '_Description' }
	
	#TODO: Property mapping and assignment for bom header creation
	$erpBomHeader.Number = $number
	$erpBomHeader.Description = $vaultEntity.$descriptionProp   
	$erpBomHeader.State = "New"

	return $erpBomHeader
}

function PrepareErpBomRow($erpBomRow, $parentNumber, $vaultEntity) {
	$number = GetEntityNumber -entity $vaultEntity

	#TODO: Property mapping for bom row creation
	$erpBomRow.ParentNumber = $parentNumber
	$erpBomRow.ChildNumber = $number
	$erpBomRow.Position = [int]$vaultEntity.'Bom_PositionNumber'
	if ($vaultEntity.Children) {
		$erpBomRow.Type = "Assembly"
	} else {
		$erpBomRow.Type = "Part"
	}
	$erpBomRow.Quantity = [double]$vaultEntity.'Bom_Quantity'

	return $erpBomRow
}

function GoToErpBom {
	$bom = $dswindow.FindName("DataGrid").DataContext
	if ($bom.Link) {
		Start-Process -FilePath $bom.Link
	}
}