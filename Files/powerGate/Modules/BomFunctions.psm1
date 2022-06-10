$bomHeaderEntitySet = "BomHeaders"
$bomHeaderEntityType = "BomHeader"

$bomRowEntitySet = "BomRows"
$bomRowEntityType = "BomRow"

#TODO: Raw material handling
# The properties 'Raw Quantity' and 'Raw Number' must be setup in Vault to enable this feature
$rawMaterialNumberProperty = "Raw Number"
$rawMaterialQuantityProperty = "Raw Quantity"

#region BOM Header
function GetErpBomHeader($number) {
    Log -Begin
    $erpBomHeader = Get-ERPObject -EntitySet $bomHeaderEntitySet -Keys @{Number = $number } -Expand "BomRows"
	$result = Get-PgsErrorForLastResponse -Entity $erpBomHeader
    Log -End
    return $result
}

function NewErpBomHeader {
    Log -Begin
    $erpBomHeader = New-ErpObject -EntityType $bomHeaderEntityType
    Log -End
    return $erpBomHeader
}

function CreateErpBomHeader($erpBomHeader) {
    Log -Begin
    #TODO: Property manipulation for bom header create
    $erpBomHeader.ModifiedDate = [DateTime]::Now

    $erpBomHeader = Add-ERPObject -EntitySet $bomHeaderEntitySet -Properties $erpBomHeader
    $result = Get-PgsErrorForLastResponse -Entity $erpBomHeader -WriteOperation
    Log -End
    return $result
}

function UpdateErpBomHeader($erpBomHeader) {
    Log -Begin
    #TODO: Property manipulation for bom header update
    $erpBomHeader.ModifiedDate = [DateTime]::Now

    $erpBomHeader = Update-ERPObject -EntitySet $bomHeaderEntitySet -keys $erpBomHeader._Keys -Properties $erpBomHeader._Properties
    $result = Get-PgsErrorForLastResponse -Entity $erpBomHeader -WriteOperation
    Log -End
    return $result
}
#endregion

#region BOM Row
function GetErpBomRow($parentNumber, $childNumber, $position) {
    Log -Begin
    $erpBomRow = Get-ERPObject -EntitySet $bomRowEntitySet -Keys @{ParentNumber = $parentNumber; ChildNumber = $childNumber; Position = $position }
    $result = Get-PgsErrorForLastResponse -Entity $erpBomRow
    Log -End
    return $result
}

function NewErpBomRow {
    Log -Begin
    $erpBomRow = New-ErpObject -EntityType $bomRowEntityType
    Log -End
    return $erpBomRow
}

function CreateErpBomRow($erpBomRow) {
    Log -Begin
    #TODO: Property manipulation for bom row create
    $erpBomRow.ModifiedDate = [DateTime]::Now

    $erpBomRow = Add-ERPObject -EntitySet $bomRowEntitySet -Properties $erpBomRow
    $result = Get-PgsErrorForLastResponse -Entity $erpBomRow -WriteOperation
    Log -End
    return $result
}

function UpdateErpBomRow($ErpBomRow, $VaultEntity) {
    Log -Begin
    #TODO: Property manipulation for bom row update
    $ErpBomRow.ModifiedDate = [DateTime]::Now

	$updateProperties = @{
		Quantity = [double]$VaultEntity.Bom_Quantity
	}
    $updatedErpBomRow = Update-ERPObject -EntitySet $bomRowEntitySet -Keys $ErpBomRow._Keys -Properties $updateProperties
    $result = Get-PgsErrorForLastResponse -Entity $updatedErpBomRow -WriteOperation

    Log -End
    return $result
}

