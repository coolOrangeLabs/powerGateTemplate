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
    $erpBomHeader = Edit-ResponseWithErrorMessage -Entity $erpBomHeader
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
    $erpBomHeader = Edit-ResponseWithErrorMessage -Entity $erpBomHeader -WriteOperation
    Log -End
    return $erpBomHeader
}

function UpdateErpBomHeader($erpBomHeader) {
    Log -Begin
    #TODO: Property manipulation for bom header update
    $erpBomHeader.ModifiedDate = [DateTime]::Now

    $erpBomHeader = Update-ERPObject -EntitySet $bomHeaderEntitySet -keys $erpBomHeader._Keys -Properties $erpBomHeader._Properties
    $erpBomHeader = Edit-ResponseWithErrorMessage -Entity $erpBomHeader -WriteOperation
    Log -End
    return $erpBomHeader
}
#endregion

#region BOM Row
function GetErpBomRow($parentNumber, $childNumber, $position) {
    Log -Begin
    $erpBomRow = Get-ERPObject -EntitySet $bomRowEntitySet -Keys @{ParentNumber = $parentNumber; ChildNumber = $childNumber; Position = $position }
    $erpBomRow = Edit-ResponseWithErrorMessage -Entity $erpBomRow
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
    $erpBomRow = Edit-ResponseWithErrorMessage -Entity $erpBomRow -WriteOperation
    Log -End
    return $erpBomRow
}

function UpdateErpBomRow($erpBomRow) {
    Log -Begin
    #TODO: Property manipulation for bom row update
    $erpBomRow.ModifiedDate = [DateTime]::Now

    $erpBomRow = Update-ERPObject -EntitySet $bomRowEntitySet -Keys $erpBomRow._Keys -Properties @{Quantity = $erpBomRow.Quantity }
    $erpBomRow = Edit-ResponseWithErrorMessage -Entity $erpBomRow -WriteOperation
    Log -End
    return $erpBomRow
}

