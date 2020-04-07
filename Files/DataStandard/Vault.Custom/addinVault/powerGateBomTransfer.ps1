function ShowBomWindow {
    $entity = GetSelectedObject
    Show-BomWindow -Entity $entity
    RefreshView
}

#region BOm Window functions: 
#https://www.coolorange.com/wiki/doku.php?id=powergate:code_reference:commandlets:show-bomwindow:required_functions
function Get-BomRows($entity) {
    if ($null -eq $entity._EntityTypeID) { return @() }
    if ($entity._EntityTypeID -eq "File") {
        if ($entity._Extension -eq 'ipt') { 
            #TODO: Raw material handling
            # The properties 'Raw Quantity' and 'Raw Number' must be setup in Vault to enable this feature
            if ($entity.'Raw Quantity' -gt 0 -and $entity.'Raw Number' -ne "") {
                # Raw Material
                $rawMaterial = New-Object PsObject -Property @{
                    'Part Number' = $entity.'Raw Number'; 
                    '_PartNumber' = $entity.'Raw Number'; 
                    'Name' = $entity.'Raw Number'; 
                    '_Name' = $entity.'Raw Number'; 
                    'Number' = $entity.'Raw Number'; 
                    '_Number' = $entity.'Raw Number'; 
                    'Bom_Number' = $entity.'Raw Number'; 
                    'Bom_Quantity' = $entity.'Raw Quantity'; 
                    'Bom_Position' = '1'; 
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

function Check-Items($entities) {
    foreach ($entity in $entities) {
        $number = GetEntityNumber -entity $entity
        if ($null -eq $number -or $number -eq "") {
            #Update-BomWindowEntity $entity -Status "Error" -Tooltip "Part Number is empty!"
            Update-BomWindowEntity $entity -Status "New" -Tooltip "Item does not exist in ERP. Will be created."
            continue
        }
        $erpMaterial = GetErpMaterial -number $number
        if ($erpMaterial) {
            $differences = CompareErpMaterial -erpMaterial $erpMaterial -vaultEntity $entity
            if ($differences) {
                Update-BomWindowEntity $entity -Status "Different" -Tooltip $differences
            }
            else {
                Update-BomWindowEntity $entity -Status "Identical" -Tooltip "Item is identical between Vault and ERP"
            }
        }
        else {
            #TODO: check if obligatory fields are filled!
            if ($missing) {
                Update-BomWindowEntity $entity -Status "Error" -Tooltip $missing
            }
            else {
                Update-BomWindowEntity $entity -Status "New" -Tooltip "Item does not exist in ERP. Will be created."
            }
        }
    }
}

function Transfer-Items($entities) {
    foreach ($entity in $entities) {
        if ($entity._Status -eq "New") {
            $erpMaterial = NewErpMaterial
            $erpMaterial = PrepareErpMaterial -erpMaterial $erpMaterial -vaultEntity $entity
            $erpMaterial = CreateErpMaterial -erpMaterial $erpMaterial
            SetEntityProperties -erpMaterial $erpMaterial
            if ($erpMaterial) {
                Update-BomWindowEntity $entity -Status "Identical" -Properties $entity
            }
            else {
                Update-BomWindowEntity $entity -Status "Error" -Tooltip $erpMaterial._ErrorMessage
            }
        }
        elseif ($entity._Status -eq "Different") {
            $erpMaterial = NewErpMaterial
            $erpMaterial = PrepareErpMaterial -erpMaterial $erpMaterial -vaultEntity $entity
            $erpMaterial = UpdateErpMaterial -erpMaterial $erpMaterial
            if ($erpMaterial) {
                Update-BomWindowEntity $entity -Status "Identical"
            }
            else {
                Update-BomWindowEntity $entity -Status "Error" -Tooltip $erpMaterial._ErrorMessage
            }
        }
        else {
            Update-BomWindowEntity $entity -Status $entity._Status
        }
    }
}

function Check-Boms($entityBoms) {
    foreach ($entityBom in $entityBoms) {
        $number = GetEntityNumber -entity $entityBom
        $erpBomHeader = GetErpBomHeader -number $number
        if ($erpBomHeader -eq $false) {
            Update-BomWindowEntity $entityBom -Status "New" -Tooltip "BOM does not exist in ERP. Will be created."
            foreach ($entityBomRow in $entityBom.Children) {
                $erpMaterial = GetErpMaterial -number $number
                if ($erpMaterial) {
                    Update-BomWindowEntity $entityBomRow -Status "New" -Tooltip "Position will be added to ERP"
                } else {
                    Update-BomWindowEntity $entityBomRow -Status "Error" -Tooltip "Position doesn't exist as Item in ERP"
                    Update-BomWindowEntity $entityBom -Status "Error" -Tooltip "BOM contains positions that do not exist as Items in ERP"
                }
            }
        }
        else {
            Update-BomWindowEntity $entityBom -Status "Identical" -Tooltip "BOM is identical between Vault and ERP"
            foreach ($entityBomRow in $entityBom.Children) {
                $childNumber = GetEntityNumber -entity $entityBomRow
                $erpBomRow = $erpBomHeader.BomRows | Where-Object { $_.ChildNumber -eq $childNumber -and $_.Position -eq $entityBomRow.Bom_PositionNumber }
                if ($null -ne $erpBomRow) {
                    if ($entityBomRow.Bom_Quantity -eq $erpBomRow.Quantity) {
                        Update-BomWindowEntity $entityBomRow -Status "Identical" -Tooltip "Position is identical"
                    }
                    else {
                        Update-BomWindowEntity $entityBomRow -Status "Different" -Tooltip "Quantity is different: '$($entityBomRow.Bom_Quantity) <> $($erpBomRow.Quantity)'"
                        Update-BomWindowEntity $entityBom -Status "Different" -Tooltip "BOMs are different between Vault and ERP!"
                    }
                }
                else {
                $erpMaterial = GetErpMaterial -number $number
                    if ($erpMaterial) {
                        Update-BomWindowEntity $entityBomRow -Status "New" -Tooltip "Position will be added to ERP"
                        Update-BomWindowEntity $entityBom -Status "Different" -Tooltip "BOMs are different between Vault and ERP!"
                    } else {
                        Update-BomWindowEntity $entityBomRow -Status "Error" -Tooltip "Position doesn't exist as Item in ERP"
                        Update-BomWindowEntity $entityBom -Status "Error" -Tooltip "BOM contains positions that do not exist as Items in ERP"
                    }
                }
            }
            foreach ($erpBomRow in $erpBomHeader.BomRows) {
                $entityBomRow = $entityBom.Children | Where-Object { (GetEntityNumber -entity $_) -eq $erpBomRow.ChildNumber -and $_.Bom_PositionNumber -eq $erpBomRow.Position }
                if ($null -eq $entityBomRow) {
                    $remove = Add-BomWindowEntity -Type BomRow -Properties @{'Bom_Number' = $erpBomRow.ChildNumber; 'Name' = $erpBomRow.ChildNumber; 'Bom_Name' = $erpBomRow.ChildNumber; '_Name' = $erpBomRow.ChildNumber; 'Bom_Quantity' = $erpBomRow.Quantity; 'Bom_PositionNumber' = $erpBomRow.Position } -Parent $entityBom
                    Update-BomWindowEntity $remove -Status "Remove" -Tooltip "Position will be deleted in ERP"
                    Update-BomWindowEntity $entityBom -Status "Different" -Tooltip "BOM rows are different between Vault and ERP!"
                }
            }
        }
    }
}

function Transfer-Boms($entityBoms) {
    foreach ($entityBom in $entityBoms) {
        $parentNumber = GetEntityNumber -entity $entityBom
        if ($entityBom._Status -eq "New") {
            $erpBomRows = @()
            foreach ($entityBomRow in $entityBom.Children) {
                $erpBomRow = NewErpBomRow          
                $erpBomRow = PrepareErpBomRow -erpBomRow $erpBomRow -parentNumber $parentNumber -vaultEntity $entityBomRow
                $erpBomRows += $erpBomRow
            }
            $erpBomHeader = NewErpBomHeader   
            $erpBomHeader = PrepareErpBomHeader -erpBomHeader $erpBomHeader -vaultEntity $entityBom
            $erpBomHeader.BomRows = $erpBomRows
            $erpBomHeader = CreateErpBomHeader -erpBomHeader $erpBomHeader
            if ($erpBomHeader) {
                Update-BomWindowEntity $entityBom -Status "Identical"
                foreach ($entityBomRow in $entityBom.Children) {
                    Update-BomWindowEntity $entityBomRow -Status "Identical" -Tooltip ""
                }
            }
            else {
                Update-BomWindowEntity $entityBom -Status "Error" -Tooltip $erpBomHeader._ErrorMessage
                foreach ($entityBomRow in $entityBom.Children) {
                    Update-BomWindowEntity $entityBomRow -Status "Error" -Tooltip $erpBomHeader._ErrorMessage
                }
            }
        } elseif ($entityBom._Status -eq "Different") {
            $bomHeaderStatus = "Identical"
            foreach ($entityBomRow in $entityBom.Children) {
                $childNumber = GetEntityNumber -entity $entityBomRow
                if ($entityBomRow._Status -eq "New") {
                    $erpBomRow = NewErpBomRow          
                    $erpBomRow = PrepareErpBomRow -erpBomRow $erpBomRow -parentNumber $parentNumber -vaultEntity $entityBomRow
                    $erpBomRow = CreateErpBomRow -erpBomRow $erpBomRow
                    if ($erpBomRow) {
                        Update-BomWindowEntity $entityBomRow -Status "Identical" -Tooltip ""
                    }
                    else {
                        Update-BomWindowEntity $entityBomRow -Status "Error" -Tooltip $erpBomRow._ErrorMessage
                        $bomHeaderStatus = "Error"
                    }
                }
                elseif ($entityBomRow._Status -eq "Different") {
                    $erpBomRow = GetErpBomRow -parentNumber $parentNumber -childNumber $childNumber -position $entityBomRow.Bom_PositionNumber             
                    $erpBomRow.Quantity = $entityBomRow.Bom_Quantity
                    $erpBomRow = UpdateErpBomRow -erpBomRow $erpBomRow
                    if ($erpBomRow) {
                        Update-BomWindowEntity $entityBomRow -Status "Identical" -Tooltip ""
                    }
                    else {
                        Update-BomWindowEntity $entityBomRow -Status "Error" -Tooltip $erpBomRow._ErrorMessage
                        $bomHeaderStatus = "Error"
                    }
                }
                elseif ($entityBomRow._Status -eq "Remove") {
                    $erpBomRow = RemoveErpBomRow -parentNumber $parentNumber -childNumber $entityBomRow.Bom_Number -position $entityBomRow.Bom_PositionNumber
                    if ($erpBomRow) {
                        $entityBomRow | Remove-BomWindowEntity
                    }
                    else {
                        Update-BomWindowEntity $entityBomRow -Status "Error" -Tooltip $erpBomRow._ErrorMessage
                        $bomHeaderStatus = "Error"
                    }
                }
                else {
                    Update-BomWindowEntity $entityBomRow -Status $entityBomRow._Status
                }
            }
            Update-BomWindowEntity $entityBom -Status $bomHeaderStatus
        } else {
            # removes the dialog questionmarks for rows that haven't been touched. should be fixed in the core product!
            Update-BomWindowEntity $entityBom -Status $entityBom._Status
            foreach ($entityBomRow in $entityBom.Children) {
                Update-BomWindowEntity $entityBomRow -Status $entityBomRow._Status
            }
        }
    }
}
#endregion