function RemoveErpBomRow($parentNumber, $childNumber, $position) {
    Log -Begin
    $erpBomRow = Remove-ERPObject -EntitySet $bomRowEntitySet -Keys @{ParentNumber = $parentNumber; ChildNumber = $childNumber; Position = $position }
    $result = Get-PgsErrorForLastResponse -Entity $erpBomRow -WriteOperation
    Log -End
    return $result
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

function CompareErpBom {
    param($VaultBom)

    $differences = @()
    $number = GetEntityNumber -entity $VaultBom
	if(-not $number) {
		$differences += New-Object -Type PsObject -Property @{AffectedObject = $VaultBom; Status = "Error"; Message = "There is no erp material linked to this entity!"; IsHeader = $true }
		foreach ($vaultBomRow in $VaultBom.Children) {
			$differences += New-Object -Type PsObject -Property @{AffectedObject = $vaultBomRow; Status = "Error"; Message = "BOM head has no linked erp material!"; IsHeader = $false }
		}

		return ,$differences
	}

	$getErpBomHeaderResult = GetErpBomHeader -number $number
	if($getErpBomHeaderResult.ErrorMessage) {
		Log -Message "Error in GetErpBomHeader $($getErpBomHeaderResult.ErrorMessage)"
		$differences += New-Object -Type PsObject -Property @{AffectedObject = $VaultBom; Status = "Error"; Message = $getErpBomHeaderResult.ErrorMessage; IsHeader = $true }
		foreach ($vaultBomRow in $VaultBom.Children) {
			$differences += New-Object -Type PsObject -Property @{AffectedObject = $vaultBomRow; Status = "Error"; Message = $getErpBomHeaderResult.ErrorMessage; IsHeader = $false }
		}

		Log -Message "Return differences error in GetERpBomHeader. $($getErpBomHeaderResult.ErrorMessage)"
		return ,$differences
	}

	if (-not $getErpBomHeaderResult.Entity) { # bomhead new
		Log -Message "Bomheader doesn't exist yet!"

        $differences += New-Object -Type PsObject -Property @{AffectedObject = $VaultBom; Status = "New"; Message = "BOM does not exist in ERP"; IsHeader = $true }

        foreach ($vaultBomRow in $VaultBom.Children) {
            $childNumber = GetEntityNumber -entity $vaultBomRow

			$getErpMaterialResult = GetErpMaterial -number $childNumber
			if($getErpMaterialResult.ErrorMessage) {
				Log -Message "Error in GetErpMaterial $($getErpMaterialResult.ErrorMessage)"
				$differences += New-Object -Type PsObject -Property @{AffectedObject = $vaultBomRow; Status = "Error"; Message = $getErpMaterialResult.ErrorMessage; IsHeader = $false }
				$differences += New-Object -Type PsObject -Property @{AffectedObject = $VaultBom; Status = "Error"; Message = $getErpMaterialResult.ErrorMessage; IsHeader = $true }
			}
			elseif (-not $getErpMaterialResult.Entity) { # material doesn't exist yet
				Log -Message "Error Erpmaterial doesn't exist yet! BomNumber $($childNumber)"
				$differences += New-Object -Type PsObject -Property @{AffectedObject = $vaultBomRow; Status = "Error"; Message = "Position doesn't exist as Item in ERP"; IsHeader = $false }
				$differences += New-Object -Type PsObject -Property @{AffectedObject = $VaultBom; Status = "Error"; Message = "BOM contains positions that do not exist as Items in ERP"; IsHeader = $true }
			}
            else {
                $differences += New-Object -Type PsObject -Property @{AffectedObject = $vaultBomRow; Status = "New"; Message = "Position will be added to ERP"; IsHeader = $false }
            }
        }
		Log -Message "Return differences new bomhead"
		return ,$differences
    }

	# bomhead exists
	Log -Message "Bom head exists! Check if rows need to be added/updated"

	$differences += New-Object -Type PsObject -Property @{AffectedObject = $VaultBom; Status = "Identical"; Message = "BOM is identical between Vault and ERP"; IsHeader = $true } 
	foreach ($vaultBomRow in $VaultBom.Children) {
		$childNumber = GetEntityNumber -entity $vaultBomRow
		$erpBomRow = $getErpBomHeaderResult.Entity.BomRows | Where-Object { $_.ChildNumber -eq $childNumber -and $_.Position -eq $vaultBomRow.Bom_PositionNumber }
		if ($erpBomRow) {
			if ($vaultBomRow.Bom_Quantity -eq $erpBomRow.Quantity) {
				$differences += New-Object -Type PsObject -Property @{AffectedObject = $vaultBomRow; Status = "Identical"; Message = "Position is identical"; IsHeader = $false } 
			}
			else {
				$differences += New-Object -Type PsObject -Property @{AffectedObject = $vaultBomRow; Status = "Different"; Message = "Quantity is different: '$($vaultBomRow.Bom_Quantity) <> $($erpBomRow.Quantity)'"; IsHeader = $false } 
				$differences += New-Object -Type PsObject -Property @{AffectedObject = $VaultBom; Status = "Different"; Message = "BOMs are different between Vault and ERP!"; IsHeader = $true } 
			}

			continue
		}

		$childNumber = GetEntityNumber -entity $vaultBomRow
		$getErpMaterialResult = GetErpMaterial -number $childNumber
		if($getErpMaterialResult.ErrorMessage) {
			Log -Message "Error in GetErpMaterial $($getErpMaterialResult.ErrorMessage)"
			$differences += New-Object -Type PsObject -Property @{AffectedObject = $vaultBomRow; Status = "Error"; Message = $getErpMaterialResult.ErrorMessage; IsHeader = $false }
			$differences += New-Object -Type PsObject -Property @{AffectedObject = $VaultBom; Status = "Error"; Message = $getErpMaterialResult.ErrorMessage; IsHeader = $true }
		}
		elseif (-not $getErpMaterialResult.Entity) {
			Log -Message "Error Erpmaterial doesn't exist yet! BomNumber $($childNumber)"
			$differences += New-Object -Type PsObject -Property @{AffectedObject = $vaultBomRow; Status = "Error"; Message = "Position doesn't exist as Item in ERP"; IsHeader = $false }
			$differences += New-Object -Type PsObject -Property @{AffectedObject = $VaultBom; Status = "Error"; Message = "BOM contains positions that do not exist as Items in ERP"; IsHeader = $true }
		}
		else {
			Log -Message "Bomrow is new!"
			$differences += New-Object -Type PsObject -Property @{AffectedObject = $vaultBomRow; Status = "New"; Message = "Position will be added to ERP"; IsHeader = $false }
			$differences += New-Object -Type PsObject -Property @{AffectedObject = $VaultBom; Status = "Different"; Message = "BOMs are different between Vault and ERP!"; IsHeader = $true }
		}
	}
	foreach ($erpBomRow in $getErpBomHeaderResult.Entity.BomRows) {
		$vaultBomRow = $VaultBom.Children | Where-Object { (GetEntityNumber -entity $_) -eq $erpBomRow.ChildNumber -and $_.Bom_PositionNumber -eq $erpBomRow.Position }
		if ($null -eq $vaultBomRow) {
			$remove = @{
				'Part Number'        = $erpBomRow.ChildNumber
				'_PartNumber'        = $erpBomRow.ChildNumber
				'Name'               = $erpBomRow.ChildNumber
				'_Name'              = $erpBomRow.ChildNumber
				'Number'             = $erpBomRow.ChildNumber
				'_Number'            = $erpBomRow.ChildNumber
				'Bom_Number'         = $erpBomRow.ChildNumber
				'Bom_Name'           = $erpBomRow.ChildNumber
				'Bom_Quantity'       = $erpBomRow.Quantity
				'Bom_Position'       = $erpBomRow.Position
				'Bom_PositionNumber' = $erpBomRow.Position
			}

			$differences += New-Object -Type PsObject -Property @{AffectedObject = $remove; Status = "Remove"; Message = "Position will be deleted in ERP"; IsHeader = $false; Parent = $VaultBom } 
			$differences += New-Object -Type PsObject -Property @{AffectedObject = $VaultBom; Status = "Different"; Message = "BOM rows are different between Vault and ERP!"; IsHeader = $true } 
		}
	}

    return ,$differences
}

#endregion