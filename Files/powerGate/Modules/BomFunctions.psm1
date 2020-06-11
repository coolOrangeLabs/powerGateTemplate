$bomHeaderEntitySet = "BomHeaders"
$bomHeaderEntityType = "BomHeader"

$bomRowEntitySet = "BomRows"
$bomRowEntityType = "BomRow"

#region BOM Header
function GetErpBomHeader($number) {
	Log -Begin
	$erpBomHeader = Get-ERPObject -EntitySet $bomHeaderEntitySet -Keys @{Number = $number } -Expand "BomRows"
	$erpBomHeader = CheckResponse -entity $erpBomHeader
	Log -End
	return $erpBomHeader
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
	$erpBomHeader = CheckResponse -entity $erpBomHeader
	Log -End
	return $erpBomHeader
}

function UpdateErpBomHeader($erpBomHeader) {
	Log -Begin
	#TODO: Property manipulation for bom header update
	$erpBomHeader.ModifiedDate = [DateTime]::Now

	$erpBomHeader = Update-ERPObject -EntitySet $bomHeaderEntitySet -keys $erpBomHeader._Keys -Properties $erpBomHeader._Properties
	$erpBomHeader = CheckResponse -entity $erpBomHeader
	Log -End
	return $erpBomHeader
}
#endregion

#region BOM Row
function GetErpBomRow($parentNumber, $childNumber, $position) {
	Log -Begin
	$erpBomRow = Get-ERPObject -EntitySet $bomRowEntitySet -Keys @{ParentNumber = $parentNumber; ChildNumber = $childNumber; Position = $position }
	$erpBomRow = CheckResponse -entity $erpBomRow
	Log -End
	return $erpBomRow
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
	$erpBomRow = CheckResponse -entity $erpBomRow
	Log -End
	return $erpBomRow
}

function UpdateErpBomRow($erpBomRow) {
	Log -Begin
	#TODO: Property manipulation for bom row update
	$erpBomRow.ModifiedDate = [DateTime]::Now

	$erpBomRow = Update-ERPObject -EntitySet $bomRowEntitySet -Keys $erpBomRow._Keys -Properties @{Quantity = $erpBomRow.Quantity }
	$erpBomRow = CheckResponse -entity $erpBomRow
	Log -End
	return $erpBomRow
}

function RemoveErpBomRow($parentNumber, $childNumber, $position) {
	Log -Begin
	$erpBomRow = Remove-ERPObject -EntitySet $bomRowEntitySet -Keys @{ParentNumber = $parentNumber; ChildNumber = $childNumber; Position = $position }
	$erpBomRow = CheckResponse -entity $erpBomRow
	Log -End
	return $erpBomRow
}
#endregion

#region Common Bom comparison logic

