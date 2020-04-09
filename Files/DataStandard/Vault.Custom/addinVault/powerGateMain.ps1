$global:ErrorActionPreference = "Stop"
$global:addinPath = $PSScriptRoot
$commonModulePath = "C:\ProgramData\coolOrange\powerGate\Modules"
$modules = Get-ChildItem -path $commonModulePath -Filter *.psm1
$modules | ForEach-Object { Import-Module -Name $_.FullName -Global }

ConnectToErpServer

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
	if ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "FileMaster") {
		$entity = Get-VaultFile -FileId $vaultContext.SelectedObject.Id
	}
	elseif ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "ItemMaster") {
		$entity = Get-VaultItem -ItemId $vaultContext.SelectedObject.Id
	}
	return $entity
}

function GetEntityNumber($entity) {
	if ($entity._EntityTypeID -eq "FILE") {
		$number = $entity._PartNumber
	}
	else {
		$number = $entity._Number
	}
	return $number
}

function RefreshView {
	$entity = GetSelectedObject
	if ($null -eq $entity) {
		return
	}

	[System.Windows.Forms.SendKeys]::SendWait("{F5}")

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

	$sc = New-Object Connectivity.Explorer.Framework.ShortcutMgr+Shortcut
	$sc.NavigationContext = $navCtx
	$sc.ViewContext = $vwCtx
	$sc.Select($null)    
}

function InitBomTab {
	$entity = GetSelectedObject
	$number = GetEntityNumber -entity $entity
	$bom = GetErpBomHeader -number $number
	$dswindow.FindName("DataGrid").DataContext = $bom
}

function InitMaterialTab {
	$entity = GetSelectedObject
	$number = GetEntityNumber -entity $entity
	$erpMaterial = GetErpMaterial -number $number
	if (-not $erpMaterial) {
		$erpMaterial = NewErpMaterial
		$erpMaterial = PrepareErpMaterial -erpMaterial $erpMaterial -vaultEntity $entity
	}
	$dswindow.FindName("DataGrid").DataContext = $erpMaterial
}

function ValidateErpMaterialTab {
	$material = $dsWindow.FindName("DataGrid").DataContext
	#TODO: Setup obligatory fields that need to be filled out to activate the 'Create' button
	$enabled = $false
	if ($null -ne $material.Type -and $material.Type -ne "") {
		$type = $true
	}
	if ($null -ne $material.Description -and $material.Description -ne "") {
		$description = $true
	}
	$enabled = $type -and $description
	$dsWindow.FindName("CreateOrUpdateMaterialButton").IsEnabled = $enabled
}

function CreateOrUpdateErpMaterial {
	$dsDiag.Trace(">>CreateOrUpdateMaterial")
	$erpMaterial = $dswindow.FindName("DataGrid").DataContext
	if ($erpMaterial.IsUpdate) {
		$erpMaterial = UpdateErpMaterial -erpMaterial $erpMaterial
		if ($erpMaterial) { 
			Show-MessageBox -message "Update successful" -icon "Information"
		} else { 
			Show-MessageBox -message $erpMaterial._ErrorMessage -icon "Error" -title "ERP material update error"
		}
		InitMaterialTab
	} else {
		$erpMaterial = CreateErpMaterial -erpMaterial $erpMaterial
		$vaultEntity = GetSelectedObject
		SetEntityProperties -erpMaterial $erpMaterial -vaultEntity $vaultEntity
		RefreshView
	}
	$dsDiag.Trace("<<CreateOrUpdateMaterial")
}

function LinkErpMaterial {
	$erpMaterial = OpenErpSearchWindow

	$vaultEntity = GetSelectedObject
	if ($vaultEntity._EntityTypeID -eq "ITEM") { 
		$searchProperty = "Number"
	} elseif ($vaultEntity._EntityTypeID -eq "FILE") { 
		#TODO: Rename "Part Number" on a german system to "Teilenummer"
		$searchProperty = "Part Number"
	}
	$entitesWithSameErpMaterial = Search-EntitiesByPropertyValue -EntityClassId $vaultEntity._EntityTypeID -PropertyName $searchProperty -SearchValue $ErpMaterial.Number -SearchCondition "IsExactly"
	if($entitesWithSameErpMaterial) {
		$entityType = $entitesWithSameErpMaterial[0]._EntityTypeID
		$filePaths = $entitesWithSameErpMaterial._FullPath
		$itemNumbers = $entitesWithSameErpMaterial.Number
		([System.Windows.Forms.MessageBox]::Show("The ERP item '$($erpMaterial.Number)' is already linked to other $($entityType)s: `n $($filePaths+$itemNumbers)", "ERP Item is already used in Vault", "Ok", "Warning")	) | Out-Null
		return;
	}

    if ($erpMaterial) {
        $answer = [System.Windows.Forms.MessageBox]::Show("Do you really want to link the item '$($erpMaterial.Number)'?", "Link ERP Item", "YesNo", "Question")	
        if ($answer -eq "Yes") {
            SetEntityProperties -erpMaterial $erpMaterial -vaultEntity $vaultEntity
			RefreshView
            #[System.Windows.Forms.MessageBox]::Show("The object has been linked")
        }       
    }
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
	$erpMaterial.Type = "CONSTRUCTION"

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