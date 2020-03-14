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

function SetEntityNumber($number) {
	if ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "FileMaster") {
		$file = Get-VaultFile -FileId $vaultContext.SelectedObject.Id
		Update-VaultFile -File $file._FullPath -Properties @{"_PartNumber" = $number }
	}
	elseif ($VaultContext.SelectedObject.TypeId.SelectionContext -eq "ItemMaster") {
		$item = Get-VaultItem -ItemId $vaultContext.SelectedObject.Id
		Update-VaultItem -Number $item._Number -NewNumber $number
	}
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
	$material = $dswindow.FindName("DataGrid").DataContext
	if ($material.IsUpdate) {
		$material = UpdateErpMaterial -erpMaterial $material
		if ($material) { 
			Show-MessageBox -message "Update successful" -icon "Information"
		} else { 
			Show-MessageBox -message $material._ErrorMessage -icon "Error" -title "ERP material update error"
		}
		InitMaterialTab
	} else {
		$material = CreateErpMaterial -erpMaterial $material
		SetEntityNumber -number $material.Number
		[System.Windows.Forms.SendKeys]::SendWait("{F5}")
	}
	$dsDiag.Trace("<<CreateOrUpdateMaterial")
}


function PrepareErpMaterial($erpMaterial, $vaultEntity) {
	$number = GetEntityNumber -entity $vaultEntity
	
	if ($vaultEntity._EntityTypeID -eq "FILE") { $titleProp = '_Title' }
	else { $titleProp = '_Title(Item,CO)' }

	#TODO: Property mapping for material creation
	$erpMaterial.Number = $number
	$erpMaterial.Description = $vaultEntity.$titleProp

	return $erpMaterial
}

function CompareErpMaterial($erpMaterial, $vaultEntity) {	
	$number = GetEntityNumber -entity $vaultEntity

	if ($vaultEntity._EntityTypeID -eq "FILE") { $titleProp = '_Title' }
	else { $titleProp = '_Title(Item,CO)' }
	
	$differences = @()
	
	#TODO: Property mapping for material comparison
	if ($erpMaterial.Number -ne $number) {
		$differences += "ERP: $($erpMaterial.Number) <> Vault: $number"
	}
	if ($erpMaterial.Description -ne $vaultEntity.$titleProp) {
		$differences += "ERP: $($erpMaterial.Description) <> Vault: $($vaultEntity.$titleProp)"
	}

	return $differences -join '\n'
}

function PrepareErpBomHeader($erpBomHeader, $vaultEntity) {
	$number = GetEntityNumber -entity $vaultEntity
	
	#TODO: Property mapping for bom header creation
	$erpBomHeader.Number = $number
	$erpBomHeader.Description = $vaultEntity._Description   
	
	#TODO: Property default values for bom header creation
	$erpBomHeader.Status = "Released"

	return $erpBomHeader
}

function PrepareErpBomRow($erpBomRow, $parentNumber, $vaultEntity) {
	$number = GetEntityNumber -entity $vaultEntity
	
	#TODO: Property mapping for bom row creation
	$erpBomRow.ParentNumber = $parentNumber
	$erpBomRow.ChildNumber = $number
	$erpBomRow.Position = $vaultEntity.Bom_PositionNumber
	$erpBomRow.Quantity = $vaultEntity.Bom_Quantity

	return $erpBomRow
}

function LinkErpMaterial {
	$erpMaterial = OpenErpSearchWindow
    if ($erpMaterial) {
        $number = $erpMaterial.Number
        $answer = [System.Windows.Forms.MessageBox]::Show("Do you really want to link the item '$number'?", "Link ERP Item", "YesNo", "Question")	
        if ($answer -eq "Yes") {
            SetEntityNumber -number $number
            [System.Windows.Forms.SendKeys]::SendWait("{F5}")
            #[System.Windows.Forms.MessageBox]::Show("The object has been linked")
        }       
    }
}