function Get-VaultBomRowsForEntity {
	param($entity)

    if ($null -eq $entity._EntityTypeID) { return @() }
    if ($entity._EntityTypeID -eq "File") {
        if ($entity._Extension -eq 'ipt') { 
            #TODO: Raw material handling
            # The properties 'Raw Quantity' and 'Raw Number' must be setup in Vault to enable this feature
            if ($entity.'Raw Quantity' -gt 0 -and $entity.'Raw Number' -ne "") {
                # Raw Material
                $rawMaterial = New-Object PsObject -Property @{
                    'Part Number'        = $entity.'Raw Number'; 
                    '_PartNumber'        = $entity.'Raw Number'; 
                    'Name'               = $entity.'Raw Number'; 
                    '_Name'              = $entity.'Raw Number'; 
                    'Number'             = $entity.'Raw Number'; 
                    '_Number'            = $entity.'Raw Number'; 
                    'Bom_Number'         = $entity.'Raw Number'; 
                    'Bom_Quantity'       = $entity.'Raw Quantity'; 
                    'Bom_Position'       = '1'; 
                    'Bom_PositionNumber' = '1' 
                }
                return @($rawMaterial)
            }
            return @()
        }
        #if($entity._FullPath -eq $null) { return @() } #due to a bug in the beta version.
        $bomRows = Get-VaultFileBom -File $entity._FullPath -GetChildrenBy LatestVersion
    } else {
        if ($entity._Category -eq 'Part') { return @() }
        $bomRows = Get-VaultItemBom -Number $entity._Number
    }
    
    foreach ($entityBomRow in $bomRows) {
        if ($entityBomRow.Bom_XrefTyp -eq "Internal") {
            # Virtual Component
            Add-Member -InputObject $entityBomRow -Name "_Name" -Value $entityBomRow.'Bom_Part Number' -MemberType NoteProperty -Force
            Add-Member -InputObject $entityBomRow -Name "Part Number" -Value $entityBomRow.'Bom_Part Number' -MemberType NoteProperty -Force
            Add-Member -InputObject $entityBomRow -Name "_PartNumber" -Value $entityBomRow.'Bom_Part Number' -MemberType NoteProperty -Force
            Add-Member -InputObject $entityBomRow -Name "_Number" -Value $entityBomRow.'Bom_Part Number' -MemberType NoteProperty -Force
            Add-Member -InputObject $entityBomRow -Name "Number" -Value $entityBomRow.'Bom_Part Number' -MemberType NoteProperty -Force
        }
    }
    return $bomRows
}