function RemoveErpBomRow($parentNumber, $childNumber, $position) {
    Log -Begin
    $erpBomRow = Remove-ERPObject -EntitySet $bomRowEntitySet -Keys @{ParentNumber = $parentNumber; ChildNumber = $childNumber; Position = $position }
    $erpBomRow = Edit-ResponseWithErrorMessage -Entity $erpBomRow -WriteOperation
    Log -End
    return $erpBomRow
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
                    'Part Number'        = $entity.$rawMaterialNumberProperty; 
                    '_PartNumber'        = $entity.$rawMaterialNumberProperty; 
                    'Name'               = $entity.$rawMaterialNumberProperty; 
                    '_Name'              = $entity.$rawMaterialNumberProperty; 
                    'Number'             = $entity.$rawMaterialNumberProperty; 
                    '_Number'            = $entity.$rawMaterialNumberProperty; 
                    'Bom_Number'         = $entity.$rawMaterialNumberProperty; 
                    'Bom_Quantity'       = $entity.$rawMaterialQuantityProperty; 
                    'Bom_Position'       = '1'; 
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
        $bomRows = @(Get-VaultItemBom -Number $entity._Number)
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

function CompareErpBom {
    param($entityBom)

    $differences = @()
    $number = GetEntityNumber -entity $entityBom
    $erpBomHeader = GetErpBomHeader -number $number
    if ($false -eq $erpBomHeader -and $erpBomHeader._ErrorMessage){
        $differences += New-Object -Type PsObject -Property @{
            AffectedObject = $entityBom;
            Status = "Error";
            Message = "failed to import BOM Header from ERP Server";
            IsHeader = $true 
        }
    }
    elseif (-not $erpBomHeader) {
            $differences += New-Object -Type PsObject -Property @{
                AffectedObject = $entityBom;
                Status = "New";
                Message = "BOM does not exist in ERP";
                IsHeader = $true
            } 
            foreach ($entityBomRow in $entityBom.Children) {
                $childNumber = GetEntityNumber -entity $entityBomRow
                $erpMaterial = GetErpMaterial -number $childNumber
                if (-not $erpMaterial -or $false -eq $erpMaterial) {
                    $differences += New-Object -Type PsObject -Property @{AffectedObject = $entityBomRow; Status = "Error"; Message = "Position doesn't exist as Item in ERP"; IsHeader = $false } 
                    $differences += New-Object -Type PsObject -Property @{AffectedObject = $entityBom; Status = "Error"; Message = "BOM contains positions that do not exist as Items in ERP"; IsHeader = $true } 
                }
                else {
                    $differences += New-Object -Type PsObject -Property @{AffectedObject = $entityBomRow; Status = "New"; Message = "Position will be added to ERP"; IsHeader = $false } 
                }
            }
    }
    else {
        $differences += New-Object -Type PsObject -Property @{AffectedObject = $entityBom; Status = "Identical"; Message = "BOM is identical between Vault and ERP"; IsHeader = $true } 
        foreach ($entityBomRow in $entityBom.Children) {
            $childNumber = GetEntityNumber -entity $entityBomRow
            $erpBomRow = $erpBomHeader.BomRows | Where-Object { $_.ChildNumber -eq $childNumber -and $_.Position -eq $entityBomRow.Bom_PositionNumber }
            if ($null -ne $erpBomRow) {
                if ($entityBomRow.Bom_Quantity -eq $erpBomRow.Quantity) {
                    $differences += New-Object -Type PsObject -Property @{AffectedObject = $entityBomRow; Status = "Identical"; Message = "Position is identical"; IsHeader = $false } 
                }
                else {
                    $differences += New-Object -Type PsObject -Property @{AffectedObject = $entityBomRow; Status = "Different"; Message = "Quantity is different: '$($entityBomRow.Bom_Quantity) <> $($erpBomRow.Quantity)'"; IsHeader = $false } 
                    $differences += New-Object -Type PsObject -Property @{AffectedObject = $entityBom; Status = "Different"; Message = "BOMs are different between Vault and ERP!"; IsHeader = $true } 
                }
            }
            else {
                $childNumber = GetEntityNumber -entity $entityBomRow
                $erpMaterial = GetErpMaterial -number $childNumber
                if (-not $erpMaterial -or $false -eq $erpMaterial) {
                    $differences += New-Object -Type PsObject -Property @{AffectedObject = $entityBomRow; Status = "Error"; Message = "Position doesn't exist as Item in ERP"; IsHeader = $false } 
                    $differences += New-Object -Type PsObject -Property @{AffectedObject = $entityBom; Status = "Error"; Message = "BOM contains positions that do not exist as Items in ERP"; IsHeader = $true } 
                }
                else {
                    $differences += New-Object -Type PsObject -Property @{AffectedObject = $entityBomRow; Status = "New"; Message = "Position will be added to ERP"; IsHeader = $false } 
                    $differences += New-Object -Type PsObject -Property @{AffectedObject = $entityBom; Status = "Different"; Message = "BOMs are different between Vault and ERP!"; IsHeader = $true } 
                }
            }
        }
        foreach ($erpBomRow in $erpBomHeader.BomRows) {
            $entityBomRow = $entityBom.Children | Where-Object { (GetEntityNumber -entity $_) -eq $erpBomRow.ChildNumber -and $_.Bom_PositionNumber -eq $erpBomRow.Position }
            if ($null -eq $entityBomRow) {
                $remove = @{
                    'Part Number'        = $erpBomRow.ChildNumber; 
                    '_PartNumber'        = $erpBomRow.ChildNumber; 
                    'Name'               = $erpBomRow.ChildNumber; 
                    '_Name'              = $erpBomRow.ChildNumber; 
                    'Number'             = $erpBomRow.ChildNumber; 
                    '_Number'            = $erpBomRow.ChildNumber; 
                    'Bom_Number'         = $erpBomRow.ChildNumber; 
                    'Bom_Name'           = $erpBomRow.ChildNumber; 
                    'Bom_Quantity'       = $erpBomRow.Quantity; 
                    'Bom_Position'       = $erpBomRow.Position;
                    'Bom_PositionNumber' = $erpBomRow.Position
                }

                $differences += New-Object -Type PsObject -Property @{AffectedObject = $remove; Status = "Remove"; Message = "Position will be deleted in ERP"; IsHeader = $false; Parent = $entityBom } 
                $differences += New-Object -Type PsObject -Property @{AffectedObject = $entityBom; Status = "Different"; Message = "BOM rows are different between Vault and ERP!"; IsHeader = $true } 
            }
        }
    }
	
    return , $differences
}

#endregion