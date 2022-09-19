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

function PrepareBomRowForCreate($ErpBomRow, $VaultEntity) {
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

function CompareErpBom {
    param($VaultBom)

    $differences = @()
    $number = GetEntityNumber -entity $VaultBom
	if(-not $number) {
		

		$vaultBom | Update-BomWindowEntity -Status Error -StatusDetails "There is no erp material linked to this entity!"
        foreach ($vaultBomRow in $VaultBom.Children) {
			$vaultBomRow | Update-BomWindowEntity -Status Error -StatusDetails "BOM head has no linked erp material!"
		}
        return
	}

	$erpBomHeader =  Get-ERPObject -EntitySet "BomHeaders" -Keys @{Number = $number } -Expand "BomRows" #-ErroVariable 'customErrorVariableWorkaroundModuleProblem'
    if ($? -eq $false) {
        foreach ($vaultBomRow in $VaultBom.Children) {
			$vaultBomRow | Update-BomWindowEntity -Status Error -StatusDetails $vaultBOM._StatusDetails #$error[0] bzw $customErrorVariableWorkaroundModuleProblem
		}
        return
    }

	if (-not $erpBomHeader) { # bomhead new
		Log -Message "Bomheader doesn't exist yet!"

        $VaultBom | Update-BomWindowEntity -Status New -StatusDetails "BOM does not exist in ERP"
        foreach ($vaultBomRow in $VaultBom.Children) {
            $childNumber = GetEntityNumber -entity $vaultBomRow
            
            $erpMaterial = Get-ERPObject -EntitySet "Materials" -Keys @{ Number = $childNumber.ToUpper() }
            if ($? -eq $false) {
                $vaultBom | Update-BomWindowEntity -Status Error -StatusDetails $vaultBomRow._StatusDetails
                continue
            }
			if (-not $erpMaterial) { # material doesn't exist yet
				Log -Message "Error Erpmaterial doesn't exist yet! BomNumber $($childNumber)"
				$vaultBomRow | Update-BomWindowEntity -Status Error -StatusDetails "Position doesn't exist as Item in ERP"
                $vaultBom | Update-BomWindowEntity -Status Error -StatusDetails "BOM contains positions that do not exist as Items in ERP"
			}
            else {
                $vaultBomRow | Update-BomWindowEntity -Status New -StatusDetails "Position will be added to ERP"
            }
        }
		Log -Message "Return differences new bomhead"
        return
    }

	# bomhead exists
	Log -Message "Bom head exists! Check if rows need to be added/updated"

    $vaultBom | Update-BomWindowEntity -Status Identical -StatusDetails "BOM is identical between Vault and ERP"
	foreach ($vaultBomRow in $VaultBom.Children) {
		$childNumber = GetEntityNumber -entity $vaultBomRow
		$erpBomRow = $erpBomHeader.BomRows | Where-Object { $_.ChildNumber -eq $childNumber -and $_.Position -eq $vaultBomRow.Bom_PositionNumber }
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
        $erpMaterial = Get-ERPObject -EntitySet "Materials" -Keys @{ Number = $childNumber.ToUpper() }
        if ($? -eq $false) {
            $vaultBom | Update-BomWindowEntity -Status Error -StatusDetails $vaultBomRow._StatusDetails
            continue
        }
		if (-not $erpMaterial) {
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
			

			$differences += New-Object -Type PsObject -Property @{AffectedObject = $remove; Status = "Remove"; Message = "Position will be deleted in ERP"; IsHeader = $false; Parent = $VaultBom } 
            $remove = Add-BomWindowEntity -Parent $VaultBom -Type BomRow -Properties @{
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
            Update-BomWindowEntity $remove -Status Remove -StatusDetails "Position will be deleted in ERP"
			$differences += New-Object -Type PsObject -Property @{AffectedObject = $VaultBom; Status = "Different"; Message = "BOM rows are different between Vault and ERP!"; IsHeader = $true } 
		}
	}

    return ,$differences
}

#endregion