function Get-VaultToErpBomsDifferences {
	param($vaultBomHeaders)

	$differences = @()
	#TODO manni schun?
	[array]::Reverse($vaultBomHeaders)

    foreach ($entityBom in $vaultBomHeaders) {
        $number = GetEntityNumber -entity $entityBom
        $erpBomHeader = GetErpBomHeader -number $number
        if ($erpBomHeader -eq $false) {
			$differences += New-Object -Type PsObject -Property @{AffectedObject = $bomRow; Status = "Error"; Message = $fehlermeldung; IsHeader = $false} 
            Update-BomWindowEntity $entityBom -Status "New" -Tooltip "BOM does not exist in ERP. Will be created."
            foreach ($entityBomRow in $entityBom.Children) {
                $erpMaterial = GetErpMaterial -number $number
                if ($erpMaterial) {
					Update-BomWindowEntity $entityBomRow -Status "New" -Tooltip "Position will be added to ERP"
					$differences += New-Object -Type PsObject -Property @{AffectedObject = $bomRow; Status = "Error"; Message = $fehlermeldung; IsHeader = $false} 
                } else {
                    Update-BomWindowEntity $entityBomRow -Status "Error" -Tooltip "Position doesn't exist as Item in ERP"
					Update-BomWindowEntity $entityBom -Status "Error" -Tooltip "BOM contains positions that do not exist as Items in ERP"
					$differences += New-Object -Type PsObject -Property @{AffectedObject = $bomRow; Status = "Error"; Message = $fehlermeldung; IsHeader = $false} 
					$differences += New-Object -Type PsObject -Property @{AffectedObject = $bomRow; Status = "Error"; Message = $fehlermeldung; IsHeader = $false} 
                }
            }
        }
        else {
			Update-BomWindowEntity $entityBom -Status "Identical" -Tooltip "BOM is identical between Vault and ERP"
			$differences += New-Object -Type PsObject -Property @{AffectedObject = $bomRow; Status = "Error"; Message = $fehlermeldung; IsHeader = $false} 
            foreach ($entityBomRow in $entityBom.Children) {
                $childNumber = GetEntityNumber -entity $entityBomRow
                $erpBomRow = $erpBomHeader.BomRows | Where-Object { $_.ChildNumber -eq $childNumber -and $_.Position -eq $entityBomRow.Bom_PositionNumber }
                if ($null -ne $erpBomRow) {
                    if ($entityBomRow.Bom_Quantity -eq $erpBomRow.Quantity) {
						Update-BomWindowEntity $entityBomRow -Status "Identical" -Tooltip "Position is identical"
						$differences += New-Object -Type PsObject -Property @{AffectedObject = $bomRow; Status = "Error"; Message = $fehlermeldung; IsHeader = $false} 
                    } else {
                        Update-BomWindowEntity $entityBomRow -Status "Different" -Tooltip "Quantity is different: '$($entityBomRow.Bom_Quantity) <> $($erpBomRow.Quantity)'"
						Update-BomWindowEntity $entityBom -Status "Different" -Tooltip "BOMs are different between Vault and ERP!"
						$differences += New-Object -Type PsObject -Property @{AffectedObject = $bomRow; Status = "Error"; Message = $fehlermeldung; IsHeader = $false} 
						$differences += New-Object -Type PsObject -Property @{AffectedObject = $bomRow; Status = "Error"; Message = $fehlermeldung; IsHeader = $false} 
                    }
                } else {
                    $erpMaterial = GetErpMaterial -number $number
                    if ($erpMaterial) {
                        Update-BomWindowEntity $entityBomRow -Status "New" -Tooltip "Position will be added to ERP"
						Update-BomWindowEntity $entityBom -Status "Different" -Tooltip "BOMs are different between Vault and ERP!"
						$differences += New-Object -Type PsObject -Property @{AffectedObject = $bomRow; Status = "Error"; Message = $fehlermeldung; IsHeader = $false} 
						$differences += New-Object -Type PsObject -Property @{AffectedObject = $bomRow; Status = "Error"; Message = $fehlermeldung; IsHeader = $false} 
                    } else {
                        Update-BomWindowEntity $entityBomRow -Status "Error" -Tooltip "Position doesn't exist as Item in ERP"
						Update-BomWindowEntity $entityBom -Status "Error" -Tooltip "BOM contains positions that do not exist as Items in ERP"
						$differences += New-Object -Type PsObject -Property @{AffectedObject = $bomRow; Status = "Error"; Message = $fehlermeldung; IsHeader = $false} 
						$differences += New-Object -Type PsObject -Property @{AffectedObject = $bomRow; Status = "Error"; Message = $fehlermeldung; IsHeader = $false} 
                    }
                }
            }
            foreach ($erpBomRow in $erpBomHeader.BomRows) {
                $entityBomRow = $entityBom.Children | Where-Object { (GetEntityNumber -entity $_) -eq $erpBomRow.ChildNumber -and $_.Bom_PositionNumber -eq $erpBomRow.Position }
                if ($null -eq $entityBomRow) {
					#TODO MANNI
                    $remove = Add-BomWindowEntity  -Parent $entityBom -Type BomRow -Properties @{
                        'Part Number' = $erpBomRow.ChildNumber; 
                        '_PartNumber' = $erpBomRow.ChildNumber; 
                        'Name' = $erpBomRow.ChildNumber; 
                        '_Name' = $erpBomRow.ChildNumber; 
                        'Number' = $erpBomRow.ChildNumber; 
                        '_Number' = $erpBomRow.ChildNumber; 
                        'Bom_Number' = $erpBomRow.ChildNumber; 
                        'Bom_Name' = $erpBomRow.ChildNumber; 
                        'Bom_Quantity' = $erpBomRow.Quantity; 
                        'Bom_Position' = $erpBomRow.Position;
                        'Bom_PositionNumber' = $erpBomRow.Position
                    }
                    Update-BomWindowEntity $remove -Status "Remove" -Tooltip "Position will be deleted in ERP"
					Update-BomWindowEntity $entityBom -Status "Different" -Tooltip "BOM rows are different between Vault and ERP!"
					$differences += New-Object -Type PsObject -Property @{AffectedObject = $bomRow; Status = "Error"; Message = $fehlermeldung; IsHeader = $false} 
					$differences += New-Object -Type PsObject -Property @{AffectedObject = $bomRow; Status = "Error"; Message = $fehlermeldung; IsHeader = $false} 
                }
            }
        }
    }
}


#endregion