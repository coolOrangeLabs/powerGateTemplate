$materialEntitySet = "Materials"
$materialEntityType = "Material"

function GetEntityNumber($entity) {
	if ($entity._EntityTypeID -eq "FILE") {
		$number = $entity._PartNumber
	}
	else {
		$number = $entity._Number
	}
	return $number
}

function GetErpMaterial($number) {
	Log -Begin
	if (-not $number) { 
		$erpMaterial = $false
		Add-Member -InputObject $erpMaterial -Name "_ErrorMessage" -Value "Number is empty!" -MemberType NoteProperty -Force
		return $erpMaterial
	}
	$number = $number.ToUpper()
	$erpMaterial = Get-ERPObject -EntitySet $materialEntitySet -Key @{ Number = $number }
	$erpMaterial = CheckResponse -entity $erpMaterial
	
	Add-Member -InputObject $erpMaterial -Name "IsCreate" -Value $false -MemberType NoteProperty -Force
	Add-Member -InputObject $erpMaterial -Name "IsUpdate" -Value $true -MemberType NoteProperty -Force	
	Log -End
	return $erpMaterial
}

function NewErpMaterial {
	Log -Begin
	$erpMaterial = New-ERPObject -EntityType $materialEntityType

	#TODO: Property default values for material creation
	$erpMaterial.UnitOfMeasure = "PCS"
	$erpMaterial.Type = "Service"

	Add-Member -InputObject $erpMaterial -Name "IsCreate" -Value $true -MemberType NoteProperty -Force
	Add-Member -InputObject $erpMaterial -Name "IsUpdate" -Value $false -MemberType NoteProperty -Force
	Log -End
	return $erpMaterial
}

function CreateErpMaterial($erpMaterial) {
	Log -Begin
	#TODO: Numbering generation for material creation (only if needed)
	if ($null -eq $erpMaterial.Number -or $erpMaterial.Number -eq "") {
		$erpMaterial.Number = "*"
	}
	#TODO: Properties that need to be set on create
	$erpMaterial.ModifiedDate = [DateTime]::Now

	$erpMaterial.PSObject.Properties.Remove('IsCreate')
	$erpMaterial.PSObject.Properties.Remove('IsUpdate')

	$erpMaterial = TransformErpMaterial -erpMaterial $erpMaterial
	$erpMaterial = Add-ErpObject -EntitySet $materialEntitySet -Properties $erpMaterial
	$erpMaterial = CheckResponse -entity $erpMaterial
	Log -End
	return $erpMaterial
}

function UpdateErpMaterial($erpMaterial) {
	Log -Begin
	#TODO: Properties that need to be set on update
	$erpMaterial.ModifiedDate = [DateTime]::Now

	$erpMaterial = TransformErpMaterial -erpMaterial $erpMaterial
	$erpMaterial = Update-ERPObject -EntitySet $materialEntitySet -Key $erpMaterial._Keys -Properties $erpMaterial._Properties
	$erpMaterial = CheckResponse -entity $erpMaterial
	Log -End
	return $erpMaterial
}

function TransformErpMaterial($erpMaterial) {
	Log -Begin
	#TODO: Property transformations on create and update
	$erpMaterial.Number = $erpMaterial.Number.ToUpper()
	Log -End
	return $erpMaterial
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