$bomHeaderEntitySet = "BomHeaders"
$bomHeaderEntityType = "BomHeader"

$bomRowEntitySet = "BomRows"
$bomRowEntityType = "BomRow"

#TODO: Raw material handling
# The properties 'Raw Quantity' and 'Raw Number' must be setup in Vault to enable this feature
$rawMaterialNumberProperty = "Raw Number"
$rawMaterialQuantityProperty = "Raw Quantity"

#region BOM Header

function NewErpBomHeader {
    Log -Begin
    $erpBomHeader = New-ErpObject -EntityType $bomHeaderEntityType
    Log -End
    return $erpBomHeader
}

function PrepareBomHeaderForCreate($erpBomHeader, $vaultEntity) {
    Log -Begin
    $number = GetEntityNumber -entity $vaultEntity

	if ($vaultEntity._EntityTypeID -eq "ITEM") { $descriptionProp = '_Description(Item,CO)' }
	else { $descriptionProp = '_Description' }
	
	#TODO: Property mapping and assignment for bom header creation
	$erpBomHeader.Number = $number
	$erpBomHeader.Description = $vaultEntity.$descriptionProp   
	$erpBomHeader.State = "New"

    Log -End
    return $erpBomHeader
}

function PrepareBomHeaderForUpdate($erpBomHeader) {
    Log -Begin
    $number = GetEntityNumber -entity $vaultEntity

	if ($vaultEntity._EntityTypeID -eq "ITEM") { $descriptionProp = '_Description(Item,CO)' }
	else { $descriptionProp = '_Description' }

    #TODO: Property manipulation for bom header update
    $erpBomHeader.ModifiedDate = [DateTime]::Now

    Log -End
    return $erpBomHeader
}
#endregion

#region BOM Row

function NewErpBomRow {
    Log -Begin
    $erpBomRow = New-ErpObject -EntityType $bomRowEntityType
    Log -End
    return $erpBomRow
}

function PrepareBomRowForCreate($ErpBomRow, $parentNumber, $VaultEntity) {
    Log -Begin

    $number = GetEntityNumber -entity $vaultEntity

	#TODO: Property mapping for bom row creation
	$erpBomRow.ParentNumber = $parentNumber
	$erpBomRow.ChildNumber = $number
	$erpBomRow.Position = [int]$vaultEntity.'Bom_PositionNumber'
	if ($vaultEntity.Children) {
		$erpBomRow.Type = "Assembly"
	}
	else {
		$erpBomRow.Type = "Part"
	}
	$erpBomRow.Quantity = [double]$vaultEntity.'Bom_Quantity'


    Log -End
    return $result
}

function PrepareBomRowForUpdate($erpBomRow, $parentNumber, $vaultEntity) {
    Log -Begin
    #TODO: Property manipulation for bom row update
    $ErpBomRow.ModifiedDate = [DateTime]::Now

	$updateProperties = @{
		Quantity = [double]$VaultEntity.Bom_Quantity
	}

    Log -End
    return $updateProperties
}
#endregion

#region Common Bom comparison logic
function GetVaultBomRows {
    param($entity)

    if ($null -eq $entity._EntityTypeID) { return @() }
    if ($entity._EntityTypeID -eq "File") {
        if ($entity._Extension -eq 'ipt') { 
            if ($entity.$rawMaterialQuantityProperty -gt 0 -and $entity.$rawMaterialNumberProperty -ne "") {
                # Raw Material
                $rawMaterial = New-Object PsObject -Property @{
                    'Part Number'        = $entity.$rawMaterialNumberProperty
                    '_PartNumber'        = $entity.$rawMaterialNumberProperty
                    'Name'               = $entity.$rawMaterialNumberProperty
                    '_Name'              = $entity.$rawMaterialNumberProperty
                    'Number'             = $entity.$rawMaterialNumberProperty
                    '_Number'            = $entity.$rawMaterialNumberProperty
                    'Bom_Number'         = $entity.$rawMaterialNumberProperty
                    'Bom_Quantity'       = $entity.$rawMaterialQuantityProperty
                    'Bom_Position'       = '1'
                    'Bom_PositionNumber' = '1'
                }
                return @($rawMaterial)
            }
            return @()
        }
        #if($entity._FullPath -eq $null) { return @() } #due to a bug in the beta version.
        $bomRows = Get-VaultFileBom -File $entity._FullPath -GetChildrenBy LatestVersion
    }
    else {
        #if ($entity._Category -eq 'Part') { return @() }
        $bomRows = Get-VaultItemBom -Number $entity._Number
    }
    
    foreach ($vaultBomRow in $bomRows) {
        if ($vaultBomRow.Bom_XrefTyp -eq "Internal") {
            # Virtual Component
            Add-Member -InputObject $vaultBomRow -Name "_Name" -Value $vaultBomRow.'Bom_Part Number' -MemberType NoteProperty -Force
            Add-Member -InputObject $vaultBomRow -Name "Part Number" -Value $vaultBomRow.'Bom_Part Number' -MemberType NoteProperty -Force
            Add-Member -InputObject $vaultBomRow -Name "_PartNumber" -Value $vaultBomRow.'Bom_Part Number' -MemberType NoteProperty -Force
            Add-Member -InputObject $vaultBomRow -Name "_Number" -Value $vaultBomRow.'Bom_Part Number' -MemberType NoteProperty -Force
            Add-Member -InputObject $vaultBomRow -Name "Number" -Value $vaultBomRow.'Bom_Part Number' -MemberType NoteProperty -Force
        }
    }
    return $bomRows
}

#endregion